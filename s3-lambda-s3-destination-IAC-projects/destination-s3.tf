resource "aws_s3_bucket" "des_bucket" {
  bucket = "<destination-bucket-name>"
}
#
resource "aws_s3_bucket_versioning" "s3_verioning" {
  bucket = aws_s3_bucket.des_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
#
resource "aws_s3_bucket_public_access_block" "des_pb_block" {
  bucket = aws_s3_bucket.des_bucket.id
  block_public_acls = true
  ignore_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
}
#
resource "aws_s3_bucket_server_side_encryption_configuration" "des_s3_encrypt" {
  bucket = aws_s3_bucket.des_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
#
