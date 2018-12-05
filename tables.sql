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
