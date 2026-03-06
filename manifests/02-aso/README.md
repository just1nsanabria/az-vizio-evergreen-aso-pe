# Azure Service Operator (ASO) v2

ASO manages Azure resources directly from Kubernetes using CRDs.  It requires the
workload identity already provisioned by Terraform Phase 1 (`infra/aso.tf`).

## Prerequisites

- cert-manager is installed and all pods are **Running** (see `01-cert-manager`).
- **Connected to the P2S VPN**.
- Terraform Phase 1 outputs are available:
  ```bash
  cd ../infra
  terraform output aso_identity_client_id
  terraform output subscription_id    # or read from terraform.tfvars
  terraform output tenant_id          # or read from terraform.tfvars
  ```
- Fill in the three placeholder values in `values.yaml`.

## Install

```bash
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update

helm install azureserviceoperator aso2/azure-service-operator \
  --namespace azureserviceoperator-system \
  --create-namespace \
  --version 2.9.0 \
  --values values.yaml
```

## Verify

```bash
kubectl -n azureserviceoperator-system get pods
# The azureserviceoperator-controller-manager-* pod should be Running.

kubectl get crds | grep azure.com | head -20
# Should list hundreds of ASO CRDs.
```

## How Workload Identity auth works

1. Terraform creates a **User-Assigned Managed Identity** (`mi-aso-hub`).
2. A **Federated Credential** binds the managed identity to the ASO Kubernetes service account
   (`azureserviceoperator-default` in namespace `azureserviceoperator-system`).
3. The managed identity has **Contributor** on the subscription so it can create/manage
   all Azure resources declared via ASO CRDs.
4. The `azure.workload.identity/use: "true"` annotation on the ASO pod triggers the
   OIDC token exchange at runtime – no secret ever leaves Azure.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `CrashLoopBackOff` – `no --crd-pattern specified` | Missing `crdPattern` value | Ensure `crdPattern: "*"` is uncommented in values.yaml |
| `CrashLoopBackOff` – `cannot unmarshal bool into Go struct field…` | Pod annotation passed as bool | Ensure `"true"` is quoted in `podAnnotations` |
| Pods pending after install | cert-manager webhook not ready | Wait for cert-manager pod readiness, then re-run helm install |
