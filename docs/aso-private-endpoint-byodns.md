# Private Endpoint for BYO-DNS AKS with ASO and Split-Horizon DNS

## Why two private DNS zones are required

When deploying an AKS cluster with a BYO private DNS zone, AKS takes ownership of that zone. It
automatically links the zone to the cluster's VNet and writes an A record pointing the cluster FQDN
to the API server's private NIC IP. AKS continues to manage this record for the lifetime of the
cluster — it cannot be overwritten.

The natural instinct when deploying a private endpoint for this cluster from a hub VNet is to
point the PE's DNS zone group at the same BYO zone. This does not work for two reasons:

1. **`customDnsConfigs` is always empty for BYO-DNS clusters.** Standard AKS populates this field
   on the private endpoint resource with the FQDN and NIC IP, which is what zone group
   auto-registration reads to write the A record. BYO-DNS clusters handle DNS themselves and never
   populate this field, so the zone group provisions successfully but writes nothing.

2. **Even if you write the A record manually into the BYO zone, you break spoke resolution.**
   The BYO zone is linked to the spoke VNet. If you write the PE NIC IP (a hub address) into that
   zone, pods in the spoke VNet will try to reach their own API server via the hub PE — routing
   that does not exist for spoke-to-spoke traffic and introduces an unnecessary hop.

The correct solution is a second private DNS zone with the same name but in a different resource
group, linked only to the hub VNet. Each VNet sees only its own zone link and resolves to a
different IP for the same FQDN.

---

## Architecture

```
  rg-eus2-hub-evergreen-01
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Hub VNet  vnet-eus2-hub-evergreen-01  (10.0.0.0/22)                        │
  │                                                                              │
  │  ┌─────────────────────────┐   ┌──────────────────────────────────────────┐ │
  │  │  snet-aks (10.0.0.0/23) │   │  snet-pe (10.0.3.128/26)                 │ │
  │  │                         │   │                                          │ │
  │  │  Hub AKS cluster        │   │  ┌────────────────────────────────────┐  │ │
  │  │  (ARC runner)           │   │  │  pe-aks-spoke-02  (ASO)            │  │ │
  │  └─────────────────────────┘   │  │  NIC IP: 10.0.3.x                  │  │ │
  │                                │  └───────────────┬────────────────────┘  │ │
  │                                └──────────────────┼───────────────────────┘ │
  │                                                   │ Azure Private Link       │
  │  ┌─ Hub DNS zone (Terraform) ──────────────────┐  │                          │
  │  │  privatelink.eastus2.azmk8s.io              │  │                          │
  │  │  rg-eus2-hub-evergreen-01                   │  │                          │
  │  │                                             │  │                          │
  │  │  aks-eus2-spoke-02 → 10.0.3.x  ◄── A record written by ASO              │
  │  │                                             │                             │
  │  │  VNet link → hub VNet only                  │                             │
  │  └─────────────────────────────────────────────┘                             │
  └──────────────────────────────────────────────────────────────────────────────┘
                                     │
                                     │ Private Link traverses to spoke
                                     ▼
  rg-eus2-spoke-evergreen-02
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │  Spoke-02 VNet  vnet-eus2-spoke-evergreen-02  (10.8.0.0/22)                 │
  │                                                                              │
  │  ┌──────────────────────────────────────────────────────────────────────┐   │
  │  │  snet-aks (10.8.2.0/23)                                              │   │
  │  │                                                                      │   │
  │  │  aks-eus2-spoke-02  (AKS managed cluster)                            │   │
  │  │  API server NIC IP: 10.8.x.x                                         │   │
  │  └──────────────────────────────────────────────────────────────────────┘   │
  │                                                                              │
  │  ┌─ BYO DNS zone (Terraform, managed by AKS) ──────────────────────────┐   │
  │  │  privatelink.eastus2.azmk8s.io                                       │   │
  │  │  rg-eus2-spoke-evergreen-02                                          │   │
  │  │                                                                      │   │
  │  │  aks-eus2-spoke-02 → 10.8.x.x  ◄── A record written by AKS          │   │
  │  │                                                                      │   │
  │  │  VNet link → spoke VNet only  (AKS auto-links on cluster creation)   │   │
  │  └──────────────────────────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────────────────────────┘

  DNS resolution per VNet:
    Hub VNet / VPN client  → hub DNS zone  → 10.0.3.x  (PE NIC — routes via Private Link)
    Spoke VNet pod         → BYO DNS zone  → 10.8.x.x  (AKS API server NIC — direct)
```

---

## Why the BYO zone must live in the spoke resource group

AKS requires the BYO zone to exist before the cluster is created and then takes ownership of it.
If the BYO zone is placed in the hub RG, AKS still links it to the spoke VNet — but the hub
DNS zone (also in the hub RG) must have the same zone name (`privatelink.eastus2.azmk8s.io`).
Azure does not allow two zones with the same name in the same resource group. Placing the BYO zone
in the spoke RG keeps the two zones in different resource groups, which Azure permits, and cleanly
separates ownership: AKS owns the spoke zone, Terraform owns the hub zone.

---

## Why `fqdnSubdomain` instead of `dnsPrefix`

The ASO `PrivateDnsZonesARecord` manifest and all Terraform references need the exact hostname
of the cluster A record ahead of time. `dnsPrefix` appends a random alphanumeric suffix at cluster
creation (e.g. `aks-eus2-spoke-02-k3ct0q08`), making the FQDN unpredictable. Setting
`fqdnSubdomain: aks-eus2-spoke-02` in the ASO `ManagedCluster` spec produces a deterministic FQDN
with no suffix:

