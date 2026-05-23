mock_provider "aws" {}
mock_provider "aws" {
  alias = "dr"
}

run "rejects_project_too_short" {
  command = plan

  variables {
    project           = "ab"
    environment       = "test"
    region            = "us-east-1"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.project,
  ]
}

run "rejects_project_too_long" {
  command = plan

  variables {
    project           = "this-is-way-too-long"
    environment       = "test"
    region            = "us-east-1"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.project,
  ]
}

run "rejects_environment_with_uppercase" {
  command = plan

  variables {
    project           = "test"
    environment       = "Prod"
    region            = "us-east-1"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.environment,
  ]
}

run "rejects_invalid_region" {
  command = plan

  variables {
    project           = "test"
    environment       = "test"
    region            = "not-a-region"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.region,
  ]
}

run "rejects_dr_region_equal_to_region" {
  command = plan

  variables {
    project           = "test"
    environment       = "test"
    region            = "us-east-1"
    dr_region         = "us-east-1"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.dr_region,
  ]
}

run "rejects_malformed_oidc_provider_arn" {
  command = plan

  variables {
    project           = "test"
    environment       = "test"
    region            = "us-east-1"
    oidc_provider_arn = "not-an-arn"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.oidc_provider_arn,
  ]
}

run "rejects_malformed_oidc_provider_url" {
  command = plan

  variables {
    project           = "test"
    environment       = "test"
    region            = "us-east-1"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.oidc_provider_url,
  ]
}

run "rejects_malformed_kms_key_arn" {
  command = plan

  variables {
    project           = "test"
    environment       = "test"
    region            = "us-east-1"
    kms_key_arn       = "not-a-kms-arn"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.kms_key_arn,
  ]
}

run "rejects_short_backup_retention" {
  command = plan

  variables {
    project               = "test"
    environment           = "test"
    region                = "us-east-1"
    backup_retention_days = 3
    oidc_provider_arn     = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url     = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.backup_retention_days,
  ]
}

run "rejects_excessive_backup_retention" {
  command = plan

  variables {
    project               = "test"
    environment           = "test"
    region                = "us-east-1"
    backup_retention_days = 99999
    oidc_provider_arn     = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url     = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.backup_retention_days,
  ]
}

run "rejects_malformed_ebs_volume_arn" {
  command = plan

  variables {
    project                 = "test"
    environment             = "test"
    region                  = "us-east-1"
    allowed_ebs_volume_arns = ["not-an-arn"]
    oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
    oidc_provider_url       = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED"
  }

  expect_failures = [
    var.allowed_ebs_volume_arns,
  ]
}
