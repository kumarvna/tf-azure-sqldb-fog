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
