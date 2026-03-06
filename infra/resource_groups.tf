resource "azurerm_resource_group" "hub" {
  name     = var.hub_rg_name
  location = var.location
}

resource "azurerm_resource_group" "spoke" {
  name     = var.spoke_rg_name
  location = var.location
}
