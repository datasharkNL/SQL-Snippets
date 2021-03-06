USE [master]
GO

--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE @SearchText       VARCHAR(8000) = '_SOURCE',
        @DBName           SYSNAME = 'HPG_EDV',
	   @SchemaName       SYSNAME = '',
        @PreviewTextSize  INT = 200,
        @SearchDBsFlag    CHAR(1) = 'Y',
        @SearchJobsFlag   CHAR(1) = 'N',
        @SearchSSISFlag   CHAR(1) = 'N',
        @SearchSPJobsFlag CHAR(1) = 'N',
	   @SearchObjectType SYSNAME = '', --PASS THE "type" VALUE FROM sys.objects TO RESTRICT THE SEARCH TO A PARTICULAR OBJECT
	   @Debug            BIT = 0, --IF 1, PRINT THE DYNAMIC SQL
	   @SQL              NVARCHAR(MAX);

IF OBJECT_ID('tempdb..#FoundObject') IS NOT NULL DROP TABLE #FoundObject;
CREATE TABLE #FoundObject 
(
 DatabaseName   SYSNAME,
 SchemaName     SYSNAME,
 ObjectName     SYSNAME,
 ObjectTypeDesc NVARCHAR(60),
 PreviewText    VARCHAR(MAX)
);--To show a little bit of the code

