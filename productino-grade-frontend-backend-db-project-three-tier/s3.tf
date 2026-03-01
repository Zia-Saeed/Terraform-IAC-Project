resource "aws_s3_bucket" "be_s3_bucket" {
  bucket = var.s3_bucket_name
  region = "us-east-1"
  tags = {
    Name = "${var.resource_name}-s3-bucket-for-be-file"
    Project = var.project_name
    Environment = var.env_name
  }
}
#
resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.be_s3_bucket.id
  versioning_configuration {
   status = var.aws_s3_bucket_versioning_status
  }
}
#
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encrypt" {
  bucket = aws_s3_bucket.be_s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.aws_s3_bucket_enrypt_algo
    }
  }
}
#
resource "aws_s3_bucket_public_access_block" "public_access_s3_block" {
  bucket = aws_s3_bucket.be_s3_bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}