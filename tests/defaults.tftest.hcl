mock_provider "aws" {}
mock_provider "aws" {
  alias = "dr"
}

variables {
  project           = "test"
  environment       = "test"
  region            = "us-east-1"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
  oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
}

run "bucket_versioning_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_versioning.velero.versioning_configuration[0].status == "Enabled"
    error_message = "Velero bucket must have versioning Enabled by default"
  }
}

run "public_access_fully_blocked" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.velero.block_public_acls,
      aws_s3_bucket_public_access_block.velero.block_public_policy,
      aws_s3_bucket_public_access_block.velero.ignore_public_acls,
      aws_s3_bucket_public_access_block.velero.restrict_public_buckets,
    ])
    error_message = "all four public-access-block attributes must be true by default"
  }
}

run "module_creates_kms_key_by_default" {
  command = plan

  assert {
    condition     = length(aws_kms_key.velero) == 1
    error_message = "module should provision its own KMS key when kms_key_arn is null"
  }

  assert {
    condition     = aws_kms_key.velero[0].enable_key_rotation == true
    error_message = "module-owned KMS key must have rotation enabled"
  }

  assert {
    condition     = aws_kms_key.velero[0].deletion_window_in_days == 30
    error_message = "module-owned KMS key must use a 30-day deletion window"
  }
}

run "no_replica_when_dr_region_unset" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket.velero_replica) == 0
    error_message = "no replica bucket should exist when dr_region is null"
  }

  assert {
    condition     = length(aws_iam_role.replication) == 0
    error_message = "no replication role should exist when dr_region is null"
  }

  assert {
    condition     = length(aws_kms_replica_key.velero) == 0
    error_message = "no replica KMS key should exist when dr_region is null"
  }
}

run "lifecycle_default_90_days" {
  command = plan

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.velero.rule[0].expiration[0].days == 90
    error_message = "default backup retention should expire current versions at 90 days"
  }
}

run "bucket_key_enabled" {
  command = plan

  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.velero.rule[0].bucket_key_enabled == true
    error_message = "bucket key must be enabled for KMS cost optimization"
  }
}

run "ownership_bucket_owner_enforced" {
  command = plan

  assert {
    condition     = aws_s3_bucket_ownership_controls.velero.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "object ownership must be BucketOwnerEnforced (ACLs disabled)"
  }
}

run "irsa_role_trusts_velero_namespace_default" {
  command = plan

  assert {
    condition = (
      jsondecode(aws_iam_role.velero.assume_role_policy).Statement[0].Condition.StringEquals["oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E:sub"] == "system:serviceaccount:velero:velero"
    )
    error_message = "IRSA trust must scope to system:serviceaccount:velero:velero by default"
  }
}

run "ebs_unscoped_when_no_volumes_provided" {
  command = plan

  assert {
    condition = contains(
      jsondecode(data.aws_iam_policy_document.velero.json).Statement[2].Resource,
      "*",
    )
    error_message = "EBS statement should be unscoped (Resource=[\"*\"]) when allowed_ebs_volume_arns is empty"
  }
}

run "ebs_scoped_when_volumes_provided" {
  command = plan

  variables {
    allowed_ebs_volume_arns = [
      "arn:aws:ec2:us-east-1:123456789012:volume/vol-1234567890abcdef0",
    ]
  }

  assert {
    condition = contains(
      jsondecode(data.aws_iam_policy_document.velero.json).Statement[2].Resource,
      "arn:aws:ec2:us-east-1:123456789012:volume/vol-1234567890abcdef0",
    )
    error_message = "EBS statement should be scoped to the configured volume ARNs"
  }
}

run "consumer_kms_key_is_used_when_provided" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-ab12-cd34-ef56-1234567890ab"
  }

  assert {
    condition     = length(aws_kms_key.velero) == 0
    error_message = "module must not create a KMS key when consumer supplies kms_key_arn"
  }

  assert {
    condition = (
      aws_s3_bucket_server_side_encryption_configuration.velero.rule[0].apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:us-east-1:123456789012:key/abcd1234-ab12-cd34-ef56-1234567890ab"
    )
    error_message = "bucket encryption must use the consumer-supplied kms_key_arn when provided"
  }
}
