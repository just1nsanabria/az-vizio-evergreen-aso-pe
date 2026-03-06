terraform {
  required_version = ">= 1.5.0"

  # ---------------------------------------------------------------------------
  # Remote state — Azure Blob Storage
  # Auth is handled via OIDC (ARM_USE_OIDC=true) in CI.
  # For local runs: `az login` is sufficient; no storage account key needed.
  # Update storage_account_name if you used a different name in Step 3.
  # ---------------------------------------------------------------------------
  backend "azurerm" {
    resource_group_name  = "rg-eus2-hub-evergreen-02"
    storage_account_name = "sttfstatevsaz01"
    container_name       = "tfstate"
    key                  = "hub-spoke.tfstate"
    use_oidc             = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.90.0"
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
