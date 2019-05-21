CREATE PROCEDURE [dbo].[sp_DatabaseBackup] @DBName NVARCHAR(255), @FileLocation NVARCHAR(255), @BackupFile NVARCHAR(255)  
AS
/******************************************************************************
*  Stored Procedure Name: sp_DatabaseBackup
*  Input Parameters: none
*  Use Case: EXEC [sp_DatabaseBackup] @DBName='EDW', @FileLocation='\\sharename\foldername\ or C:\Folder Location', @BackupFile='edw-bu-20170110.bak'
*  ** NOTE ** The SQL Engine service accounts needs administrator access to the share or folder location
*  Description: Backsup a database to a network or local file location
*  History:
*  Date:		    Action:								Developer: 
*  2017-12-21	  Initial version			  Patrick Lee
******************************************************************************/
BEGIN
-- SET NOCOUNT ON added to prevent extra result sets from interfering with SELECT statements.
 
EXEC ('BACKUP DATABASE ['+ @DBName +'] TO  DISK = N'''+ @FileLocation + 
        @BackupFile +''' WITH NOFORMAT, INIT, COPY_ONLY,  NAME = N'''+ @DBName +'-Full Database Backup'', SKIP, NOREWIND, NOUNLOAD, COMPRESSION,  STATS = 10')
END
