# ---------------------------------------------------------
# Hub AKS Cluster
# ---------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  dns_prefix          = var.aks_dns_prefix
  kubernetes_version  = var.aks_kubernetes_version

  # Private cluster – system-managed private DNS zone
  private_cluster_enabled = true
  private_dns_zone_id     = "System"

  # System-assigned managed identity for the control plane
  identity {
    type = "SystemAssigned"
  }

  # Default (system) node pool – placed in the hub AKS subnet
  default_node_pool {
    name           = "system"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Azure CNI overlay, dual-stack (IPv4 + IPv6)
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    ip_versions         = ["IPv4", "IPv6"]
    pod_cidrs           = [var.aks_pod_cidr_v4, var.aks_pod_cidr_v6]
    service_cidrs       = [var.aks_service_cidr_v4, var.aks_service_cidr_v6]
    dns_service_ip      = var.aks_dns_service_ip
    # UDR on the AKS subnet routes default traffic through Azure Firewall
    outbound_type = "userDefinedRouting"
  }

  # OIDC + Workload Identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  depends_on = [
    azurerm_network_manager_deployment.hub_spoke,
    azurerm_subnet_route_table_association.hub_aks,
  ]
}

# ---------------------------------------------------------
# Role Assignments
# ---------------------------------------------------------

# Network Contributor on the hub VNet for AKS control-plane identity
resource "azurerm_role_assignment" "aks_hub_vnet_network_contributor" {
  scope                = azurerm_virtual_network.hub.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Contributor on the hub RG for the kubelet (node pool) identity
resource "azurerm_role_assignment" "aks_kubelet_hub_rg_contributor" {
  scope                = azurerm_resource_group.hub.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# ---------------------------------------------------------
# Spoke-02 UAMI role assignments
# The UAMI must exist before the spoke-02 AKS cluster is created (BYO DNS
# requires UserAssigned identity so the DNS zone permission can be granted
# before cluster provisioning). The UAMI is looked up by name/RG via a
# data source so Terraform does not own its lifecycle.
# ---------------------------------------------------------
data "azurerm_user_assigned_identity" "spoke2_aks" {
  name                = var.spoke2_aks_uami_name
  resource_group_name = var.spoke2_aks_uami_rg
}

# Private DNS Zone Contributor on the BYO zone so AKS can write the A record
resource "azurerm_role_assignment" "spoke2_aks_dns_zone_contributor" {
  scope                = azurerm_private_dns_zone.spoke2_aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = data.azurerm_user_assigned_identity.spoke2_aks.principal_id
}

# Network Contributor on the spoke-02 VNet so AKS can manage NIC/subnet resources
resource "azurerm_role_assignment" "spoke2_aks_vnet_network_contributor" {
  scope                = azurerm_virtual_network.spoke2.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.spoke2_aks.principal_id
}
