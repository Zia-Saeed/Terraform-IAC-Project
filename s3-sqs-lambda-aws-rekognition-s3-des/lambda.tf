#
# data "archive_file" "lambda_file" {
#   type = "zip"
#   source_file = "${path.module}/package/*"
#   output_path =  "${path.module}/lambda_function.zip"
# }
#
# Lambda Function
resource "aws_lambda_function" "processor" {
  filename      = "${path.module}/pillow.zip"
  function_name = "s3-upload-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12" # Ensure this runtime is available in your region
  timeout     = 120       # 2 minutes for large images
  memory_size = 1024       # 1024 MB for better performance


  logging_config {
    log_format = "JSON"
  }

  environment {
    variables = {
      OUTPUT_BUCKET = var.des_bucket_name  # Use Terraform reference, not hardcoded
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_policy.lambda_processing_policy,
 # ← Attach new policy
  # ← Attach new policy
  ]
  tags = merge(local.tags, {
    Name = "${var.resource}-lambda-function-for-image-processsing"
  })
}
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = aws_sqs_queue.sqs_main_fifo.arn
  function_name                      = aws_lambda_function.processor.arn
  batch_size                         = 10  # Process up to 10 messages per invocation
  enabled                              = true
#   visibility_timeout                 = 60  # Must match queue visibility_timeout
#   max_batching_window_in_seconds     = 5   # Wait up to 5s to batch messages
  maximum_batching_window_in_seconds = 5
#   destination_config {
#     on_failure {
#       destination_arn = aws_sqs_queue.dlq_sqs.arn
#     }
#   }
  # Scaling configuration
  scaling_config {
    maximum_concurrency = 10  # Limit concurrent Lambda invocations
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_processing
  ]
}