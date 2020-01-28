CREATE PROCEDURE [dbo].[sp_AG_Secondary_DropDBs] @Debug BIT=0
AS
/******************************************************************************
*  Stored Procedure Name: sp_AG_DropDBs
*  Input Parameters: none
*  Optional Parameters: @Debug
*  Use Case: exec sp_AG_Secondary_DropDBs or exec sp_AG_Secondary_DropDBs @Debug=1
*  Description: Loops through user databases, and any database with a create 
*  older than 30 days remove from the AG, and delete from the secondary servers
*
*
*  History:
*  Date:		Action:								Developer: 
*  2019-10-31	Initial version						Patrick Lee
******************************************************************************/

DECLARE @MaxDB INT
DECLARE @MinDB INT
DECLARE @DBName NVARCHAR(50)
DECLARE @SQL NVARCHAR (1000)
--DECLARE @Debug BIT
--SET @Debug = 0


IF OBJECT_ID('tempdb..#databases') IS NOT NULL DROP TABLE #databases

CREATE TABLE #databases
(
	ID INT IDENTITY(1, 1) primary key,
	DBName NVARCHAR(200)
);

-- Get DBs to be dropped from the secondary instancec
INSERT INTO #databases(DBName)
select name from sys.databases where state_desc = 'RESTORING'

/*------------------------------------------------------------------ Get databases to be removed from the secondary instance ------------------------------------------------------------------*/
/*---------- Get min and max IDs from the #databases table ----------*/
SELECT @MaxDB=MAX(ID), @MinDB=MIN(ID) FROM #databases

-- Loop through the databases and perform processes against them
WHILE (@MaxDB >= @MinDB)
	BEGIN
		
		-- Get Recovery Model of the Database
		SELECT @DBName=DBName FROM #databases where ID = @MinDB

		SET @SQL='DROP DATABASE ['+@DBName+'];'
		IF @Debug = 1
			PRINT @SQL
		ELSE
			EXEC sp_executeSQL @SQL

		-- Loop to the next record
		set @MinDB +=1

	END
