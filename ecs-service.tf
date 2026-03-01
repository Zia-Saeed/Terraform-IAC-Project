resource "aws_security_group" "sg_ecs_service" {
  vpc_id = aws_vpc.vpc_1.id
  name = "security-group-for-ecs-service"
  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    # cidr_blocks = [ "0.0.0.0/0" ]
    security_groups = [ aws_security_group.sg_alb.id ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = {
    Name = "${var.resource_name}-sg-for-ecs-service"
    Environment = var.env_name
    Project = var.project_name
  }
}
resource "aws_ecs_service" "be_service" {
  name = "esc-be-service"
  cluster = aws_ecs_cluster.ecs_nginx_cluster.id
  task_definition = aws_ecs_task_definition.aws_be_task_defination.id
  desired_count = 2
  launch_type = "FARGATE"
  network_configuration {
    subnets = [for subnet in aws_subnet.pri_subnets: subnet.id]
    security_groups = [ aws_security_group.sg_ecs_service.id ]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_alb_target_group.nginx-alb-tg.arn
    container_port = 3000
    container_name = "be-app"
  }
  enable_execute_command = true
  depends_on = [ aws_alb_listener.alb-lst, aws_s3_bucket.be_s3_bucket]
}
