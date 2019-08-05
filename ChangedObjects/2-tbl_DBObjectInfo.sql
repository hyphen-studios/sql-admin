CREATE TABLE [dbo].[DBObjectInfo](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](50) NULL,
	[SessionID] [int] NULL,
	[LoginName] [nvarchar](150) NULL,
	[HostName] [nvarchar](75) NULL,
	[ProgramName] [nvarchar](75) NULL,
	[DBName] [nvarchar](50) NULL,
	[EventTime] [datetime2](7) NULL,
	[EventType] [nvarchar](50) NULL,
	[EventClass] [int] NULL,
	[ObjectType] [nvarchar](50) NULL,
	[Object] [nvarchar](150) NULL,
 CONSTRAINT [PK_DBObjectInfo] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO


