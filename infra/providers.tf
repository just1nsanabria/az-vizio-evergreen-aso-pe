terraform {
  required_version = ">= 1.5.0"

  # ---------------------------------------------------------------------------
  # Remote state — Azure Blob Storage
  # Auth is handled via OIDC (ARM_USE_OIDC=true) in CI.
  # For local runs: `az login` is sufficient; no storage account key needed.
  # Update storage_account_name if you used a different name in Step 3.
  # ---------------------------------------------------------------------------
  # use_azuread_auth=true forces Bearer token auth.
  # Required because key-based auth is disabled on this storage account.
  backend "azurerm" {
    resource_group_name  = "rg-eus2-evergreen-mgmt"
    storage_account_name = "sttfstatevsaz01"
    container_name       = "tfstate"
    key                  = "hub-spoke.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.90.0"
    }
    # azapi is used to set customDnsServers on the VPN gateway P2S
    # configuration — a property not exposed by the azurerm provider.
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.13.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

provider "azapi" {}
