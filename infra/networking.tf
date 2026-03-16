# ---------------------------------------------------------
# Hub Virtual Network
# ---------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = var.hub_vnet_address_space
}

resource "azurerm_subnet" "aks" {
  name                 = var.hub_aks_subnet_name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_aks_subnet_prefix, var.hub_aks_subnet_prefix_v6]
}

resource "azurerm_subnet" "mgmt" {
  name                 = var.hub_mgmt_subnet_name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_mgmt_subnet_prefix, var.hub_mgmt_subnet_prefix_v6]
}

# Azure Firewall requires a subnet named exactly "AzureFirewallSubnet" (/26 minimum)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_fw_subnet_prefix, var.hub_fw_subnet_prefix_v6]
}

# VPN Gateway requires a subnet named exactly "GatewaySubnet" (/27 minimum, /26 recommended)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_gw_subnet_prefix]
}

# Private endpoint subnet – network policies must be disabled on PE subnets
resource "azurerm_subnet" "hub_pe" {
  name                 = var.hub_pe_subnet_name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_pe_subnet_prefix]

  private_endpoint_network_policies = "Disabled"
}

# DNS Private Resolver inbound endpoint subnet.
# Azure requires a dedicated /28+ subnet with no other resources.
# Delegation is required before the inbound endpoint can be created.
resource "azurerm_subnet" "dns_inbound" {
  name                 = var.hub_dns_inbound_subnet_name
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_dns_inbound_subnet_prefix]

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      name    = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ---------------------------------------------------------
# Spoke Virtual Network
# ---------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = var.spoke_vnet_name
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  address_space       = var.spoke_vnet_address_space
}

resource "azurerm_subnet" "spoke_workload" {
  name                 = var.spoke_workload_subnet_name
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_workload_subnet_prefix, var.spoke_workload_subnet_prefix_v6]
}

resource "azurerm_subnet" "spoke_aks" {
  name                 = var.spoke_aks_subnet_name
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_aks_subnet_prefix, var.spoke_aks_subnet_prefix_v6]
}

# ---------------------------------------------------------
# Spoke-02 Virtual Network
# ---------------------------------------------------------
resource "azurerm_virtual_network" "spoke2" {
  name                = var.spoke2_vnet_name
  resource_group_name = azurerm_resource_group.spoke2.name
  location            = azurerm_resource_group.spoke2.location
  address_space       = var.spoke2_vnet_address_space
}

resource "azurerm_subnet" "spoke2_workload" {
  name                 = var.spoke2_workload_subnet_name
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [var.spoke2_workload_subnet_prefix, var.spoke2_workload_subnet_prefix_v6]
}

resource "azurerm_subnet" "spoke2_aks" {
  name                 = var.spoke2_aks_subnet_name
  resource_group_name  = azurerm_resource_group.spoke2.name
  virtual_network_name = azurerm_virtual_network.spoke2.name
  address_prefixes     = [var.spoke2_aks_subnet_prefix, var.spoke2_aks_subnet_prefix_v6]
}

# BYO private DNS zone for spoke-02 AKS.
# By pre-creating this zone and granting the UAMI (uami-aks-eus2-spoke-byodns)
# Private DNS Zone Contributor on it, the spoke-02 AKS cluster can use
# privateDNSZone = <this zone's resource ID> for a predictable, GUID-free FQDN:
#   aks-eus2-spoke-02.privatelink.eastus2.azmk8s.io
resource "azurerm_private_dns_zone" "spoke2_aks" {
  name                = "privatelink.eastus2.azmk8s.io"
  resource_group_name = azurerm_resource_group.spoke2.name
}
