# Output the Bucket Name for easy testing
output "s3_bucket_name" {
  value = aws_s3_bucket.source_bucket.id
}