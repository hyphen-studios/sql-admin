ALTER PROCEDURE sp_ReplicationStart @Publication NVARCHAR(75), @PubDBName NVARCHAR(75), @Schemas NVARCHAR(150), @DestDBName NVARCHAR(150), @Subscriber NVARCHAR(75), @ExecutedBy NVARCHAR(75)
As
DECLARE
	
	@SchemasTotal INT,
	@JobName NVARCHAR(150),
	@JobID UNIQUEIDENTIFIER,
	@StartTime DATETIME2,	
	@TSQL NVARCHAR(MAX),
	@MinRec INT,
	@MaxRec INT,
	@Table NVARCHAR(50),
	@Schema NVARCHAR(50)

-- Set Variables
SET @SchemasTotal = LEN(@Schemas) - LEN(REPLACE(@Schemas, ',', ''))+1
SET @JobName='Start Replication - ' + convert(varchar, getdate(), 0)
SET @JobID = NEWID(); 
SET @StartTime = GETDATE()

SET NOCOUNT ON


-- Insert Job Information into the ReplicationJob Table
INSERT INTO ReplicationJob(JobID, JobName, StartTime, ExecutedBy)
VALUES(@JobID, @JobName, @StartTime, @ExecutedBy)

-- Drop / Create temp table
IF OBJECT_ID('tempdb..#schemas') IS NOT NULL DROP TABLE #schemas

CREATE TABLE #schemas
(
ID INT IDENTITY(1, 1) primary key ,
DBName NVARCHAR(200),
SchemaName NVARCHAR(150)
);


-- Loop through schemas, and insert them into a temp table
WHILE @SchemasTotal > 0
BEGIN

  -- Insert the Schemas into the temp table #schemas
  INSERT INTO #schemas(DBName, SchemaName)
  VALUES(@PubDBName, REPLACE(LEFT(@Schemas, CHARINDEX(',', @Schemas+',')), ',', ''))
  
  -- Setup the next record
  set @Schemas = stuff(@Schemas, 1, charindex(',', @Schemas+','), '')
  SET @SchemasTotal = @SchemasTotal-1

END


SET @TSQL = N'
SELECT st.SchemaName, t.name, GETDATE()
FROM #schemas AS st
	INNER JOIN '+@PubDBName+'.sys.schemas as s
		on st.SchemaName = s.name
	INNER JOIN '+@PubDBName+'.sys.tables as t
		on s.schema_id = t.schema_id
	INNER JOIN '+@PubDBName+'.sys.indexes as i
		on t.object_id = i.object_id and i.is_primary_key = 1
order by st.SchemaName DESC
'

-- Insert tables that will be replicated
INSERT INTO ReplicationArticles(SchemaName, TableName, DateAdded)
EXEC sp_executesql @TSQL


-- Update the JobID since we couldn't insert it with the Dynamic SQL
UPDATE ReplicationArticles
	SET JobID = @JobID
where JobID IS NULL

/*--------------------------------------------- Build Replication Foundation ---------------------------------------------------*/
SET @TSQL = N'
use master
exec sp_replicationdboption @dbname = N'''+@PubDBName+''', @optname = N''publish'', @value = N''true''

exec ['+@PubDBName+'].sys.sp_addlogreader_agent @job_login = null, @job_password = null, @publisher_security_mode = 1

-- Adding the transactional publication
use ['+@PubDBName+']
exec sp_addpublication @publication = N'''+@Publication+''', @description = N''Transactional publication of database '''''+@PubDBName+''''' from Publisher '''''+@@SERVERNAME+'''''. Started on '+convert(varchar, getdate(), 0)+''', @sync_method = N''concurrent'', @retention = 0, @allow_push = N''true'', @allow_pull = N''true'', @allow_anonymous = N''false'', @enabled_for_internet = N''false'', @snapshot_in_defaultfolder = N''true'', @compress_snapshot = N''false'', @ftp_port = 21, @ftp_login = N''anonymous'', @allow_subscription_copy = N''false'', @add_to_active_directory = N''false'', @repl_freq = N''continuous'', @status = N''active'', @independent_agent = N''true'', @immediate_sync = N''false'', @allow_sync_tran = N''false'', @autogen_sync_procs = N''false'', @allow_queued_tran = N''false'', @allow_dts = N''false'', @replicate_ddl = 1, @allow_initialize_from_backup = N''false'', @enabled_for_p2p = N''false'', @enabled_for_het_sub = N''false''


exec sp_addpublication_snapshot @publication = N'''+@Publication+''', @frequency_type = 1, @frequency_interval = 0, @frequency_relative_interval = 0, @frequency_recurrence_factor = 0, @frequency_subday = 0, @frequency_subday_interval = 0, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @active_start_date = 0, @active_end_date = 0, @job_login = null, @job_password = null, @publisher_security_mode = 1
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''DBMS_Admin''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT SERVICE\Winmgmt''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT Service\MSSQL$AMPSS''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT SERVICE\SQLWriter''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT SERVICE\SQLAgent$AMPSS''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''distributor_admin''
'
-- Execute the dynamic SQL to create the Replication Foundation
EXEC sp_executesql @TSQL


/*--------------------------------------------- Add tables to replication ---------------------------------------------------*/
SET @MinRec = (SELECT MIN(ID) FROM ReplicationArticles where JobID = @JobID)
SET @MaxRec = (SELECT MAX(ID) FROM ReplicationArticles where JobID = @JobID)

WHILE @MaxRec > @MinRec
BEGIN
	
	SELECT @Table=TableName, @Schema=SchemaName from ReplicationArticles where JobID=@JobID and ID = @MinRec

	SET @TSQL = N'USE ['+@PubDBName+']; exec sp_addarticle @publication = N'''+@Publication+''', @article = N'''+@Table+''', @source_owner = N'''+@Schema+''', @source_object = N'''+@Table+''', @type = N''logbased'', @description = N'''', @creation_script = N'''', @pre_creation_cmd = N''drop'', @schema_option = 0x000000000803409F, @identityrangemanagementoption = N''manual'', @destination_table = N'''+@Table+''', @destination_owner = N'''+@Schema+''', @status = 24, @vertical_partition = N''false'', @ins_cmd = N''CALL [sp_MSins_'+@Schema+''+@Table+']'', @del_cmd = N''CALL [sp_MSdel_'+@Schema+''+@Table+']'', @upd_cmd = N''SCALL [sp_MSupd_'+@Schema+''+@Table+']'''
	--PRINT @TSQL
	EXEC sp_executesql @TSQL

	set @MinRec +=1
END


/*--------------------------------------------- Add the subscription to replication ---------------------------------------------------*/
SET @TSQL = N'
use ['+@PubDBName+']
exec sp_addsubscription @publication = N'''+@Publication+''', @subscriber = N'''+@Subscriber+''', @destination_db = N'''+@DestDBName+''', @subscription_type = N''Push'', @sync_type = N''automatic'', @article = N''all'', @update_mode = N''read only'', @subscriber_type = 0
exec sp_addpushsubscription_agent @publication = N'''+@Publication+''', @subscriber = N'''+@Subscriber+''', @subscriber_db = N'''+@DestDBName+''', @job_login = null, @job_password = null, @subscriber_security_mode = 1, @frequency_type = 64, @frequency_interval = 1, @frequency_relative_interval = 1, @frequency_recurrence_factor = 0, @frequency_subday = 4, @frequency_subday_interval = 5, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @active_start_date = 0, @active_end_date = 0, @dts_package_location = N''Distributor''
exec sp_startpublication_snapshot @publication = N'''+@Publication+'''
'

EXEC sp_executesql @TSQL
