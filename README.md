# Creating Geo-Replicated Azure SQL Database with auto-failover group using Terraform

[![Github](https://img.shields.io/badge/Github%20-Repository-brightgreen.svg?style=flat)](https://github.com/kumarvna/tf-azure-sqldb-fog.git)

In this post, we are going to learn how to use Terraform to create an Azure SQL Database and then extend the Terraform template to create a geo-replicated database with an auto-failover group.

-----------------------
## Getting Started with Terrafom

If you're new to Terraform and want to get started creating infrastructure, please checkout our [Getting Started](https://learn.hashicorp.com/terraform/azure/install_az) guide, available on the [Terraform website](https://www.terraform.io/).

All documentation is available on the Terraform website:

[Introduction](https://www.terraform.io/intro/index.html)

[Documentation](https://www.terraform.io/docs/index.html)

-----------------------

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

Now, create file name `vnet.tf` to add vNet, subnet and storage account declaration.

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
Now that the requirements are in place, we can now create Azure SQL Servers definition.

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

Now we need to add a SQL Server firewall rule to allow Azure services to connect to this database. This is not done by default when using Terraform.  Add following declaration to enable the rule.

```
resource "azurerm_sql_firewall_rule" "iibdb_fw01" {
 name                          = "sqldb-fwrule-001"
 resource_group_name           = azurerm_resource_group.iib_rg01.name
 server_name                   = azurerm_sql_server.iibdb_server01.name
 start_ip_address              = "0.0.0.0"
 end_ip_address                = "0.0.0.0"
 }
```
Next create Azure SQL Database on primary database server. We are using already declared storage account to store the audit and TDP logs. 
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

Next step is to Create a failover group of databases on a collection of Azure SQL servers.

```
resource "azurerm_sql_failover_group" "sql-failovergrp" {
 name                         = "sqldb-failover-group01"
 resource_group_name          = azurerm_resource_group.iib_rg01.name
 server_name                  = azurerm_sql_server.iibdb_server01.name
 databases                    = [azurerm_sql_database.iibdb_sqldb01.id]
 partner_servers {
   id = azurerm_sql_server.iibdb_server02.id
 }
 read_write_endpoint_failover_policy {
   mode           = "Automatic"
   grace_minutes  = 60
 }
}
```

## All the changes together
Here is the template which should look like with all the configuration. You can also look at it on Github [here](https://github.com/kumarvna/tf-azure-sqldb-fog/blob/master/sqldb.tf) 

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

resource "azurerm_sql_firewall_rule" "iibdb_fw01" {
 name                          = "sqldb-fwrule-001"
 resource_group_name           = azurerm_resource_group.iib_rg01.name
 server_name                   = azurerm_sql_server.iibdb_server01.name
 start_ip_address              = "0.0.0.0"
 end_ip_address                = "0.0.0.0"
 }

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

resource "azurerm_sql_failover_group" "sql-failovergrp" {
 name                         = "sqldb-failover-group01"
 resource_group_name          = azurerm_resource_group.iib_rg01.name
 server_name                  = azurerm_sql_server.iibdb_server01.name
 databases                    = [azurerm_sql_database.iibdb_sqldb01.id]
 partner_servers {
   id = azurerm_sql_server.iibdb_server02.id
 }
 read_write_endpoint_failover_policy {
   mode           = "Automatic"
   grace_minutes  = 60
 }
depends_on  = [azurerm_sql_server.iibdb_server02]
}
```

Let’s create a variable file to pass those variables into all tf files we created so far.

```
$ touch terraform.tfvars
```
Now let's open the terraform.tfvars file define all variables. You can also look at it on Github [here](https://github.com/kumarvna/tf-azure-sqldb-fog/blob/master/terraform.tfvars) 

```
resource_group_name = "rg-iib-demo-001"
location = "northeurope"
db_secondary_location="westeurope"
environment = "Development"
costcenter_id = "Cloud-Division"
project_name = "MyTestProject"
vnet_name = "vnet-iib-northeurope-001"
vnet_address_space = ["10.0.0.0/16"]
app_subnet = "snet-iibapp-northeurope-001"
app_subnet_prefix = "10.0.2.0/24"
db_subnet = "snet-iibdb-northeurope-001"
db_subnet_prefix = "10.0.3.0/24"
gateway_subnet = "snet-bastionvm-northeurope-001"
gateway_subnet_prefix = "10.0.1.0/24"
db_server_name01 = "sqldbserver-i2iapp-dev-01"
db_server_name02 = "sqldbserver-i2iapp-dev-02"
db_name = "sqldbi2iapp"
db_version = "12.0"
db_admin_login = "masterdoe"
db_admin_pass = "LtKBrRTZ3k8gJfgD"
storage_alert_emailid = ["abcd@me.com"]
```
We can validate if our template syntax is correctly defined. The first step is to initialize Terraform to get the required modules.

```
$ terraform init

Initializing the backend...

Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "azurerm" (hashicorp/azurerm) 2.2.0...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.azurerm: version = "~> 2.2"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Now let's validate the terraform syntax we crated.

```
$ terraform validate
Success! The configuration is valid.
```

Now that it is validated and successful, we need to login to our Azure Account to execute against it.

One of the unique features of Terraform is that it creates a plan, sort of like an execution plan of the resources. When you enter *`terraform Plan`* in the command prompt, it will list out all the resources it will deploy.
Let’s execute our plan and see what will be created.

```
$ terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

Plan: 15 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------
```

The plan shows it will be creating 15 resources. it looks ok to me, let's execute the plan. You will be prompted if you would like to proceed and type yes if you do.

```
$  terraform apply

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

Plan: 15 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
```
## Conclusion

This post intended to get you to create Azure SQL DB using Terraform. We started with a basic example and expanded upon it to build out a geo-replicated database using an auto-failover group. There are a lot of inventive techniques accomplish this as well. Next time, we will discuss creating Private Link for Azure SQL Database and make it available to all apps within the VPC.

Thanks for reading. Please let me know on this repo’s GitHub, workplace, LinkedIn what you thought about this post.

*- Kumar*


