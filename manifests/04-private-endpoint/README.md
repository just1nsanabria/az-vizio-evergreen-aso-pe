# Private Endpoint + DNS Zone Group (via ASO)

These two ASO manifests complete the hub-spoke connectivity story by creating a
Private Endpoint inside the hub `snet-pe` subnet, pointing at the spoke AKS
management plane.  After DNS propagates, both the hub AKS pods and any P2S VPN
client can `kubectl` into the spoke cluster using its private FQDN.

## Architecture

```
┌─ Spoke VNet ──────────────────────────────────────────────────────────────┐
│  MC_ RG private DNS zone  (<guid>.privatelink.eastus2.azmk8s.io)          │
│    A record: aks-eus2-spoke-<id>  →  10.4.x.x  (spoke snet-aks NIC)      │
│    VNet link: spoke VNet  (auto-created by AKS — untouched)               │
│                                                                            │
│  Spoke pods → MC_ zone → 10.4.x.x  ✅ direct to API server               │
└────────────────────────────────────────────────────────────────────────────┘

┌─ Hub VNet ─────────────────────────────────────────────────────────────────┐
│  Hub RG private DNS zone  (<guid>.privatelink.eastus2.azmk8s.io)  ← NEW   │
│    A record: aks-eus2-spoke-<id>  →  10.0.3.x  (PE NIC in snet-pe)       │
│    VNet link: hub VNet  → DNS Private Resolver sees this zone             │
│                                                                            │
│  VPN client / hub pod                                                      │
│    → DNS Private Resolver (10.0.3.196)                                    │
│    → hub zone  →  10.0.3.x                                                │
│    → Private Endpoint (snet-pe)  →  Spoke AKS management plane  ✅        │
└────────────────────────────────────────────────────────────────────────────┘
```

Two zones, same name, different RGs, different VNet links. Each VNet resolves
the spoke FQDN to the IP that makes sense for its network path:
- **Spoke VNet**: native API server NIC (`10.4.x.x`) — no PE hairpin
- **Hub VNet / VPN**: PE NIC in `snet-pe` (`10.0.3.x`) — no AVNM peering needed

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

From any pod inside hub AKS or from your VPN-connected workstation:

```bash
# Replace with actual spoke API server FQDN from:
#   az aks show -g <spoke-rg> -n <spoke-aks> --query privateFqdn -o tsv
nslookup <spoke-private-fqdn>
# Should resolve to a 10.x.x.x address (the PE NIC IP), not a public IP.
```

## VPN client DNS note

Private DNS resolution is handled automatically by the **Azure DNS Private Resolver**
(`dnspr-eus2-hub-evergreen-01`) deployed in the hub VNet. The VPN gateway pushes the
resolver's inbound endpoint IP to P2S clients as `dns_servers` — no manual `.ovpn`
edit is required.
