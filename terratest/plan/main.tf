provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "dr"
  region = coalesce(var.dr_region, var.region)
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

  tags = {
    Owner = "ci-terratest"
  }
}
