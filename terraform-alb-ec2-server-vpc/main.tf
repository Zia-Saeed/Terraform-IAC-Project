#
resource "aws_vpc" "vpc_1" {
  cidr_block = "192.168.0.0/16"
  region = "us-east-1"
  tags = {
    Name = "${var.resouce_name}-VPC-1"
    Environment = var.environment_name
    Project = var.project_name
  }
}
#
resource "aws_internet_gateway" "ig_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "${var.resouce_name}-ig-1"
    Environment = var.environment_name
    Project = var.resouce_name
  }
}
#
resource "aws_subnet" "pub_sub_1" {
  vpc_id = aws_vpc.vpc_1.id
  cidr_block = var.cidr_block[0]
  availability_zone = "us-east-1a"
  tags = {
    Name = "${var.resouce_name}-pub-sub-1"
    Environment = var.environment_name
    Project = var.project_name
  }
}
#
resource "aws_subnet" "pub_sub_2" {
  cidr_block = var.cidr_block[1]
  vpc_id = aws_vpc.vpc_1.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "${var.resouce_name}-pub-sub-2"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_subnet" "pub_sub_3" {
  cidr_block = var.cidr_block[2]
  vpc_id = aws_vpc.vpc_1.id
  availability_zone = "us-east-1c"
  tags = {
    Name = "${var.resouce_name}-pub-sub-3"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_route_table" "pub_route_1" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig_1.id
  }
  tags = {
    Name = "${var.resouce_name}-pub-route-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_route_table_association" "associate_pub_1" {
  route_table_id = aws_route_table.pub_route_1.id
  subnet_id = aws_subnet.pub_sub_1.id
}
#
resource "aws_route_table_association" "associate_pub_2" {
  route_table_id = aws_route_table.pub_route_1.id
  subnet_id = aws_subnet.pub_sub_2.id
}
#
resource "aws_route_table_association" "associate_pub_3" {
  route_table_id = aws_route_table.pub_route_1.id
  subnet_id = aws_subnet.pub_sub_3.id
}
#
resource "aws_subnet" "pri_sub_1" {
  vpc_id = aws_vpc.vpc_1.id
  cidr_block = var.cidr_block[3]
  availability_zone = "us-east-1a"
  tags = {
    Name = "${var.resouce_name}-pri-subnet-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_subnet" "pri_sub_2" {
  vpc_id = aws_vpc.vpc_1.id
  cidr_block = var.cidr_block[4]
  availability_zone = "us-east-1b"
  tags = {
    Name = "${var.resouce_name}-pri-subnet-2"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_subnet" "pri_sub_3" {
  vpc_id = aws_vpc.vpc_1.id
  cidr_block = var.cidr_block[5]
  availability_zone = "us-east-1c"
  tags = {
    Name = "${var.resouce_name}-pri-subnet-3"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_eip" "eip_1" {
  domain = "vpc"
  tags = {
    Name = "${var.resouce_name}-eip-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_nat_gateway" "nat_1" {
  subnet_id = aws_subnet.pub_sub_1.id
  allocation_id = aws_eip.eip_1.id
  depends_on = [ aws_eip.eip_1 ]
  tags = {
    Name = "${var.resouce_name}-nat-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_route_table" "pir_route_1" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_1.id
  }
  tags = {
    Name = "${var.resouce_name}-pri-route-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_route_table_association" "associate_pri_1" {
 route_table_id = aws_route_table.pir_route_1.id
 subnet_id = aws_subnet.pri_sub_1.id
}
#
resource "aws_route_table_association" "associate_pri_2" {
  route_table_id = aws_route_table.pir_route_1.id
  subnet_id = aws_subnet.pri_sub_2.id
}
#
resource "aws_route_table_association" "associate_pri_3" {
  route_table_id = aws_route_table.pir_route_1.id
  subnet_id = aws_subnet.pri_sub_3.id
}
#
resource "aws_security_group" "sg_for_servers" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = {
    Name = "${var.resouce_name}-sg-for-sever"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_instance" "server_1" {
  ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  security_groups = [ aws_security_group.sg_for_servers.id ]
  associate_public_ip_address = true
  key_name = "corvit-demo-practise"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.pub_sub_1.id
user_data_base64 = base64encode(<<EOF
#!/bin/bash
yum update -y

# Enable nginx repository (important for Amazon Linux 2)
amazon-linux-extras enable nginx1

# Install nginx
yum install -y nginx

# Start and enable nginx
systemctl start nginx
#
systemctl enable nginx

# Set custom web page
echo "HELLO from SERVER 1 (NGINX)" > /usr/share/nginx/html/index.html
EOF
)

  tags = {
    Name = "${var.resouce_name}-server-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_instance" "server_2" {
  ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  security_groups = [ aws_security_group.sg_for_servers.id ]
  instance_type = "t2.micro"
  associate_public_ip_address = true
  subnet_id = aws_subnet.pub_sub_2.id
  key_name = "corvit-demo-practise"
user_data_base64 = base64encode(<<EOF
#!/bin/bash
yum update -y

# Enable nginx repository (important for Amazon Linux 2)
amazon-linux-extras enable nginx1

# Install nginx
yum install -y nginx

# Start and enable nginx
systemctl start nginx
# enable nginx 
systemctl enable nginx

# Set custom web page
echo "HELLO from SERVER 2 (NGINX)" > /usr/share/nginx/html/index.html
EOF
)
  tags = {
    Name = "${var.resouce_name}-server-2"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_lb_target_group" "al_target_group_1" {
  vpc_id = aws_vpc.vpc_1.id
  port = 80
  protocol = "HTTP"
  name = "${var.resouce_name}-alb-target-group-1"
  health_check {
    interval = 40
    timeout = 10
    healthy_threshold = 3
    unhealthy_threshold = 3
    path = "/"
    matcher = 200
  }
}
#
resource "aws_lb_target_group_attachment" "tg_server_1" {
  target_group_arn = aws_lb_target_group.al_target_group_1.arn
  target_id = aws_instance.server_1.id
}
#
resource "aws_lb_target_group_attachment" "tg_server_2" {
  target_group_arn = aws_lb_target_group.al_target_group_1.arn
  target_id = aws_instance.server_2.id
}
#
resource "aws_security_group" "sg_for_alb" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = {
    Name = "${var.resouce_name}-alb-1"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_lb" "alb_for_servers" {
  name = "${var.resouce_name}-alb-for-ec2-server"
  subnets = [ aws_subnet.pub_sub_1.id, aws_subnet.pub_sub_2.id ]
  load_balancer_type = "application"
  internal = false
  security_groups = [ aws_security_group.sg_for_alb.id ]
  depends_on = [ aws_lb_target_group.al_target_group_1 ]
  tags = {
    Name = "${var.resouce_name}-applicatoin-alb-for-servers"
    Environment = var.environment_name
    Project = var.project_name
  }
}
#
resource "aws_alb_listener" "alb_listener" {
  port = 80
  protocol = "HTTP"
  load_balancer_arn = aws_lb.alb_for_servers.arn
  default_action {
    target_group_arn = aws_lb_target_group.al_target_group_1.arn
    type = "forward"
  }
  tags = {
    Name = "${var.resouce_name}-alb1-listener"
    Environment = var.environment_name
    Project = var.project_name
  }
}
