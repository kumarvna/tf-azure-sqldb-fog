# Creating Geo-Replicated Azure SQL Database with auto-failover group using Terraform
[![Github](https://img.shields.io/badge/Github%20-Repository-brightgreen.svg?style=flat)](https://github.com/kumarvna/tf-azure-sqldb-fog.git)

In this post, we are going to learn how to use Terraform to create an Azure SQL Database and then extend the Terraform template to create a geo-replicated database with an auto-failover group.

## Azure SQL Geo-Replication and Failover Groups

Microsoft Azure offers different types of business continuity solutions for their SQL database. One of these solutions is Geo-Replication that provides an asynchronous database copy. You can store this copy in the same or different regions. You can setup up to four readable database copies. In the documentation of Microsoft notes, the recovery point objective (RPO is the maximum acceptable amount of data loss measured in time) is less than 5 seconds. If we want to automate and make (users will not affect) failover mechanism transparent, we have to create the auto-failover group.

![https://docs.microsoft.com/en-us/azure/sql-database/media/sql-database-auto-failover-group/auto-failover-group.png](https://docs.microsoft.com/en-us/azure/sql-database/media/sql-database-auto-failover-group/auto-failover-group.png)

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

## Prerequisites

The below example assumes you have Terraform configured for use with your Azure Subscription. Terraform supports a number of different methods for authenticating to Azure.   I recommend using either a Service Principal or Managed Service Identity when running Terraform non-interactively (such as when running Terraform in a CI server) - and authenticating using the Azure CLI when running Terraform locally.

Firstly, login to the Azure CLI using:

```
$ az login
```
Should you have more than one Subscription, you can specify the Subscription to use via the following command:

```
$ az account set --subscription="SUBSCRIPTION_ID"
```

## Azure SQL Database terraform template

First, we are going to create a required Azure SQL Database template. The first step is to create our terraform files.

```
$ touch main.tf
```

Let’s start adding content. Firstly, we need to add the Azure provider.

```
provider "azurerm" {
    features {}
  }
```

Next, we need to add a resource group.

```
resource "azurerm_resource_group" "iib_rg01" {
  name      = var.resource_group_name
  location  = var.location
  tags      = local.tags
}
```

We need to make sure that we add some tags to all of our resources.

Create a local variable to hold our tag map, so we can reuse those tags and apply the same to all of our resources.

Add all required tags the following to main.tf right after our provider statement.

```
locals {
  tags = {
    "ApplicationName" = "MytestApplication"
    "Approver"        = "abcd@me.com"
    "BusinessUnit"    = "Finance Serivces"
    "CostCenter"      = var.costcenter_id
    "Environment"     = var.environment
    "Project"         = var.project_name
  } 
}
```

Now, create file name vnet.tf to add vNet, subnet and storage account declaration.

```
$ touch vnet.tf
```

Let's add network resources and relevant configuration to vnet.tf file. 

```
resource "azurerm_network_ddos_protection_plan" "iib_ddos_plan" {
 name                 = "iibvpcddosplan01"
 location             = var.location
 resource_group_name  = azurerm_resource_group.iib_rg01.name
}

resource "azurerm_virtual_network" "iib_vpc01" {
 name                 = var.vnet_name
 location             = var.location
 resource_group_name  = azurerm_resource_group.iib_rg01.name
 address_space        = var.vnet_address_space
 tags                 = local.tags
 ddos_protection_plan {
   id     = azurerm_network_ddos_protection_plan.iib_ddos_plan.id
   enable = "true"
 }
 }

resource "azurerm_subnet" "snet_gw01" {
  name                  = var.gateway_subnet
  resource_group_name   = azurerm_resource_group.iib_rg01.name
  virtual_network_name  = azurerm_virtual_network.iib_vpc01.name
  address_prefix        = var.gateway_subnet_prefix
}

resource "azurerm_subnet" "snet_app01" {
 name                   = var.app_subnet
 resource_group_name    = azurerm_resource_group.iib_rg01.name
 virtual_network_name   = azurerm_virtual_network.iib_vpc01.name
 address_prefix         = var.app_subnet_prefix 
}

resource "azurerm_subnet" "snet_db01" {
  name                  = var.db_subnet
  resource_group_name   = azurerm_resource_group.iib_rg01.name
  virtual_network_name  = azurerm_virtual_network.iib_vpc01.name
  address_prefix        = var.db_subnet_prefix
}
```
Now add the network security group to define the security rules and attach that into subnets.  

*Please note this is a sample NSG configuration, you have to really work out what ports need to be opened between your subnets and your own corporate network and add relevant rules here to make this more secure and efficient.*

```
resource "azurerm_network_security_group" "nsg_group01" {
 name                 = "nsg-appsubnet"
 location             = var.location
 resource_group_name  = azurerm_resource_group.iib_rg01.name
 tags                 = local.tags
 security_rule {
   name                           = "AllowRDP"
   priority                       = "100"
   direction                      = "Inbound"
   access                         = "Allow"
   protocol                       = "Tcp"
   source_port_range              = "*"
   destination_port_range         = "3389"
   source_address_prefix          = "*"
   destination_address_prefix     = "*"
 }
 security_rule {
   name                           = "Allowhttp"
   priority                       = "101"
   direction                      = "Inbound"
   access                         = "Allow"
   protocol                       = "Tcp"
   source_port_range              = "*"
   destination_port_range         = "80"
   source_address_prefix          = "*"
   destination_address_prefix     = "*"
 }
}

resource "azurerm_subnet_network_security_group_association" "snat-appsec01" {
 subnet_id                  = azurerm_subnet.snet_app01.id
 network_security_group_id  = azurerm_network_security_group.nsg_group01.id
}

resource "azurerm_subnet_network_security_group_association" "snat-dbsec01" {
 subnet_id                  = azurerm_subnet.snet_db01.id
 network_security_group_id  = azurerm_network_security_group.nsg_group01.id
}
```

Next, create a storage account.  This one has a bit more detail to it.  Here you can see, I am giving it a name, telling it to use the already declared resource group to deploy to along with the location.  Since there are different types of storage accounts,  we need to tell it to create a standard storage account with version 2. 

```
resource "azurerm_storage_account" "iibstoreacc" {
  name                      = "iibprojectstorage0001"
  resource_group_name       = azurerm_resource_group.iib_rg01.name
  location                  = var.location
  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
}
```
Now we need to make sure that we have a SQL Server defined.

```
resource "azurerm_sql_server" "iibdb_server01" {
  name                          = var.db_server_name01
  location                      = var.location
  resource_group_name           = azurerm_resource_group.iib_rg01.name
  version                       = var.db_version
  administrator_login           = var.db_admin_login
  administrator_login_password  = var.db_admin_pass
  tags                          = local.tags
  extended_auditing_policy {
      storage_account_access_key = azurerm_storage_account.iibstoreacc.primary_access_key
      storage_endpoint = azurerm_storage_account.iibstoreacc.primary_blob_endpoint
      retention_in_days = 30
  }
}

resource "azurerm_sql_server" "iibdb_server02" {
  name                          = var.db_server_name02
  location                      = var.db_secondary_location
  resource_group_name           = azurerm_resource_group.iib_rg01.name
  version                       = var.db_version
  administrator_login           = var.db_admin_login
  administrator_login_password  = var.db_admin_pass
  tags                          = local.tags
  extended_auditing_policy {
      storage_account_access_key = azurerm_storage_account.iibstoreacc.primary_access_key
      storage_endpoint = azurerm_storage_account.iibstoreacc.primary_blob_endpoint
      retention_in_days = 30
  }
}
```

ow we need to add a SQL Server firewall rule to allow Azure services to connect to this database. This is not done by default when using Terraform.  Add following declaration to enable the rule.

```
resource "azurerm_sql_firewall_rule" "iibdb_fw01" {
 name                          = "sqldb-fwrule-001"
 resource_group_name           = azurerm_resource_group.iib_rg01.name
 server_name                   = azurerm_sql_server.iibdb_server01.name
 start_ip_address              = "0.0.0.0"
 end_ip_address                = "0.0.0.0"
 }
```
Now that the requirements are in place, we can get into creating an Azure SQL Database. We are using already declared storage account to store the audit and TDP logs. 

```
resource "azurerm_sql_database" "iibdb_sqldb01" {
 name                           = var.db_name
 resource_group_name            = azurerm_resource_group.iib_rg01.name
 location                       = var.location
 server_name                    = azurerm_sql_server.iibdb_server01.name
 tags                           = local.tags
 edition                        = "Standard"
 requested_service_objective_name = "S1"

 threat_detection_policy {
    state                      = "Enabled"
    storage_endpoint           = azurerm_storage_account.iibstoreacc.primary_blob_endpoint
    storage_account_access_key = azurerm_storage_account.iibstoreacc.primary_access_key
    disabled_alerts            = ["Sql_Injection"]
    retention_days             = 30
    email_addresses            = var.storage_alert_emailid
 }
}
```
