output "bucket_id" {
  description = "Name of the CUI bucket."
  value       = aws_s3_bucket.cui.id
}

output "bucket_arn" {
  description = "ARN of the CUI bucket."
  value       = aws_s3_bucket.cui.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name (used for VPC endpoint / SDK clients pinned to a region)."
  value       = aws_s3_bucket.cui.bucket_regional_domain_name
}

output "access_logs_bucket_id" {
  description = "Name of the access-log target bucket."
  value       = aws_s3_bucket.access_logs.id
}

output "access_logs_bucket_arn" {
  description = "ARN of the access-log target bucket."
  value       = aws_s3_bucket.access_logs.arn
}

output "partition" {
  description = "Partition the module resolved (`aws` or `aws-us-gov`)."
  value       = data.aws_partition.current.partition
}
