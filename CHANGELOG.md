# Changelog

All notable changes to this module are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/), versioning follows
[SemVer](https://semver.org/).

## [2.0.0] - 2026-05-24

### Breaking changes

- **Region short-code derivation rewritten** (S-1 fix). The `region_code`
  local previously derived its value from a substring formula that produced
  non-canonical codes (`us-east-1` → `useast1`, `eu-west-2` → `euwest2`,
  `ap-southeast-1` → `apsoutheast1`). v2.0.0 replaces it with an explicit
  `region_code_map` lookup, giving the canonical short codes
  (`use1`, `euw2`, `apse1`, ...). **Every resource name and every `Name`
  tag in this module shifts as a result.** Consumers upgrading from
  v1.x will see destroy+recreate on first apply.

  See [`UPGRADE_GUIDE.md`](../UPGRADE_GUIDE.md) at the workspace root for
  the recommended per-environment cutover sequence.
- **`dr_kms_key_arn` input added** (S-3 fix). Required when both
  `kms_key_arn` and `dr_region` are set. The replica bucket's SSE
  config and `replica_kms_key_id` now reference the DR-region key
  instead of falling back to the primary-region key (which AWS rejected
  with `KMS.NotFoundException` on every PutObject — silently broken
  replication).

  Migration: callers passing a consumer-supplied `kms_key_arn` with
  `dr_region` set must add `dr_kms_key_arn`. A cross-variable
  validation enforces the pairing at plan time.

- **EBS IAM statement split** (V-C3 fix). The single previous statement
  scoped `ec2:DescribeVolumes`, `ec2:DescribeSnapshots`, and
  `ec2:CreateVolume` to specific volume ARNs, which AWS rejects (those
  actions require `Resource: "*"`). Velero's `DescribeVolumes` returned
  AccessDenied and silently enumerated zero volumes. v2.0.0 splits it
  into two statements:
  - `VeleroEBSDescribe` (Describe + CreateVolume + CreateTags) at
    `Resource: "*"`.
  - `VeleroEBSSnapshot` (CreateSnapshot + DeleteSnapshot) optionally
    scoped via `var.allowed_ebs_volume_arns` + an `ec2:SourceVolume`
    ArnEquals condition.

  Migration: no input change. Backups will now actually capture
  volumes (consumers upgrading should re-run the next scheduled
  backup and verify Velero's logs report a non-zero snapshot count).

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
