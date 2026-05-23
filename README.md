# terraform-aws-velero-backend

Provision the AWS side of a Velero installation: an S3 bucket for backups
(versioned, KMS-encrypted, lifecycle-bounded), an IAM role with IRSA trust on
the Velero service account, and an inline policy with the S3 + EBS snapshot +
KMS permissions Velero needs.

This is module 10 of 10 in the [AWS MTKP Terraform Module Library](../projects/1-aws-mtkp-terraform-module-library/).

## Usage

```hcl
module "velero_backend" {
  source = "git::https://github.com/<org>/terraform-aws-velero-backend.git?ref=v1.0.0"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project     = "mtkp"
  environment = "prod"
  region      = "us-east-1"
  dr_region   = "us-west-2"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  tags = {
    Owner = "platform-team"
  }
}
```

The module always requires two provider configurations: the default `aws`
provider for the primary region and an `aws.dr` alias for the DR region. When
DR is not enabled (`dr_region = null`), point `aws.dr` at the same region as
the primary — its resources will not be materialized.

The Velero Helm chart then consumes `iam_role_arn`:

```yaml
serviceAccount:
  server:
    create: true
    name: velero
    annotations:
      eks.amazonaws.com/role-arn: <module.velero_backend.iam_role_arn>
configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: <module.velero_backend.bucket_name>
      config:
        region: us-east-1
        kmsKeyId: <module.velero_backend.kms_key_arn>
```

## Operational defaults

- Encryption: SSE-KMS. Either the consumer-supplied `kms_key_arn` or a
  module-owned customer-managed key (annual rotation, 30-day deletion window,
  multi-region when DR is on).
- Versioning: enabled.
- Public access: fully blocked (all four flags true).
- ACLs: disabled (`BucketOwnerEnforced`).
- Lifecycle: current backup objects expire after `backup_retention_days`
  (default 90); non-current versions expire after 30 days.
- IRSA trust: scoped to `system:serviceaccount:${velero_namespace}:${velero_service_account}`
  (default `velero/velero`) and `sts.amazonaws.com` audience.
- Replication (DR mode): delete markers replicated, KMS-encrypted objects
  replicated, encryption with the replica key in DR.

None of the above is configurable. They are operational invariants — if a
consumer needs a different posture, they are using the wrong module.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project` | `string` | — | Required. 3-12 chars, lowercase letters/digits/hyphens. Drives `primary_name` and the Project tag. |
| `environment` | `string` | — | Required. Lowercase letters/digits/hyphens. Drives `primary_name` and the Environment tag. |
| `region` | `string` | — | Required. Primary AWS region (e.g. `us-east-1`). |
| `oidc_provider_arn` | `string` | — | Required. EKS cluster OIDC provider ARN. From terraform-aws-eks. |
| `oidc_provider_url` | `string` | — | Required. EKS cluster OIDC provider URL (no `https://` prefix). From terraform-aws-eks. |
| `dr_region` | `string` | `null` | When set, enables cross-region replication. |
| `kms_key_arn` | `string` | `null` | Consumer-supplied KMS key ARN. When null, the module creates one. |
| `velero_namespace` | `string` | `"velero"` | Kubernetes namespace of the Velero service account. |
| `velero_service_account` | `string` | `"velero"` | Velero service account name. |
| `backup_retention_days` | `number` | `90` | Days to retain backup objects. Range 7-3650. |
| `allowed_ebs_volume_arns` | `list(string)` | `[]` | EBS volume ARNs Velero may snapshot. Empty = all volumes. |
| `tags` | `map(string)` | `{}` | Consumer-specific tags merged with the module's spine. |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | Name of the Velero backup bucket. |
| `bucket_arn` | ARN of the Velero backup bucket. |
| `iam_role_arn` | ARN of the Velero IRSA role. Goes on the Velero serviceAccount annotation. |
| `dr_bucket_name` | Name of the DR replica bucket (`null` when DR is off). |
| `kms_key_arn` | ARN of the KMS key used to encrypt the bucket. |
| `region` | Echo of the input region. |

## Examples

- [`examples/main`](./examples/main) — single-region minimal usage.
- [`examples/complete`](./examples/complete) — DR enabled, scoped EBS, BYO KMS.

## Testing

Three layers per the [testing pyramid](../projects/1-aws-mtkp-terraform-module-library/01-foundations/04-the-testing-pyramid.md):

```bash
# Layer 1 — static analysis (sub-second)
terraform fmt -check -recursive
tflint --config .tflint.hcl
checkov --config-file .checkov.yaml -d .

# Layer 2 — unit tests with mock_provider (<5s)
terraform test

# Layer 3 — integration tests against real AWS (post-merge only)
cd terratest/test && go test -v -timeout 30m ./...
```

The Terratest layer requires `TERRATEST_OIDC_PROVIDER_ARN` and
`TERRATEST_OIDC_PROVIDER_URL` to be set, pointing at a pre-existing EKS
cluster's IRSA OIDC provider.

## Versioning

See [CHANGELOG.md](./CHANGELOG.md). Tag `v<MAJOR>.<MINOR>.<PATCH>` is the
immutable artifact; the `VERSION` file mirrors the tag and CI enforces
agreement at release.
