/* ------------------------------ Scripts - Create Tables ------------------------------*/

-- MaintenanceTasks - Captures the task being executed, start and end time, along with the script being executed
CREATE TABLE [dbo].[MaintenanceTasks](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[GUID] [uniqueidentifier] NOT NULL,
	[ProcessTask] [nvarchar](50) NOT NULL,
	[DBName] [nvarchar](150) NOT NULL,
	[StartTime] [datetime] NULL,
	[EndTime] [datetime] NULL,
	[Command] [text] NULL,
 CONSTRAINT [PK_MaintenanceTasks] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

-- Maintenance Indexes - Captures the statistics of indexes before and after maintenance tasks.
CREATE TABLE [dbo].[MaintenanceIndexes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[JobID] [uniqueidentifier] NOT NULL,
	[DBName] [nvarchar](150) NOT NULL,
	[DBID] [int] NOT NULL,
	[TblName] [nvarchar](150) NULL,
	[TblID] [int] NULL,
	[IndxID] [int] NULL,
	[IndxName] [nvarchar](150) NULL,
	[IndxType] [nvarchar](50) NULL,
	[IndxDepth] [int] NULL,
	[IndxLevel] [int] NULL,
	[PartitionNum] [int] NULL,
	[PreDeFrag] [nvarchar](50) NULL,
	[PostDefrag] [nvarchar](50) NULL,
	[AvgRecordSize] [nvarchar](50) NULL,
	[AvgSpaceUsed] [nvarchar](50) NULL,
	[RecordCount] [int] NULL,
	[CalcDate] [datetime] NULL,
 CONSTRAINT [PK_MaintenanceIndexes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

-- Maintenance DBCC CHECKDB - Captures the info related to the CHECKDB maintenance tasks
CREATE TABLE [dbo].[MaintenanceCheckDB](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[JobID] [uniqueidentifier] NOT NULL,
	[DBName] [nvarchar](150) NULL,
	[CheckDBErrors] [int] NULL,
	[CheckDBFixed] [int] NULL,
	[CheckDBText] [nvarchar](500) NULL,
 CONSTRAINT [PK_MaintenanceCheckDB] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO



