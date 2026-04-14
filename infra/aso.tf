# ---------------------------------------------------------
# ASO – Azure Infrastructure Prerequisites
# These resources are provisioned in Phase 1 (Terraform) so ASO has a
# managed identity and federated credential waiting for it when it is
# installed in Phase 2 (post-VPN, via Helm).
# ---------------------------------------------------------

# User-assigned managed identity used by ASO to authenticate to Azure ARM
resource "azurerm_user_assigned_identity" "aso" {
  name                = var.aso_identity_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
}

# Federated credential – binds the Azure identity to the ASO Kubernetes
# service account so that workload identity token exchange works without
# storing any client secrets.
resource "azurerm_federated_identity_credential" "aso" {
  name                      = "aso-federated-credential"
  user_assigned_identity_id = azurerm_user_assigned_identity.aso.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer    = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  subject   = "system:serviceaccount:${var.aso_namespace}:azureserviceoperator-default"
}

# Contributor on the subscription – narrow to specific resource groups for
# least-privilege deployments
resource "azurerm_role_assignment" "aso_contributor" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aso.principal_id
}
