CREATE TABLE [dbo].[ReplicationJob](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[JobID] [uniqueidentifier] NULL,
	[JobName] [nvarchar](50) NULL,
	[StartTime] [datetime] NULL,
	[EndTime] [datetime] NULL,
	[Duration] [int] NULL,
	[ExecutedBy] [nvarchar](250) NULL,
 CONSTRAINT [PK_ReplicationJob] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

CREATE TABLE [dbo].[ReplicationArticles](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[JobID] [nvarchar](150) NULL,
	[SchemaName] [nvarchar](50) NULL,
	[ArticleName] [nvarchar](150) NULL,
	[ArticleType] [nvarchar](5) NULL,
	[DateAdded] [datetime] NULL,
 CONSTRAINT [PK_ReplicationArticles] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
