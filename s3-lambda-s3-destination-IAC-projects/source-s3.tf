resource "aws_s3_bucket" "source_bucket" {
  bucket = var.s3_source_name
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
# Permission to Trigger Lambda Function 
resource "aws_lambda_permission" "name" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal = "s3.amazonaws.com"
  statement_id = "AllowExecutionFromS3"
  source_arn = aws_s3_bucket.source_bucket.arn
}

#
resource "aws_s3_bucket_notification" "s3_source_notifier" {
  bucket = aws_s3_bucket.source_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"] # Triggers on PUT, POST, COPY, etc.
    filter_prefix       = ""                     # Optional: Filter by prefix (e.g., "uploads/")
    filter_suffix       = ""    
  }
    depends_on = [
    aws_lambda_permission.name,  # ← Critical: Wait for permission first
    aws_s3_bucket.des_bucket,
    aws_s3_bucket.source_bucket
  ]
}
