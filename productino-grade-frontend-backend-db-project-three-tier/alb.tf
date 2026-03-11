#
resource "aws_security_group" "sg_alb" {
    vpc_id = aws_vpc.vpc_1.id
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }
    tags = {
      Name = "${var.resource_name}-nginx-alb"
      Environment = var.env_name
      Project = var.project_name
    }
}
#
resource "aws_lb" "nginx-lb" {
  name = "nginx-alb"
  security_groups = [ aws_security_group.sg_alb.id ]
  load_balancer_type = "application"
  internal = false
  subnets = [ for subnet in aws_subnet.pub_subnets : subnet.id ]
  tags = {
    Name = "${var.resource_name}-nginx-alb"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_alb_target_group" "nginx-alb-tg" {
  name = "ngnix-alb-tg"
  target_type = "ip"
  vpc_id = aws_vpc.vpc_1.id
  port = 3000
  protocol = "HTTP"
  health_check {
    interval = 60
    timeout = 10
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher = 200
    path = "/health"
  }
  tags = {
    Name = "${var.resource_name}-nginx-alb-tg"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_alb_listener" "alb-lst" {
  load_balancer_arn = aws_lb.nginx-lb.arn
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_alb_target_group.nginx-alb-tg.arn
    type = "forward"
  }
  tags = {
    Name = "${var.resource_name}-nginx-alb-lst"
    Environment = var.env_name
    Project = var.project_name
  }
}
