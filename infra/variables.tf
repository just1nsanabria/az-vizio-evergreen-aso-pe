# ---------------------------------------------------------
# Global
# ---------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID to scope the deployment and AVNM."
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "tenant_id" {
  description = "Azure AD tenant ID – required for VPN Gateway AAD auth and ASO workload identity."
  type        = string
}

# ---------------------------------------------------------
# Resource Groups
# ---------------------------------------------------------
variable "hub_rg_name" {
  description = "Name of the hub resource group."
  type        = string
}

variable "spoke_rg_name" {
  description = "Name of the spoke resource group."
  type        = string
}

# ---------------------------------------------------------
# Networking – Hub
# ---------------------------------------------------------
variable "hub_vnet_name" {
  description = "Name of the hub virtual network."
  type        = string
}

variable "hub_vnet_address_space" {
  description = "Address space for the hub VNet (IPv4 /22 + IPv6 /48)."
  type        = list(string)
}

variable "hub_aks_subnet_name" {
  description = "Name of the AKS subnet inside the hub VNet."
  type        = string
  default     = "snet-aks"
}

variable "hub_aks_subnet_prefix" {
  description = "IPv4 address prefix for the hub AKS subnet."
  type        = string
}

variable "hub_aks_subnet_prefix_v6" {
  description = "IPv6 address prefix for the hub AKS subnet."
  type        = string
}

variable "hub_mgmt_subnet_name" {
  description = "Name of the management subnet inside the hub VNet."
  type        = string
  default     = "snet-mgmt"
}

variable "hub_mgmt_subnet_prefix" {
  description = "IPv4 address prefix for the management subnet."
  type        = string
}

variable "hub_mgmt_subnet_prefix_v6" {
  description = "IPv6 address prefix for the management subnet."
  type        = string
}

variable "hub_fw_subnet_prefix" {
  description = "IPv4 address prefix for AzureFirewallSubnet (minimum /26)."
  type        = string
}

variable "hub_fw_subnet_prefix_v6" {
  description = "IPv6 address prefix for AzureFirewallSubnet."
  type        = string
}

variable "hub_gw_subnet_prefix" {
  description = "IPv4 address prefix for GatewaySubnet (/27 minimum, /26 recommended). GatewaySubnet does not support IPv6 for P2S."
  type        = string
}

variable "hub_pe_subnet_name" {
  description = "Name of the private endpoint subnet inside the hub VNet."
  type        = string
  default     = "snet-pe"
}

variable "hub_pe_subnet_prefix" {
  description = "IPv4 address prefix for the hub private endpoint subnet."
  type        = string
}

# ---------------------------------------------------------
# Azure Firewall
# ---------------------------------------------------------
variable "firewall_name" {
  description = "Name of the Azure Firewall."
  type        = string
}

variable "firewall_sku_tier" {
  description = "SKU tier for the Azure Firewall (Standard or Premium)."
  type        = string
  default     = "Standard"
}

variable "firewall_pip_name" {
  description = "Name of the IPv4 public IP for the Azure Firewall."
  type        = string
}

variable "firewall_pip_v6_name" {
  description = "Name of the IPv6 public IP for the Azure Firewall."
  type        = string
}

variable "firewall_private_ip_v6" {
  description = "IPv6 private IP of the Azure Firewall used as the ::/0 UDR next hop. Azure reserves the first 3 addresses in a subnet so the firewall always receives the 4th (e.g. fd00:1:0:3::4 for fd00:1:0:3::/64)."
  type        = string
}

# ---------------------------------------------------------
# Route Tables
# ---------------------------------------------------------
variable "hub_aks_rt_name" {
  description = "Name of the route table for the hub AKS subnet."
  type        = string
  default     = "rt-hub-snet-aks"
}

variable "hub_mgmt_rt_name" {
  description = "Name of the route table for the hub management subnet."
  type        = string
  default     = "rt-hub-snet-mgmt"
}

variable "spoke_workload_rt_name" {
  description = "Name of the route table for the spoke workload subnet."
  type        = string
  default     = "rt-spoke-snet-workload"
}

variable "spoke_aks_rt_name" {
  description = "Name of the route table for the spoke AKS subnet. Must exist before ASO deploys the spoke cluster."
  type        = string
  default     = "rt-spoke-snet-aks"
}

# ---------------------------------------------------------
# Networking – Spoke
# ---------------------------------------------------------
variable "spoke_vnet_name" {
  description = "Name of the spoke virtual network."
  type        = string
}

variable "spoke_vnet_address_space" {
  description = "Address space for the spoke VNet (IPv4 /22 + IPv6 /48)."
  type        = list(string)
}

variable "spoke_workload_subnet_name" {
  description = "Name of the workload subnet inside the spoke VNet."
  type        = string
  default     = "snet-workload"
}

variable "spoke_workload_subnet_prefix" {
  description = "IPv4 address prefix for the spoke workload subnet."
  type        = string
}

variable "spoke_workload_subnet_prefix_v6" {
  description = "IPv6 address prefix for the spoke workload subnet."
  type        = string
}

variable "spoke_aks_subnet_name" {
  description = "Name of the AKS subnet inside the spoke VNet."
  type        = string
  default     = "snet-aks"
}

variable "spoke_aks_subnet_prefix" {
  description = "IPv4 address prefix for the spoke AKS subnet."
  type        = string
}

variable "spoke_aks_subnet_prefix_v6" {
  description = "IPv6 address prefix for the spoke AKS subnet."
  type        = string
}

# ---------------------------------------------------------
# Azure Virtual Network Manager
# ---------------------------------------------------------
variable "avnm_name" {
  description = "Name of the Azure Virtual Network Manager."
  type        = string
}

variable "avnm_ng_hub_name" {
  description = "Name of the hub network group."
  type        = string
  default     = "ng-hub"
}

variable "avnm_ng_spokes_name" {
  description = "Name of the spokes network group."
  type        = string
  default     = "ng-spokes"
}

variable "avnm_connectivity_config_name" {
  description = "Name of the AVNM connectivity configuration."
  type        = string
  default     = "cc-hub-spoke"
}

# ---------------------------------------------------------
# Hub AKS Cluster
# ---------------------------------------------------------
variable "aks_name" {
  description = "Name of the hub AKS cluster."
  type        = string
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the hub AKS cluster."
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes in the default node pool."
  type        = number
  default     = 3
}

variable "aks_node_vm_size" {
  description = "VM size for the default node pool."
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version. null = latest stable."
  type        = string
  default     = null
}

variable "aks_pod_cidr_v4" {
  description = "IPv4 pod CIDR for the hub AKS cluster (overlay)."
  type        = string
  default     = "192.168.0.0/16"
}

variable "aks_pod_cidr_v6" {
  description = "IPv6 pod CIDR for the hub AKS cluster (overlay)."
  type        = string
  default     = "fd00:10::/112"
}

variable "aks_service_cidr_v4" {
  description = "IPv4 service CIDR for the hub AKS cluster."
  type        = string
  default     = "172.16.0.0/16"
}

variable "aks_service_cidr_v6" {
  description = "IPv6 service CIDR for the hub AKS cluster."
  type        = string
  default     = "fd00:11::/108"
}

variable "aks_dns_service_ip" {
  description = "IPv4 DNS service IP for the hub AKS cluster (within aks_service_cidr_v4)."
  type        = string
  default     = "172.16.0.10"
}

# ---------------------------------------------------------
# Azure Service Operator – Azure Resources
# (Helm install of cert-manager and ASO happens in Phase 2)
# ---------------------------------------------------------
variable "aso_identity_name" {
  description = "Name of the user-assigned managed identity used by ASO."
  type        = string
  default     = "mi-aso-hub"
}

variable "aso_namespace" {
  description = "Kubernetes namespace ASO will be installed into."
  type        = string
  default     = "azureserviceoperator-system"
}

# ---------------------------------------------------------
# VPN Gateway
# ---------------------------------------------------------
variable "vpn_gateway_name" {
  description = "Name of the VPN gateway."
  type        = string
}

variable "vpn_gateway_pip_name" {
  description = "Name of the public IP for the VPN gateway."
  type        = string
}

variable "vpn_gateway_sku" {
  description = "SKU for the VPN gateway. Must be VpnGw2AZ-VpnGw5AZ for Generation2; VpnGw1AZ-VpnGw5AZ for Generation1."
  type        = string
  default     = "VpnGw1AZ"
}

variable "vpn_client_address_pool" {
  description = "CIDR block allocated to P2S VPN clients. Must not overlap any VNet or on-premises address space."
  type        = string
  default     = "172.20.0.0/24"
}

# ---------------------------------------------------------
# DNS Private Resolver
# ---------------------------------------------------------
variable "dns_resolver_name" {
  description = "Name of the Azure DNS Private Resolver deployed in the hub VNet."
  type        = string
  default     = "dnspr-eus2-hub-evergreen-01"
}

variable "hub_dns_inbound_subnet_name" {
  description = "Name of the inbound endpoint subnet for the DNS Private Resolver."
  type        = string
  default     = "snet-dns-inbound"
}

variable "hub_dns_inbound_subnet_prefix" {
  description = "IPv4 address prefix for the DNS Private Resolver inbound subnet (/28 minimum, dedicated). Must fall within hub_vnet_address_space."
  type        = string
}

# ---------------------------------------------------------
# Jumpbox
# ---------------------------------------------------------

variable "jumpbox_vm_name" {
  description = "Name of the Windows jumpbox VM."
  type        = string
  default     = "vm-jumpbox-01"
}

variable "jumpbox_admin_username" {
  description = "Local administrator username for the jumpbox VM."
  type        = string
  default     = "azureadmin"
}

variable "jumpbox_admin_password" {
  description = "Local administrator password for the jumpbox VM. Store in a secret; never commit plaintext."
  type        = string
  sensitive   = true
}


