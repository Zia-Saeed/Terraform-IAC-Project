# Execution Role For Lambda Function
resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
#
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
#
resource "aws_iam_policy" "lambda_processing_policy" {
  name        = "lambda-rekognition-s3-policy"
  description = "Policy for Lambda to process S3 images with Rekognition"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadSourceBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.source_bucket.arn}/*"
      },
      {
        Sid    = "AllowWriteDestBucket"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.des_bucket.arn}/*"
      },
      {
        Sid    = "AllowRekognition"
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowGetBucketLocation"
        Effect = "Allow"
        Action = "s3:GetBucketLocation"
        Resource = [
          aws_s3_bucket.source_bucket.arn,
          aws_s3_bucket.des_bucket.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_processing" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_processing_policy.arn
}