```
aks-eus2-spoke-02.privatelink.eastus2.azmk8s.io
```

This allows the A record `azureName` and all ARM ID references to be hardcoded in manifests and
Terraform before the cluster is deployed.

---

## Why the PE zone group does not create the A record

After deploying the private endpoint and attaching an `PrivateEndpointsPrivateDnsZoneGroup`, the
hub zone remains empty. This is confirmed by:

```bash
az network private-endpoint show \
  -g rg-eus2-hub-evergreen-01 \
  -n pe-aks-spoke-02 \
  --query "customDnsConfigs"
# Output: []
```

Azure's zone group writes an A record by reading `customDnsConfigs` from the private endpoint
resource. For BYO-DNS AKS clusters, AKS handles DNS itself and never populates this field. The
zone group is a no-op and can be omitted entirely.

---

## Solution: ASO writes the A record directly

Since auto-registration is unavailable, the workflow:

1. Applies `private-endpoint.yaml` (ASO `PrivateEndpoint`) and waits for `Ready`
2. Reads the PE NIC IP from the provisioned Azure resource
3. Substitutes `<pe-nic-ip>` in `dns-a-record.yaml` using `sed`
4. Applies the rendered manifest (ASO `PrivateDnsZonesARecord`)

```bash
# Step 2 — read PE NIC IP after PE is Ready
PE_NIC_ID=$(az network private-endpoint show \
  -g rg-eus2-hub-evergreen-01 \
  -n pe-aks-spoke-02 \
  --query "networkInterfaces[0].id" -o tsv)
PE_NIC_IP=$(az network nic show --ids "${PE_NIC_ID}" \
  --query "ipConfigurations[0].privateIPAddress" -o tsv)

# Step 3 — render manifest
sed "s|<pe-nic-ip>|${PE_NIC_IP}|g" \
  manifests/04.1-private-endpoint-byodns/dns-a-record.yaml \
  > /tmp/dns-a-record-spoke2-rendered.yaml

# Step 4 — apply
kubectl apply -f /tmp/dns-a-record-spoke2-rendered.yaml
```

The A record object:

```yaml
apiVersion: network.azure.com/v1api20200601
kind: PrivateDnsZonesARecord
metadata:
  name: spoke-02-api-server-a-record
  namespace: default
spec:
  azureName: aks-eus2-spoke-02         # exact hostname — no GUID, no random suffix
  owner:
    armId: /subscriptions/.../resourceGroups/rg-eus2-hub-evergreen-01/providers/
             Microsoft.Network/privateDnsZones/privatelink.eastus2.azmk8s.io
  ttl: 10
  aRecords:
    - ipv4Address: <pe-nic-ip>         # substituted at deploy time
```

---

## Resources by owner

| Owner | Resource | Purpose |
|---|---|---|
| Terraform | `azurerm_private_dns_zone.spoke2_aks` (spoke RG) | BYO zone — AKS writes cluster NIC A record |
| Terraform | `azurerm_private_dns_zone.spoke2_aks_hub` (hub RG) | Hub zone — ASO writes PE NIC A record |
| Terraform | `azurerm_private_dns_zone_virtual_network_link.spoke2_aks_hub` | Links hub zone → hub VNet |
| Terraform | `azurerm_role_assignment` × 2 | UAMI: DNS Zone Contributor + Network Contributor |
| ASO | `PrivateEndpoint/pe-aks-spoke-02` | PE in hub `snet-pe` |
| ASO | `PrivateDnsZonesARecord/spoke-02-api-server-a-record` | A record in hub zone → PE NIC IP |

---

## Scaling to additional clusters

The hub DNS zone (`privatelink.eastus2.azmk8s.io` in `rg-eus2-hub-evergreen-01`) is shared across
all spoke clusters. Each new cluster adds:

- One Terraform BYO zone in its own spoke RG (separate A record managed by AKS)
- One `PrivateDnsZonesARecord` in the shared hub zone (different `azureName` per cluster)
- One `PrivateEndpoint` in hub `snet-pe`

| Cluster | BYO zone RG | PE name | Hub A record `azureName` |
|---|---|---|---|
| `aks-eus2-spoke-02` | `rg-eus2-spoke-evergreen-02` | `pe-aks-spoke-02` | `aks-eus2-spoke-02` |
| `aks-eus2-spoke-03` | `rg-eus2-spoke-evergreen-03` | `pe-aks-spoke-03` | `aks-eus2-spoke-03` |

No changes to the hub zone or its VNet link are needed when adding clusters.

---

## File reference

```
infra/
  networking.tf                         # BYO zone, hub zone, hub VNet link
  aks.tf                                # UAMI data source, RBAC assignments

manifests/
  03.1-spoke-cluster-byodns/
    custom-managed-cluster.yaml         # ASO ManagedCluster — fqdnSubdomain + privateDNSZone

  04.1-private-endpoint-byodns/
    private-endpoint.yaml               # ASO PrivateEndpoint in hub snet-pe
    dns-a-record.yaml                   # ASO PrivateDnsZonesARecord (<pe-nic-ip> placeholder)

.github/workflows/
  manifests.yml                         # Step 04.1-private-endpoint-byodns
```
