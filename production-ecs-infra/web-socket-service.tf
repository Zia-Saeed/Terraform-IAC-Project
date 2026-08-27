resource "aws_ecs_service" "ws_service" {
  name = "${var.name_prefix}-ws-service"
  task_definition = aws_ecs_task_definition.ws_td.id
  desired_count = 1
  cluster = aws_ecs_cluster.ecs_cluster_1.id
  launch_type = "FARGATE"
  
  load_balancer {
    target_group_arn = aws_lb_target_group.web_soc_tg.arn
    container_name = "${var.name_prefix}-ws-container"
    container_port = 8001
  }
  network_configuration {
    subnets = aws_subnet.pub_subnets[*].id
    security_groups = [ aws_security_group.web_soc_sg.id ]
    assign_public_ip = true
  }
  enable_execute_command = true
  depends_on = [ aws_ecs_task_definition.backend_task, aws_ecs_cluster.ecs_cluster_1, aws_ecs_task_definition.ws_td ]
  health_check_grace_period_seconds = 90
  
}


####
# ---------------------------
# Application Auto Scaling Target
# ---------------------------
resource "aws_appautoscaling_target" "ws_scaling_target" {
  max_capacity       = 3
  min_capacity        = 1
  resource_id         = "service/${aws_ecs_cluster.ecs_cluster_1.name}/${aws_ecs_service.ws_service.name}"
  scalable_dimension  = "ecs:service:DesiredCount"
  service_namespace   = "ecs"
}

# ---------------------------
# Step Scaling Policy - CPU
# ---------------------------
resource "aws_appautoscaling_policy" "ws_cpu_scale_up" {
  name               = "${var.name_prefix}-ws-cpu-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ws_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ws_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ws_scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 3
      metric_interval_lower_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ws_cpu_high" {
  alarm_name          = "${var.name_prefix}-ws-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 7
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU > 80% for 7 minutes on ws_service"

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster_1.name
    ServiceName = aws_ecs_service.ws_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.ws_cpu_scale_up.arn]
}

# ---------------------------
# Step Scaling Policy - Memory
# ---------------------------
resource "aws_appautoscaling_policy" "ws_mem_scale_up" {
  name               = "${var.name_prefix}-ws-mem-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ws_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ws_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ws_scaling_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 3
      metric_interval_lower_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "ws_mem_high" {
  alarm_name          = "${var.name_prefix}-ws-mem-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 7
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Memory > 85% for 7 minutes on ws_service"

  dimensions = {
    ClusterName = aws_ecs_cluster.ecs_cluster_1.name
    ServiceName = aws_ecs_service.ws_service.name
  }

  alarm_actions = [aws_appautoscaling_policy.ws_mem_scale_up.arn]
}