locals {
  region_code = format(
    "%s%s",
    substr(replace(var.region, "-", ""), 0, length(replace(var.region, "-", "")) - 1),
    substr(var.region, length(var.region) - 1, 1),
  )

  primary_name = "${var.project}-${var.environment}-${local.region_code}"

  module_version = trimspace(file("${path.module}/VERSION"))

  default_tags = {
    Project       = var.project
    Environment   = var.environment
    Region        = var.region
    ManagedBy     = "terraform"
    Module        = "terraform-aws-velero-backend"
    ModuleVersion = local.module_version
  }

  tags = merge(var.tags, local.default_tags)

  replication_enabled = var.dr_region != null
  caller_account_id   = data.aws_caller_identity.current.account_id

  # Whether the module owns the KMS key (and may create a multi-region replica).
  create_kms_key    = var.kms_key_arn == null
  effective_kms_arn = local.create_kms_key ? aws_kms_key.velero[0].arn : var.kms_key_arn
  effective_replica_kms_arn = (
    local.replication_enabled && local.create_kms_key
    ? aws_kms_replica_key.velero[0].arn
    : null
  )
}

data "aws_caller_identity" "current" {}

# --------------------------------------------------------------------------
# KMS key (optional — only when consumer does not supply one)
# --------------------------------------------------------------------------

resource "aws_kms_key" "velero" {
  count = local.create_kms_key ? 1 : 0

  description             = "${local.primary_name} Velero backup KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  multi_region            = local.replication_enabled

  policy = data.aws_iam_policy_document.kms_key[0].json

  tags = local.tags
}

resource "aws_kms_alias" "velero" {
  count = local.create_kms_key ? 1 : 0

  name          = "alias/${local.primary_name}-velero"
  target_key_id = aws_kms_key.velero[0].key_id
}

resource "aws_kms_replica_key" "velero" {
  count = local.create_kms_key && local.replication_enabled ? 1 : 0

  provider                = aws.dr
  description             = "${local.primary_name} Velero backup replica key"
  primary_key_arn         = aws_kms_key.velero[0].arn
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_replica_key[0].json
  tags                    = local.tags
}

resource "aws_kms_alias" "velero_replica" {
  count = local.create_kms_key && local.replication_enabled ? 1 : 0

  provider      = aws.dr
  name          = "alias/${local.primary_name}-velero"
  target_key_id = aws_kms_replica_key.velero[0].key_id
}

# --------------------------------------------------------------------------
# Primary backup bucket
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "velero" {
  bucket = "${local.primary_name}-velero"
  tags   = merge(local.tags, { Name = "${local.primary_name}-velero" })
}

resource "aws_s3_bucket_versioning" "velero" {
  bucket = aws_s3_bucket.velero.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.effective_kms_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    filter {}
  }
}

# --------------------------------------------------------------------------
# Cross-region replica bucket (optional — only when dr_region is set)
# --------------------------------------------------------------------------

resource "aws_s3_bucket" "velero_replica" {
  count = local.replication_enabled ? 1 : 0

  provider = aws.dr
  bucket   = "${local.primary_name}-velero-replica"
  tags     = merge(local.tags, { Name = "${local.primary_name}-velero-replica" })
}

resource "aws_s3_bucket_versioning" "velero_replica" {
  count = local.replication_enabled ? 1 : 0

  provider = aws.dr
  bucket   = aws_s3_bucket.velero_replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "velero_replica" {
  count = local.replication_enabled ? 1 : 0

  provider = aws.dr
  bucket   = aws_s3_bucket.velero_replica[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_replica" {
  count = local.replication_enabled ? 1 : 0

  provider = aws.dr
  bucket   = aws_s3_bucket.velero_replica[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
      kms_master_key_id = (
        local.create_kms_key
        ? aws_kms_replica_key.velero[0].arn
        : var.kms_key_arn
      )
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_ownership_controls" "velero_replica" {
  count = local.replication_enabled ? 1 : 0

  provider = aws.dr
  bucket   = aws_s3_bucket.velero_replica[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_iam_role" "replication" {
  count = local.replication_enabled ? 1 : 0

  name               = "${local.primary_name}-velero-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume_role[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy" "replication" {
  count = local.replication_enabled ? 1 : 0

  name   = "${local.primary_name}-velero-replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication_permissions[0].json
}

resource "aws_s3_bucket_replication_configuration" "velero" {
  count = local.replication_enabled ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.velero.id

  depends_on = [
    aws_s3_bucket_versioning.velero,
    aws_s3_bucket_versioning.velero_replica,
  ]

  rule {
    id       = "primary-to-dr"
    status   = "Enabled"
    priority = 1

    filter {}

    destination {
      bucket        = aws_s3_bucket.velero_replica[0].arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = (
          local.create_kms_key
          ? aws_kms_replica_key.velero[0].arn
          : var.kms_key_arn
        )
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }
}

# --------------------------------------------------------------------------
# Velero IRSA IAM role
# --------------------------------------------------------------------------

resource "aws_iam_role" "velero" {
  name               = "${local.primary_name}-velero"
  assume_role_policy = data.aws_iam_policy_document.velero_irsa_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy" "velero" {
  name   = "${local.primary_name}-velero"
  role   = aws_iam_role.velero.id
  policy = data.aws_iam_policy_document.velero.json
}
