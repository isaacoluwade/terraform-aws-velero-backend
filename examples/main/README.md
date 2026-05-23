# `examples/main` — minimal Velero backend

Provisions a single-region Velero backup bucket plus an IRSA-trusted IAM role.
Module owns the KMS key; no DR replication.

## Apply

```bash
terraform init
terraform apply \
  -var oidc_provider_arn=arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED \
  -var oidc_provider_url=oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED
```

Outputs `helm_values_snippet` — paste into your Velero Helm chart's `values.yaml`.

## Tear down

```bash
terraform destroy
```
