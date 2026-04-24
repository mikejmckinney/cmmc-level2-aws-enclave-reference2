output "trail_arn" {
  description = "ARN of the CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "trail_name" {
  description = "Name of the CloudTrail trail."
  value       = aws_cloudtrail.this.name
}

output "log_bucket_name" {
  description = "S3 bucket holding trail logs."
  value       = aws_s3_bucket.trail.id
}

output "log_bucket_arn" {
  description = "ARN of the S3 bucket holding trail logs."
  value       = aws_s3_bucket.trail.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group for the trail."
  value       = aws_cloudwatch_log_group.trail.name
}

output "log_group_arn" {
  description = "CloudWatch Logs group ARN."
  value       = aws_cloudwatch_log_group.trail.arn
}

output "metric_filter_names" {
  description = "Names of the CloudWatch metric filters."
  value       = [for mf in aws_cloudwatch_log_metric_filter.this : mf.name]
}

output "partition" {
  description = "AWS partition this module deployed into."
  value       = data.aws_partition.current.partition
}
