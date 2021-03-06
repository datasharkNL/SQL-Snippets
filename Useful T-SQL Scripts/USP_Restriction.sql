CREATE PROC [dbo].[USP_Restriction]
@Type VARCHAR(20),
@Mode VARCHAR (30),
@tablename VARCHAR(50) = NULL
AS
BEGIN
SET NOCOUNT ON
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

/* ============================================
-- Author      : Rahul Kr. Ghosh
               : MCITP-DBA 2009
-- Create date : Sep 20 2010  1:34PM
-- Description : STOPPING ALL ROWS UPDATE, DELETE AT ONCE
-- @Type       : 'ALL' if to create trigger in all the tables of the database
               : '1' if to create trigger in the tables of the database but 1 by 1 (table by table)
-- @Mode       : 'Update' if to create update trigger
               : 'Delete' if to create delete trigger
               : 'Both' if to create update and delete (combine) trigger
-- @tablename  : Need to mention the table name if @Type is set to 1
               : Table name need not be mentioned if @Type is set to ALL (cursor will do that)
-- Usage	   : EXEC USP_Restriction 1, 'Update', 'Address'
-- ============================================= */
--getting my tools
DECLARE @U_trgname NVARCHAR(50),
        @U_tblname VARCHAR(50),
        @errdel VARCHAR(50),
        @errupd VARCHAR(50),
        @errboth VARCHAR(50),
        @severity NVARCHAR(5),
        @state NVARCHAR(5),
        @no INT
--setting my tools
SET @no = 1
SET @errupd = 'Cannot update all rows. Use WHERE CONDITION'; --- UPDATE TRIGGER ERROR MSG
SET @errdel = 'Cannot delete all rows. Use WHERE CONDITION'; --- DELETE TRIGGER ERROR MSG
SET @errboth = 'Cannot update or delete all rows. Use WHERE CONDITION'; --- UPDATE & DELETE TRIGGER ERROR MSG
SET @severity = '16'
SET @state = '1'

