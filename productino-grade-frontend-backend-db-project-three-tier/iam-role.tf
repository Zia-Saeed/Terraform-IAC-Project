# ==============================================================================
# IAM Roles and Policies for ECS Task Execution
# ==============================================================================
# This file defines two distinct IAM roles required for ECS tasks running on 
# Fargate:
# 
# 1. ECS Task Execution Role: Used by the ECS agent to pull images, send logs,
#    and manage task lifecycle operations.
# 
# 2. ECS Task Role: Assumed by the application container itself to access 
#    AWS services (e.g., S3, DynamoDB) at runtime.
#
# Separating these roles follows the principle of least privilege and is an 
# AWS security best practice.
# ==============================================================================

# ------------------------------------------------------------------------------
# ECS Task Execution Role
# ------------------------------------------------------------------------------
# This role is assumed by the ECS agent (not your application code).
# It grants permissions for infrastructure-level operations:
# - Pulling container images from ECR
# - Sending logs to CloudWatch Logs
# - Retrieving secrets from Secrets Manager/Parameter Store (if configured)
resource "aws_iam_role" "ecs_task_exec_role" {
  name = "ecsexecrole"
  
  # Trust policy: Allows ECS tasks service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  
  tags = {
    Name        = "${var.resource_name}-ecs-task-role"
    Resource    = var.resource_name
    Environment = var.env_name
  }
}

# ------------------------------------------------------------------------------
# Attach AWS Managed Policy to Execution Role
# ------------------------------------------------------------------------------
# The AmazonECSTaskExecutionRolePolicy is a AWS-managed policy that provides
# the minimum required permissions for the ECS agent to function:
# - ecr:GetAuthorizationToken, ecr:BatchGetImage, ecr:GetDownloadUrlForLayer
# - logs:CreateLogStream, logs:PutLogEvents
# - secretsmanager:GetSecretValue, ssm:GetParameters (if needed)
#
# NOTE: Resource name has typo "aim" should be "iam" (ecs_iam_role_attachment)
resource "aws_iam_role_policy_attachment" "ecs_aim_role_attch" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------------------------------
# ECS Task Role (Application Role)
# ------------------------------------------------------------------------------
# This role is assumed by your application code running inside the container.
# Use this role to grant your backend app permissions to access AWS resources
# like S3 buckets, DynamoDB tables, SQS queues, etc.
#
# IMPORTANT: Do NOT grant permissions here that are only needed for task 
# execution (e.g., ECR pull, CloudWatch logs). Keep execution and task roles 
# separate for security and auditability.
resource "aws_iam_role" "ecs_task_role" {
  name = "ecstaskrole"
  
  # Trust policy: Allows ECS tasks service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  
  tags = {
    Name        = "${var.resource_name}-ecs-task-role"
    Project     = var.project_name
    Environment = var.env_name
  }
}

# ------------------------------------------------------------------------------
# Custom IAM Policy for S3 Access (Task Role)
# ------------------------------------------------------------------------------
# This policy grants the application container permissions to read from and 
# write to a specific S3 bucket. Adjust actions and resources based on your 
# application's actual requirements.
#
# SECURITY BEST PRACTICES:
# 1. Replace "your-bucket-name" with actual bucket name or use Terraform variable
# 2. Consider using bucket ARN variables: aws_s3_bucket.your_bucket.arn
# 3. If possible, restrict to specific prefixes: "arn:aws:s3:::bucket/prefix/*"
# 4. Avoid wildcard (*) actions; only grant what the app truly needs
resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecs-task-policy-s3-access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",  # Download/read objects
          "s3:PutObject"   # Upload/write objects
          # Consider adding if needed:
          # - "s3:ListBucket" (for listing objects)
          # - "s3:DeleteObject" (if app deletes files)
        ]
        # ⚠️  WARNING: Replace placeholder with actual bucket reference
        # Example: "arn:aws:s3:::${aws_s3_bucket.be_s3_bucket.id}/*"
        Resource = "arn:aws:s3:::your-bucket-name/*"
      }
    ]
  })
  
  tags = {
    Name        = "${var.resource_name}-ecs-task-s3-access-policy"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# Attach Custom S3 Policy to Task Role
# ------------------------------------------------------------------------------
# Links the custom S3 access policy defined above to the ECS task role,
# enabling the application container to perform S3 operations at runtime.
resource "aws_iam_role_policy_attachment" "ecs_task_iam_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# ==============================================================================
# IAM Architecture Summary
# ==============================================================================
# 
# ┌─────────────────────────────────────────────────────┐
# │ ECS Task (Fargate)                                  │
# │                                                     │
# │  ┌─────────────────┐  ┌─────────────────┐          │
# │  │ ECS Agent       │  │ App Container   │          │
# │  │ (Infrastructure)│  │ (Your Code)     │          │
# │  └────────┬────────┘  └────────┬────────┘          │
# │           │                    │                    │
# │           ▼                    ▼                    │
# │  ┌─────────────────┐  ┌─────────────────┐          │
# │  │ Execution Role  │  │ Task Role       │          │
# │  │ - Pull ECR      │  │ - S3 Access     │          │
# │  │ - CloudWatch    │  │ - DynamoDB      │          │
# │  │ - Secrets       │  │ - Other AWS     │          │
# │  └─────────────────┘  └─────────────────┘          │
# └─────────────────────────────────────────────────────┘
#
# ==============================================================================
