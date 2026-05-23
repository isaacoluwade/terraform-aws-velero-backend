output "bucket_name" {
  description = "Name of the Velero backup S3 bucket. Drop into the Velero Helm chart's configuration.backupStorageLocation.bucket."
  value       = aws_s3_bucket.velero.bucket
}

output "bucket_arn" {
  description = "ARN of the Velero backup bucket. For consumers writing IAM policies that scope to this bucket."
  value       = aws_s3_bucket.velero.arn
}

output "iam_role_arn" {
  description = "ARN of the Velero IAM role with IRSA trust on the configured namespace and service account. Consumed by the Velero Helm chart via serviceAccount.server.annotations[\"eks.amazonaws.com/role-arn\"]."
  value       = aws_iam_role.velero.arn
}

output "dr_bucket_name" {
  description = "Name of the DR replica bucket, when dr_region is set. Null otherwise."
  value       = local.replication_enabled ? aws_s3_bucket.velero_replica[0].bucket : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the Velero bucket. Either the consumer-supplied kms_key_arn or the module-managed key when kms_key_arn was null."
  value       = local.effective_kms_arn
}

output "region" {
  description = "Echo of the input region. Convenient when wiring multiple modules in a composition."
  value       = var.region
}
