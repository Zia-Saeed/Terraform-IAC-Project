# AWS VPC creation
resource "aws_vpc" "custom_vpc_1" {
  cidr_block = var.vpc_cidr
  region = var.region_value
  
  tags = {
    Name = "${var.resource_name}-VPC-1"
    Project = var.project_name
    Environment = var.environment_name
  }
} 
# VPC endpoint for s3 bucket 
resource "aws_vpc_endpoint" "s3_endpoints" {
  vpc_id = aws_vpc.custom_vpc_1.id
  service_name = "com.amazonaws.${var.region_value}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [ aws_route_table.route_table_2.id ]
}
# Internet gateway
resource "aws_internet_gateway" "ig1" {
  vpc_id = aws_vpc.custom_vpc_1.id

}
# AWS Public Subnets
resource "aws_subnet" "public_subnet_1" {
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.custom_vpc_1.id
  tags = {
    Name = "public-subnet-1"
  }
}
# Public Route Table
resource "aws_route_table" "route_table_1" {
  vpc_id = aws_vpc.custom_vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig1.id
  }
  tags = {
    Name = "public-route-table"
  }
}
# AWS Public Subnets Association with Public Route Table
resource "aws_route_table_association" "pub_route_table1_association" {
  subnet_id = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.route_table_1.id
}
# AWS Private Subnet
resource "aws_subnet" "private_subet_1" {
  cidr_block = "10.0.2.0/24"
  vpc_id = aws_vpc.custom_vpc_1.id
  tags = {
    Name = "${var.resource_name}-private_subnet-1"
  }
}
# Elastic Ip for Natgatway
resource "aws_eip" "elastic_ip_1" {
  domain = "vpc"
}
# Natgateway for Private subnets
resource "aws_nat_gateway" "natgateway_1" {
  allocation_id = aws_eip.elastic_ip_1.id
  subnet_id = aws_subnet.public_subnet_1.id
}
# Private Route Table
resource "aws_route_table" "route_table_2" {
  vpc_id = aws_vpc.custom_vpc_1.id
  route {
    gateway_id = aws_nat_gateway.natgateway_1.id
    cidr_block = "0.0.0.0/0"
  }
  tags = {
    Name = "private-route-table"
  }
}
# Private Subnet association with Private Route Table
resource "aws_route_table_association" "pri_route_table_association" {
  subnet_id = aws_subnet.private_subet_1.id
  route_table_id = aws_route_table.route_table_2.id
}

#S3 bucket Creation only Accessible by VPC Private Subnets
resource "aws_s3_bucket" "bucket_1" {
  region = var.region_value
  bucket = "bucket-for-vpc-gateway-demo-${var.resource_name}"
}
# Bucket Policy for resouce in private subnet to acess the buckets
resource "aws_s3_bucket_policy" "bucket_policy_gateway" {
    bucket = aws_s3_bucket.bucket_1.id
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Principal = "*"
        Action   = "s3:*"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.bucket_1.id}",
          "arn:aws:s3:::${aws_s3_bucket.bucket_1.id}/*"
        ]
        Condition = {
          StringNotEquals = {
            "aws:SourceVpce" = aws_vpc_endpoint.s3_endpoints.id
          }
        }
      }
    ]
  }) 
}
