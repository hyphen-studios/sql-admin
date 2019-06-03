CREATE PROCEDURE [dbo].[sp_ReplicationStart] 
	@Publication NVARCHAR(75),
	@PubDBName NVARCHAR(75),
	@Schemas NVARCHAR(250),
	@ArticleType NVARCHAR(15),
	@DestDBName NVARCHAR(150),
	@Subscriber NVARCHAR(75),
	@ExecutedBy NVARCHAR(75),
	@Debug INT = 0
AS
/******************************************************************************
*  Stored Procedure Name: sp_ReplicationStart
*  Input Parameters: @Publication=Replication Publication Name, @PubDBName=The database that is the source of the data,
*  @Schemas=The database schemas you want to replicate, @ArticleType=The types of objects you want to replicate(tables, views, functions),
*  @DestDBName=The destination database where you want the data to end up,@Subscriber=The server where the subscription database lives, 
*  @ExecutedBy=The name of the person running the scripts, @Debug=Set to 1 if you want to see the scripts before running the scripts
*  Use Case: EXEC sp_ReplicationStop  @Publication='AMPSS_Dev',@Subscriber='',  @DestDBName='DbTools'
*  Description: Dynamically create replication based on input parameters
*  History:
*  Date:		Action:								Developer: 
*  2019-04-24	Initial version						Patrick Lee
*  2019-05-29	Allow wild card for schemas			Patrick Lee
******************************************************************************/
DECLARE
	
	@SchemasTotal INT,
	@JobName NVARCHAR(150),
	@JobID UNIQUEIDENTIFIER,
	@StartTime DATETIME2,	
	@TSQL NVARCHAR(MAX),
	@MinRec INT,
	@MaxRec INT,
	@Article NVARCHAR(50),
	@ArticleRepType NVARCHAR(5),
	@Schema NVARCHAR(50),
	@SchemasInsert NVARCHAR(50)
	--,-- Run things manually
	--@Publication NVARCHAR(75),
	--@PubDBName NVARCHAR(75),
	--@Schemas NVARCHAR(250),
	--@ArticleType NVARCHAR(15),
	--@DestDBName NVARCHAR(150),
	--@Subscriber NVARCHAR(75),
	--@ExecutedBy NVARCHAR(75),
	--@Debug INT = 0
	
	---- One time run
	--SET @Publication='AMPSS_DEV'
	--SET @PubDBName='AMPSS'
	--SET @Schemas='ampss%,staging_west,reporting'
	--SET @ArticleType='T,V'
	--SET @DestDBName='ReplTest'
	--SET @Subscriber='DESKTOP-OVN2GNF'
	--SET @ExecutedBy='Patrick'
	--SET @Debug= 0

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
IF OBJECT_ID('tempdb..##schemas') IS NOT NULL DROP TABLE ##schemas

CREATE TABLE ##schemas
(
	ID INT IDENTITY(1, 1) primary key ,
	DBName NVARCHAR(200),
	SchemaName NVARCHAR(150)
);


