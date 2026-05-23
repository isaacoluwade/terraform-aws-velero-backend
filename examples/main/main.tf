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

# Required by the module even when DR is not enabled (configuration_aliases),
# pointed at the primary region so the unused provider has a valid config.
provider "aws" {
  alias  = "dr"
  region = var.region
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

  oidc_provider_arn = var.oidc_provider_arn
  oidc_provider_url = var.oidc_provider_url

  tags = {
    Owner = "platform-team"
  }
}
