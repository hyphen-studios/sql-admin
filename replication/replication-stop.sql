ALTER PROCEDURE [dbo].[sp_ReplicationStop] @Publication NVARCHAR(75), @Subscriber NVARCHAR(75), @DestDBName NVARCHAR(150)
AS
/******************************************************************************
*  Stored Procedure Name: sp_ReplicationStop
*  Input Parameters: @Publication=Replication Publication Name, @Subscriber=The server where the subscription database lives, @DestDBName=The database will the data lands
*  Use Case: EXEC sp_ReplicationStop  @Publication='AMPSS_Dev',@Subscriber='',  @DestDBName='DbTools'
*  Description: Dynamically create replication based on input parameters
*  History:
*  Date:		Action:								Developer: 
*  2019-04-24	Initial version						Patrick Lee
******************************************************************************/
DECLARE  	
	@PublicationID INT,
	@PubDBName NVARCHAR(75),		
	@ExecutedBy NVARCHAR(75),
	@Article NVARCHAR(75),
	@Schema NVARCHAR(75),
	@MinRec INT,
	@MaxRec INT,
	@TSQL NVARCHAR(1000)

SET NOCOUNT ON

-- Get the Publication information 
SELECT 
	@PubDBName=pub.publisher_db,
	@PublicationID=pub.publication_id
FROM distribution.dbo.MSpublications as pub
WHERE pub.publication = @Publication

SET @TSQL = N'USE ['+@PubDBName+']; exec sp_dropsubscription @publication = N'''+@PubDBName+''', @subscriber = N'''+@Subscriber+''', @destination_db = N'''+@DestDBName+''', @article = N''all'''
--PRINT @TSQL
EXEC sp_executesql @TSQL


-- Get the Articles that need to be dropped
-- Drop / Create temp table
IF OBJECT_ID('tempdb..#articles') IS NOT NULL DROP TABLE #articles

CREATE TABLE #articles
(
	ID INT IDENTITY(1, 1) primary key ,
	Article NVARCHAR(75),
	SourceOwner NVARCHAR(25)
);

-- Insert articles / tables into the temp table
INSERT INTO #articles(Article, SourceOwner)
SELECT
	a.article,
    a.source_owner    
FROM distribution.dbo.MSarticles AS a
	INNER JOIN distribution.dbo.MSpublications AS p
        ON a.publication_id = p.publication_id
where p.publication_id = @PublicationID


-- Get Min and Max Record IDs
SET @MinRec = (SELECT MIN(ID) FROM #articles)
SET @MaxRec = (SELECT MAX(ID) FROM #articles)

WHILE @MaxRec > @MinRec
BEGIN
	
	SELECT @Article=Article, @Schema=SourceOwner FROM #articles where ID = @MinRec

	SET @TSQL = N'
	USE ['+@PubDBName+']; exec sp_dropsubscription @publication = N'''+@Publication+''', @article = N'''+@Article+''', @subscriber = N''all'', @destination_db = N''all'';
	USE ['+@PubDBName+']; exec sp_droparticle @publication = N'''+@Publication+''', @article = N'''+@Article+''', @force_invalidate_snapshot = 1
	'
	--PRINT @TSQL
	EXEC sp_executesql @TSQL

	set @MinRec +=1

END

-- Final step of dropping replication
-- Dropping the transactional publication
SET @TSQL = N'use [AMPSS_DEV]; exec sp_droppublication @publication = N'''+@Publication+''''
EXEC sp_executesql @TSQL
