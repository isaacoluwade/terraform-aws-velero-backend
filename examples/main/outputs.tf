output "bucket_name" {
  description = "Echo of the module's bucket_name output."
  value       = module.velero_backend.bucket_name
}

output "iam_role_arn" {
  description = "Echo of the module's iam_role_arn output."
  value       = module.velero_backend.iam_role_arn
}

output "helm_values_snippet" {
  description = "Drop into your Velero Helm chart's values.yaml to point Velero at this backend and IRSA role."
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
