# ---------------------------------------------------------
# Azure Firewall – Application Rule Collections
# ---------------------------------------------------------

# AKS-required FQDNs (Microsoft-maintained FQDN tag covers the AKS control
# plane, node image downloads, and Azure services required for cluster health)
resource "azurerm_firewall_application_rule_collection" "aks_required" {
  name                = "arc-aks-required"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "aks-fqdn-tag"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    fqdn_tags = ["AzureKubernetesService"]
  }
}

# Container registries – required for cert-manager and ASO image pulls
resource "azurerm_firewall_application_rule_collection" "container_registries" {
  name                = "arc-container-registries"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 110
  action              = "Allow"

  rule {
    name = "quay-io"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    target_fqdns = ["quay.io", "*.quay.io"]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "mcr-microsoft-com"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    target_fqdns = ["mcr.microsoft.com", "*.mcr.microsoft.com"]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "registry-k8s-io"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    target_fqdns = ["registry.k8s.io", "*.registry.k8s.io"]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "ghcr-io"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    target_fqdns = ["ghcr.io", "*.ghcr.io"]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}

# Azure platform services – required for ASO (ARM, Entra ID) and workload identity
resource "azurerm_firewall_application_rule_collection" "azure_services" {
  name                = "arc-azure-services"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 120
  action              = "Allow"

  rule {
    name = "entra-id"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    target_fqdns = [
      "login.microsoftonline.com",
      "*.login.microsoftonline.com",
      "login.microsoft.com",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "azure-management"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    target_fqdns = [
      "management.azure.com",
      "*.management.azure.com",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}

# ---------------------------------------------------------
# Azure Firewall – Network Rule Collections
# ---------------------------------------------------------

# NTP – required for node time sync
resource "azurerm_firewall_network_rule_collection" "ntp" {
  name                = "nrc-ntp"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "ntp"
    source_addresses = [
      var.hub_vnet_address_space[0],
      var.spoke_vnet_address_space[0],
    ]
    destination_ports     = ["123"]
    destination_addresses = ["*"]
    protocols             = ["UDP"]
  }
}
