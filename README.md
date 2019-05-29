# sql-admin
This Administration database is a tool to be used by DBAs and developers alike to help with their maintenance tasks and processing. It's a collection of tables, stored procedures, and functions that I've written over the years to help me with my daily, weekly, and monthly tasks.

This is for Microsoft SQL Server - Not all SQL versions have been validated.

# Replication - Creating and Dropping Replication Dynamically
The tables, and the stored procedures will help you automate the creation and deletion of replication. You will need to edit the sp_ReplicationStart script to accept the security settings for your environment. I will go over how to handle that later.
