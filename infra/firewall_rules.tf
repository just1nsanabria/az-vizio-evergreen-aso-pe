# ---------------------------------------------------------
# Azure Firewall – NAT Rule Collections (DNAT)
# ---------------------------------------------------------

# RDP to jumpbox – restricted to a single source IP
resource "azurerm_firewall_nat_rule_collection" "jumpbox_rdp" {
  name                = "nrc-jumpbox-rdp"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 100
  action              = "Dnat"

  rule {
    name = "rdp-to-jumpbox"
    source_addresses = [
      var.jumpbox_rdp_source_ip,
    ]
    destination_addresses = [azurerm_public_ip.firewall.ip_address]
    destination_ports     = ["3389"]
    protocols             = ["TCP"]
    translated_address    = azurerm_network_interface.jumpbox.private_ip_address
    translated_port       = "3389"
  }
}

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

# GitHub – required for Actions Runner Controller (ARC)
# The self-hosted runner inside hub AKS must reach GitHub to:
#   - Register the runner (api.github.com)
#   - Poll for and receive jobs (*.actions.githubusercontent.com)
#   - Download runner binaries and action packages (objects.githubusercontent.com,
#     *.blob.core.windows.net, *.pkg.github.com, *.pkg.githubusercontent.com)
resource "azurerm_firewall_application_rule_collection" "github_actions" {
  name                = "arc-github-actions"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 130
  action              = "Allow"

  rule {
    name = "github-api"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    target_fqdns = [
      "api.github.com",
      "github.com",
      "*.github.com",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "github-actions-runner"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    target_fqdns = [
      "*.actions.githubusercontent.com",
      "objects.githubusercontent.com",
      "pkg-containers.githubusercontent.com",
      "*.pkg.github.com",
      "*.pkg.githubusercontent.com",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "github-runner-blob-downloads"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    # Runner binaries and action archives are served from Azure Blob Storage
    target_fqdns = [
      "*.blob.core.windows.net",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "helm-chart-repos"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    # Helm repos for cert-manager (charts.jetstack.io) and ASO (raw.githubusercontent.com)
    target_fqdns = [
      "charts.jetstack.io",
      "raw.githubusercontent.com",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }

  rule {
    name = "ci-tooling-install"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    # Domains required to install az CLI, kubectl, and Helm on the ARC runner:
    #   aka.ms                  – Azure CLI bootstrap script redirect
    #   packages.microsoft.com  – Azure CLI apt package repository
    #   dl.k8s.io               – kubectl binary download
    #   get.helm.sh             – Helm binary CDN
    target_fqdns = [
      "aka.ms",
      "packages.microsoft.com",
      "dl.k8s.io",
      "get.helm.sh",
    ]
    protocol {
      port = "443"
      type = "Https"
    }
  }
}

# ---------------------------------------------------------
# TESTING ONLY – Wildcard allow-all HTTP/HTTPS
# Allows all outbound web traffic from the hub VNet so CI
# tooling install (apt, curl, etc.) doesn't hit individual
# FQDN blocks. Remove or tighten before production use.
# ---------------------------------------------------------
resource "azurerm_firewall_application_rule_collection" "allow_all_web" {
  name                = "arc-allow-all-web"
  azure_firewall_name = azurerm_firewall.hub.name
  resource_group_name = azurerm_resource_group.hub.name
  priority            = 500
  action              = "Allow"

  rule {
    name = "allow-all-http"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    target_fqdns = ["*"]
    protocol {
      port = "80"
      type = "Http"
    }
  }

  rule {
    name = "allow-all-https"
    source_addresses = [
      var.hub_vnet_address_space[0],
    ]
    target_fqdns = ["*"]
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
