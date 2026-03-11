# fw_private_ip_v4 is read from the primary ip_configuration (known after plan).
# fw_private_ip_v6 cannot be reliably computed during plan because the azurerm
# provider does not expose the private_ip_address of secondary ip_configurations
# until after apply. Azure always assigns the 4th IPv6 address in the subnet
# (first 3 are reserved), so it is deterministic and set as a variable instead.
locals {
  fw_private_ip_v4 = one([for ic in azurerm_firewall.hub.ip_configuration : ic.private_ip_address if ic.name == "ipconfig-fw"])
}

# ---------------------------------------------------------
# Route Tables
# One per workload subnet so each can be managed independently.
# Default routes send all internet-bound traffic through Azure Firewall.
# Dual-stack clusters with userDefinedRouting require BOTH 0.0.0.0/0 and
# ::/0 default routes pointing to VirtualAppliance.
# bgp_route_propagation_enabled = false prevents on-premises routes from
# overriding the forced-tunnel defaults.
# ---------------------------------------------------------

# --- Hub: AKS subnet ---
resource "azurerm_route_table" "hub_aks" {
  name                          = var.hub_aks_rt_name
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "hub_aks_default_v4" {
  name                   = "route-default-v4"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hub_aks.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.fw_private_ip_v4
}

resource "azurerm_route" "hub_aks_default_v6" {
  name                   = "route-default-v6"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hub_aks.name
  address_prefix         = "::/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip_v6
}

resource "azurerm_subnet_route_table_association" "hub_aks" {
  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.hub_aks.id
}

# --- Hub: Management subnet ---
resource "azurerm_route_table" "hub_mgmt" {
  name                          = var.hub_mgmt_rt_name
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "hub_mgmt_default_v4" {
  name                   = "route-default-v4"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hub_mgmt.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.fw_private_ip_v4
}

resource "azurerm_route" "hub_mgmt_default_v6" {
  name                   = "route-default-v6"
  resource_group_name    = azurerm_resource_group.hub.name
  route_table_name       = azurerm_route_table.hub_mgmt.name
  address_prefix         = "::/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip_v6
}

# Return path for P2S VPN clients – without this, replies from snet-mgmt
# (forced through the firewall by the 0.0.0.0/0 UDR) would hit the firewall
# with no session state and be dropped. Routing return traffic back via
# VirtualNetworkGateway keeps the path symmetric.
resource "azurerm_route" "hub_mgmt_vpn_clients" {
  name                = "route-vpn-clients"
  resource_group_name = azurerm_resource_group.hub.name
  route_table_name    = azurerm_route_table.hub_mgmt.name
  address_prefix      = var.vpn_client_address_pool
  next_hop_type       = "VirtualNetworkGateway"
}

resource "azurerm_subnet_route_table_association" "hub_mgmt" {
  subnet_id      = azurerm_subnet.mgmt.id
  route_table_id = azurerm_route_table.hub_mgmt.id
}

# --- Spoke: Workload subnet ---
resource "azurerm_route_table" "spoke_workload" {
  name                          = var.spoke_workload_rt_name
  resource_group_name           = azurerm_resource_group.spoke.name
  location                      = azurerm_resource_group.spoke.location
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "spoke_workload_default_v4" {
  name                   = "route-default-v4"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.spoke_workload.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.fw_private_ip_v4
}

resource "azurerm_route" "spoke_workload_default_v6" {
  name                   = "route-default-v6"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.spoke_workload.name
  address_prefix         = "::/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip_v6
}

resource "azurerm_subnet_route_table_association" "spoke_workload" {
  subnet_id      = azurerm_subnet.spoke_workload.id
  route_table_id = azurerm_route_table.spoke_workload.id
}

# --- Spoke: AKS subnet ---
# This route table must be associated BEFORE ASO deploys the spoke AKS cluster
# because outbound_type = userDefinedRouting requires the UDR to exist at
# cluster creation time.
resource "azurerm_route_table" "spoke_aks" {
  name                          = var.spoke_aks_rt_name
  resource_group_name           = azurerm_resource_group.spoke.name
  location                      = azurerm_resource_group.spoke.location
  bgp_route_propagation_enabled = false
}

resource "azurerm_route" "spoke_aks_default_v4" {
  name                   = "route-default-v4"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.spoke_aks.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.fw_private_ip_v4
}

resource "azurerm_route" "spoke_aks_default_v6" {
  name                   = "route-default-v6"
  resource_group_name    = azurerm_resource_group.spoke.name
  route_table_name       = azurerm_route_table.spoke_aks.name
  address_prefix         = "::/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip_v6
}

resource "azurerm_subnet_route_table_association" "spoke_aks" {
  subnet_id      = azurerm_subnet.spoke_aks.id
  route_table_id = azurerm_route_table.spoke_aks.id
}
