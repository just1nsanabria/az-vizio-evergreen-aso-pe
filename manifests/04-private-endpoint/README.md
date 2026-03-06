# Private Endpoint + DNS Zone Group (via ASO)

These two ASO manifests complete the hub-spoke connectivity story by creating a
Private Endpoint inside the hub `snet-pe` subnet, pointing at the spoke AKS
management plane.  After DNS propagates, both the hub AKS pods and any P2S VPN
client can `kubectl` into the spoke cluster using its private FQDN.

## Architecture

```
Hub VNet (snet-pe)
  └── Private Endpoint  ──►  Spoke AKS management NIC (10.x.x.x)
        └── DNS Zone Group → AKS private DNS zone (MC_ resource group)
                             *.privatelink.eastus2.azmk8s.io
```

## Step 1 – Gather values

```bash
# Subscription / hub RG / hub VNet / snet-pe
cd ../../infra
terraform output hub_rg_name
terraform output hub_pe_subnet_id

# Spoke cluster ARM ID
az aks show \
  -g <spoke-rg-name> \
  -n <spoke-aks-name> \
  --query id -o tsv

# Private DNS zone name (GUID prefix, created automatically by AKS)
az network private-dns zone list \
  -g mc_<spoke-rg-name>_<spoke-aks-name>_eastus2 \
  --query "[].name" -o tsv
# → <guid>.privatelink.eastus2.azmk8s.io
```

## Step 2 – Fill in placeholders

Edit `private-endpoint.yaml` and `dns-zonegroup.yaml`, replacing every
`<placeholder>` with the real values gathered above.

## Step 3 – Apply

```bash
# Apply in order – zone group depends on the endpoint existing first
kubectl apply -f private-endpoint.yaml
kubectl get privateendpoint pe-aks-spoke-01 -o yaml   # wait for Ready

kubectl apply -f dns-zonegroup.yaml
kubectl get privateendpointsprivatednszonegroup pe-aks-spoke-01-dnsgroup -o yaml
```

## Step 4 – Verify DNS resolution

From any pod inside hub AKS (or from your VPN-connected workstation after adding
`168.63.129.16` as DNS):

```bash
# Replace with actual spoke API server FQDN from:
#   az aks show -g <spoke-rg> -n <spoke-aks> --query privateFqdn -o tsv
nslookup <spoke-private-fqdn>
# Should resolve to a 10.x.x.x address (the PE NIC IP), not a public IP.
```

## VPN client DNS note

P2S VPN clients do not automatically use Azure's internal DNS (`168.63.129.16`).
Add the following line to your downloaded `.ovpn` profile **before** connecting:

```
dhcp-option DNS 168.63.129.16
```
