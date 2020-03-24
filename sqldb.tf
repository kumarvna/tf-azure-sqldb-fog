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
