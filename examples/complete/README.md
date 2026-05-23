# `examples/complete` — full-featured Velero backend

Provisions a Velero backup bucket with cross-region replication, a tighter
30-day retention, scoped EBS snapshot permissions, a non-default namespace
and service account, and the option to bring your own KMS key.

## Apply

```bash
terraform init
terraform apply \
  -var oidc_provider_arn=arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED \
  -var oidc_provider_url=oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED
```

To exercise consumer-supplied KMS, pass `kms_key_arn`:

```bash
terraform apply -var kms_key_arn=arn:aws:kms:us-east-1:123456789012:key/abc
```

## Tear down

```bash
terraform destroy
```

> Note: cross-region replication can take 30+ seconds to fully apply.
> S3 buckets created in this example must be empty before destroy succeeds.
