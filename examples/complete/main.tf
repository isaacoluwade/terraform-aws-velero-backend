terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

module "velero_backend" {
  source = "../../"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project     = var.project
  environment = var.environment
  region      = var.region
  dr_region   = var.dr_region

  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url

  # Consumer-supplied KMS key. When null, the module provisions one.
  kms_key_arn = var.kms_key_arn

  # Tighter retention for the example.
  backup_retention_days = 30

  # Scope EBS snapshot perms to a specific volume set.
  allowed_ebs_volume_arns = var.allowed_ebs_volume_arns

  # Non-default namespace/service account.
  velero_namespace       = "velero-system"
  velero_service_account = "velero"

  tags = {
    Owner      = "platform-team"
    Compliance = "sox"
  }
}
