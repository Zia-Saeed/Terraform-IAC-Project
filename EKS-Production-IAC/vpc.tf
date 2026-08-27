resource "aws_vpc" "vpc_1" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = merge(locals.commom_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}