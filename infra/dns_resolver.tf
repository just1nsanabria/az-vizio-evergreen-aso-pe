# ---------------------------------------------------------
# Azure DNS Private Resolver – hub VNet
#
# Provides a real IP inside the hub VNet that P2S VPN clients
# can query for DNS. The resolver forwards all queries to Azure's
# internal DNS (168.63.129.16), which is not directly reachable
# from outside the VNet. This enables VPN clients to resolve:
#   - Hub AKS private FQDN (system-managed private DNS zone)
#   - Spoke AKS private FQDN (via PE DNS zone linked to hub VNet)
#   - Any other private DNS zones linked to the hub VNet
#
# The inbound endpoint's private IP is set as the hub VNet's
# custom DNS server via azurerm_virtual_network_dns_servers.
# Azure VPN Gateway automatically pushes VNet DNS servers to
# P2S clients in the downloaded OpenVPN profile.
# ---------------------------------------------------------

resource "azurerm_private_dns_resolver" "hub" {
  name                = var.dns_resolver_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  virtual_network_id  = azurerm_virtual_network.hub.id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  name                    = "ep-inbound-01"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  location                = azurerm_resource_group.hub.location

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.dns_inbound.id
  }
}

# ---------------------------------------------------------
# Hub VNet custom DNS servers → DNS Private Resolver
#
# Setting dns_servers on the hub VNet causes Azure to push
# the resolver's inbound IP to P2S VPN clients automatically
# via the downloaded OpenVPN profile (dhcp-option DNS).
# This is more reliable than patching the VPN gateway via
# azapi, which can be overwritten by azurerm PUT operations.
#
# A separate resource is used (rather than inline dns_servers
# on the VNet) to avoid a circular dependency:
#   hub VNet → resolver → inbound endpoint IP → VNet dns_servers
# ---------------------------------------------------------
resource "azurerm_virtual_network_dns_servers" "hub" {
  virtual_network_id = azurerm_virtual_network.hub.id
  dns_servers        = [azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address]
}
