####
resource "aws_vpc" "vpc_1" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(locals.commom_tags, {
    Name = "${var.name_prefix}-vpc1"
  })
}
####
resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
  depends_on = [ aws_vpc.vpc_1.id ]
}
####
resource "aws_subnet" "public_subnets" {
  vpc_id = aws_vpc.vpc_1.id
  count = length(var.availability_zones)
  availability_zone = var.availability_zones[count.index]
  cidr_block = var.pub_cidr_value[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-subnet-${count.index}"
  })
}
####
resource "aws_subnet" "private_subnets" {
  vpc_id = aws_vpc.vpc_1.id
  count = length(var.availability_zones)
  availability_zone = var.availability_zones[count.index]
  cidr_block = var.pri_cidr_value[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-private-subnet-${count.index}"
  })
}
####
resource "aws_subnet" "db_subnets" {
  vpc_id = aws_vpc.vpc_1.id
  count = length(var.availability_zones)
  availability_zone = var.availability_zones[count.index]
  cidr_block = var.db_cidr_value[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-subnet-${count.index}"
  })
}
####

####
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_1.id
  
  
}