# ---------------------------------------------------------
# Resource Groups
# ---------------------------------------------------------
output "hub_resource_group_name" {
  description = "Name of the hub resource group."
  value       = azurerm_resource_group.hub.name
}

output "spoke_resource_group_name" {
  description = "Name of the spoke resource group."
  value       = azurerm_resource_group.spoke.name
}

# ---------------------------------------------------------
# Networking
# ---------------------------------------------------------
output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "hub_aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "hub_pe_subnet_id" {
  description = "Resource ID of the hub private endpoint subnet (snet-pe)."
  value       = azurerm_subnet.hub_pe.id
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "spoke_aks_subnet_id" {
  description = "Resource ID of the spoke AKS subnet – pass this to the ASO ManagedCluster manifest."
  value       = azurerm_subnet.spoke_aks.id
}

# ---------------------------------------------------------
# AVNM
# ---------------------------------------------------------
output "avnm_id" {
  value = azurerm_network_manager.avnm.id
}

# ---------------------------------------------------------
# Hub AKS
# ---------------------------------------------------------
output "aks_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_fqdn" {
  description = "Private FQDN of the hub AKS API server."
  value       = azurerm_kubernetes_cluster.aks.private_fqdn
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL – used to configure ASO federated credential."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "aks_node_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}

# ---------------------------------------------------------
# Azure Firewall
# ---------------------------------------------------------
output "firewall_private_ip_v4" {
  description = "Private IPv4 address of the Azure Firewall (UDR next hop)."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  value = azurerm_public_ip.firewall.ip_address
}

# ---------------------------------------------------------
# ASO Identity – values needed for the Helm install in Phase 2
# ---------------------------------------------------------
output "aso_identity_client_id" {
  description = "Client ID to pass to the ASO Helm chart as azureClientID."
  value       = azurerm_user_assigned_identity.aso.client_id
}

output "aso_identity_principal_id" {
  value = azurerm_user_assigned_identity.aso.principal_id
}

# ---------------------------------------------------------
# VPN Gateway
# ---------------------------------------------------------
output "vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.hub.id
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN gateway – use this as the tunnel endpoint in your P2S VPN client."
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

# ---------------------------------------------------------
# DNS Private Resolver
# ---------------------------------------------------------
output "dns_resolver_inbound_ip" {
  description = "Private IP of the DNS resolver inbound endpoint. Automatically pushed to P2S VPN clients as dns_servers; also useful for configuring on-premises DNS forwarders."
  value       = azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address
}
