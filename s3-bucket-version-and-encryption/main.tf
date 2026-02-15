# s3 bucket creation
resource "aws_s3_bucket" "bucket_1" {
  bucket = "<bucket name>"
  region = "us-east-1"
  tags = {
    Name = "<tag name of bucket>"
    Environment = "<environment>"
    Project = "<project>"
  }
}
# enabling version on s3 bucket
resource "aws_s3_bucket_versioning" "s3_versioning" {
  bucket = aws_s3_bucket.bucket_1.id
  versioning_configuration {
    status = "Enabled"
  }
}
# Enabling server side encryption on s3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_server_side_encryption" {
  bucket = aws_s3_bucket.bucket_1.id
  rule {
    apply_server_side_encryption_by_default {
        # algorithm type
        sse_algorithm = "AES256"
    }
  }
}
