# ____________ S3 Bucket _____________ #
resource "aws_s3_bucket" "s3_portfolio" {
  bucket = var.bucket_name
  region = var.region
  tags = merge(local.tags_value, {
    Resource = "s3-bucket-${var.resource_name}"
  })
}
# ______________ S3 Bucket Policy _______________ #
resource "aws_s3_bucket_public_access_block" "s3_pb_block" {
  bucket                  = aws_s3_bucket.s3_portfolio.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}
# _________________ S3 Server Side Encryption __________________ #
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encrypt" {
  bucket = aws_s3_bucket.s3_portfolio.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
# _________________ S3 bucket Versioning __________________ #
resource "aws_s3_bucket_versioning" "s3_versioning" {
  bucket = aws_s3_bucket.s3_portfolio.id
  versioning_configuration {
    status = "Enabled"
  }
}
# __________________ S3 Bucket Policy ___________________ #
resource "aws_s3_bucket_policy" "s3_policy" {
  bucket     = aws_s3_bucket.s3_portfolio.id
  depends_on = [aws_s3_bucket_public_access_block.s3_pb_block]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOnly"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.s3_portfolio.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.static_site.arn
          }
        }
      }
    ]
  })
}
#
