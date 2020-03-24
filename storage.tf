resource "azurerm_storage_account" "iibstoreacc" {
  name                      = "iibprojectstorage0001"
  resource_group_name       = azurerm_resource_group.iib_rg01.name
  location                  = var.location
  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
}
