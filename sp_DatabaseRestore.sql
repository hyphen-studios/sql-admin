ALTER PROCEDURE [dbo].[sp_DatabaseRestore] @DBName NVARCHAR(100), @FileLocation NVARCHAR(150), @BackupFile NVARCHAR(100), @SetToSimple BIT = 1, @ShrinkLog BIT = 1  
AS
/******************************************************************************
*  Stored Procedure Name: [sp_DatabaseRestore]
*  Input Parameters: none
*  Use Case: EXEC [sp_DatabaseRestore] @DBName='EDW', @FileLocation='\\sharename\foldername\ or C:\Folder Location', @BackupFile='edw-bu-20170110.bak', @SetToSimple=1, @ShrinkLog=1
*  ** NOTE ** The SQL Engine service accounts needs administrator access to the share or folder location
*  Description: Restores the database
*  History:
*  Date:		    Action:								Developer: 
*  2017-12-21		Initial version						Patrick Lee
*  2019-05-23		Update to allow debug				Patrick Lee
******************************************************************************/
SET NOCOUNT ON
DECLARE
	@SQL NVARCHAR(max),
	@dbexist INT,
	@backupdatalogicalname NVARCHAR(75),
	@backuploglogicalname NVARCHAR(75),
	@datafile NVARCHAR(200),
	@datafilename NVARCHAR(75),
	@logfile NVARCHAR(250),
	@logfilename NVARCHAR(75),
	@defaultdatafilelocation NVARCHAR(250),
	@defaultlogfilelocaiton NVARCHAR(250),
	@ddflcount INT,
	@dlfcount INT,
	@dbfilecount INT,
	@dbfileend INT,
	@dbfilestart INT = 3,
	@dbdatafiles NVARCHAR(max) = ''

/* ---------- Ge information from the backup file ---------- */
DECLARE @Table TABLE 
(
	LogicalName varchar(128),
	[PhysicalName] varchar(128),
	[Type] varchar,
	[FileGroupName] varchar(128),
	[Size] varchar(128),
	[MaxSize] varchar(128),
	[FileId] varchar(128),
	[CreateLSN] varchar(128),
	[DropLSN] varchar(128),
	[UniqueId] varchar(128),
	[ReadOnlyLSN] varchar(128),
	[ReadWriteLSN] varchar(128),
	[BackupSizeInBytes] varchar(128),
	[SourceBlockSize] varchar(128),
	[FileGroupId] varchar(128),
	[LogGroupGUID] varchar(128),
	[DifferentialBaseLSN] varchar(128),
	[DifferentialBaseGUID] varchar(128),
	[IsReadOnly] varchar(128),
	[IsPresent] varchar(128),
	[TDEThumbprint] varchar(128)
)

