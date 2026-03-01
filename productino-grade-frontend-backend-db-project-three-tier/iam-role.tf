#
resource "aws_iam_role" "ecs_task_exec_role" {
  name = "ecsexecrole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
        Effect = "Allow",
        Principal = {
            Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        } 
    ]
  })
  tags = {
    Name = "${var.resource_name}-ecs-task-role"
    Resource = var.resource_name
    Environment = var.env_name
  }
}
#
resource "aws_iam_role_policy_attachment" "ecs_aim_role_attch" {
    role =  aws_iam_role.ecs_task_exec_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
#
resource "aws_iam_role" "ecs_task_role" {
  name = "ecstaskrole"
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
    Name = "${var.resource_name}-ecs-task-role"
    Project = var.project_name
    Environment = var.env_name
  }
}
#
resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecs-task-policy-s3-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::your-bucket-name/*"
      }
    ]
  })
  tags = {
    Name = "${var.resource_name}-ecs-task-s3-access-policy"
    Environment = var.env_name
    Project = var.project_name
  }
}
resource "aws_iam_role_policy_attachment" "ecs_task_iam_attach" {
  role = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}