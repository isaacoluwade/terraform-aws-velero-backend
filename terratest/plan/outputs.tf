output "bucket_name" {
  value = module.velero_backend.bucket_name
}

output "bucket_arn" {
  value = module.velero_backend.bucket_arn
}

output "iam_role_arn" {
  value = module.velero_backend.iam_role_arn
}

output "kms_key_arn" {
  value = module.velero_backend.kms_key_arn
}

output "dr_bucket_name" {
  value = module.velero_backend.dr_bucket_name
}

output "region" {
  value = module.velero_backend.region
}
