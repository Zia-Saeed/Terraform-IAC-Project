#
resource "aws_vpc" "vpc_1" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-VPC-1"
  })
}
#
resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-IGW"
  })
}
#
resource "aws_subnet" "pub_subnets" {
  count = length(var.public_subnet_group_cidr)
  vpc_id = aws_vpc.vpc_1.id
  availability_zone = var.availability_zones[count.index]
  cidr_block = var.public_subnet_group_cidr[count.index]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-subnet-${count.index}"
  })
  
}
#
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }
  tags = merge(local.common_tags, 
    {
        Name = "${var.name_prefix}-pb-rt"
    }
  )
}
#
resource "aws_route_table_association" "pub_rt_asc" {
  count = length(var.public_subnet_group_cidr)
  route_table_id = aws_route_table.pub_rt.id
  subnet_id = aws_subnet.pub_subnets[count.index].id
}
#
resource "aws_subnet" "db_subnet" {
  count = length(var.private_subnet_group_cidr)
  cidr_block = var.private_subnet_group_cidr[count.index]
  availability_zone = var.availability_zones[count.index]
  vpc_id = aws_vpc.vpc_1.id
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db_subnet-${count.index}"
  })
}
#
resource "aws_route_table" "db_rt" {
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_1.id
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-route-table"
  })
}
#
resource "aws_route_table_association" "db_rt_asc" {
  count = length(var.private_subnet_group_cidr)
  subnet_id = aws_subnet.db_subnet[count.index].id
  route_table_id = aws_route_table.db_rt.id
}
#

resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_endpoint_type = "Gateway"
  vpc_id = aws_vpc.vpc_1.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [ 
    aws_route_table.pub_rt.id
   ]
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-s3-gateway-endpoint"
  })
}
#
resource "aws_vpc_endpoint" "ecr_endpoint" {
  vpc_id = aws_vpc.vpc_1.id
  service_name = "com.amazonaws.${var.region}.ecr.api"
  subnet_ids = aws_subnet.pub_subnets[*].id
  security_group_ids = [ aws_security_group.vpc_endpoints_sg.id ]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  
}
###
# ------------------------------------------------------------------------------
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.vpc_1.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.pub_subnets[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ecr-dkr-vpce"
  })
}