resource "aws_s3_bucket" "source_bucket" {
  bucket = var.s3_source_name
  tags = merge(local.tags, {
    Name = "${var.resource}-source-bucket"
  })
}
#
resource "aws_s3_bucket_public_access_block" "s3_block" {
  bucket = aws_s3_bucket.source_bucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
#
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encrypt" {
  bucket = aws_s3_bucket.source_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

  }
}
#
resource "aws_s3_bucket_versioning" "s3_source_version" {
  bucket = aws_s3_bucket.source_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
#

#
resource "aws_s3_bucket_notification" "s3_source_notifier" {
  bucket = aws_s3_bucket.source_bucket.id
  queue {
    events = ["s3:ObjectCreated:*"]
    queue_arn = aws_sqs_queue.sqs_main_fifo.arn
    filter_prefix = ""
    filter_suffix = ""
  }
  depends_on = [
    aws_sqs_queue_policy.main_queue_policy
  ]
}
