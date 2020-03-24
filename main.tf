provider "azurerm" {
    features {}
  }

# to get the list of all locations with table format "az account list-locations -o table"
resource "azurerm_resource_group" "iib_rg01" {
  name      = var.resource_group_name
  location  = var.location
  tags      = local.tags
}

locals {
  tags = {
    "ApplicationName" = "Insurance-in-a-Box"
    "Approver"        = "kumaraswamy.vithanala@tieto.com"
    "BusinessUnit"    = "Finance Serivces"
    "CostCenter"      = var.costcenter_id
    "Environment"     = var.environment
    "Project"         = var.project_name
  } 
}
