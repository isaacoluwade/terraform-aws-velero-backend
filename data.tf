# --------------------------------------------------------------------------
# IRSA trust policy for the Velero IAM role.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "velero_irsa_trust" {
  statement {
    sid     = "VeleroIRSATrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.velero_namespace}:${var.velero_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# --------------------------------------------------------------------------
# Velero inline permissions: S3 backup bucket + EBS snapshots + KMS.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "velero" {
  statement {
    sid    = "VeleroBucketAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]

    resources = compact([
      "${aws_s3_bucket.velero.arn}/*",
      local.replication_enabled ? "${aws_s3_bucket.velero_replica[0].arn}/*" : "",
    ])
  }

  statement {
    sid    = "VeleroBucketList"
    effect = "Allow"

    actions = ["s3:ListBucket"]

    resources = compact([
      aws_s3_bucket.velero.arn,
      local.replication_enabled ? aws_s3_bucket.velero_replica[0].arn : "",
    ])
  }

  # V-C3 fix: split into two statements.
  #
  # ec2:Describe* and ec2:CreateVolume only accept `Resource: "*"` — the EC2
  # API rejects the call entirely if resources are scoped to ARNs, which
  # caused Velero's DescribeVolumes to return AccessDenied and silently
  # enumerate zero volumes (backups appeared "successful" but were empty).
  #
  # Snapshot creation/deletion can be scoped via the ec2:SourceVolume
  # condition when the consumer supplies allowed_ebs_volume_arns.
  statement {
    sid    = "VeleroEBSDescribe"
    effect = "Allow"

    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:CreateVolume",
      "ec2:CreateTags",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "VeleroEBSSnapshot"
    effect = "Allow"

    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
    ]

    resources = length(var.allowed_ebs_volume_arns) > 0 ? var.allowed_ebs_volume_arns : ["*"]

    dynamic "condition" {
      for_each = length(var.allowed_ebs_volume_arns) > 0 ? toset(["scope"]) : toset([])

      content {
        test     = "ArnEquals"
        variable = "ec2:SourceVolume"
        values   = var.allowed_ebs_volume_arns
      }
    }
  }

  statement {
    sid    = "VeleroKMSAccess"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]

    resources = compact([
      local.effective_kms_arn,
      local.effective_replica_kms_arn,
    ])
  }
}

# --------------------------------------------------------------------------
# KMS key policy (only used when the module owns the key).
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "kms_key" {
  count = local.create_kms_key ? 1 : 0

  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.caller_account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = local.replication_enabled ? toset(["replication"]) : toset([])

    content {
      sid    = "AllowReplicationRole"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [aws_iam_role.replication[0].arn]
      }

      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
        "kms:ReEncrypt*",
      ]

      resources = ["*"]
    }
  }
}

data "aws_iam_policy_document" "kms_replica_key" {
  count = local.create_kms_key && local.replication_enabled ? 1 : 0

  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.caller_account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowReplicationRole"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.replication[0].arn]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
      "kms:ReEncrypt*",
    ]

    resources = ["*"]
  }
}

# --------------------------------------------------------------------------
# Replication role assume-role and permissions policies.
# --------------------------------------------------------------------------

data "aws_iam_policy_document" "replication_assume_role" {
  count = local.replication_enabled ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "replication_permissions" {
  count = local.replication_enabled ? 1 : 0

  statement {
    sid    = "AllowSourceBucketRead"
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = [
      aws_s3_bucket.velero.arn,
      "${aws_s3_bucket.velero.arn}/*",
    ]
  }

  statement {
    sid    = "AllowDestinationWrite"
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner",
    ]

    resources = ["${aws_s3_bucket.velero_replica[0].arn}/*"]
  }

  statement {
    sid    = "AllowKMS"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]

    resources = compact([
      local.effective_kms_arn,
      local.effective_replica_kms_arn,
    ])
  }
}
