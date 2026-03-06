# cert-manager

cert-manager is required by ASO (Azure Service Operator) for webhook certificate management.

## Prerequisites

- **Connected to the P2S VPN** so `kubectl` can reach the private AKS API server.
- `helm` ≥ 3.x installed locally.

## Install

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.14.4 \
  --values values.yaml
```

## Verify

```bash
kubectl -n cert-manager get pods
# All three pods (controller, cainjector, webhook) should be Running.
```

## Notes

- `installCRDs: true` in `values.yaml` installs the cert-manager CRDs automatically.
- cert-manager must be **Ready** before proceeding to `02-aso`.
