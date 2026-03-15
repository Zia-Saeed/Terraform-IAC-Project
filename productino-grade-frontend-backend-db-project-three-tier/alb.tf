# ------------------------------------------------------------------------------
# Security Group for the ALB
# ------------------------------------------------------------------------------
# Allows inbound HTTP traffic from the internet and allows the ALB 
# to communicate outbound to the target instances.
resource "aws_security_group" "sg_alb" {
  vpc_id = aws_vpc.vpc_1.id # Associates SG with the main VPC

  # Ingress Rule: Allow HTTP (Port 80) from anywhere (Internet-facing)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to the public internet
  }

  # Egress Rule: Allow all outbound traffic (Required for ALB to reach targets & AWS APIs)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 indicates all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.resource_name}-nginx-alb"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# Application Load Balancer
# ------------------------------------------------------------------------------
# Creates the actual LB resource distributed across public subnets.
resource "aws_lb" "nginx-lb" {
  name               = "nginx-alb"
  security_groups    = [aws_security_group.sg_alb.id] # Attach the SG defined above
  load_balancer_type = "application"                  # Layer 7 LB (HTTP/HTTPS)
  internal           = false                          # false = Internet-facing, true = Internal only
  
  # Deploy the LB across all available public subnets for high availability
  subnets = [for subnet in aws_subnet.pub_subnets : subnet.id]

  tags = {
    Name        = "${var.resource_name}-nginx-alb"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# Target Group
# ------------------------------------------------------------------------------
# Defines the backend targets (IPs) that will receive traffic from the ALB.
# Note: 'aws_alb_target_group' is a legacy alias for 'aws_lb_target_group'.
resource "aws_alb_target_group" "nginx-alb-tg" {
  name        = "ngnix-alb-tg" 
  target_type = "ip"      # Targets are registered by IP (common for Fargate or EC2)
  vpc_id      = aws_vpc.vpc_1.id
  port        = 3000      # The port the backend application listens on
  protocol    = "HTTP"

  # Health Check Configuration
  health_check {
    interval            = 60  # Seconds between checks
    timeout             = 10  # Seconds to wait for a response
    healthy_threshold   = 2   # Consecutive successes required to mark healthy
    unhealthy_threshold = 2   # Consecutive failures required to mark unhealthy
    matcher             = 200 # HTTP code indicating success
    path                = "/health" # Endpoint to ping for health status
  }

  tags = {
    Name        = "${var.resource_name}-nginx-alb-tg"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# ALB Listener
# ------------------------------------------------------------------------------
# Configures the ALB to listen on Port 80 and forward traffic to the Target Group.
# Note: 'aws_alb_listener' is a legacy alias for 'aws_lb_listener'.
resource "aws_alb_listener" "alb-lst" {
  load_balancer_arn = aws_lb.nginx-lb.arn # Attach to the LB defined above
  port              = 80                  # Listener Port (Client -> LB)
  protocol          = "HTTP"

  # Default Action: Forward traffic to the Nginx Target Group
  default_action {
    target_group_arn = aws_alb_target_group.nginx-alb-tg.arn
    type             = "forward"
  }

  tags = {
    Name        = "${var.resource_name}-nginx-alb-lst"
    Environment = var.env_name
    Project     = var.project_name
  }
}
