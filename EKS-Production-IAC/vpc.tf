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
  depends_on = [ aws_vpc.vpc_1 ]
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
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-route-table"
  })
}
###
resource "aws_route_table_association" "pub_rt_asc" {
  count = length(var.pub_cidr_value)
  route_table_id = aws_route_table.pub_rt.id
  subnet_id = aws_subnet.public_subnets[count.index].id
}
####
resource "aws_eip" "nat_ips" {
  count = length(var.availability_zones)
  domain = "vpc"
  depends_on = [ aws_internet_gateway.igw_1 ]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-nat-${var.availability_zones[count.index]}"
  })
}
####
resource "aws_nat_gateway" "nat_gwts" {
  count = length(var.availability_zones)
  allocation_id = aws_eip.nat_ips[count.index].id
  subnet_id = aws_subnet.public_subnets[count.index].id
}
####
resource "aws_route_table" "pri_rt" {
  count = length(var.availability_zones)
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gwts[count.index].id
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-pri-rt-${var.availability_zones[count.index]}"
  })
}
####
resource "aws_route_table_association" "pri_rt_asc" {
  count = length(var.availability_zones)
  route_table_id = aws_route_table.pri_rt[count.index].id
  subnet_id = aws_subnet.private_subnets[count.index].id
}
###
resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.vpc_1.id
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-rt"
  })
}
####
resource "aws_route_table_association" "db_rt_asc" {
  count = length(var.availability_zones)
  route_table_id = aws_route_table.db_rt.id
  subnet_id = aws_subnet.db_subnets[count.index].id
}
####
