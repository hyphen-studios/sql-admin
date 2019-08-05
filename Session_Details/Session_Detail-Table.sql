CREATE TABLE [dbo].[SessionDetails](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[server_name] [nvarchar](128) NOT NULL,
	[session_id] [int] NOT NULL,
	[login_name] [nchar](128) NOT NULL,
	[login_time] [datetime] NOT NULL,
	[loggedoffby_time] [datetime] NULL,
	[host_name] [nchar](128) NOT NULL,
	[program_name] [nchar](128) NULL,
	[db_name] [nvarchar](128) NULL
--PRIMARY KEY CLUSTERED 
CONSTRAINT [PK_SessionDetails] PRIMARY KEY CLUSTERED
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

CREATE UNIQUE NONCLUSTERED INDEX [IX_unique_SessionDetails] ON [dbo].[SessionDetails]
(
	[session_id] ASC,
	[login_name] ASC,
	[login_time] ASC,
	[db_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
--GO
ALTER TABLE [dbo].[SessionDetails] ADD  CONSTRAINT [DF_server_name]  DEFAULT (@@servername) FOR [server_name]
