data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  account_root = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

data "aws_iam_policy_document" "key" {
  for_each = var.keys

  # Root account always retains full administrative control.
  statement {
    sid       = "EnableRootAccountPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  # Optional additional admins.
  dynamic "statement" {
    for_each = length(each.value.additional_admins) > 0 ? [1] : []
    content {
      sid    = "AllowKeyAdministration"
      effect = "Allow"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = each.value.additional_admins
      }
    }
  }

  # Optional additional users (data plane).
  dynamic "statement" {
    for_each = length(each.value.additional_users) > 0 ? [1] : []
    content {
      sid    = "AllowKeyUsage"
      effect = "Allow"
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey",
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = each.value.additional_users
      }
    }
  }

  # Deny use outside this AWS partition. Defense-in-depth: prevents an
  # exfiltrated key reference from being used from an unexpected partition.
  statement {
    sid       = "DenyOutsidePartition"
    effect    = "Deny"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  for_each = var.keys

  description             = each.value.description
  deletion_window_in_days = each.value.deletion_window
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.key[each.key].json
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-${each.key}" })
}

resource "aws_kms_alias" "this" {
  for_each      = var.keys
  name          = "alias/${var.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
