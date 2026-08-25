resource "aws_security_group" "be_sg" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    security_groups = [ 
        aws_security_group.alb_sg.id
    ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-be-sg"
  })
}
##
resource "aws_security_group" "web_soc_sg" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 8001
    to_port = 8001
    protocol = "tcp"
    security_groups = [ aws_security_group.alb_sg.id ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-web-soc-sg"
  })
}
#
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 80
    to_port = 80
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "tcp"
  }
  ingress {
    from_port = 443
    to_port = 443
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "tcp"
  }
  egress {
    from_port = 0
    to_port = 0
    cidr_blocks = [ 
        "0.0.0.0/0"
    ]
    protocol = "-1"
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}
##
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 5432
    to_port = 5432
    cidr_blocks = [ "0.0.0.0/0" ]
    # security_groups = [ 
    #     aws_security_group.be_sg.id, 
    #     aws_security_group.web_soc_sg.id
    # ]4322
    protocol = "tcp"
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ 
        "0.0.0.0/0"
    ]
  }
}
#
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Security Group for private VPC Interface Endpoints"
  vpc_id      = aws_vpc.vpc_1.id


  ingress {
    description     = "Allow HTTPS from ECS Tasks"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.web_soc_sg.id, aws_security_group.be_sg.id] 
  }
  

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpc-endpoints-sg"
  })
}