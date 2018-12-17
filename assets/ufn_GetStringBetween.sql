CREATE FUNCTION ufn_GetStringBetween (@str varchar(500), @str1 varchar(30), @str2 varchar(30))
RETURNS varchar(200)
AS
/******************************************************************************
*  Stored Procedure Name: sp_CheckDBIntegrity
*  Input Parameters: none
*  Use Case: exec sp_CheckDBIntegrity
*  Description: Funciton pulled from sqltips.com article - https://www.mssqltips.com/sqlservertip/4626/script-to-quickly-find-sql-server-dbcc-checkdb-errors/
*  The function takes two strings such 'Str1' and 'Str2' and returns anything in the middle of these strings.
*  For 
*  History:
*  Date:		Action:								Developer: 
*  2017-02-08	Initial version						SQL Tips - Eli Leiba
******************************************************************************/
BEGIN
   DECLARE @Result varchar(200)
   DECLARE @p1 int
   DECLARE @p2 int
   SET @p1 = charindex (@str1 , @str ,1)
   SET @p2 = charindex (@str2 , @str ,1)
   RETURN rtrim(ltrim(substring (@str, @p1 + len(@str1) , @p2 - len(@str1) - @p1  )))
END
GO
