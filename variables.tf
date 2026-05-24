variable "project" {
  type        = string
  description = "Project / platform name. Drives primary_name and the Project tag on every resource. Lowercase letters, digits, and hyphens only; 3-12 characters."

  validation {
    condition     = can(regex("^[a-z0-9-]{3,12}$", var.project))
    error_message = "project must be 3-12 chars, lowercase letters, digits, and hyphens only."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod, ci-*). Drives primary_name and the Environment tag. Lowercase letters, digits, and hyphens only."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be lowercase letters, digits, and hyphens only."
  }
}

variable "region" {
  type        = string
  description = "Primary AWS region (e.g. us-east-1). Where the Velero backup bucket and IAM role live."

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "region must look like 'us-east-1', 'eu-west-2', etc."
  }
}

variable "dr_region" {
  type        = string
  description = "DR region for cross-region replication of the Velero backup bucket (e.g. us-west-2). When set, the module provisions a replica bucket, KMS replica key (when the module creates the key), and replication configuration. When null, no DR resources are created."
  default     = null

  validation {
    condition     = var.dr_region == null || can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.dr_region))
    error_message = "dr_region must be null or a valid AWS region."
  }

  validation {
    condition     = var.dr_region == null || var.dr_region != var.region
    error_message = "dr_region must differ from region."
  }
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster's IAM OIDC provider. Sourced from terraform-aws-eks's oidc_provider_arn output. Used as the IRSA trust principal for the Velero IAM role."

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:oidc-provider/", var.oidc_provider_arn))
    error_message = "oidc_provider_arn must be a valid IAM OIDC provider ARN (arn:aws:iam::ACCOUNT:oidc-provider/...)."
  }
}

variable "oidc_provider_url" {
  type        = string
  description = "Issuer URL of the EKS cluster's IAM OIDC provider, without the leading 'https://'. Sourced from terraform-aws-eks's oidc_provider_url output. Used to build the IRSA trust condition."

  validation {
    condition     = can(regex("^oidc\\.eks\\.[a-z0-9-]+\\.amazonaws\\.com/id/[A-F0-9]+$", var.oidc_provider_url))
    error_message = "oidc_provider_url must look like oidc.eks.<region>.amazonaws.com/id/<HEXID> (no https:// prefix)."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "Consumer-supplied KMS key ARN in the PRIMARY region, used to encrypt the Velero backup bucket. When null, the module provisions a customer-managed key (multi-region when dr_region is set) and outputs its ARN via kms_key_arn. When supplied and dr_region is set, dr_kms_key_arn must also be supplied (a KMS key in the DR region) or replicated objects will fail with KMS.NotFoundException."
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be null or a valid KMS key ARN."
  }
}

variable "dr_kms_key_arn" {
  type        = string
  description = "Consumer-supplied KMS key ARN in the DR REGION. Required when both kms_key_arn and dr_region are set — the replica bucket's SSE config and replication configuration encrypt with this key. When the module owns the KMS key (kms_key_arn = null), the module creates a multi-region replica and dr_kms_key_arn is ignored."
  default     = null

  validation {
    condition     = var.dr_kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:", var.dr_kms_key_arn))
    error_message = "dr_kms_key_arn must be null or a valid KMS key ARN."
  }

  validation {
    # S-3 fix: enforce DR-with-consumer-KMS pairing at plan time.
    condition     = var.kms_key_arn == null || var.dr_region == null || var.dr_kms_key_arn != null
    error_message = "dr_kms_key_arn is required when both kms_key_arn and dr_region are set (the replica bucket needs a DR-region KMS key)."
  }
}

variable "velero_namespace" {
  type        = string
  description = "Kubernetes namespace where the Velero service account lives. Used in the IRSA trust condition."
  default     = "velero"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.velero_namespace))
    error_message = "velero_namespace must be a valid Kubernetes namespace (DNS-1123 label)."
  }
}

variable "velero_service_account" {
  type        = string
  description = "Name of the Velero Kubernetes service account. Used in the IRSA trust condition and consumed by the Velero Helm chart's serviceAccount.server.create=false, serviceAccount.server.name."
  default     = "velero"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.velero_service_account))
    error_message = "velero_service_account must be a valid Kubernetes service account name (DNS-1123 label)."
  }
}

variable "backup_retention_days" {
  type        = number
  description = "Days to retain Velero backup objects before lifecycle expiry. Velero's own backup metadata effectively replaces the concept of 'current version' — old backups are meant to age out."
  default     = 90

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 3650
    error_message = "backup_retention_days must be between 7 and 3650 (10 years)."
  }
}

variable "allowed_ebs_volume_arns" {
  type        = list(string)
  description = "EBS volume ARNs Velero is allowed to snapshot. When empty, the policy grants snapshot permissions on all EBS volumes in the account (broad). When populated, scopes the snapshot statement to those volumes."
  default     = []

  validation {
    condition = alltrue([
      for arn in var.allowed_ebs_volume_arns :
      can(regex("^arn:aws[a-z-]*:ec2:[a-z0-9-]+:[0-9]{12}:volume/vol-", arn))
    ])
    error_message = "allowed_ebs_volume_arns entries must be EBS volume ARNs (arn:aws:ec2:REGION:ACCOUNT:volume/vol-...)."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to merge with the module's default tag spine. Keys that conflict with the spine are overridden by the spine."
  default     = {}
}
