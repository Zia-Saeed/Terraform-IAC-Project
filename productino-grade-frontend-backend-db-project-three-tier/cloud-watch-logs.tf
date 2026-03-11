resource "aws_cloudwatch_log_group" "be_cloud_logs" {
  name = "/ecs/be-express-app"
  retention_in_days = 7
  tags = {
    Name = "${var.resource_name}-ecs-express-be-logs"
    Project = var.project_name
    Environment = var.env_name
  }
}
