CREATE PROCEDURE [dbo].[sp_AG_AddDBs] @Debug BIT=0
AS
/******************************************************************************
*  Stored Procedure Name: sp_AG_AddDBs
*  Input Parameters: none
*  Optional Parameters: @Debug
*  Use Case: exec sp_AG_AddDBs or exec sp_AG_AddDBs @Debug=1
*  Description: Loops through user databases, and those that aren't apart of
*  the AG add to the availability group
*
*  Variables: The following varaibles need to be updated manually:
*  @AGName - The name of the AG. Run the query above it to figureout which
*  availability group you need to call out
*
*  History:
*  Date:		Action:										Developer: 
*  2019-10-25	Initial version								Patrick Lee
*  2019-11-4	Update - Commtented out last section		Patrick Lee
******************************************************************************/

DECLARE @MaxDB INT
DECLARE @MinDB INT
DECLARE @MaxRepl INT
DECLARE @MinRepl INT
DECLARE @AGName NVARCHAR(25)
DECLARE @AGGroupID NVARCHAR(40)
DECLARE @ReplName NVARCHAR(50)
DECLARE @DBRecoveryModel NVARCHAR(10)
DECLARE @DBName NVARCHAR(50)
DECLARE @BackupLocation NVARCHAR(500)
DECLARE @BackupFile NVARCHAR (150)
DECLARE @DeleteDate DATETIME = DATEADD(mi,-1,GETDATE());
DECLARE @SQL NVARCHAR(1000)
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
	DBName NVARCHAR(200),
	RecoveryModel NVARCHAR(10),
	InAG BIT
);

CREATE TABLE #replicas
(
	ID INT IDENTITY(1, 1) primary key,
	AGName NVARCHAR(25),
	ReplName NVARCHAR(200)
);

-- Instance default backup location
EXEC master.dbo.xp_instance_regread  N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'BackupDirectory', @BackupLocation OUTPUT, 'no_output'

--  Delete old backups
EXEC master.sys.xp_delete_file 0, @BackupLocation,'BAK',@DeleteDate,0;

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
INSERT INTO #agdatabases(GroupID, DBName)
SELECT group_id, database_name FROM master.sys.availability_databases_cluster where group_id = @AGGroupID


/*------------------------------------------------------------------ Get databases to be added to the AG ------------------------------------------------------------------*/
-- Insert DBs that are not in the AG
INSERT INTO #databases
SELECT a.name, a.recovery_model_desc, 1 FROM sys.databases a
	LEFT JOIN #agdatabases b
		on a.name = b.DBName
where a.database_id > 4 and b.DBName IS NULL AND a.name != 'SQL_Admin' and a.create_date >= DATEADD(dy,-1,GETDATE())


/*------------------------------------------------------------------ Loop Through the databases to be added ------------------------------------------------------------------*/
/*---------- Get min and max IDs from the #databases table ----------*/
SELECT @MaxDB=MAX(ID), @MinDB=MIN(ID) FROM #databases

-- Loop through the databases and perform processes against them
WHILE (@MaxDB >= @MinDB)
BEGIN

	-- Get information about the database
	SELECT @DBRecoveryModel=RecoveryModel, @DBName=DBName FROM #databases where ID = @MinDB

	-- Change Recovery Model if not set to FULL
	IF @DBRecoveryModel = 'Simple'
	Begin	
		SET @SQL='ALTER DATABASE [' + @DBName + ']  SET RECOVERY FULL WITH NO_WAIT';
		IF @Debug = 1
			PRINT @SQL
		ELSE
			EXEC sp_executeSQL @SQL
	END

	-- Backup the database
	SET @SQL = 'BACKUP DATABASE [' + @DBName + '] TO DISK = N''' + @BackupLocation +'\'+@DBName+'_initial.bak'' WITH INIT, NOFORMAT, NAME = N''Initial back to prep for AG seeding'', SKIP, NOREWIND, NOUNLOAD, STATS = 100';
	IF @Debug = 1
		PRINT @SQL				
	ELSE
		EXEC sp_executeSQL @SQL

--ALTER AVAILABILITY GROUP [NTESTAG1] ADD DATABASE [DrivingConditions];
--ALTER AVAILABILITY GROUP [NTESTAG1]	MODIFY REPLICA ON N''WVTESTMSFCSDB01'' WITH (SEEDING_MODE = AUTOMATIC)

	SET @SQL='USE [master]; ALTER AVAILABILITY GROUP ['+@AGName+'] ADD DATABASE ['+@DBName+'];'
	IF @Debug = 1
		PRINT @SQL				
	ELSE
		EXEC sp_executeSQL @SQL

	WAITFOR DELAY '00:00:25';

	/*------------------------------------------------------------------ Prepare the AGs to be modified ------------------------------------------------------------------*/
	-- Get min and max
	SELECT @MinRepl=MIN(ID), @MaxRepl=MAX(ID) FROM #replicas

	WHILE (@MaxRepl >= @MinRepl)
	BEGIN

		SET @ReplName = (SELECT ReplName FROM #replicas where ID = @MinRepl)	
		
		SET @SQL=N'USE [master]; ALTER AVAILABILITY GROUP ['+@AGName+'] MODIFY REPLICA ON N'''+@ReplName+''' WITH (SEEDING_MODE = AUTOMATIC)'
		
		IF @Debug = 1
			PRINT @SQL				
		ELSE
			EXEC sp_executeSQL @SQL

		-- Loop to the next record
		set @MinRepl +=1		
	END

	-- Loop to the next record
	set @MinDB +=1
		
	
END
