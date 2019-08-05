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