INSERT INTO @Table
	EXEC('RESTORE FILELISTONLY FROM DISK=''' +@FileLocation+'/'+@BackupFile+ '''')
	--SELECT * FROM @Table
	SELECT @dbfilecount = count(*) FROM @Table
	SET @dbfileend = (Select Max(FileId) From @Table);
	SELECT @backupdatalogicalname = LogicalName FROM @Table WHERE Type = 'D'
	SELECT @backuploglogicalname = LogicalName FROM @Table WHERE Type = 'L'

IF @Debug = 1
BEGIN
	SELECT * FROM @Table
END


BEGIN TRY
/* ---------- Check to see if the databases exists. If not Restore to a new database ---------- */
IF OBJECT_ID('tempdb..##dbexists', 'U') IS NOT NULL
   drop TABLE ##dbexists

SET @SQL =N'SELECT * INTO ##dbexists FROM '+@DBName+'.sys.database_files;'
EXEC sys.sp_executesql @SQL

SET @dbexist = (SELECT COUNT(*) FROM ##dbexists)

IF @dbexist >=1
BEGIN
	/* ---------- Get File info ---------- */
	SELECT @datafile = physical_name, @datafilename = name FROM ##dbexists WHERE file_id = 1;
	SELECT @logfile = physical_name, @logfilename = name FROM ##dbexists WHERE file_id = 2;
	-- Get the total number of file configurations for the database
	SELECT @dbfileend = MAX(file_id) FROM ##dbexists

	IF @dbexist = 2
		BEGIN				
			/* ----------  Prep dynamic SQL for the restore code --------- */
			SET @SQL = N'ALTER DATABASE ['+@DBName+'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
RESTORE DATABASE ['+@DBName+'] 
FROM DISK=N'''+@FileLocation++@BackupFile+''' WITH  FILE = 1,
MOVE '''+@backupdatalogicalname+''' TO '''+@datafile+''',
MOVE '''+@backuploglogicalname+''' TO '''+@logfile+''', NOUNLOAD,  REPLACE,  STATS = 5					 
'
			IF @Debug = 0
				EXEC sp_executesql @SQL
			ELSE
				PRINT '1'
				PRINT @SQL
		END
	ELSE			
		BEGIN
		WHILE @dbfilestart <= @dbfileend
		BEGIN
			SET @dbdatafiles=@dbdatafiles+(SELECT ',MOVE '''+name+''' TO '''+physical_name+'''' FROM ##dbexists WHERE file_id=@dbfilestart)
			SET @dbfilestart += 1
		END
		SET @SQL = N'ALTER DATABASE ['+@DBName+'] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
RESTORE DATABASE ['+@DBName+'] 
FROM DISK=N'''+@FileLocation++@BackupFile+''' WITH  FILE = 1,
MOVE '''+@datafilename+''' TO '''+@datafile+'''
'+@dbdatafiles+',
MOVE '''+@logfilename+''' TO '''+@logfile+''',
NOUNLOAD,  REPLACE,  STATS = 5					 
'
		IF @Debug = 0
			EXEC sp_executesql @SQL
		ELSE
			PRINT '2'
			PRINT @SQL	
		END
			
END
END TRY
BEGIN CATCH
	/* ---------- Get full count to prep for left() statement ---------- */
	SELECT @defaultdatafilelocation=( SELECT LEFT(physical_name,LEN(physical_name)-CHARINDEX('\',REVERSE(physical_name))+1) 
    FROM sys.master_files mf   
		INNER JOIN sys.[databases] d   
			ON mf.[database_id] = d.[database_id]   
    WHERE d.[name] = @dbname AND type = 0);
	--Get the default Log path  
	SELECT @defaultlogfilelocaiton=(SELECT LEFT(physical_name,LEN(physical_name)-CHARINDEX('\',REVERSE(physical_name))+1)   
	FROM sys.master_files mf   
		INNER JOIN sys.[databases] d   
			ON mf.[database_id] = d.[database_id]   
	WHERE d.[name] = @dbname AND type = 1);
	--/* ---------- Start to build the files for restore ----------*/
	IF @dbfilecount >= 3
	BEGIN
		WHILE @dbfilestart <= @dbfileend
		BEGIN
			SET @dbdatafiles=@dbdatafiles+ (SELECT ',MOVE '''+LogicalName+''' TO '''+@defaultdatafilelocation++@DBName+'_0'+CAST(@dbfilestart AS NVARCHAR)+'.ndf''' FROM @Table WHERE FileId=@dbfilestart)
			SET @dbfilestart += 1
		END		
	END
	ELSE
		BEGIN	
			SET @dbdatafiles=''
			--PRINT 'NO ADD FILES'
		END
	
	/* ----------  Prep dynamic SQL for the restore code --------- */
	SET @SQL=N'RESTORE DATABASE '+@DBName+'
FROM DISK=N'''+@FileLocation+'/'+@BackupFile+''' WITH FILE=1,
	MOVE '''+@backupdatalogicalname+''' TO '''+@defaultdatafilelocation++@DBName+'.mdf'',
	MOVE '''+@backuploglogicalname+''' TO '''+@defaultdatafilelocation++@DBName+'_log.ldf''
	'+@dbdatafiles+';

'
	IF @Debug = 0
		EXEC sp_executesql @SQL
	ELSE
		PRINT '3'
		PRINT @SQL
    
END CATCH
-- Set proper logical names for the database
SET @SQL=N'USE [master]; ALTER DATABASE ['+@DBName+'] MODIFY FILE ( NAME = '+@backupdatalogicalname+', NEWNAME = '+@DBName+' );'
IF @Debug = 0
	EXEC sp_executesql @SQL
ELSE
	PRINT '4'
	PRINT @SQL

SET @SQL=N'USE [master]; ALTER DATABASE ['+@DBName+'] MODIFY FILE ( NAME = '+@backuploglogicalname+', NEWNAME = '+@DBName+'_log );'
IF @Debug = 0
	EXEC sp_executesql @SQL
ELSE
	PRINT '5'
	PRINT @SQL

-- Set database to simple recovery model
IF @SetToSimple = 1
BEGIN
	SET @SQL= 'USE Master; ALTER DATABASE ['+ @DBName +'] SET RECOVERY SIMPLE WITH NO_WAIT;'
		
	IF @Debug = 0
		EXEC sp_executesql @SQL
	ELSE
		PRINT '6'
		PRINT @SQL
		
END

-- Shring the log file to 64 megs
IF @ShrinkLog = 1
BEGIN
	SET @SQL = 'USE ['+@DBName+']
	DBCC SHRINKFILE ('+@DBName+'_log , 64)
	'
	IF @Debug = 0
		EXEC sp_executesql @SQL
	ELSE
		PRINT '7'
		PRINT @SQL
END 
