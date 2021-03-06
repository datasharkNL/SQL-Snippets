IF EXISTS (SELECT * FROM sys.sysobjects WHERE name = 'usp_MERGE_Statement_In_SSIS' AND xtype = 'P')
BEGIN
	 DROP PROC usp_MERGE_Statement_In_SSIS
END
GO

CREATE PROCEDURE [usp_MERGE_Statement_In_SSIS]
                 @SrcDB       SYSNAME, --Name of the Source database
                 @SrcSchema   SYSNAME, --Name of the Source schema
                 @SrcTable    SYSNAME, --Name of the Source table
                 @TgtDB       SYSNAME, --Name of the Target database
                 @TgtSchema   SYSNAME, --Name of the Target schema
                 @TgtTable    SYSNAME, --Name of the Target table               
                 @predicate   SYSNAME = NULL,
				 @debug       BIT = 0  --Used to print the Dynamic SQL                                
AS
BEGIN
SET NOCOUNT ON

/*
 ======================================================================
 Author:	  NICHOLAS C. SMITH
 Source:      http://www.sqlservercentral.com/articles/EDW/77100/
 Create Date: 23-JAN-2012
 Description: This stored proc dynamically generates the MERGE 
			  statement outside of the SSIS Execute SQL Task & executes it.	
 Revision History:
 24-JAN-2012 - RAGHUNANDAN CUMBAKONAM Replaced the single quotes with QUOTENAME
 ======================================================================
*/


	DECLARE @merge_sql      NVARCHAR(MAX);  --overall dynamic sql statement for the merge	
	DECLARE @columns_sql    NVARCHAR(MAX);  --the dynamic sql to generate the list of columns used in the update, insert, and insert-values portion of the merge dynamic sql
	DECLARE @pred_sql       NVARCHAR(MAX);	--the dynamic sql to generate the predicate/matching-statement of the merge dynamic sql (populates @pred)
	DECLARE @updt           NVARCHAR(MAX);  --contains the comma-seperated columns used in the UPDATE portion of the merge dynamic sql (populated by @columns_sql)
	DECLARE @insert         NVARCHAR(MAX);  --contains the comma-seperated columns used in the INSERT portion of the merge dynamic sql (populated by @insert_sql)
	DECLARE @vals           NVARCHAR(MAX);  --contains the comma-seperated columns used in the VALUES portion of the merge dynamic sql (populated by @vals_sql)
	DECLARE @pred           NVARCHAR(MAX);  --contains the predicate/matching-statement of the merge dynamic sql (populated by @pred_sql)
	DECLARE @pred_param     NVARCHAR(MAX) = @predicate;
	DECLARE @pred_item      NVARCHAR(MAX);
	DECLARE @done_ind       SMALLINT = 0;
	DECLARE @dsql_param     NVARCHAR(500);  --contains the necessary parameters for the dynamic sql execution
	
	--Create the temporary table to collect all the columns shared 
	--between both the Source and Target tables.
	DECLARE @columns TABLE 
	(                
      table_catalog            VARCHAR(100) NULL,
      table_schema             VARCHAR(100) NULL,
      table_name               VARCHAR(100) NULL,
      column_name              VARCHAR(100) NULL,
      data_type                VARCHAR(100) NULL,
      character_maximum_length INT NULL,
      numeric_precision        INT NULL,
      src_column_path          VARCHAR(100) NULL,
      tgt_column_path          VARCHAR(100) NULL
    )
	
    --Generate the dynamic sql (@columns_sql) statement that will 
    --populate the @columns temp table with the columns that will be used in the merge dynamic sql
	--The @columns table will contain columns that exist in both the source and target 
	--tables that have the same data types.
	
    SET @columns_sql = 
    'SELECT
     tgt.table_catalog,
     tgt.table_schema,
     tgt.table_name,
     tgt.column_name,
     tgt.data_type,
     tgt.character_maximum_length,
     tgt.numeric_precision,
     (src.table_catalog+''.''+src.table_schema+''.''+src.table_name+''.''+src.column_name) AS src_column_path,
     (tgt.table_catalog+''.''+tgt.table_schema+''.''+tgt.table_name+''.''+tgt.column_name) AS tgt_column_path
     FROM
     ' + @TgtDB + '.INFORMATION_SCHEMA.COLUMNS tgt
     INNER JOIN ' + @SrcDB + '.INFORMATION_SCHEMA.COLUMNS src
       ON tgt.column_name = src.column_name
       AND tgt.data_type = src.data_type
       AND (tgt.character_maximum_length IS NULL OR tgt.character_maximum_length >= src.character_maximum_length)
       AND (tgt.numeric_precision IS NULL OR tgt.numeric_precision >= src.numeric_precision)
     WHERE
     tgt.table_catalog     = ' + QUOTENAME(@TgtDB, '''') + '
     AND tgt.table_schema  = ' + QUOTENAME(@TgtSchema, '''') + '
     AND tgt.table_name    = ' + QUOTENAME(@TgtTable, '''') + '
     AND src.table_catalog = ' + QUOTENAME(@SrcDB, '''') + '
     AND src.table_schema  = ' + QUOTENAME(@SrcSchema, '''') + '
     AND src.table_name    = ' + QUOTENAME(@SrcTable, '''') + '
     ORDER BY tgt.ordinal_position'
	 IF @debug = 1 PRINT @columns_sql + CHAR(10) + CHAR(13)

     --execute the @columns_sql dynamic sql and populate @columns table with the data
     INSERT INTO @columns
     EXEC sp_executesql @columns_sql
     
    /****************************************************************************************
     * This generates the matching statement (aka Predicate) statement of the Merge         *                 
     * If a predicate is explicitly passed in, use that to generate the matching statement  *
     * Else execute the @pred_sql statement to decide what to match on and generate the     *    
     * matching statement automatically                                                     *
     ****************************************************************************************/
     
    IF @pred_param IS NOT NULL
      BEGIN
      --if the user passed in a predicate that begins with a comma, strip it out
      SET @pred_param = CASE WHEN SUBSTRING(LTRIM(@pred_param),1,1) = ',' THEN SUBSTRING(@pred_param,(CHARINDEX(',',@pred_param)+1),LEN(@pred_param)) ELSE @pred_param END
      --if the user passed in a predicate that ends with a comma, strip it out
      SET @pred_param = CASE WHEN SUBSTRING(RTRIM(@pred_param),LEN(@pred_param),1) = ',' THEN SUBSTRING(@pred_param,1,LEN(@pred_param)-1) ELSE @pred_param END
      -- loop through the comma-seperated predicate that was passed in via the paramater and construct the predicate statement
      WHILE (@done_ind = 0)
        BEGIN
        SET @pred_item = CASE WHEN CHARINDEX(',',@pred_param) > 0 THEN SUBSTRING(@pred_param,1,(CHARINDEX(',',@pred_param)-1)) ELSE @pred_param END
        SET @pred_param = SUBSTRING(@pred_param,(CHARINDEX(',',@pred_param)+1),LEN(@pred_param))
        SET @pred = CASE WHEN @pred IS NULL THEN (COALESCE(@pred,'') + 'src.[' + @pred_item + '] = ' + 'tgt.[' + @pred_item + ']') ELSE (COALESCE(@pred,'') + ' and ' + 'src.[' + @pred_item + '] = ' + 'tgt.[' + @pred_item + ']') END
        SET @done_ind = CASE WHEN @pred_param = @pred_item THEN 1 ELSE 0 END
        END
      END
	  IF @debug = 1 PRINT @pred_param + CHAR(10) + CHAR(13)
    ELSE
      BEGIN
      SET @pred_sql = ' SELECT @predsqlout = COALESCE(@predsqlout+'' and '','''')+' +
                      '(''''+''src.''+column_name+'' = tgt.''+ccu.column_name)' +
                      ' FROM ' +
                      @TgtDB + '.INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc_tgt' +
                      ' INNER JOIN ' + @TgtDB +'.INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE ccu' +
                      ' ON tc_tgt.CONSTRAINT_NAME = ccu.Constraint_name' +
                      ' AND tc_tgt.table_schema = ccu.table_schema' +
                      ' AND tc_tgt.table_name = ccu.table_name' +
                      ' WHERE' +
                      ' tc_tgt.CONSTRAINT_TYPE = ''Primary Key''' +
                      ' and tc_tgt.table_catalog = ' + QUOTENAME(@TgtDB, '''') + ''
                      ' and tc_tgt.table_name = ' + QUOTENAME(@TgtTable, '''') + ''
                      ' and tc_tgt.table_schema = ' + QUOTENAME(@TgtTable, '''') + ''

       SET @dsql_param = '	@predsqlout nvarchar(max) OUTPUT'
	   IF @debug = 1 PRINT @pred_sql + CHAR(10) + CHAR(13)

       EXEC sp_executesql 
       @pred_sql,
       @dsql_param,
       @predsqlout = @pred OUTPUT;
       END

	/*************************************************************************
	* A Merge statement contains 3 seperate lists of column names            *
	*   1) List of columns used for Update Statement                         *
	*   2) List of columns used for Insert Statement                         *
	*   3) List of columns used for Values portion of the Insert Statement   *
	**************************************************************************/
	--1) List of columns used for Update Statement
	--Populate @updt with the list of columns that will be used to construct the Update Statment portion of the Merge
	
	 SET @updt = CAST((SELECT ',tgt.[' + column_name + '] = src.[' + column_name + ']' 
	                   FROM @columns
	                   WHERE column_name != 'meta_orignl_load_dts'    --we want to filter out this column because we do not want the 
                       FOR XML PATH(''))                              --meta_orginl_load_dts of the target table to be overwritten on updates.  
                       AS NVARCHAR(MAX)                               --we want to preserve the original date/time the row was written out.
	                  )
	 IF @debug = 1 PRINT @updt + CHAR(10) + CHAR(13)

	--2) List of columns used for Insert Statement
	--Populate @insert with the list of columns that will be used to construct the Insert Statment portion of the Merge
	                  
	 SET @insert = CAST((SELECT ',' + '[' + column_name + ']' 
	                   FROM @columns
                       FOR XML PATH(''))
                       AS NVARCHAR(MAX)
	                  )	
	 IF @debug = 1 PRINT @insert + CHAR(10) + CHAR(13)

	--3) List of columns used for Insert-Values Statement
	--Populate @vals with the list of columns that will be used to construct the Insert-Values Statment portion of the Merge	                  
	 SET @vals = CAST((SELECT ',src.' + '[' + column_name + ']'
	                   FROM @columns
                       FOR XML PATH(''))
                       AS NVARCHAR(MAX)
	                  )	       
     IF @debug = 1 PRINT @vals + CHAR(10) + CHAR(13)
    /*************************************************************************************
     *  Generate the final Merge statement using                                         *
     *    -The parameters (@TgtDB, @TgtSchema, @TgtTable, @SrcDB, @SrcSchema, @SrcTable) *
     *    -The predicate matching statement (@pred)                                      *
     *    -The update column list (@updt)                                                *
     *    -The insert column list (@insert)                                              *
     *    -The insert-value column list (@vals)                                          * 
     *************************************************************************************/
     
	SET @merge_sql = (' MERGE INTO ' + @TgtDB + '.' + @TgtSchema + '.' + @TgtTable + ' tgt ' + 
	                  ' USING ' + @SrcDB + '.' + @SrcSchema + '.' + @SrcTable + ' src ' +
	                  ' ON ' + @pred +
	                  ' WHEN MATCHED THEN UPDATE ' + 
	                  ' SET ' + SUBSTRING(@updt, 2, LEN(@updt)) +
	                  ' WHEN NOT MATCHED THEN INSERT (' + SUBSTRING(@insert, 2, LEN(@insert)) + ')' +
	                  ' VALUES ( ' + SUBSTRING(@vals, 2, LEN(@vals)) + ');'
					 );
	IF @debug = 1 PRINT @merge_sql
	--Execute the final Merge statement to merge the staging table into production
	EXEC sp_executesql @merge_sql;

SET NOCOUNT OFF
END;