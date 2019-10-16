CREATE PROCEDURE [dbo].[sp_OptimizeIndexes]
as
/******************************************************************************
*  Stored Procedure Name: sp_OptimizeIndexes
*  Input Parameters: none
*  Use Case: exec sp_OptimizeIndexes
*  Description: Loops through MaintenanceIndexes table and runs a command to
*  either rebuild or orginize indexes based on on fragmentation percentage
*  History:
*  Date:		Action:								Developer: 
*  2018-12-21	Initial version						Patrick Lee
******************************************************************************/

/*------------------------ Declared variables ------------------------*/
DECLARE @dbid INT
DECLARE @dbname NVARCHAR(200)
DECLARE @schname NVARCHAR(50)
DECLARE @tblname NVARCHAR(130)
DECLARE @tblid INT
DECLARE @indxname NVARCHAR(130)
DECLARE @indxid INT
DECLARE @indxlvl INT
DECLARE @indxdepth INT
DECLARE @prtnum BIGINT
DECLARE @prefrag REAL
DECLARE @postfrag REAL
DECLARE @allwpagecnt INT
DECLARE @sql NVARCHAR(MAX)
DECLARE @current INT
DECLARE @maxrows INT
DECLARE @StartTime datetime2
DECLARE @EndTime INT


SET @current = (SELECT MIN(id) FROM MaintenanceIndexes WHERE PostDefrag is NULL)
SET @maxrows = (SELECT MAX(id) FROM MaintenanceIndexes WHERE PostDefrag is NULL)


-- Loop through the index records
while (@current <= @maxrows)
	BEGIN
	
		SET @StartTime = GETDATE()
		
		-- Set varaibles to prep for taking action on the indexes
		SELECT @dbname = DBName, @dbid = DBID, @schname = schname, @tblid = TblID ,@tblname = TblName, @indxid = IndxID, @indxname = IndxName, @indxlvl = IndxLevel, @indxdepth = IndxDepth, 
		@prtnum = PartitionNum,	@prefrag = PreDeFrag, @allwpagecnt = allowpagecount
		FROM dbo.MaintenanceIndexes WHERE id = @current

		-- Only take action on records that populated variables
		IF LEN(@dbname) >= 1
		BEGIN
			SET @sql = 'USE [' + @dbName + ']; ALTER INDEX [' + @indxname + '] ON [' + @dbName  + '].' +  @schname + '.[' + @tblname + ']'
			IF (@prefrag < 30 AND @allwpagecnt = 1)
				SET @sql =   @sql + ' REORGANIZE'
			IF (@prefrag >= 30 OR @allwpagecnt = 0)
				SET @sql =  @sql + ' REBUILD'
			IF @prtnum  > 1
				SET @sql = @sql + ' PARTITION=' + CAST(@allwpagecnt AS nvarchar(10))

			--print @sql
			EXEC sp_executesql @sql
		END
		
		-- Update table with the index command and post defrag results
		SELECT  @postfrag = avg_fragmentation_in_percent
		FROM sys.dm_db_index_physical_stats (DB_ID(@dbName), @tblid, @indxid, @prtnum , 'Detailed')
		WHERE index_depth = @indxdepth 
		AND index_level = @indxlvl

		SET @EndTime = DATEDIFF(MINUTE, @StartTime, GETDATE())

		UPDATE MaintenanceIndexes
		SET
        Command = @sql,
		PostDefrag = @postfrag,
		RunTime = @EndTime
		WHERE id = @current

		SET @current +=1
	END

