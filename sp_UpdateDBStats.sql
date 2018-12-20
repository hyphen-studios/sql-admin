Create PROCEDURE [dbo].[sp_UpdateDBStats]
as
/******************************************************************************
*  Stored Procedure Name: sp_UpdateDBStats
*  Input Parameters: none
*  Use Case: exec sp_UpdateDBStats
*  Description: Loops through user database, and updates the statistics for all objects
*  History:
*  Date:		Action:								Developer: 
*  2018-12-6	Initial version						Patrick Lee
******************************************************************************/

/*------------------------ Declared variables ------------------------*/
DECLARE @current int
DECLARE @maxrows INT
DECLARE @dbname NVARCHAR(200)
DECLARE @guid uniqueidentifier  
DECLARE @sql nvarchar(250)

/*------------------------ Database temp table ------------------------*/
-- Drop temp table if it exists
IF OBJECT_ID('tempdb..#databases') IS NOT NULL DROP TABLE #databases

-- Create temp table
CREATE TABLE #databases
(
ID INT IDENTITY(1, 1) primary key ,
DBName NVARCHAR(200),
);

-- Insert database names into a temp table
INSERT INTO #databases (DBName)
SELECT name FROM sys.databases WHERE state_desc = 'ONLINE'

SET @current = 1
SET @maxrows = (SELECT MAX(id) FROM #databases)

-- Loop through the databases
while (@current <= @maxrows)
	BEGIN
		SET @guid = NEWID()
		SET @dbname = (SELECT dbname FROM #databases WHERE id = @current)
		SET @sql = 'Use [' +  @dbname + ']; EXEC sp_updatestats;'

		-- Insert Record into MaintenanceTask table with start time
		INSERT INTO maintenancetasks(JobID, ProcessTask, DBname, StartTime)
		VALUES(@guid,'Update Database Statistics', @dbname, GETDATE())

		PRINT @sql
		exec sp_executesql @sql;

		-- Update MaintenceTasks with end time and command
		UPDATE maintenancetasks
		SET
        	command = @sql,
		EndTime = GETDATE(),
		RunTime = DATEDIFF(MINUTE, StartTime, GETDATE())
		WHERE JobID = @guid;

		-- loop to the next database
		set @current +=1

	END

-- Kind of sledgehammer approach - For sure a topic for debate on if this is a good approach or not
DBCC FREEPROCCACHE
