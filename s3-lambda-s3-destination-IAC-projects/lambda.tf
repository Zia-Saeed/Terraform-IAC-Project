#
data "archive_file" "lambda_file" {
  type = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path =  "${path.module}/lambda_function.zip"
}
#
# Lambda Function
resource "aws_lambda_function" "processor" {
  filename      = data.archive_file.lambda_file.output_path
  function_name = "s3-upload-processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12" # Ensure this runtime is available in your region
  timeout     = 60        # 60 seconds (adjust based on image size)
  memory_size = 512       # 512 MB for better performance


  logging_config {
    log_format = "JSON"
  }

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.des_bucket.id  # Use Terraform reference, not hardcoded
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_iam_role_policy_attachment.lambda_processing  # ← Attach new policy
  ]
}