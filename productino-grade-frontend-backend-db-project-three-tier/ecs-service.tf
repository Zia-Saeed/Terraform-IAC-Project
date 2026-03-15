# ------------------------------------------------------------------------------
# Security Group for ECS Service Tasks
# ------------------------------------------------------------------------------
# This security group controls traffic to and from the running containers.
# It is designed to be private, allowing traffic only from the ALB.
resource "aws_security_group" "sg_ecs_service" {
  vpc_id = aws_vpc.vpc_1.id
  name   = "security-group-for-ecs-service"

  # Ingress Rule: Allow backend traffic (Port 3000) ONLY from the ALB Security Group
  ingress {
    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"
    
    # SECURITY BEST PRACTICE:
    # Instead of opening to 0.0.0.0/0, we reference the ALB security group.
    # This ensures only the ALB can talk to the containers.
    # cidr_blocks = ["0.0.0.0/0"] 
    security_groups = [aws_security_group.sg_alb.id]
  }

  # Egress Rule: Allow all outbound traffic
  # Required for containers to pull images, reach external APIs, or send logs
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.resource_name}-sg-for-ecs-service"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# ECS Service Definition
# ------------------------------------------------------------------------------
# Defines the service that maintains the desired number of tasks (containers)
# running the backend application.
resource "aws_ecs_service" "be_service" {
  # NOTE: Typo "esc" should likely be "ecs" for consistency
  name            = "esc-be-service" 
  cluster         = aws_ecs_cluster.ecs_nginx_cluster.id
  # NOTE: Typo "defination" should likely be "definition"
  task_definition = aws_ecs_task_definition.aws_be_task_defination.id
  
  desired_count = 2       # Run 2 tasks for high availability
  launch_type   = "FARGATE" # Serverless compute engine

  # Network Configuration
  network_configuration {
    # Deploy into private subnets for security
    subnets = [for subnet in aws_subnet.pri_subnets : subnet.id]
    
    # Attach the security group defined above
    security_groups = [aws_security_group.sg_ecs_service.id]
    
    # No public IP assigned. Traffic flows via NAT Gateway (egress) and ALB (ingress)
    assign_public_ip = false
  }

  # Load Balancer Integration
  # Registers the service tasks with the ALB Target Group
  load_balancer {
    target_group_arn = aws_alb_target_group.nginx-alb-tg.arn
    container_port   = 3000
    container_name   = "be-app"
  }

  # Enables AWS Systems Manager (SSM) Execute Command for debugging into containers
  enable_execute_command = true

  # Explicit dependencies to ensure resources exist before service creation
  depends_on = [
    aws_alb_listener.alb-lst,
    aws_s3_bucket.be_s3_bucket
  ]
}