--IF YOU WANT TO CREATE ON ALL THE TABLES THEN @Type = ALL
IF (@Type = 'All') 
BEGIN 
	--DECALRING MY CURSOR TO GET ALL THE TABLE NAME
	DECLARE U_tablename CURSOR
	FOR
	SELECT name AS [TABLE Name]
	FROM sys.tables
	WHERE [type] = 'U'
	  AND [type_desc] = 'USER_TABLE'
	ORDER BY SCHEMA_ID

	--OPENING IT 
	OPEN U_tablename

	--FETCHING THE TABLE NAME INTO MY VARIABLE
	FETCH NEXT FROM U_tablename 
	INTO @U_tblname

	--IF FETCHING IS OK 
	WHILE (@@FETCH_STATUS = 0)
	BEGIN --cursor start
		-- FORMATTING THE TABLE NAME
		SET @U_tblname = SUBSTRING(@U_tblName,CHARINDEX('.',@U_tblName)+1, LEN(@U_tblName))

		-- IF YOU WANT THE UPDATE TRIGGER THEN @Mode = UPDATE
		IF (@Mode = 'Update')
		BEGIN -- @Mode update begin
			-- GETTING THE TRIGGER NAME
			SET	@U_trgname = '[dbo].[trg_upd_'+ @U_tblName +']'; 

			-- CHECKING IF THE TRIGGER IS ALREADY PRESENT
			IF  NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@U_trgname)) -- checking whether trigger exists
			BEGIN
				-- trigger code start
				DECLARE @strTRGText VARCHAR(MAX)
				SET @strTRGText = '';
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
							SET @strTRGText = @strTRGText +  CHAR(13) + '/*-- ============================================='
							SET @strTRGText = @strTRGText +  CHAR(13) + '-- Author      : Rahul Kr. Ghosh'
							SET @strTRGText = @strTRGText +  CHAR(13) + '               : MCITP-DBA 2009'
							SET @strTRGText = @strTRGText +  CHAR(13) + '-- Create date : ' + CONVERT(VARCHAR(20),GETDATE())
							SET @strTRGText = @strTRGText +  CHAR(13) + '-- Description : STOPPING THE UPDATE OF ALL ROWS AT A STRESS IN TABLE '  + @U_tblName
							SET @strTRGText = @strTRGText +  CHAR(13) + '-- ============================================= */'
				-- creating the update trigger code
				SET @strTRGText = @strTRGText +  CHAR(13) + 'CREATE TRIGGER ' + @U_trgname
				SET @strTRGText = @strTRGText +  CHAR(13) + 'ON ' + @U_tblname
				SET @strTRGText = @strTRGText +  CHAR(13) + 'FOR UPDATE AS'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'BEGIN' 
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'DECLARE @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' INT'
				SET @strTRGText = @strTRGText +  CHAR(13) + 'SET @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' = @@ROWCOUNT;'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'IF @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' >= (SELECT SUM(row_count)' 
				SET @strTRGText = @strTRGText +  CHAR(13) + 'FROM sys.dm_db_partition_stats'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @U_tblname + ''')'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'AND index_id = (select index_id from sys.dm_db_partition_stats' 
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @U_tblname + ''') AND index_id = 1))'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'BEGIN'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'RAISERROR('''+ @errupd + ''',' + @severity +',' + @state +')'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'ROLLBACK TRANSACTION' 
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'RETURN;'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'END'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + 'END'
				SET @strTRGText = @strTRGText +  CHAR(13) + ''
				SET @strTRGText = @strTRGText +  CHAR(13) + ''

				EXEC(@strTRGText);
				PRINT 'TRIGGER GOT CREATED ON ' + @U_tblname + ' TABLE!!!!!! '
				PRINT 'Trigger done (update)'
				SET @no = @no+1
			END -- trigger code end

			-- IF THE TRIGGER IS ALREADY CREATED
			ELSE
				PRINT 'Sorry!!  ' + @U_trgname + ' Already exists in the database... '
			END 
			-----------------------------------------------------------------------------------------------------------------
		ELSE
		-- IF YOU WANT THE DELETE TRIGGER THEN @Mode = DELETE
		IF (@Mode = 'DELETE')
		BEGIN -- @Mode delete begins
			-- GETTING THE TRIGGER NAME
			SET	@U_trgname = '[dbo].[trg_del_'+ @U_tblName +']'; 

			-- CHECKING IF THE TRIGGER IS ALREADY PRESENT
			IF  NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@U_trgname)) 
			BEGIN
				-- trigger code start
				DECLARE @strTRGText1 VARCHAR(MAX)
				SET @strTRGText1 = '';
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
							SET @strTRGText1 = @strTRGText1 +  CHAR(13) + '/*-- ============================================='
							SET @strTRGText1 = @strTRGText1 +  CHAR(13) + '-- Author      : Rahul Kr. Ghosh'
							SET @strTRGText1 = @strTRGText1 +  CHAR(13) + '               : MCITP-DBA 2009'
							SET @strTRGText1 = @strTRGText1 +  CHAR(13) + '-- Create date : ' + CONVERT(VARCHAR(20),GETDATE())
							SET @strTRGText1 = @strTRGText1 +  CHAR(13) + '-- Description : STOPPING THE DELETE OF ALL ROWS AT A STRESS IN TABLE '  + @U_tblName
							SET @strTRGText1 = @strTRGText1 +  CHAR(13) + '-- ============================================= */'
				-- creating the update trigger code
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'CREATE TRIGGER ' + @U_trgname
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'ON ' + @U_tblname
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'FOR DELETE AS'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'BEGIN' 
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'DECLARE @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' INT'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'SET @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' = @@ROWCOUNT;'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'IF @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' >= (SELECT SUM(row_count)' 
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'FROM sys.dm_db_partition_stats'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @U_tblname + ''')'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'AND index_id = (select index_id from sys.dm_db_partition_stats' 
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @U_tblname + ''') AND index_id = 1))'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'BEGIN'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'RAISERROR('''+ @errdel + ''',' + @severity +',' + @state +')'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'ROLLBACK TRANSACTION' 
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'RETURN;'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'END'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + 'END'
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''
				SET @strTRGText1 = @strTRGText1 +  CHAR(13) + ''

				EXEC(@strTRGText1);
				PRINT 'TRIGGER GOT CREATED ON ' + @U_tblname + ' TABLE!!!!!! '
				PRINT 'Trigger done (DELETE)'
				SET @no = @no+1
			END -- trigger code end

			-- IF THE TRIGGER IS ALREADY CREATED
			ELSE
				PRINT 'Sorry!!  ' + @U_trgname + ' Already exists in the database... '
			END 
			--------------------------------------------------------------------------------------------------------------------
		ELSE
		-- IF YOU WANT THE BOTH (UPDATE AND DELETE) TRIGGER THEN @Mode = BOTH
		IF (@Mode = 'BOTH')
		BEGIN -- @Mode both begins
			-- GETTING THE TRIGGER NAME
			SET	@U_trgname = '[dbo].[trg_DelUpd_'+ @U_tblName +']'; 

			-- CHECKING IF THE TRIGGER IS ALREADY PRESENT
			IF  NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@U_trgname)) 
			BEGIN
				-- trigger code start
				DECLARE @strTRGText2 VARCHAR(MAX)
				SET @strTRGText2 = '';
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
							SET @strTRGText2 = @strTRGText2 +  CHAR(13) + '/*-- ============================================='
							SET @strTRGText2 = @strTRGText2 +  CHAR(13) + '-- Author      : Rahul Kr. Ghosh'
							SET @strTRGText2 = @strTRGText2 +  CHAR(13) + '               : MCITP-DBA 2009'
							SET @strTRGText2 = @strTRGText2 +  CHAR(13) + '-- Create date : ' + CONVERT(VARCHAR(20),GETDATE())
							SET @strTRGText2 = @strTRGText2 +  CHAR(13) + '-- Description : STOPPING THE UPDATE AND DELETE OF ALL ROWS AT A STRESS IN TABLE '  + @U_tblName
							SET @strTRGText2 = @strTRGText2 +  CHAR(13) + '-- ============================================= */'
				-- creating the update trigger code
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'CREATE TRIGGER ' + @U_trgname
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'ON ' + @U_tblname
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'FOR UPDATE , DELETE AS'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'BEGIN' 
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'DECLARE @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' INT'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'SET @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' = @@ROWCOUNT;'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'IF @Count_'+CONVERT(VARCHAR (MAX) , @no)+ ' >= (SELECT SUM(row_count)' 
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'FROM sys.dm_db_partition_stats'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @U_tblname + ''')'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'AND index_id = (select index_id from sys.dm_db_partition_stats' 
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @U_tblname + ''') AND index_id = 1))'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'BEGIN'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'RAISERROR('''+ @errboth + ''',' + @severity +',' + @state +')'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'ROLLBACK TRANSACTION' 
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'RETURN;'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'END'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + 'END'
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''
				SET @strTRGText2 = @strTRGText2 +  CHAR(13) + ''

				EXEC(@strTRGText2);
				PRINT 'TRIGGER GOT CREATED ON ' + @U_tblname + ' TABLE!!!!!! '
				PRINT 'Trigger done (UPDATE & DELETE)'
				SET @no = @no+1
			END -- trigger code end

			-- IF THE TRIGGER IS ALREADY CREATED
			ELSE
				PRINT 'Sorry!!  ' + @U_trgname + ' Already exists in the database... '
			END 
			--------------------------------------------------------------------------------------------------------------------
		-- GETTING THE NEXT TABLE NAME
		FETCH NEXT FROM U_tablename 
		INTO  @U_tblname
	END --cursor end

	CLOSE U_tablename
		DEALLOCATE U_tablename
	END
	------------------------------------------------------------------------------------------------------------------
