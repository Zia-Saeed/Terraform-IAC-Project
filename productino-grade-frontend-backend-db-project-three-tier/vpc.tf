#
resource "aws_vpc" "vpc_1" {
  region = "us-east-1"
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "${var.resource_name}-VPC-1"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_internet_gateway" "ig_1" {
  vpc_id = aws_vpc.vpc_1.id
  depends_on = [ aws_vpc.vpc_1 ]
  tags = {
    Name = "${var.resource_name}-Ig-1"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_subnet" "pub_subnets" {
  vpc_id = aws_vpc.vpc_1.id
  count = length(var.pub_subnets_cidr)
  cidr_block = var.pub_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.resource_name}-public-subnet-${count.index}"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_subnet" "pri_subnets" {
  vpc_id = aws_vpc.vpc_1.id
  count = length(var.pri_subnets_cidr)
  cidr_block = var.pri_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.resource_name}-private-subnet-${count.index}"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    gateway_id = aws_internet_gateway.ig_1.id
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "${var.resource_name}-public-route-table"
    Project = var.project_name
    Environment = var.env_name
  }
}
#
resource "aws_route_table_association" "pub_rt_asc" {
  count = length(aws_subnet.pub_subnets)
  route_table_id = aws_route_table.pub_rt.id
  subnet_id = aws_subnet.pub_subnets[count.index].id
}
#
resource "aws_eip" "eip_1" {
  domain = "vpc"
  depends_on = [ aws_internet_gateway.ig_1 ]
  tags = {
    Name = "${var.resource_name}-eip-1"
  }
}
#
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.eip_1.id
  subnet_id = aws_subnet.pub_subnets[0].id
  tags = {
    Name = "${var.resource_name}-nat-1"
    Project = var.project_name
    Environment = var.env_name
  }
}
#
resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }
  tags = {
    Name = "${var.resource_name}-private-route-table"
    Environment = var.env_name
    Project = var.project_name
  }
}
resource "aws_route_table_association" "pri_rt_asc" {
  count = length(aws_subnet.pri_subnets)
  route_table_id = aws_route_table.pri_rt.id
  subnet_id = aws_subnet.pri_subnets[count.index].id
}
#
resource "aws_subnet" "db_subnets" {
  count = length(var.db_subnets)
  vpc_id = aws_vpc.vpc_1.id
  cidr_block = var.db_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  tags = {
    Name = "${var.resource_name}-db-subnet-${count.index}"
    Project = var.project_name
    Environment = var.env_name
  }
}
# 
resource "aws_route_table" "rt_db" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    gateway_id = "local"
    cidr_block = "192.168.0.0/16"
  }
}
resource "aws_route_table_association" "db_rt_asc" {
  count = length(aws_subnet.db_subnets)
  route_table_id = aws_route_table.pri_rt.id
  subnet_id = aws_subnet.db_subnets[count.index].id
}


