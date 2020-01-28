CREATE PROCEDURE [dbo].[sp_AG_DropDBs] @Debug BIT=0
AS
/******************************************************************************
*  Stored Procedure Name: sp_AG_DropDBs
*  Input Parameters: none
*  Optional Parameters: @Debug
*  Use Case: exec sp_AG_DropDBs or exec sp_AG_DropDBs @Debug=1
*  Description: Loops through user databases, and any database with a create 
*  older than 30 days remove from the AG, and delete from the secondary servers
*
*
*  History:
*  Date:		Action:								Developer: 
*  2019-10-30	Initial version						Patrick Lee
******************************************************************************/

DECLARE @MaxDB INT
DECLARE @MinDB INT
DECLARE @MaxRepl INT
DECLARE @MinRepl INT
DECLARE @AGName NVARCHAR(25)
DECLARE @AGGroupID NVARCHAR(40)
DECLARE @ReplName NVARCHAR(50)
DECLARE @DBName NVARCHAR(50)
DECLARE @SQL NVARCHAR(1000)
DECLARE @DropSQL NVARCHAR(1000)
--DECLARE @Debug BIT
--SET @Debug = 0

/*---------------------------------------- Temp Tables - Other Main Configurations - Delete Backups ----------------------------------------*/
IF OBJECT_ID('tempdb..#agdatabases') IS NOT NULL DROP TABLE #agdatabases
IF OBJECT_ID('tempdb..#databases') IS NOT NULL DROP TABLE #databases
IF OBJECT_ID('tempdb..#replicas') IS NOT NULL DROP TABLE #replicas

-- Create temp tables
CREATE TABLE #agdatabases
(
	ID INT IDENTITY(1, 1) primary key,
	DBName NVARCHAR(200),
	GroupID NVARCHAR(40)
);

CREATE TABLE #databases
(
	ID INT IDENTITY(1, 1) primary key,
	DBName NVARCHAR(200)
);

CREATE TABLE #replicas
(
	ID INT IDENTITY(1, 1) primary key,
	AGName NVARCHAR(25),
	ReplName NVARCHAR(200)
);

/*------------------------------------------------------------------ Get Replica / AG Information / Databases already in the AG ------------------------------------------------------------------*/
-- Insert the replica servers into the #replicas table
INSERT INTO #replicas(AGName, ReplName)
SELECT agc.name, rcs.replica_server_name
FROM sys.availability_groups_cluster AS agc
	INNER JOIN sys.dm_hadr_availability_replica_cluster_states AS rcs
		ON rcs.group_id = agc.group_id
	INNER JOIN sys.dm_hadr_availability_replica_states AS ars
		ON ars.replica_id = rcs.replica_id
	INNER JOIN sys.availability_group_listeners AS agl
		ON agl.group_id = ars.group_id
WHERE ars.role_desc <> 'PRIMARY'

-- Get the AG Name
SELECT TOP 1 @AGName=AGName FROM #replicas

-- Get AG Group ID
SELECT @AGGroupID=group_id FROM master.sys.availability_groups_cluster where name = @AGName

-- Insert DB that are already in the AG
--INSERT INTO #agdatabases(GroupID, DBName)
SELECT group_id, database_name FROM master.sys.availability_databases_cluster where group_id = @AGGroupID

INSERT INTO #databases(DBName)
SELECT a.name FROM sys.databases a
	LEFT JOIN #agdatabases b
		on a.name = b.DBName
where a.database_id > 4 and b.DBName IS NULL AND a.name <> 'SQL_Admin' and a.name <> 'settings' and a.replica_id is not null
and a.create_date <= DATEADD(dy,-5,GETDATE())

select * from #databases


/*------------------------------------------------------------------ Get databases to be removed from the AG ------------------------------------------------------------------*/
/*---------- Get min and max IDs from the #databases table ----------*/
SELECT @MaxDB=MAX(ID), @MinDB=MIN(ID) FROM #databases

-- Loop through the databases and perform processes against them
WHILE (@MaxDB >= @MinDB)
	BEGIN
		-- Get Recovery Model of the Database
		SELECT @DBName=DBName FROM #databases where ID = @MinDB

		SET @SQL='USE master; ALTER AVAILABILITY GROUP ['+@AGName+'] REMOVE DATABASE ['+@DBName+'];'
		SET @DropSQL = 'DROP DATABASE ['+@DBName+']; '
		IF @Debug = 1
			PRINT @SQL +' - '+ @DropSQL
		ELSE
			EXEC sp_executeSQL @SQL
			EXEC sp_executeSQL @DropSQL

		-- Loop to the next record
		set @MinDB +=1
	END
