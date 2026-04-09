#
resource "aws_vpc" "vpc1" {
  cidr_block = var.vpc1_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(local.tags, {
    Name = "${var.resource_name}-VPC1"
  })
}
resource "aws_internet_gateway" "igw1" {
  vpc_id = aws_vpc.vpc1.id
}
#
resource "aws_subnet" "subnets_vpc1" {
  count = length(var.vpc1_subnets)
  vpc_id = aws_vpc.vpc1.id
  cidr_block = var.vpc1_subnets[count.index]
  availability_zone = var.availability_zone[count.index]
  tags = merge(local.tags, {
    Name = "${var.resource_name}-VPC1-Subnet${count.index}"
  })
}
#
resource "aws_route_table" "internal_route_table_for_vpc1" {
  vpc_id = aws_vpc.vpc1.id
  tags = local.tags
  route {
    cidr_block = aws_vpc.vpc2.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering_1.id
    # gateway_id = aws_internet_gateway.igw1.id
  }
}
#
resource "aws_route_table_association" "internal_association" {
  count = 2
  route_table_id = aws_route_table.internal_route_table_for_vpc1.id
  subnet_id = aws_subnet.subnets_vpc1[count.index].id
}
resource "aws_instance" "vpc1_instance" {
  subnet_id = aws_subnet.subnets_vpc1[0].id
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t3.micro"
  security_groups = [ aws_security_group.sg_1.id ]
  associate_public_ip_address = true
  key_name = "corvit-demo-practise"
  user_data = <<EOF
    #!/bin/bash
    yum update -y
    yum install nginx -y
    systemctl start nginx
    systemctl enable nginx
  EOF
  

  tags = {
    Name = "HelloWorld"
  }
}

#
resource "aws_vpc" "vpc2" {
  cidr_block = var.vpc2_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(local.tags,{
    Name = "${var.resource_name}-VPC2"
  })
}
#
resource "aws_internet_gateway" "igw2" {
  vpc_id = aws_vpc.vpc2.id
}
#
resource "aws_subnet" "subnets_vpc2" {
  count = length(var.vpc2_subnets)
  vpc_id = aws_vpc.vpc2.id
  cidr_block = var.vpc2_subnets[count.index]
  availability_zone = var.availability_zone[count.index]
  tags = merge(local.tags,{
    Name = "${var.resource_name}-VPC2-Subnets"
  })
}
#
resource "aws_route_table" "internal_route_table_for_vpc2" {
  vpc_id = aws_vpc.vpc2.id
  route {
    cidr_block = aws_vpc.vpc1.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peering_1.id
    # gateway_id = aws_internet_gateway.igw2.id
  }
  tags = local.tags
}
#
resource "aws_route_table_association" "internal_association2" {
  count = 2
  route_table_id = aws_route_table.internal_route_table_for_vpc2.id
  subnet_id = aws_subnet.subnets_vpc2[count.index].id
}
#
resource "aws_instance" "vpc2_instance" {
  subnet_id = aws_subnet.subnets_vpc2[0].id
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t3.micro"
  security_groups = [ aws_security_group.sg_2.id ]
  associate_public_ip_address = true
  key_name = "corvit-demo-practise"
  user_data = <<EOF
    #!/bin/bash
    yum update -y
    yum install nginx -y
    systemctl start nginx
    systemctl enable nginx
  EOF
  

  tags = {
    Name = "HelloWorld"
  }
}
