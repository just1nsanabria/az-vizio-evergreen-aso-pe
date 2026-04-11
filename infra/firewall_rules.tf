# ---------------------------------------------------------
# Azure Firewall Policy – Rule Collection Groups
# ---------------------------------------------------------

# Network rules (processed first – priority 100)
resource "azurerm_firewall_policy_rule_collection_group" "network" {
  name               = "rcg-network"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 100

  # NTP – required for node time sync
  network_rule_collection {
    name     = "nrc-ntp"
    priority = 100
    action   = "Allow"

    rule {
      name = "ntp"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_ports     = ["123"]
      destination_addresses = ["*"]
      protocols             = ["UDP"]
    }
  }
}

# Application rules – AKS FQDN tag (priority 200)
# Isolated from destination_fqdns rules to avoid Azure API conflicts
resource "azurerm_firewall_policy_rule_collection_group" "aks_fqdn_tag" {
  name               = "rcg-aks-fqdn-tag"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 200

  # AKS-required FQDNs (Microsoft-maintained FQDN tag covers the AKS control
  # plane, node image downloads, and Azure services required for cluster health)
  application_rule_collection {
    name     = "arc-aks-required"
    priority = 100
    action   = "Allow"

    rule {
      name = "aks-fqdn-tag"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdn_tags = ["AzureKubernetesService"]
    }
  }
}

# Application rules – container registries & Azure services (priority 300)
resource "azurerm_firewall_policy_rule_collection_group" "aks_infra" {
  name               = "rcg-aks-infra"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 300

  # Container registries – required for cert-manager and ASO image pulls
  application_rule_collection {
    name     = "arc-container-registries"
    priority = 110
    action   = "Allow"

    rule {
      name = "quay-io"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdns = ["quay.io", "*.quay.io"]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "mcr-microsoft-com"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdns = ["mcr.microsoft.com", "*.mcr.microsoft.com"]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "registry-k8s-io"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdns = ["registry.k8s.io", "*.registry.k8s.io"]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "ghcr-io"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdns = ["ghcr.io", "*.ghcr.io"]
      protocols {
        port = 443
        type = "Https"
      }
    }
  }

  # Azure platform services – required for ASO (ARM, Entra ID) and workload identity
  application_rule_collection {
    name     = "arc-azure-services"
    priority = 120
    action   = "Allow"

    rule {
      name = "entra-id"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdns = [
        "login.microsoftonline.com",
        "*.login.microsoftonline.com",
        "login.microsoft.com",
      ]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "azure-management"
      source_addresses = [
        var.hub_vnet_address_space[0],
        var.spoke_vnet_address_space[0],
        var.spoke2_vnet_address_space[0],
      ]
      destination_fqdns = [
        "management.azure.com",
        "*.management.azure.com",
      ]
      protocols {
        port = 443
        type = "Https"
      }
    }
  }
}

# Application rules – GitHub & CI tooling (priority 400)
resource "azurerm_firewall_policy_rule_collection_group" "github_ci" {
  name               = "rcg-github-ci"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 400

  # GitHub – required for Actions Runner Controller (ARC)
  # The self-hosted runner inside hub AKS must reach GitHub to:
  #   - Register the runner (api.github.com)
  #   - Poll for and receive jobs (*.actions.githubusercontent.com)
  #   - Download runner binaries and action packages (objects.githubusercontent.com,
  #     *.blob.core.windows.net, *.pkg.github.com, *.pkg.githubusercontent.com)
  application_rule_collection {
    name     = "arc-github-actions"
    priority = 100
    action   = "Allow"

    rule {
      name = "github-api"
      source_addresses = [
        var.hub_vnet_address_space[0],
      ]
      destination_fqdns = [
        "api.github.com",
        "github.com",
        "*.github.com",
      ]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "github-actions-runner"
      source_addresses = [
        var.hub_vnet_address_space[0],
      ]
      destination_fqdns = [
        "*.actions.githubusercontent.com",
        "objects.githubusercontent.com",
        "pkg-containers.githubusercontent.com",
        "*.pkg.github.com",
        "*.pkg.githubusercontent.com",
      ]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "github-runner-blob-downloads"
      source_addresses = [
        var.hub_vnet_address_space[0],
      ]
      # Runner binaries and action archives are served from Azure Blob Storage
      destination_fqdns = [
        "*.blob.core.windows.net",
      ]
      protocols {
        port = 443
        type = "Https"
      }
    }

    rule {
      name = "helm-chart-repos"
      source_addresses = [
        var.hub_vnet_address_space[0],
      ]
      # Helm repos for cert-manager (charts.jetstack.io) and ASO (raw.githubusercontent.com)
      destination_fqdns = [
        "charts.jetstack.io",
        "raw.githubusercontent.com",
      ]
      protocols {
        port = 443
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
      destination_fqdns = [
        "aka.ms",
        "packages.microsoft.com",
        "dl.k8s.io",
        "get.helm.sh",
      ]
      protocols {
        port = 443
        type = "Https"
      }
    }
  }
}

# ---------------------------------------------------------
# TESTING ONLY – Wildcard allow-all HTTP/HTTPS (priority 900)
# Allows all outbound web traffic from the hub VNet so CI
# tooling install (apt, curl, etc.) doesn't hit individual
# FQDN blocks. Remove or tighten before sandbox use.
# ---------------------------------------------------------
resource "azurerm_firewall_policy_rule_collection_group" "allow_all" {
  name               = "rcg-allow-all"
  firewall_policy_id = azurerm_firewall_policy.hub.id
  priority           = 900

  application_rule_collection {
    name     = "arc-allow-all-web"
    priority = 100
    action   = "Allow"

    rule {
      name = "allow-all-http"
      source_addresses = [
        var.hub_vnet_address_space[0],
      ]
      destination_fqdns = ["*"]
      protocols {
        port = 80
        type = "Http"
      }
    }

    rule {
      name = "allow-all-https"
      source_addresses = [
        var.hub_vnet_address_space[0],
      ]
      destination_fqdns = ["*"]
      protocols {
        port = 443
        type = "Https"
      }
    }
  }
}

