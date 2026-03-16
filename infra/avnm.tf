# ---------------------------------------------------------
# Azure Virtual Network Manager
# ---------------------------------------------------------
resource "azurerm_network_manager" "avnm" {
  name                = var.avnm_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  description         = "AVNM managing hub-and-spoke topology"

  scope {
    subscription_ids = ["/subscriptions/${var.subscription_id}"]
  }

  scope_accesses = ["Connectivity"]
}

# ---------------------------------------------------------
# Network Groups
# ---------------------------------------------------------
resource "azurerm_network_manager_network_group" "ng_hub" {
  name               = var.avnm_ng_hub_name
  network_manager_id = azurerm_network_manager.avnm.id
  description        = "Network group for hub virtual networks"
}

resource "azurerm_network_manager_network_group" "ng_spokes" {
  name               = var.avnm_ng_spokes_name
  network_manager_id = azurerm_network_manager.avnm.id
  description        = "Network group for spoke virtual networks"
}

# ---------------------------------------------------------
# Static Members – associate VNets to network groups
# ---------------------------------------------------------
resource "azurerm_network_manager_static_member" "hub_vnet" {
  name                      = "sm-hub-vnet"
  network_group_id          = azurerm_network_manager_network_group.ng_hub.id
  target_virtual_network_id = azurerm_virtual_network.hub.id
}

resource "azurerm_network_manager_static_member" "spoke_vnet" {
  name                      = "sm-spoke-vnet"
  network_group_id          = azurerm_network_manager_network_group.ng_spokes.id
  target_virtual_network_id = azurerm_virtual_network.spoke.id
}

resource "azurerm_network_manager_static_member" "spoke2_vnet" {
  name                      = "sm-spoke2-vnet"
  network_group_id          = azurerm_network_manager_network_group.ng_spokes.id
  target_virtual_network_id = azurerm_virtual_network.spoke2.id
}

# ---------------------------------------------------------
# Connectivity Configuration – Hub and Spoke
# ---------------------------------------------------------
resource "azurerm_network_manager_connectivity_configuration" "hub_spoke" {
  name                  = var.avnm_connectivity_config_name
  network_manager_id    = azurerm_network_manager.avnm.id
  connectivity_topology = "HubAndSpoke"
  description           = "Hub-and-spoke connectivity managed by AVNM"

  hub {
    resource_id   = azurerm_virtual_network.hub.id
    resource_type = "Microsoft.Network/virtualNetworks"
  }

  applies_to_group {
    network_group_id    = azurerm_network_manager_network_group.ng_spokes.id
    group_connectivity  = "None"
    use_hub_gateway     = false
    global_mesh_enabled = false
  }

  delete_existing_peering_enabled = true
  global_mesh_enabled             = false
}

# ---------------------------------------------------------
# Deployment – commit the connectivity configuration
# ---------------------------------------------------------
resource "azurerm_network_manager_deployment" "hub_spoke" {
  network_manager_id = azurerm_network_manager.avnm.id
  location           = var.location
  scope_access       = "Connectivity"
  configuration_ids  = [azurerm_network_manager_connectivity_configuration.hub_spoke.id]

  depends_on = [
    azurerm_network_manager_static_member.hub_vnet,
    azurerm_network_manager_static_member.spoke_vnet,
    azurerm_network_manager_static_member.spoke2_vnet,
  ]
}
