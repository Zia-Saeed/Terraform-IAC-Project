resource "aws_cloudwatch_log_group" "be_cloud_logs" {
  # The name of the log group.
  # Using the '/ecs/' prefix helps organize logs within the CloudWatch console
  # and aligns with AWS ECS logging conventions.
  name = "/ecs/be-express-app"

  # Specifies the number of days to retain log events in the log group.
  # Setting this prevents logs from being stored indefinitely, helping to 
  # manage storage costs. Adjust based on compliance or debugging requirements.
  retention_in_days = 7

  tags = {
    # Standard tagging strategy for resource identification, cost allocation, 
    # and automation filtering.
    Name        = "${var.resource_name}-ecs-express-be-logs"
    Project     = var.project_name
    Environment = var.env_name
  }
}
