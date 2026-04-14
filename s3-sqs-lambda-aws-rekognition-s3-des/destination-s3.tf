resource "aws_s3_bucket" "des_bucket" {
  bucket = var.des_bucket_name
  tags = merge(local.tags, {
    Name = "${var.resource}-destination-bucket-for-image-processing"
  })
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
  block_public_acls = false
  ignore_public_acls = false
  block_public_policy = false
  restrict_public_buckets = false
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
resource "aws_s3_bucket_policy" "des_bucket_policy" {
  bucket = aws_s3_bucket.des_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.des_bucket.arn}/*"
      }
    ]
  })
}
