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
  description = "Primary AWS region."
  default     = "us-east-1"
}

variable "dr_region" {
  type        = string
  description = "DR AWS region for cross-region replication of the Velero backup bucket."
  default     = "us-west-2"
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS cluster's IAM OIDC provider ARN."
}

variable "oidc_provider_url" {
  type        = string
  description = "EKS cluster's IAM OIDC provider URL (no https:// prefix)."
}

variable "kms_key_arn" {
  type        = string
  description = "Optional consumer-supplied KMS key ARN. Null means the module creates one."
  default     = null
}

variable "allowed_ebs_volume_arns" {
  type        = list(string)
  description = "EBS volume ARNs Velero is allowed to snapshot. Empty means all."
  default     = []
}
