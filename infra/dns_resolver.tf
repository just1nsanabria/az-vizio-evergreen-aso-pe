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
# The inbound endpoint's private IP is pushed to P2S OpenVPN
# clients automatically via dns_servers in vpn_gateway.tf.
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
