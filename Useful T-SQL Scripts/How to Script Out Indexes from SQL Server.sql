/*
 ===============================================================================
 Author:	     Kendra Little
 Source:       https://www.littlekendra.com/2016/05/05/how-to-script-out-indexes-from-sql-server/
 Article Name: How to Script Out Indexes from SQL Server
 Create Date:  05-MAY-2016
 Description:  This script analyses the data.	
 Revision History:
 04-JAN-2016 - RAGHUNANDAN CUMBAKONAM
			 - Formatted the code.
			 - Added the history.
			 - Added the CTE CREATE_INDEX.
			 - Added is_included & type_desc columns.
			 - Added linefeed to the CREATE/ALTER statements.
 Usage:		N/A			   
 ===============================================================================
*/
SET NOCOUNT ON;

;WITH CREATE_INDEX
AS
(
SELECT DB_NAME() AS database_name,
       sc.name AS [schema_name],
	  t.name AS table_name,
       (SELECT MAX(user_reads) 
          FROM (VALUES (last_user_seek), (last_user_scan), (last_user_lookup)) AS value(user_reads)
	  ) AS last_user_read,
       last_user_update,
	  si.type_desc,
       CASE si.index_id 
	       WHEN 0 THEN N'/* No create statement (Heap) */'
            ELSE CASE is_primary_key 
		            WHEN 1 THEN N'ALTER TABLE ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + CHAR(13) + N'ADD CONSTRAINT ' + QUOTENAME(si.name) + N' PRIMARY KEY ' + IIF(si.index_id > 1, N'NON', N'') + N'CLUSTERED '
                      ELSE N'CREATE ' + IIF(si.is_unique = 1, N'UNIQUE ', N'') + IIF(si.index_id > 1, N'NON', N'') + N'CLUSTERED ' + N'INDEX ' + QUOTENAME(si.name) + N' ON ' + QUOTENAME(sc.name) + N'.' + QUOTENAME(t.name) + N' '
                 END
                +
                 /* key def */ N'(' + key_definition + N')' +
                 /* includes */ IIF(include_definition IS NOT NULL, CHAR(13) + N'INCLUDE (' + include_definition + N')', N'') +
                 /* filters */ IIF(filter_definition IS NOT NULL, CHAR(13) + N'WHERE ' + filter_definition, N'') +
                 /* with clause - compression goes here */
                 CASE WHEN row_compression_partition_list IS NOT NULL OR page_compression_partition_list IS NOT NULL 
                      THEN N' WITH (' + CASE WHEN row_compression_partition_list IS NOT NULL
		 	       				     THEN N'DATA_COMPRESSION  =  ROW ' + IIF(psc.name IS NULL, N'', + N' ON PARTITIONS (' + row_compression_partition_list + N')')
		 	       				     ELSE N''
		 	       				END
		 	       			   + IIF(row_compression_partition_list IS NOT NULL AND page_compression_partition_list IS NOT NULL, N', ', N'')
		 	       			   + CASE WHEN page_compression_partition_list IS NOT NULL
		 	       			          THEN N'DATA_COMPRESSION  =  PAGE ' + IIF(psc.name IS NULL, N'', + N' ON PARTITIONS (' + page_compression_partition_list + N')')
                                             ELSE N''
                                        END
                                      + N')'
                      ELSE N''
                 END
                +
                 /* ON where? filegroup? partition scheme? */
                 CHAR(13) + 'ON ' + IIF(psc.name IS NULL, COALESCE(QUOTENAME(fg.name), N''), psc.name + N' (' + partitioning_column.column_name + N')')
                + N';'
       END AS index_create_statement,
       si.index_id,
       si.name AS index_name,
       si.is_unique,
	  si.has_filter,
	  IIF(include_definition IS NOT NULL, 1, 0) AS is_included,
       partition_sums.reserved_in_row_GB,
       partition_sums.reserved_LOB_GB,
       partition_sums.row_count,
       stat.user_seeks,
       stat.user_scans,
       stat.user_lookups,
       user_updates AS queries_that_modified,
       partition_sums.partition_count,
       si.allow_page_locks,
       si.allow_row_locks,
       si.is_hypothetical,       
       si.fill_factor,
       COALESCE(pf.name, '/* Not partitioned */') AS partition_function,
       COALESCE(psc.name, fg.name) AS partition_scheme_or_filegroup,
       t.create_date AS table_created_date,
       t.modify_date AS table_modify_date
  FROM sys.indexes AS si
       INNER JOIN sys.tables AS t ON si.object_id = t.object_id
       INNER JOIN sys.schemas AS sc ON t.schema_id = sc.schema_id
       LEFT JOIN sys.dm_db_index_usage_stats AS stat ON stat.database_id  =  DB_ID() 
             AND si.object_id = stat.object_id 
             AND si.index_id = stat.index_id
       LEFT JOIN sys.partition_schemes AS psc ON si.data_space_id = psc.data_space_id
       LEFT JOIN sys.partition_functions AS pf ON psc.function_id = pf.function_id
       LEFT JOIN sys.filegroups AS fg ON si.data_space_id = fg.data_space_id
       /* Key list */
	  OUTER APPLY (SELECT STUFF (
                                  (SELECT N', ' + QUOTENAME(c.name) +
                                          CASE ic.is_descending_key WHEN 1 THEN N' DESC' ELSE N'' END
                                     FROM sys.index_columns AS ic 
                                          INNER JOIN sys.columns AS c ON ic.column_id = c.column_id  
                                                 AND ic.object_id = c.object_id
                                    WHERE ic.object_id  =  si.object_id
                                      AND ic.index_id = si.index_id
                                      AND ic.key_ordinal > 0
                                    ORDER BY ic.key_ordinal FOR XML PATH(''), TYPE
                                  ).value('.', 'NVARCHAR(MAX)'),
                                  1, 2, ''
                                 ) AS key_definition
                   ) AS keys
	  /* Partitioning Ordinal */
	  OUTER APPLY (SELECT MAX(QUOTENAME(c.name)) AS column_name
                      FROM sys.index_columns AS ic 
                           INNER JOIN sys.columns AS c ON ic.column_id = c.column_id  
                                  AND ic.object_id = c.object_id
                     WHERE ic.object_id  =  si.object_id
                       AND ic.index_id = si.index_id
                       AND ic.partition_ordinal = 1
			    ) AS partitioning_column
	  /* Include list */
       OUTER APPLY (SELECT STUFF (
                                  (SELECT N', ' + QUOTENAME(c.name)
                                     FROM sys.index_columns AS ic 
                                          INNER JOIN sys.columns AS c ON ic.column_id = c.column_id  
                                                 AND ic.object_id = c.object_id
                                    WHERE ic.object_id  =  si.object_id
                                      AND ic.index_id = si.index_id
                                      AND ic.is_included_column  =  1
                                    ORDER BY c.name FOR XML PATH(''), TYPE
                                  ).value('.', 'NVARCHAR(MAX)'),
						    1, 2, ''
                                 ) AS include_definition
                   ) AS includes
	  /* Partitions */
	  OUTER APPLY (SELECT COUNT(*) AS partition_count,
                           CAST(SUM(ps.in_row_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_in_row_GB,
                           CAST(SUM(ps.lob_reserved_page_count)*8./1024./1024. AS NUMERIC(32,1)) AS reserved_LOB_GB,
                           SUM(ps.row_count) AS row_count
                      FROM sys.partitions AS p
                           INNER JOIN sys.dm_db_partition_stats AS ps ON p.partition_id = ps.partition_id
                     WHERE p.object_id = si.object_id
                       AND p.index_id = si.index_id
                   ) AS partition_sums
	  /* row compression list by partition */
	  OUTER APPLY (SELECT STUFF (
                                  (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
                                     FROM sys.partitions AS p
                                    WHERE p.object_id = si.object_id
                                      AND p.index_id = si.index_id
                                      AND p.data_compression = 1
                                    ORDER BY p.partition_number FOR XML PATH(''), TYPE
                                  ).value('.', 'NVARCHAR(MAX)'),
                                  1, 2, ''
                                 ) AS row_compression_partition_list
                   ) AS row_compression_clause
	  /* data compression list by partition */
	  OUTER APPLY (SELECT STUFF (
                                  (SELECT N', ' + CAST(p.partition_number AS VARCHAR(32))
                                     FROM sys.partitions AS p
                                    WHERE p.object_id  =  si.object_id
                                      AND p.index_id = si.index_id
                                      AND p.data_compression = 2
                                    ORDER BY p.partition_number FOR XML PATH(''), TYPE
                                  ).value('.', 'NVARCHAR(MAX)'),
                                  1, 2, ''
                                 ) AS page_compression_partition_list
                   ) AS page_compression_clause
 WHERE 1 = 1
   AND si.type IN (0, 1, 2) /* heap, clustered, nonclustered */
)
SELECT *
  FROM CREATE_INDEX 
 WHERE 1 = 1
   AND [schema_name] = 'wrk'
   AND table_name  =  'InvPOMemberDataPass1'
   --AND is_unique = 0
   --AND has_filter = 1
   --AND is_included = 1
 ORDER BY table_name, index_id
OPTION (RECOMPILE)
;

SET NOCOUNT OFF;