ELSE 
--IF YOU WANT TO CREATE TRIGGER IN TABLES 1 BY 1 THEN @Type = 1
IF (@Type = '1') 
BEGIN 
	-- IF YOU WANT THE UPDATE TRIGGER THEN @Mode = UPDATE
	IF (@Mode = 'Update')
	BEGIN 
		--CHECKING WHETHER THE TABLE NAME GIVEN IS PRESENT IN TTHE DATABASE OR USER HAVE PASSED A NULL VALUE
		IF (@tablename IS NOT NULL AND @tablename IN (SELECT name AS [TABLE Name] FROM sys.tables) )
		BEGIN
			-- FORMATTING THE TABLE NAME
			SET @tablename = SUBSTRING(@tablename,CHARINDEX('.',@tablename)+1, LEN(@tablename))
			-- GETTING THE TRIGGER NAME
			SET	@U_trgname = '[dbo].[trg_upd_'+ @tablename +']';
			-- CHECKING IF THE TRIGGER IS ALREADY PRESENT
			IF  NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@U_trgname))
			BEGIN
				DECLARE @strTRGText3 VARCHAR(MAX)
				SET @strTRGText3 = '';
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
							SET @strTRGText3 = @strTRGText3 +  CHAR(13) + '/*-- ============================================='
							SET @strTRGText3 = @strTRGText3 +  CHAR(13) + '-- Author      : Rahul Kr. Ghosh'
							SET @strTRGText3 = @strTRGText3 +  CHAR(13) + '               : MCITP-DBA 2009'
							SET @strTRGText3 = @strTRGText3 +  CHAR(13) + '-- Create date : ' + CONVERT(VARCHAR(20),GETDATE())
							SET @strTRGText3 = @strTRGText3 +  CHAR(13) + '-- Description : STOPPING THE UPDATE OF ALL ROWS AT A STRESS '  + @tablename
							SET @strTRGText3 = @strTRGText3 +  CHAR(13) + '-- ============================================= */'
				-- creating the update trigger code

				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'CREATE TRIGGER ' + @U_trgname
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'ON ' + @tablename
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'FOR UPDATE AS'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'BEGIN' 
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'DECLARE @Count INT'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'SET @Count = @@ROWCOUNT;'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'IF @Count >= (SELECT SUM(row_count)' 
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'FROM sys.dm_db_partition_stats'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @tablename + ''')'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'AND index_id = (select index_id from sys.dm_db_partition_stats' 
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @tablename + ''') and index_id = 1))'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'BEGIN'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'RAISERROR('''+ @errupd + ''',' + @severity +',' + @state +')'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'ROLLBACK TRANSACTION' 
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'RETURN;'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'END'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + 'END'
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''
				SET @strTRGText3 = @strTRGText3 +  CHAR(13) + ''

				EXEC(@strTRGText3);
				PRINT 'TRIGGER GOT CREATED ON ' + @tablename + ' TABLE!!!!!! '
				PRINT 'Trigger done (update)' 
			END
			ELSE
				PRINT 'Sorry!!  ' + @U_trgname + ' Already exists in the database... '
			END
		ELSE 
			PRINT 'The table name is not present in current database, or null value has been passed'
		END
	--------------------------------------------------------------------------------------------------------------------
	ELSE
	-- IF YOU WANT THE DELETE TRIGGER THEN @Mode = DELETE
	IF (@Mode = 'Delete')
	BEGIN
		--CHECKING WHETHER THE TABLE NAME GIVEN IS PRESENT IN THE DATABASE OR USER HAVE PASSED A NULL VALUE
		IF (@tablename IS NOT NULL AND @tablename IN (SELECT name AS [TABLE Name] FROM sys.Tables) )
		BEGIN
			-- FORMATTING THE TABLE NAME
			SET @tablename = SUBSTRING(@tablename,CHARINDEX('.',@tablename)+1, LEN(@tablename))
			-- GETTING THE TRIGGER NAME
			SET	@U_trgname = '[dbo].[trg_del_'+ @tablename +']';
			-- CHECKING IF THE TRIGGER IS ALREADY PRESENT
			IF  NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@U_trgname))
			BEGIN
				DECLARE @strTRGText4 VARCHAR(MAX)
				SET @strTRGText4 = '';
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
							SET @strTRGText4 = @strTRGText4 +  CHAR(13) + '/*-- ============================================='
							SET @strTRGText4 = @strTRGText4 +  CHAR(13) + '-- Author      : Rahul Kr. Ghosh'
							SET @strTRGText4 = @strTRGText4 +  CHAR(13) + '               : MCITP-DBA 2009'
							SET @strTRGText4 = @strTRGText4 +  CHAR(13) + '-- Create date : ' + CONVERT(VARCHAR(20),GETDATE())
							SET @strTRGText4 = @strTRGText4 +  CHAR(13) + '-- Description : STOPPING THE DELETE OF ALL ROWS AT A STRESS '  + @tablename
							SET @strTRGText4 = @strTRGText4 +  CHAR(13) + '-- ============================================= */'
				-- creating the update trigger code

				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'CREATE TRIGGER ' + @U_trgname
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'ON ' + @tablename
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'FOR DELETE AS'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'BEGIN' 
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'DECLARE @Count INT'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'SET @Count = @@ROWCOUNT;'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'IF @Count >= (SELECT SUM(row_count)' 
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'FROM sys.dm_db_partition_stats'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @tablename + ''')'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'AND index_id = (select index_id from sys.dm_db_partition_stats' 
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @tablename + ''') and index_id = 1))'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'BEGIN'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'RAISERROR('''+ @errupd + ''',' + @severity +',' + @state +')'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'ROLLBACK TRANSACTION' 
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'RETURN;'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'END'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + 'END'
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''
				SET @strTRGText4 = @strTRGText4 +  CHAR(13) + ''

				EXEC(@strTRGText4);
				PRINT 'TRIGGER GOT CREATED ON ' + @tablename + ' TABLE!!!!!! '
				PRINT 'Trigger done (delete)' 
			END
			ELSE
				PRINT 'Sorry!!  ' + @U_trgname + ' Already exists in the database... '
			END
		ELSE 
			PRINT 'The table name is not present in current database, or null value has been passed'
		END
		-------------------------------------------------------------------------------------------------------------------
		ELSE 
		-- IF YOU WANT THE BOTH (UPDATE AND DELETE) TRIGGER THEN @Mode = BOTH
		IF (@Mode = 'Both')
		BEGIN
			--CHECKING WHETHER THE TABLE NAM EGIVEN IS PRESENT INT THE DATABASE OR USER HAVE PASSED A NULL VALUE
			IF (@tablename IS NOT NULL AND @tablename IN (SELECT name AS [TABLE Name] FROM sys.Tables) )
			BEGIN
				-- FORMATTING THE TABLE NAME
				SET @tablename = SUBSTRING(@tablename,CHARINDEX('.',@tablename)+1, LEN(@tablename))
				-- GETTING THE TRIGGER NAME
				SET	@U_trgname = '[dbo].[trg_delupd_'+ @tablename +']';
				-- CHECKING IF THE TRIGGER IS ALREADY PRESENT
				IF  NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(@U_trgname))
				BEGIN
					DECLARE @strTRGText5 VARCHAR(MAX)
					SET @strTRGText5 = '';
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
								SET @strTRGText5 = @strTRGText5 +  CHAR(13) + '/*-- ============================================='
								SET @strTRGText5 = @strTRGText5 +  CHAR(13) + '-- Author      : Rahul Kr. Ghosh'
								SET @strTRGText5 = @strTRGText5 +  CHAR(13) + '               : MCITP-DBA 2009'
								SET @strTRGText5 = @strTRGText5 +  CHAR(13) + '-- Create date : ' + CONVERT(VARCHAR(20),GETDATE())
								SET @strTRGText5 = @strTRGText5 +  CHAR(13) + '-- Description : STOPPING THE UPDATE AND DELETE OF ALL ROWS AT A STRESS '  + @tablename
								SET @strTRGText5 = @strTRGText5 +  CHAR(13) + '-- ============================================= */'
					-- creating the update trigger code

					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'CREATE TRIGGER ' + @U_trgname
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'ON ' + @tablename
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'FOR UPDATE , DELETE AS'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'BEGIN' 
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'DECLARE @Count INT'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'SET @Count = @@ROWCOUNT;'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'IF @Count >= (SELECT SUM(row_count)' 
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'FROM sys.dm_db_partition_stats'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @tablename + ''')'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'AND index_id = (select index_id from sys.dm_db_partition_stats' 
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'WHERE OBJECT_ID = OBJECT_ID(''' + @tablename + ''') and index_id = 1))'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'BEGIN'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'RAISERROR('''+ @errupd + ''',' + @severity +',' + @state +')'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'ROLLBACK TRANSACTION' 
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'RETURN;'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'END'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + 'END'
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''
					SET @strTRGText5 = @strTRGText5 +  CHAR(13) + ''

					EXEC(@strTRGText5);
					PRINT 'TRIGGER GOT CREATED ON ' + @tablename + ' TABLE!!!!!! '
					PRINT 'Trigger done (update & delete)' 
				END
				ELSE
					PRINT 'Sorry!!  ' + @U_trgname + ' Already exists in the database... '
				END
			ELSE 
				PRINT 'The table name is not present in current database, or null value has been passed'
			END
	END
END
SET NOCOUNT OFF