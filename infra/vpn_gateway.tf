# ---------------------------------------------------------
# Public IP for VPN Gateway (zone-redundant)
# ---------------------------------------------------------
resource "azurerm_public_ip" "vpn_gateway" {
  name                = var.vpn_gateway_pip_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  lifecycle {
    ignore_changes = [ip_tags]
  }
}

# ---------------------------------------------------------
# Virtual Network Gateway – Route-based, P2S with Entra ID SSO
# ---------------------------------------------------------
# Prerequisite: in your Entra tenant, navigate to
#   Enterprise Applications → Azure VPN (app ID 41b23e61-6c1e-4545-b367-cd054e0ed4b4)
# and either:
#   a) disable "Assignment required" so all users can connect, or
#   b) assign the specific users/groups who should have VPN access.
#
# After apply, download the VPN client package from the Azure Portal:
#   Virtual Network Gateway → Point-to-site configuration → Download VPN client
# The package contains an OpenVPN config that authenticates via browser-based
# Entra ID sign-in (supports MFA, Conditional Access, etc.)
# ---------------------------------------------------------
resource "azurerm_virtual_network_gateway" "hub" {
  name                = var.vpn_gateway_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  generation          = "Generation1"
  active_active       = false
  bgp_enabled         = false

  ip_configuration {
    name                          = "ipconfig-vpngw"
    subnet_id                     = azurerm_subnet.gateway.id
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
  }

  vpn_client_configuration {
    address_space        = [var.vpn_client_address_pool]
    vpn_client_protocols = ["OpenVPN"]
    vpn_auth_types       = ["AAD"]

    aad_tenant   = "https://login.microsoftonline.com/${var.tenant_id}/"
    aad_audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
    aad_issuer   = "https://sts.windows.net/${var.tenant_id}/"
  }

  depends_on = [
    azurerm_subnet.gateway,
  ]
}
