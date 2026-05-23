output "bucket_name" {
  description = "Name of the primary Velero backup bucket."
  value       = module.velero_backend.bucket_name
}

output "dr_bucket_name" {
  description = "Name of the DR replica bucket."
  value       = module.velero_backend.dr_bucket_name
}

output "iam_role_arn" {
  description = "ARN of the Velero IRSA role."
  value       = module.velero_backend.iam_role_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the bucket."
  value       = module.velero_backend.kms_key_arn
}

output "helm_values_snippet" {
  description = "Drop into the Velero Helm chart's values.yaml."
  value       = <<-EOT
    configuration:
      backupStorageLocation:
        - name: default
          provider: aws
          bucket: ${module.velero_backend.bucket_name}
          config:
            region: ${module.velero_backend.region}
            kmsKeyId: ${module.velero_backend.kms_key_arn}
      volumeSnapshotLocation:
        - name: default
          provider: aws
          config:
            region: ${module.velero_backend.region}
    serviceAccount:
      server:
        create: true
        name: velero
        annotations:
          eks.amazonaws.com/role-arn: ${module.velero_backend.iam_role_arn}
  EOT
}
