DECLARE
	@DBName NVARCHAR(75),
	@Schemas NVARCHAR(150),
	@SchemasTotal INT,
	@JobName NVARCHAR(150),
	@JobID UNIQUEIDENTIFIER,
	@StartTime DATETIME2,
	@ExecutedBy NVARCHAR(75),
	@TSQL NVARCHAR(MAX)

-- Set Variables
SET @DBName='CustomWorks'
SET @Schemas='Sales,Person,Other,dbo'
SET @SchemasTotal = LEN(@Schemas) - LEN(REPLACE(@Schemas, ',', ''))+1
SET @JobName='Start Replication - ' + convert(varchar, getdate(), 0)
SET @JobID = NEWID(); 
SET @StartTime = GETDATE()
SET @ExecutedBy = 'Patrick Lee'

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
  VALUES(@DBName, REPLACE(LEFT(@Schemas, CHARINDEX(',', @Schemas+',')), ',', ''))
  
  -- Setup the next record
  set @Schemas = stuff(@Schemas, 1, charindex(',', @Schemas+','), '')
  SET @SchemasTotal = @SchemasTotal-1

END


SET @TSQL = N'
SELECT st.SchemaName, t.name, GETDATE()
FROM #schemas AS st
	INNER JOIN '+@DBName+'.sys.schemas as s
		on st.SchemaName = s.name
	INNER JOIN '+@DBName+'.sys.tables as t
		on s.schema_id = t.schema_id
	INNER JOIN '+@DBName+'.sys.indexes as i
		on t.object_id = i.object_id and i.is_primary_key = 1
order by st.SchemaName DESC
'

PRINT @TSQL

-- Insert tables that will be replicated
INSERT INTO ReplicationArticles(SchemaName, TableName, DateAdded)
EXEC sp_executesql @TSQL


-- Update the JobID since we couldn't insert it with the Dynamic SQL
UPDATE ReplicationArticles
	SET JobID = @JobID
where JobID IS NULL
