CREATE PROCEDURE sp_OBjectChanges
AS
/******************************************************************************
*  Stored Procedure Name: sp_OBjectChanges
*  Input Parameters: none
*  Use Case: EXEC sp_OBjectChanges
*  Description: Captures object changes in all of the user databases on this server
*  Results end up in the DBObjectInfo table.
*  History:
*  Date:		Action:								Developer: 
*  2019-05-08	Initial version						Patrick Lee
******************************************************************************/
DECLARE 
	@TraceFile NVARCHAR(255),
	@DBName NVARCHAR(50),
	@DBMax int,
	@DBMin int,
	@maxdate datetime2,
	@TSQL NVARCHAR(max)

/*----------------- SET Trace File Information -----------------*/
SELECT 
	@TraceFile = SUBSTRING(PATH, 0, LEN(PATH)-CHARINDEX('\', REVERSE(PATH))+1) + '\LOG.TRC'  
FROM SYS.TRACES   
WHERE IS_DEFAULT = 1;  

-- Drop / Truncate / Create tables
TRUNCATE table SQLEvents;
IF OBJECT_ID('tempdb..#databases') IS NOT NULL DROP TABLE #databases

CREATE TABLE #databases
(
ID INT IDENTITY(1, 1) primary key ,
DBName NVARCHAR(200),
);

-- Truncate SQLEvents
TRUNCATE TABLE SQLEvents

-- Insert data from the trace file into a temp table
INSERT INTO SQLEvents
SELECT * FROM ::fn_trace_gettable(@TraceFile, default)

-- Insert user database names into a temp table - NO SYSTEM databases (master, model, tempDB)
INSERT INTO #databases (DBName)
SELECT name FROM sys.databases WHERE state_desc = 'ONLINE' and database_id >=5


-- Set Min and Max DB IDs
select @DBMax=max(id), @DBMin=min(id) from #databases

WHILE @DBMin <= @DBMax
BEGIN
	
	-- Get Database to work in
	SELECT @DBName=DBName FROM #databases WHERE ID = @DBMin
	SELECT @maxdate=max(eventtime) FROM SQL_Admin.dbo.DBObjectInfo WHERE DBName = 'AMPSS_TEST'

	SET @TSQL = N'
	INSERT INTO SQL_Admin.dbo.DBObjectInfo(ServerName, SessionID, LoginName, HostName, ProgramName, DBName, EventTime, EventType, ObjectType, Object)
	select
		@@SERVERNAME,
		e.SPID, 
		e.LoginName,
		e.HostName,
		e.ApplicationName,
		e.DatabaseName,
		e.StartTime,
		te.name,
		o.type_desc,
		o.name
	from SQLEvents as e
		INNER JOIN '+@DBName+'.sys.trace_events as te
			ON e.EventClass = te.trace_event_id
		INNER JOIN '+@DBName+'.sys.objects as o
			on e.ObjectID=o.object_id
	where e.DatabaseName = '''+@DBName+''' and StartTime > '+ CHAR(39) + CONVERT(VARCHAR(23), @maxdate, 126) + CHAR(39)+'
	'
	EXEC sp_executesql @TSQL

	SET @DBMin +=1

END