-- Loop through schemas, and insert them into a temp table
WHILE @SchemasTotal > 0
BEGIN
	
	SET @SchemasInsert=REPLACE(LEFT(@Schemas, CHARINDEX(',', @Schemas+',')), ',', '')
	-- Check to see if the schemas contains a wild card
	IF CHARINDEX('%', @SchemasInsert) >=1
	BEGIN	
		SET @TSQL='SELECT '''+@PubDBName+''', name from '+@PubDBName+'.sys.schemas where name like '''+@SchemasInsert+'''';
		INSERT INTO ##schemas(DBName, SchemaName)
		EXEC sp_executesql @TSQL;
	END
	ELSE

	-- Insert the Schemas into the temp table #schemas
	INSERT INTO ##schemas(DBName, SchemaName)
	VALUES(@PubDBName, @SchemasInsert)
  
	-- Setup the next record
	set @Schemas = stuff(@Schemas, 1, charindex(',', @Schemas+','), '')
	SET @SchemasTotal = @SchemasTotal-1

END

/*------------------------------------------------- Insert Tables -------------------------------------------------*/
IF CHARINDEX('T', @ArticleType) > 0
BEGIN
	SET @TSQL = N'
	SELECT st.SchemaName, t.name,''T'',GETDATE()
	FROM ##schemas AS st
		INNER JOIN '+@PubDBName+'.sys.schemas as s
			on st.SchemaName = s.name
		INNER JOIN '+@PubDBName+'.sys.tables as t
			on s.schema_id = t.schema_id
		INNER JOIN '+@PubDBName+'.sys.indexes as i
			on t.object_id = i.object_id and i.is_primary_key = 1
	order by st.SchemaName DESC
	'

	-- Insert tables that will be replicated
	INSERT INTO ReplicationArticles(SchemaName, ArticleName, ArticleType, DateAdded)
	EXEC sp_executesql @TSQL


	-- Update the JobID since we couldn't insert it with the Dynamic SQL
	UPDATE ReplicationArticles
		SET JobID = @JobID
	where JobID IS NULL

	IF @Debug = 1
		PRINT @TSQL
END

/*------------------------------------------------- Insert Views -------------------------------------------------*/
IF CHARINDEX('V', @ArticleType) > 0
BEGIN
	SET @TSQL = N'
	SELECT st.SchemaName, t.name,''V'',GETDATE()
	FROM ##schemas AS st
		INNER JOIN '+@PubDBName+'.sys.schemas as s
			on st.SchemaName = s.name
		INNER JOIN '+@PubDBName+'.sys.objects as t
			on s.schema_id = t.schema_id
		LEFT JOIN AdventureWorks2016.sys.indexes as i
			on t.object_id = i.object_id
	where t.type=''V'' and i.index_id is null
	order by st.SchemaName DESC
	'

	-- Insert tables that will be replicated
	INSERT INTO ReplicationArticles(SchemaName, ArticleName, ArticleType, DateAdded)
	EXEC sp_executesql @TSQL


	-- Update the JobID since we couldn't insert it with the Dynamic SQL
	UPDATE ReplicationArticles
		SET JobID = @JobID
	where JobID IS NULL

	IF @Debug = 1
		PRINT @TSQL
END

/*------------------------------------------------- Insert Indexed Views -------------------------------------------------*/
IF CHARINDEX('IV', @ArticleType) > 0
BEGIN
	SET @TSQL = N'
	SELECT st.SchemaName, v.name,''IV'',GETDATE()
	FROM ##schemas AS st
		INNER JOIN '+@PubDBName+'.sys.schemas as s
			on st.SchemaName = s.name
		INNER JOIN '+@PubDBName+'.sys.views v
			on s.schema_id = v.schema_id
		INNER JOIN '+@PubDBName+'.sys.indexes as i
			on v.object_id = i.object_id	
	order by st.SchemaName DESC
	'

	-- Insert tables that will be replicated
	INSERT INTO ReplicationArticles(SchemaName, ArticleName, ArticleType, DateAdded)
	EXEC sp_executesql @TSQL

	-- Update the JobID since we couldn't insert it with the Dynamic SQL
	UPDATE ReplicationArticles
		SET JobID = @JobID
	where JobID IS NULL

	IF @Debug = 1
		PRINT @TSQL
END

/*------------------------------------------------- Insert Stored Procs -------------------------------------------------*/
IF CHARINDEX('P', @ArticleType) > 0
BEGIN
	SET @TSQL = N'
	SELECT st.SchemaName, t.name,''P'',GETDATE()
	FROM ##schemas AS st
		INNER JOIN '+@PubDBName+'.sys.schemas as s
			on st.SchemaName = s.name
		INNER JOIN '+@PubDBName+'.sys.objects as t
			on s.schema_id = t.schema_id
	where t.type=''P''
	order by st.SchemaName DESC
	'

	-- Insert tables that will be replicated
	INSERT INTO ReplicationArticles(SchemaName, ArticleName, ArticleType, DateAdded)
	EXEC sp_executesql @TSQL


	-- Update the JobID since we couldn't insert it with the Dynamic SQL
	UPDATE ReplicationArticles
		SET JobID = @JobID
	where JobID IS NULL

	IF @Debug = 1
		PRINT @TSQL
END

/*------------------------------------------------- Insert Functions -------------------------------------------------*/
IF CHARINDEX('F', @ArticleType) > 0
BEGIN
	SET @TSQL = N'
	SELECT s.name, o.name, ''F'', GETDATE()
	FROM '+@PubDBName+'.sys.objects o
		INNER JOIN '+@PubDBName+'.sys.schemas as s
			on o.schema_id = s.schema_id
	WHERE o.type_Desc LIKE ''%function%''
	'

	-- Insert tables that will be replicated
	INSERT INTO ReplicationArticles(SchemaName, ArticleName, ArticleType, DateAdded)
	EXEC sp_executesql @TSQL

	-- Update the JobID since we couldn't insert it with the Dynamic SQL
	UPDATE ReplicationArticles
		SET JobID = @JobID
	where JobID IS NULL

	IF @Debug = 1
		PRINT @TSQL
END

/*--------------------------------------------- Build Replication Foundation ---------------------------------------------------*/
SET @TSQL = N'
use master
exec sp_replicationdboption @dbname = N'''+@PubDBName+''', @optname = N''publish'', @value = N''true''

exec ['+@PubDBName+'].sys.sp_addlogreader_agent @job_login = null, @job_password = null, @publisher_security_mode = 1

-- Adding the transactional publication
use ['+@PubDBName+']
exec sp_addpublication @publication = N'''+@Publication+''', @description = N''Transactional publication of database '''''+@PubDBName+''''' from Publisher '''''+@@SERVERNAME+'''''. Started on '+convert(varchar, getdate(), 0)+''', @sync_method = N''concurrent'', @retention = 0, @allow_push = N''true'', @allow_pull = N''true'', @allow_anonymous = N''false'', @enabled_for_internet = N''false'', @snapshot_in_defaultfolder = N''true'', @compress_snapshot = N''false'', @ftp_port = 21, @ftp_login = N''anonymous'', @allow_subscription_copy = N''false'', @add_to_active_directory = N''false'', @repl_freq = N''continuous'', @status = N''active'', @independent_agent = N''true'', @immediate_sync = N''false'', @allow_sync_tran = N''false'', @autogen_sync_procs = N''false'', @allow_queued_tran = N''false'', @allow_dts = N''false'', @replicate_ddl = 1, @allow_initialize_from_backup = N''false'', @enabled_for_p2p = N''false'', @enabled_for_het_sub = N''false''
exec sp_addpublication_snapshot @publication = N'''+@Publication+''', @frequency_type = 1, @frequency_interval = 0, @frequency_relative_interval = 0, @frequency_recurrence_factor = 0, @frequency_subday = 0, @frequency_subday_interval = 0, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @active_start_date = 0, @active_end_date = 0, @job_login = null, @job_password = null, @publisher_security_mode = 1
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''sa''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT SERVICE\Winmgmt''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT SERVICE\SQLWriter''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT SERVICE\SQLSERVERAGENT''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''NT Service\MSSQLSERVER''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''distributor_admin''
exec sp_grant_publication_access @publication = N'''+@Publication+''', @login = N''sqlmigrate''
'
-- Execute the dynamic SQL to create the Replication Foundation
IF @Debug = 0
EXEC sp_executesql @TSQL


