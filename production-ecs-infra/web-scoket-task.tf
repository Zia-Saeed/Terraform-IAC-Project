resource "aws_ecs_task_definition" "ws_td" {
  family = "${var.name_prefix}-ws-tg"
  requires_compatibilities = [ "FARGATE" ]
  network_mode = "awsvpc"
  cpu = "1024"
  memory = "2048"
  execution_role_arn = aws_iam_role.ecs_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
        name = "${var.name_prefix}-ws-container"
        image = var.http_backend_image_url 
        essential = true
        portMappings = [
        {
          containerPort = 8001
          hostPort      = 800
          protocol      = "tcp"
        }
      ]
        environment = var.env_vars
        logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "websocket-backend"
        }
      }
    }
  ])
}