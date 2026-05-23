# Changelog

All notable changes to this module are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/), versioning follows
[SemVer](https://semver.org/).

## [1.0.0] - 2026-05-22

### Added

- Initial release of `terraform-aws-velero-backend`.
- S3 bucket for Velero backups with versioning, public access blocked,
  SSE-KMS, BucketOwnerEnforced ownership, and a lifecycle rule that expires
  current backup objects after `backup_retention_days` (default 90) and
  non-current versions after 30 days.
- IAM role with IRSA trust on the configured EKS OIDC provider, namespace,
  and service account (`velero/velero` by default), plus an inline policy
  with four statements: S3 bucket read/write, S3 list, EBS snapshot ops,
  and KMS access to the bucket's encryption key.
- Optional cross-region replication: when `dr_region` is set, the module
  provisions a replica bucket, a multi-region KMS key with its replica
  (only when the module owns the key), an S3 replication role, and a
  replication configuration with delete-marker replication enabled.
- Optional consumer-supplied `kms_key_arn`: when null, the module creates
  a customer-managed KMS key with annual rotation and a 30-day deletion
  window.
- Optional scoping of EBS snapshot permissions to specific volume ARNs via
  `allowed_ebs_volume_arns`.
- Native `terraform test` suite covering defaults, naming, and validation
  (~30 assertions, all running against `mock_provider "aws" {}`).
- Terratest suite covering happy-path apply and DR replication round-trip.
- `examples/main/` minimal consumer and `examples/complete/` full-featured
  consumer.

### Module contract

- Required inputs: `project`, `environment`, `region`, `oidc_provider_arn`,
  `oidc_provider_url`.
- Optional inputs: `dr_region`, `kms_key_arn`, `velero_namespace`,
  `velero_service_account`, `backup_retention_days`,
  `allowed_ebs_volume_arns`, `tags`.
- Outputs: `bucket_name`, `bucket_arn`, `iam_role_arn`, `dr_bucket_name`
  (nullable), `kms_key_arn`, `region`.

[1.0.0]: https://github.com/example/terraform-aws-velero-backend/releases/tag/v1.0.0
