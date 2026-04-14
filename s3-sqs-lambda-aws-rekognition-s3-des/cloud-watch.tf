# resource "aws_cloudwatch_log_group" "lambda_logs" {
#   retention_in_days = 7
#   name = "aws/lambda/${aws_lambda_function.processor.function_name}"
# }