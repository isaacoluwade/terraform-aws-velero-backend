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

run "bucket_name_follows_primary_name" {
  command = plan

  assert {
    condition     = aws_s3_bucket.velero.bucket == "test-test-use1-velero"
    error_message = "bucket name should be $${project}-$${environment}-$${region_code}-velero"
  }
}

run "iam_role_name_follows_primary_name" {
  command = plan

  assert {
    condition     = aws_iam_role.velero.name == "test-test-use1-velero"
    error_message = "IAM role name should be $${primary_name}-velero"
  }
}

run "kms_alias_follows_primary_name" {
  command = plan

  assert {
    condition     = aws_kms_alias.velero[0].name == "alias/test-test-use1-velero"
    error_message = "KMS alias should be alias/$${primary_name}-velero"
  }
}

run "all_resources_carry_module_tag" {
  command = plan

  assert {
    condition     = aws_s3_bucket.velero.tags["Module"] == "terraform-aws-velero-backend"
    error_message = "bucket must carry Module=terraform-aws-velero-backend"
  }

  assert {
    condition     = aws_iam_role.velero.tags["Module"] == "terraform-aws-velero-backend"
    error_message = "IAM role must carry the Module tag"
  }

  assert {
    condition     = aws_kms_key.velero[0].tags["Module"] == "terraform-aws-velero-backend"
    error_message = "KMS key must carry the Module tag"
  }
}

run "all_resources_carry_project_tag" {
  command = plan

  assert {
    condition     = aws_s3_bucket.velero.tags["Project"] == "test"
    error_message = "bucket must carry the Project tag"
  }

  assert {
    condition     = aws_s3_bucket.velero.tags["Environment"] == "test"
    error_message = "bucket must carry the Environment tag"
  }

  assert {
    condition     = aws_s3_bucket.velero.tags["ManagedBy"] == "terraform"
    error_message = "bucket must carry ManagedBy=terraform tag"
  }
}

run "consumer_tags_do_not_override_spine" {
  command = plan

  variables {
    tags = {
      Module = "evil-override"
      Owner  = "platform-team"
    }
  }

  assert {
    condition     = aws_s3_bucket.velero.tags["Module"] == "terraform-aws-velero-backend"
    error_message = "consumer tags must not override the Module tag from the spine"
  }

  assert {
    condition     = aws_s3_bucket.velero.tags["Owner"] == "platform-team"
    error_message = "consumer-provided non-spine tags must be applied"
  }
}

run "region_compression_eu_west_2" {
  command = plan

  variables {
    region = "eu-west-2"
  }

  assert {
    condition     = aws_s3_bucket.velero.bucket == "test-test-euw2-velero"
    error_message = "region compression should produce 'euw2' from 'eu-west-2'"
  }
}

run "dr_replica_bucket_name_follows_primary_name" {
  command = plan

  variables {
    dr_region = "us-west-2"
  }

  assert {
    condition     = aws_s3_bucket.velero_replica[0].bucket == "test-test-use1-velero-replica"
    error_message = "DR replica bucket name should be $${primary_name}-velero-replica"
  }
}
