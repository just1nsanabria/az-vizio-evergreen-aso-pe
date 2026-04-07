# ---------------------------------------------------------
# Public IPs for Azure Firewall (IPv4 + IPv6)
# ---------------------------------------------------------
resource "azurerm_public_ip" "firewall" {
  name                = var.firewall_pip_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "firewall_v6" {
  name                = var.firewall_pip_v6_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv6"
  zones               = ["1", "2", "3"]
}

# ---------------------------------------------------------
# Azure Firewall Policy
# ---------------------------------------------------------
resource "azurerm_firewall_policy" "hub" {
  name                = var.firewall_policy_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  sku                 = var.firewall_sku_tier
}

# ---------------------------------------------------------
# Azure Firewall (dual-stack)
# ---------------------------------------------------------
resource "azurerm_firewall" "hub" {
  name                = var.firewall_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.hub.id
  zones               = ["1", "2", "3"]

  # Primary IPv4 configuration – must specify subnet_id
  ip_configuration {
    name                 = "ipconfig-fw"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  # Secondary IPv6 configuration – no subnet_id (shares AzureFirewallSubnet)
  ip_configuration {
    name                 = "ipconfig-fw-v6"
    public_ip_address_id = azurerm_public_ip.firewall_v6.id
  }

  depends_on = [
    azurerm_subnet.firewall,
  ]
}