/*--------------------------------------------- Add tables to replication ---------------------------------------------------*/
SET @MinRec = (SELECT MIN(ID) FROM ReplicationArticles where JobID = @JobID)
SET @MaxRec = (SELECT MAX(ID) FROM ReplicationArticles where JobID = @JobID)

WHILE @MaxRec > @MinRec
BEGIN
	
	SELECT @Article=ArticleName, @Schema=SchemaName, @ArticleRepType=ArticleType from ReplicationArticles where JobID=@JobID and ID = @MinRec	

	IF @ArticleRepType='F'
	SET @TSQL = N'USE ['+@PubDBName+']; exec sp_addarticle @publication = N'''+@Publication+''', @article = N'''+@Article+''', @source_owner = N'''+@Schema+''', @source_object = N'''+@Article+''', @type = N''func schema only'', @description = N'''', @creation_script = N'''', @pre_creation_cmd = N''drop'', @schema_option =0x0000000008000001, @destination_table = N'''+@Article+''', @destination_owner = N'''+@Schema+''', @status = 16'
	
	IF @ArticleRepType='T'
	SET @TSQL = N'USE ['+@PubDBName+']; exec sp_addarticle @publication = N'''+@Publication+''', @article = N'''+@Article+''', @source_owner = N'''+@Schema+''', @source_object = N'''+@Article+''', @type = N''logbased'', @description = N'''', @creation_script = N'''', @pre_creation_cmd = N''drop'', @schema_option = 0x000000000803409F, @identityrangemanagementoption = N''manual'', @destination_table = N'''+@Article+''', @destination_owner = N'''+@Schema+''', @status = 24, @vertical_partition = N''false'', @ins_cmd = N''CALL [sp_MSins_'+@Schema+''+@Article+']'', @del_cmd = N''CALL [sp_MSdel_'+@Schema+''+@Article+']'', @upd_cmd = N''SCALL [sp_MSupd_'+@Schema+''+@Article+']'''
	
	IF @ArticleRepType='IV'
	SET @TSQL = N'USE ['+@PubDBName+']; exec sp_addarticle @publication = N'''+@Publication+''', @article = N'''+@Article+''', @source_owner = N'''+@Schema+''', @source_object = N'''+@Article+''', @type = N''indexed view logbased'', @description = N'''', @creation_script = N'''', @pre_creation_cmd = N''drop'', @schema_option =0x0000000008000001, @destination_table = N'''+@Article+''', @destination_owner = N'''+@Schema+''', @status = 16'

	IF @ArticleRepType='V'
	SET @TSQL = N'USE ['+@PubDBName+']; exec sp_addarticle @publication = N'''+@Publication+''', @article = N'''+@Article+''', @source_owner = N'''+@Schema+''', @source_object = N'''+@Article+''', @type = N''view schema only'', @description = N'''', @creation_script = N'''', @pre_creation_cmd = N''drop'', @schema_option =0x0000000008000001, @destination_table = N'''+@Article+''', @destination_owner = N'''+@Schema+''', @status = 16'
	
	IF @ArticleRepType='P'
	SET @TSQL = N'USE ['+@PubDBName+']; exec sp_addarticle @publication = N'''+@Publication+''', @article = N'''+@Article+''', @source_owner = N'''+@Schema+''', @source_object = N'''+@Article+''', @type = N''proc schema only'', @description = N'''', @creation_script = N'''', @pre_creation_cmd = N''drop'', @schema_option =0x0000000008000001, @destination_table = N'''+@Article+''', @destination_owner = N'''+@Schema+''', @status = 16'
	
	
	IF @Debug = 0	
		EXEC sp_executesql @TSQL	
	ELSE
		PRINT @TSQL
	
	set @MinRec +=1
END

/*--------------------------------------------- Add the subscription to replication ---------------------------------------------------*/
IF @Debug = 0
BEGIN
	SET @TSQL = N'
	use ['+@PubDBName+']
	exec sp_addsubscription @publication = N'''+@Publication+''', @subscriber = N'''+@Subscriber+''', @destination_db = N'''+@DestDBName+''', @subscription_type = N''Push'', @sync_type = N''automatic'', @article = N''all'', @update_mode = N''read only'', @subscriber_type = 0
	exec sp_addpushsubscription_agent @publication = N'''+@Publication+''', @subscriber = N'''+@Subscriber+''', @subscriber_db = N'''+@DestDBName+''', @job_login = null, @job_password = null, @subscriber_security_mode = 1, @frequency_type = 64, @frequency_interval = 1, @frequency_relative_interval = 1, @frequency_recurrence_factor = 0, @frequency_subday = 4, @frequency_subday_interval = 5, @active_start_time_of_day = 0, @active_end_time_of_day = 235959, @active_start_date = 0, @active_end_date = 0, @dts_package_location = N''Distributor''
	exec sp_startpublication_snapshot @publication = N'''+@Publication+'''
	'

	EXEC sp_executesql @TSQL
  
END
