# Creating Geo-Replicated Azure SQL Database with an auto-failover group using Terraform
[![Github](https://img.shields.io/badge/Github%20-Repository-brightgreen.svg?style=flat)](https://github.com/kumarvna/tf-azure-sqldb-fog.git)

In this post, we are going to learn how to use Terraform to create an Azure SQL Database and then extend the Terraform template to create a geo-replicated database with an auto-failover group.

## Azure SQL Geo-Replication and Failover Groups

Microsoft Azure offers different types of business continuity solutions for their SQL database. One of these solutions is Geo-Replication that provides an asynchronous database copy. You can store this copy in the same or different regions. You can setup up to four readable database copies. In the documentation of Microsoft notes, the recovery point objective (RPO is the maximum acceptable amount of data loss measured in time) is less than 5 seconds. If we want to automate and make (users will not affect) failover mechanism transparent, we have to create the auto-failover group.

![enter image description here](https://docs.microsoft.com/en-us/azure/sql-database/media/sql-database-auto-failover-group/auto-failover-group.png)

## Failover group (FOG)

A failover group is a named group of databases managed by a single SQL Database server or within a single managed instance that can fail over as a unit to another region in case all or some primary databases become unavailable due to an outage in the primary region. When created for managed instances, a failover group contains all user databases in the instance and therefore only one failover group can be configured on an instance. The name of the failover group must be globally unique within the .database.windows.net domain.

## SQL Database servers

With SQL Database servers, some or all of the user databases on a single SQL Database server can be placed in a failover group. Also, a SQL Database server supports multiple failover groups on a single SQL Database server.

### Primary

The SQL Database server or managed instance that hosts the primary databases in the failover group.

### Secondary

The SQL Database server or managed instance that hosts the secondary databases in the failover group. The secondary cannot be in the same region as the primary.

### Adding single databases to failover group

You can put several single databases on the same SQL Database server into the same failover group. If you add a single database to the failover group, it automatically creates a secondary database using the same edition and the compute size on the secondary server. You specified that server when the failover group was created.

For more information,  [![Github](https://img.shields.io/badge/Visit%20Mircosoft%20-Documentation-brightgreen.svg?style=flat)](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-auto-failover-group?tabs=azure-powershell)


### Let’s get started.


## Azure SQL Database template

First, we are going to create a required Azure SQL Database template. The first step is to create our terraform files.