SET @SearchObjectType = IIF(@SearchObjectType > '', 'type = ' + QUOTENAME(@SearchObjectType, '''') + ' AND ', '');
SET @SchemaName = IIF(@SchemaName > '', 'SCH.name = ' + QUOTENAME(@SchemaName, '''') + ' AND ', '');

SELECT 'Searching For: ''' + @SearchText + '''' AS CurrentSearch;

/******************
  Database Search
******************/
IF @SearchDBsFlag = 'Y'
BEGIN
     IF (@DBName IS NULL OR @DBName = '') --Loop through all normal user databases
     BEGIN
          DECLARE ObjCursor CURSOR LOCAL FAST_FORWARD FOR 
          SELECT name
            FROM master.sys.databases
           WHERE name NOT IN ('Distribution', 'Master', 'MSDB', 'Model', 'TempDB')
             AND LEFT(name, 14) NOT IN ('AdventureWorks','Litespeed')
             AND ISNULL(HAS_DBACCESS(name),0) = 1;
          
          OPEN ObjCursor;
          
          FETCH NEXT FROM ObjCursor INTO @DBName;
          WHILE @@FETCH_STATUS = 0
          BEGIN
               SELECT @SQL = '
               USE [' + @DBName + ']
               
               INSERT INTO #FoundObject 
               (
               DatabaseName,
               SchemaName,
               ObjectName,
               ObjectTypeDesc,
               PreviewText
               )
               SELECT DISTINCT ''' + @DBName + ''',
                      SCH.name,
                      SO.name AS ObjectName,
                      SO.type_desc,
                      REPLACE(REPLACE(SUBSTRING(SM.definition, CHARINDEX(''' + @SearchText + ''', SM.definition) - ' + CAST(@PreviewTextSize / 2 AS VARCHAR) + ', ' + 
                      CAST(@PreviewTextSize AS VARCHAR) + '), CHAR(13) + CHAR(10), ''''), ''' + @SearchText + ''', ''***' + @SearchText + '***'')
                 FROM sys.objects AS SO 
                      INNER JOIN sys.sql_modules AS SM ON SO.object_id = SM.object_id
                      INNER JOIN sys.schemas AS SCH ON SO.schema_id = SCH.schema_id
                WHERE ' + @SearchObjectType + @SchemaName + 'SM.Definition LIKE ''%' + @SearchText + '%'' 
                ORDER BY ObjectName;';
               
			IF @Debug = 1
			   PRINT @SQL
		     ELSE
                  EXEC dbo.sp_executesql @SQL;
               
               SELECT @SQL = '
               USE [' + @DBName + ']
               
               INSERT INTO #FoundObject 
               (
               DatabaseName,
               SchemaName,
               ObjectName,
               ObjectTypeDesc,
               PreviewText
               )
               SELECT DISTINCT ''' + @DBName + ''',
                      SCH.name,
                      IIF(SO.type = ''TT'', STT.name, SO.name) AS ObjectName,
                      SO.type_desc,
                      SC.NAME
                 FROM sys.columns AS SC
                      LEFT JOIN sys.objects AS SO ON SC.object_id = SO.object_id
                      LEFT JOIN sys.table_types AS STT ON SC.object_id = STT.type_table_object_id
                      LEFT JOIN sys.schemas AS SCH ON SCH.schema_id = IIF(SO.type = ''TT'', STT.schema_id, SO.schema_id)
                WHERE ' + @SearchObjectType + @SchemaName + 'SC.NAME = ''' + @SearchText + ''' 
                ORDER BY ObjectName, SC.NAME;';
               
			IF @Debug = 1
			   PRINT @SQL
		     ELSE
                  EXEC dbo.sp_executesql @SQL;

               FETCH NEXT FROM ObjCursor INTO @DBName;
          END; --END OF WHILE LOOP
          
          CLOSE ObjCursor;
          
          DEALLOCATE ObjCursor;
     END --END OF IF "@DBName" BLOCK

     ELSE --Only look through given database
     BEGIN
          SELECT @SQL = '
          USE [' + @DBName + ']
          
          INSERT INTO #FoundObject
          (
          DatabaseName,
          SchemaName,
          ObjectName,
          ObjectTypeDesc,
          PreviewText
          )
          SELECT DISTINCT ''' + @DBName + ''',
                 SCH.name,
                 SO.name AS ObjectName,
                 SO.type_desc,
                 REPLACE(REPLACE(SUBSTRING(SM.definition, CHARINDEX(''' + @SearchText + ''', SM.definition) - ' + CAST(@PreviewTextSize / 2 AS VARCHAR) + ', ' + 
                 CAST(@PreviewTextSize AS VARCHAR) + '), CHAR(13) + CHAR(10), ''''), ''' + @SearchText + ''', ''***' + @SearchText + '***'')
            FROM sys.objects AS SO 
                 INNER JOIN sys.sql_modules AS SM ON SO.object_id = SM.object_id
                 INNER JOIN sys.schemas AS SCH ON SO.schema_id = SCH.schema_id
           WHERE ' + @SearchObjectType + @SchemaName + 'SM.Definition LIKE ''%' + @SearchText + '%'' 
           ORDER BY ObjectName;';
          
		IF @Debug = 1
		   PRINT @SQL
	     ELSE
             EXEC dbo.sp_ExecuteSQL @SQL;
          	
          SELECT @SQL = '
          USE [' + @DBName + ']
          
          INSERT INTO #FoundObject 
          (
          DatabaseName,
          SchemaName,
          ObjectName,
          ObjectTypeDesc,
          PreviewText
          )
          SELECT DISTINCT ''' + @DBName + ''',
                 SCH.name,
                 IIF(SO.type = ''TT'', STT.name, SO.name) AS ObjectName,
                 SO.type_desc,
                 SC.NAME
            FROM sys.columns AS SC
                 LEFT JOIN sys.objects AS SO ON SC.object_id = SO.object_id
                 LEFT JOIN sys.table_types AS STT ON SC.object_id = STT.type_table_object_id
                 LEFT JOIN sys.schemas AS SCH ON SCH.schema_id = IIF(SO.type = ''TT'', STT.schema_id, SO.schema_id)
           WHERE ' + @SearchObjectType + @SchemaName + 'SC.NAME = ''' + @SearchText + ''' 
           ORDER BY ObjectName, SC.NAME;';
          
		IF @Debug = 1
		   PRINT @SQL
	     ELSE
             EXEC dbo.sp_ExecuteSQL @SQL;
		        
     END; --END OF ELSE BLOCK

     SELECT 'DATABASE OBJECTS: FUNCTIONS, SPs, TABLES, VIEWS, TABLE_TYPES' AS SearchType;
     
     SELECT ObjectTypeDesc AS ObjectType,
            DatabaseName,
            SchemaName,
            ObjectName,
            PreviewText
       FROM #FoundObject
      WHERE 1 = 1
	   --AND ObjectName LIKE '%DEA%'
      ORDER BY ObjectType, DatabaseName, SchemaName, ObjectName;    
END --END OF IF "@SearchDBsFlag" BLOCK

/**************
  PROCS Search
**************/
IF @SearchSPJobsFlag = 'Y'
BEGIN
     SELECT 'JOBS THAT FOUND STORED PROCEDURES RUN UNDER' AS SearchType;
	;WITH SP
	 AS
     (SELECT Command,j.[Name] AS [Job Name],
	        s.Step_Id AS [Step #]
        FROM msdb.dbo.sysjobs j
             INNER JOIN msdb.dbo.sysjobsteps s ON j.Job_Id = s.Job_Id
     )
	SELECT DatabaseName,
            SchemaName,
            ObjectName,
            SP.[Job Name],
            SP.[Step #],
            SP.Command AS JobCommand
       FROM #FoundObject FO
            INNER JOIN SP ON SP.Command LIKE '%' + FO.ObjectName + '%'
      WHERE ObjectTypeDesc = 'SQL_STORED_PROCEDURE' 
      ORDER BY DatabaseName, ObjectName, [Job Name];
END

/*************
  Job Search
*************/
IF @SearchJobsFlag = 'Y'
BEGIN
     SELECT 'JOBS AND JOB STEPS' AS SearchType;
     SELECT j.[Name] AS [Job Name],
            s.Step_Id AS [Step #],
            REPLACE(REPLACE(SUBSTRING(s.Command, CHARINDEX(@SearchText, s.Command) - @PreviewTextSize / 2, @PreviewTextSize), CHAR(13) + CHAR(10), ''), @SearchText, '***' + @SearchText + '***')            AS Command
       FROM msdb.dbo.sysjobs j
            INNER JOIN msdb.dbo.sysjobsteps s ON j.Job_Id = s.Job_Id 
      WHERE s.Command LIKE '%' + @SearchText + '%';
END

/**************
  SSIS Search
**************/
IF @SearchSSISFlag = 'Y'
BEGIN
     SELECT 'SSIS PACKAGES' AS SearchType;
     SELECT [Name] AS [SSIS Name],
            REPLACE(REPLACE(SUBSTRING(CAST(CAST(PackageData AS VARBINARY(MAX)) AS VARCHAR(MAX)), CHARINDEX(@SearchText, CAST(CAST(PackageData AS VARBINARY(MAX)) AS VARCHAR(MAX))) -
            @PreviewTextSize / 2, @PreviewTextSize), CHAR(13) + CHAR(10), ''), @SearchText, '***' + @SearchText + '***') AS [SSIS XML]
       FROM msdb.dbo.sysssispackages
      WHERE CAST(CAST(PackageData AS VARBINARY(MAX)) AS VARCHAR(MAX)) LIKE '%' + @SearchText + '%';
END
GO

SET NOCOUNT OFF;
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED;