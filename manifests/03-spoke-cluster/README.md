# Spoke AKS Cluster (via ASO)

This manifest deploys a private, dual-stack AKS cluster in the spoke VNet using the
[Azure Service Operator ManagedCluster CRD](https://azure.github.io/azure-service-operator/reference/containerservice/).

The cluster mirrors the hub AKS network topology:
- **Azure CNI Overlay** with dual-stack (IPv4 + IPv6)
- **Private cluster** – API server exposed only via private endpoint
- **`userDefinedRouting`** – all egress forced through Azure Firewall

## Before applying

1. Confirm ASO is running (`02-aso`).
2. Get the required IDs from Terraform outputs:

   ```bash
   cd ../../infra

   # Spoke resource group ARM ID
   terraform output spoke_rg_id

   # Spoke snet-aks subnet ARM ID
   terraform output spoke_aks_subnet_id
   ```

3. Replace `<subscription-id>`, `<spoke-rg-name>`, and `<spoke-vnet-name>` in
   `managed-cluster.yaml` with the values above.

## Apply

```bash
kubectl apply -f managed-cluster.yaml
```

## Monitor reconciliation

```bash
# Watch ASO reconcile the cluster (typically 5-10 minutes)
kubectl get managedcluster aks-eus2-spoke-01 -o yaml -w

# Look for:
#   status.conditions[].type: Ready
#   status.conditions[].status: "True"
```

## After the cluster is ready

Proceed to `04-private-endpoint` to create a Private Endpoint in the hub VNet
so the hub AKS (and any VPN-connected client) can reach the spoke API server.
