data "aws_partition" "current" {}

resource "aws_guardduty_detector" "this" {
  count                        = var.enable ? 1 : 0
  enable                       = true
  finding_publishing_frequency = var.finding_publishing_frequency
  tags                         = var.tags
}

resource "aws_guardduty_detector_feature" "this" {
  for_each    = var.enable ? var.features : {}
  detector_id = aws_guardduty_detector.this[0].id
  name        = each.key
  status      = each.value ? "ENABLED" : "DISABLED"
}
