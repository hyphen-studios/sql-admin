/*
TRUNCATE TABLE msdb.dbo.sysjobhistory
*/

/* Create dependent function if necessary */
USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [dbo].[ufnSplit]
(@strIn VARCHAR (MAX))
RETURNS 
    @t_Items TABLE (
        [item] VARCHAR (8000) NULL)
AS
BEGIN
  DECLARE @strElt VARCHAR(MAX), @sepPos INT
  SET @strIn = @strIn + ','
  SET @sepPos = CHARINDEX(',', @strIn)
  WHILE ISNULL(@sepPos, 0) > 0
  BEGIN
     SET @strElt = LEFT(@strIn, @sepPos - 1)
     INSERT INTO @t_Items VALUES ( RTRIM(LTRIM(@strElt))) 
     SET @strIn = RIGHT(@strIn, DATALENGTH(@strIn) - @sepPos)
     SET @sepPos = CHARINDEX(',', @strIn)
  END
RETURN
END

GO

/* Create session_details table if necessary */
USE [SQL_Admin]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--IF OBJECT_ID('SQL_Admin.dbo.session_details', 'U') IS NOT NULL 
--BEGIN
--	DROP TABLE [dbo].[session_details];
--END
--IF OBJECT_ID('SQL_Admin.dbo.session_details', 'U') IS NULL 
--BEGIN
	CREATE TABLE [dbo].[session_details](
		[id] [int] IDENTITY(1,1) NOT NULL,
		[server_name] [nvarchar](128) NOT NULL,
		[session_id] [int] NOT NULL,
		[login_name] [nchar](128) NOT NULL,
		[login_time] [datetime] NOT NULL,
		[loggedoffby_time] [datetime] NULL,
		[host_name] [nchar](128) NOT NULL,
		[program_name] [nchar](128) NULL,
		[db_name] [nvarchar](128) NULL
	--PRIMARY KEY CLUSTERED 
	CONSTRAINT [PK_session_details] PRIMARY KEY CLUSTERED
	(
		[id] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]



	CREATE UNIQUE NONCLUSTERED INDEX [IX_unique_session_details] ON [dbo].[session_details]
	(
		[session_id] ASC,
		[login_name] ASC,
		[login_time] ASC,
		[db_name] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
	--GO
	ALTER TABLE [dbo].[session_details] ADD  CONSTRAINT [DF_server_name]  DEFAULT (@@servername) FOR [server_name]
	--GO
--END

/* Create associated Stored Procedure */
USE [SQL_Admin]
GO

IF OBJECT_ID('[SQL_Admin].[dbo].[prUpdateSessionDetails]') IS NOT NULL 
DROP PROCEDURE [dbo].[prUpdateSessionDetails];
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[prUpdateSessionDetails]
/******************************************************************************
** NAME:	prUpdateSessionDetails
** DESCRIPTION: Inserts or updates records in the [SQL_Admin].[dbo].[session_details] table used for login auditing 
** DEPENDENCIES: [SQL_Admin].[dbo].[session_details] table and [SQL_Admin].[dbo].[ufnSplit] must exist 

   EXAMPLE:	
	EXEC SQL_Admin.dbo.prUpdateSessionDetails
	EXEC SQL_Admin.dbo.prUpdateSessionDetails N'CPADMIN, CPSYSTEM, DELTEK, NT AUTHORITY\SYSTEM, SNCORP\sncsql, SNCORP\svc-CP01SB-SQLA, SNCORP\svc-CP01D-SQL, SNCORP\svc-CP01D-SQLA, SNCORP\svc-CP01U-SQL, SNCORP\svc-CP01U-SQLA, SNCORP\svc-CP01T-SQL, SNCORP\svc-CP01T-SQLA, SNCORP\svc-CP01P-SQL, SNCORP\svc-CP01P-SQLA, SNCORP\svc-CP01YE-SQLA, SNCORP\svc-SP5CPH-SQL, SNCORP\svc-SP5CPH-SQLA, SNCORP\svc-CSU2P-SQLA, SNCORP\svc-CSU2X-SQLA, svc-Proxy-Dev, svc-Proxy-Test, svc-Proxy-UAT, svc-Proxy-Prod, TCLOGIN, TC_0001, TC_0002, SNCORP\svc-IDERA-prod, SNCORP\svc-solarmonitor, SNCORP\svc-DPA-Prod'
	
	--TRUNCATE TABLE SQL_Admin.dbo.session_details
	SELECT * FROM SQL_Admin.dbo.session_details ORDER BY session_id ASC, login_time DESC

	/* Range and record counts */
	SELECT MIN(loggedoffby_time) AS MonitoringStarted, MAX(loggedoffby_time) AS MonitoringThrough, COUNT(*) AS RecordCount FROM SQL_Admin.dbo.session_details 

	/* Accounts logged in at a specific time */
	DECLARE @BeginTime DATETIME, @EndTime DATETIME
	SELECT @BeginTime = '2017-02-09 08:00:00.000', @EndTime = '2017-02-09 09:00:00.000'
	SELECT * FROM SQL_Admin.sd.session_details 
	WHERE login_time <= @EndTime
		AND (loggedoffby_time >= @BeginTime OR loggedoffby_time IS NULL)
		AND db_name = 'TRANSCP'
	ORDER BY login_name ASC, login_time ASC

	/* View record counts from sysjobhistory since continuous schedule generates a large history */
	SELECT run_date, COUNT(run_date) FROM msdb.dbo.sysjobhistory GROUP BY run_date ORDER BY run_date DESC

** MODIFICATION HISTORY BELOW
** Date 	Name		Description
** ----------------------------------------------------------------------------
** 20170130	PLEE		Created
** 20170208	PLEE	Excluded NULL db_name records since they were transitory states
** 20170312	PLEE	Added Group By clause to address duplicate records for columns selected
*******************************************************************************/
(
	@service_accounts NVARCHAR (1024) = N''
)
AS
--SET STATISTICS TIME ON -- Temp for testing
SET NOCOUNT ON

/* Create Table Variable for logins to exclude */
DECLARE @service_account_list TABLE
( login_name NVARCHAR (128)
	PRIMARY KEY
)

INSERT @service_account_list
        ( login_name)
SELECT fn.item
FROM dbo.ufnSplit(@service_accounts) fn;

--SELECT login_name AS excluded_logins FROM @service_account_list -- Temp for testing

/* Run MERGE to insert or update data not including "excluded" logins */
	MERGE [SQL_Admin].[dbo].[session_details] AS [target]  
		USING
			(SELECT 
				[a].[session_id]
			,	[a].[login_name]
			,	[a].[login_time]
			,	[a].[host_name]
			,	[a].[program_name] -- NULL for internal sessions
			--,	DB_NAME([a].[database_id]) [db_name] -- SQL 2012 and newer only
			,	DB_NAME([b].[dbid]) AS [db_name]
			FROM [sys].[dm_exec_sessions] AS [a]
				LEFT JOIN [sys].[sysprocesses] AS [b]
					ON [a].[session_id] = [b].[spid]
				LEFT JOIN @service_account_list AS [c]
					ON [a].[login_name] = [c].[login_name]
			WHERE 
				[a].[host_name] IS NOT NULL
				AND [c].[login_name] IS NULL -- This eliminates "excluded" logins
			GROUP BY
				[a].[session_id]
			,	[a].[login_name]
			,	[a].[login_time]
			,	[a].[host_name]
			,	[a].[program_name]
			,	[b].[dbid]
				 ) AS source ([session_id], [login_name], [login_time], [host_name], [program_name], [db_name])
		ON	([target].[session_id] = [source].[session_id] 
			AND [target].[login_name] = [source].[login_name] 
			AND [target].[host_name] = [source].[host_name] 
			AND [target].[program_name] = [source].[program_name] 
			AND [target].[db_name] = [source].[db_name])  
	WHEN NOT MATCHED BY SOURCE AND [target].[loggedoffby_time] IS NULL THEN -- Records that are in the target but not in the source
		UPDATE SET [target].[loggedoffby_time] = GETDATE()
	WHEN NOT MATCHED BY TARGET AND [source].[login_name] <> '' AND [source].[db_name] IS NOT NULL THEN -- Records that are in the source but not in the target
		INSERT	(
			[session_id]
		,	[login_name]
		,	[login_time]
		,	[host_name]
		,	[program_name]
		,	[db_name])
		VALUES	(
			[source].[session_id]
		,	[source].[login_name]
		,	[source].[login_time]
		,	[source].[host_name]
		,	[source].[program_name]
		,	[source].[db_name]);

	--SET STATISTICS TIME OFF -- Temp for testing
GO

/* Create dedicated schema/view/role */
USE [SQL_Admin]
GO
CREATE SCHEMA [sd] AUTHORIZATION [dbo]
GO

USE [SQL_Admin]
GO
CREATE VIEW [sd].[session_details]
AS

SELECT server_name, session_id, login_name, login_time, loggedoffby_time, host_name, program_name, db_name
FROM     dbo.session_details

GO

USE [SQL_Admin]
GO
CREATE ROLE [SD_Data_Reader] AUTHORIZATION [dbo]
GO
USE [SQL_Admin]
GO
GRANT SELECT ON SCHEMA::[sd] TO [SD_Data_Reader]
GO


/* Create associated SQL Agent jobs */
USE [msdb]
GO

--IF EXISTS (SELECT name FROM msdb.dbo.sysjobs WHERE name=N'06.1 Update Session History - Continuous')
--BEGIN
--	EXEC msdb.dbo.sp_delete_job @job_name=N'06.1 Update Session History - Continuous', @delete_unused_schedule=1
--END

/****** Object:  Job [06.1 Update Session History - Continuous]    Script Date: 1/31/2017 9:26:55 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]    Script Date: 1/31/2017 9:26:56 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'06.1 Update Session History - Continuous', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Collects session details and logs them to the SQL_Admin.dbo.session_details table to track login history for audit and reporting of user access.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [INSERT or UPDATE records in SQL_Admin.dbo.session_details]    Script Date: 1/31/2017 9:26:57 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'INSERT or UPDATE records in SQL_Admin.dbo.session_details', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=2, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=5, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC SQL_Admin.dbo.prUpdateSessionDetails N''''', 
		@database_name=N'SQL_Admin', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Go To Step 1]    Script Date: 1/31/2017 9:26:57 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Go To Step 1', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=4, 
		@on_success_step_id=1, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SELECT 1', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Persistence Schedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170118, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Start When Agent Starts', 
		@enabled=1, 
		@freq_type=64, 
		@freq_interval=0, 
		@freq_subday_type=0, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170118, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


IF EXISTS (SELECT name FROM msdb.dbo.sysjobs WHERE name=N'06.2 Delete Session Job History')
BEGIN
	EXEC msdb.dbo.sp_delete_job @job_name=N'06.2 Delete Session Job History', @delete_unused_schedule=1
END

/****** Object:  Job [06.2 Delete Session Job History]    Script Date: 2/8/2017 11:12:04 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 2/8/2017 11:12:04 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'06.2 Delete Session Job History', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Delete SQL Agent job history for only the "06.1 Update Session History - Continuous" job older than 10 minutes due to the frequency of execution', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Purge Job History]    Script Date: 2/8/2017 11:12:05 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge Job History', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* Delete SQL Agent job history for only the "06.1 Update Session History - Continuous" job older than 10 minutes due to the frequency of execution */
DECLARE @oldestdate DATETIME
SET @oldestdate = DATEADD(MINUTE,-10, GETDATE())
EXEC msdb.dbo.sp_purge_jobhistory @job_name = N''06.1 Update Session History - Continuous'', @oldest_date = @oldestdate;

--EXEC msdb.dbo.sp_spaceused ''msdb.dbo.sysjobhistory''
', 
		@database_name=N'msdb', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every Minute', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170208, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
