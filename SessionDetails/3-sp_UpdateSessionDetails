CREATE PROCEDURE [dbo].[sp_UpdateSessionDetails]
/******************************************************************************
* NAME:	prUpdateSessionDetails
* DESCRIPTION: Inserts or updates records in the [SQL_Admin].[dbo].[SessionDetails] table used for login auditing 
* DEPENDENCIES: [SQL_Admin].[dbo].[SessionDetails] table and [SQL_Admin].[dbo].[ufnSplit] must exist 
*  EXAMPLE:	
*  EXEC SQL_Admin.dbo.prUpdateSessionDetails
*  EXEC SQL_Admin.dbo.prUpdateSessionDetails N'serviceaccount, DOMAIN\serviceaccount' -- Accounts to ignore
*	
*	--TRUNCATE TABLE SQL_Admin.dbo.SessionDetails
*	SELECT * FROM SQL_Admin.dbo.SessionDetails ORDER BY session_id ASC, login_time DESC
*	/* Range and record counts */
*	SELECT MIN(loggedoffby_time) AS MonitoringStarted, MAX(loggedoffby_time) AS MonitoringThrough, COUNT(*) AS RecordCount FROM SQL_Admin.dbo.SessionDetails 
*
*	/* Accounts logged in at a specific time */
*	DECLARE @BeginTime DATETIME, @EndTime DATETIME
*	SELECT @BeginTime = '2017-02-09 08:00:00.000', @EndTime = '2017-02-09 09:00:00.000'
*	SELECT * FROM SQL_Admin.sd.SessionDetails 
*	WHERE login_time <= @EndTime
*		AND (loggedoffby_time >= @BeginTime OR loggedoffby_time IS NULL)
*		AND db_name = 'DBNAME'
*	ORDER BY login_name ASC, login_time ASC
*
*	/* View record counts from sysjobhistory since continuous schedule generates a large history */
*	SELECT run_date, COUNT(run_date) FROM msdb.dbo.sysjobhistory GROUP BY run_date ORDER BY run_date DESC
*
* MODIFICATION HISTORY BELOW
* Date 		Name			Description
* ----------------------------------------------------------------------------
* 20170130		Patrick Lee		Created
* 20170208		Patrick Lee		Excluded NULL db_name records since they were transitory states
* 20170312		Patrick Lee		Added Group By clause to address duplicate records for columns selected
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
	MERGE [SQL_Admin].[dbo].[SessionDetails] AS [target]  
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
