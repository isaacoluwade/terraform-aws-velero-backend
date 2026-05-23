variable "project" {
  type        = string
  description = "Project name passed through to the module."
  default     = "example"
}

variable "environment" {
  type        = string
  description = "Environment name passed through to the module."
  default     = "dev"
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS cluster's IAM OIDC provider ARN. Output of terraform-aws-eks.oidc_provider_arn."
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS cluster's IAM OIDC provider URL (no https:// prefix). Output of terraform-aws-eks.oidc_provider_url."
}
