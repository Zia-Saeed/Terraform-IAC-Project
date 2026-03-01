resource "aws_vpc_endpoint" "s3_bucket_endpoint" {
  vpc_id = aws_vpc.vpc_1.id
  vpc_endpoint_type = "Gateway"
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [ aws_route_table.pri_rt.id ]
  tags = {
    Name = "${var.resource_name}-vpc-endpoint-for-s3-bucket"
    Resource = var.resource_name
    Environment = var.env_name
  }
}