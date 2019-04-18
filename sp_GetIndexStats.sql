CREATE PROCEDURE [dbo].[sp_GetIndexStats]
as
/******************************************************************************
*  Stored Procedure Name: sp_GetIndexStats
*  Input Parameters: none
*  Use Case: exec sp_GetIndexStats
*  Description: Loops through user database, and updates the statistics for all objects
*  History:
*  Date:		Action:								Developer: 
*  2018-12-6	Initial version						Patrick Lee
******************************************************************************/

/*------------------------ Declared variables ------------------------*/
DECLARE @current int
DECLARE @maxrows INT
DECLARE @dbname NVARCHAR(200)
DECLARE @dbid INT
DECLARE @guid uniqueidentifier  
DECLARE @sql nvarchar(max)

/*------------------------ Database temp table ------------------------*/
-- Drop temp table if it exists
IF OBJECT_ID('tempdb..#databases') IS NOT NULL DROP TABLE #databases

-- Create temp table
CREATE TABLE #databases
(
ID INT IDENTITY(1, 1) primary key ,
DBName NVARCHAR(200),
DBID INT
);

-- Insert database names into a temp table
INSERT INTO #databases (DBName, DBID)
SELECT name, database_id FROM sys.databases WHERE state_desc = 'ONLINE' AND database_id > 4

SET @current = 1
SET @maxrows = (SELECT MAX(id) FROM #databases)

-- Loop through the databases
while (@current <= @maxrows)
	BEGIN
		SET @guid = NEWID()
		SET @dbname = (SELECT dbname FROM #databases WHERE id = @current)
		SET @dbid = (SELECT DBID FROM #databases WHERE id = @current)
		

		---- Insert Record into MaintenanceTask table with start time
		INSERT INTO maintenancetasks(JobID, ProcessTask, DBname, StartTime)
		VALUES(@guid,'Capture Index Statistics', @dbname, GETDATE())

		SET @sql = '
		SELECT
			@guidkey,
			DB_NAME(indxstats.database_id) AS DBName,
			indxstats.database_id AS DBId,
			schm.name,
			OBJECT_NAME (indxstats.object_id, indxstats.database_id) AS TblName,
			indxstats.object_id AS TblID,
			indx.name AS IndxName,
			indx.index_id AS indxID,
			indxstats.index_type_desc AS IndxType,			
			indxstats.index_depth AS IndxDepth,
			indxstats.index_level AS IndxLevel,
			indxstats.partition_number AS PartitionNum,
			indxstats.avg_fragmentation_in_percent AS PreDeFrag,
			indxstats.avg_record_size_in_bytes AS AvgRecordSize,
			indxstats.avg_page_space_used_in_percent AS AvgSpaceUsed,
			indxstats.record_count,
			GETDATE() AS CalcDate,
			indx.allow_page_locks
		FROM sys.dm_db_index_physical_stats (@dbidkey , NULL, NULL , NULL, ''DETAILED'') AS indxstats
			INNER JOIN '+@dbname+'.sys.indexes AS indx
				ON indx.object_id = indxstats.object_id AND indx.index_id = indxstats.index_id
			INNER JOIN '+@dbname+'.sys.tables AS tbl
				ON indxstats.object_id = tbl.object_id
			INNER JOIN '+@dbname+'.sys.schemas AS schm
				ON tbl.schema_id = schm.schema_id
		WHERE indxstats.avg_fragmentation_in_percent > 10.0 AND (indxstats.index_id > 0)
		'

		-- Insert records into MaintenanceIndex table prior to index maintenance tasks
		INSERT INTO MaintenanceIndexes(JobID, DBName, DBID, SchName, TblName, TblID, IndxName, IndxID, IndxType, IndxDepth, IndxLevel, PartitionNum, PreDeFrag ,AvgRecordSize, AvgSpaceUsed, RecordCount, CalcDate, AllowPageCount)	
		EXEC sp_executesql @sql, N'@guidkey uniqueidentifier, @dbidkey int', @guidkey = @guid, @dbidkey = @dbid
					
		-- Update MaintenceTasks with end time and command
		UPDATE maintenancetasks
		SET
        command = 'No Command for this task',
		EndTime = GETDATE(),
		RunTime = DATEDIFF(MINUTE, StartTime, GETDATE())
		WHERE JobID = @guid;

		 --loop to the next database
		set @current +=1

	END
