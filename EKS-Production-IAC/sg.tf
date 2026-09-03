resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.vpc_1.id
  egress {
    from_port = 0
    to_port = 0
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "-1"
  }
  ingress {
    from_port = 5432
    to_port = 5432
    cidr_blocks = [ "0.0.0.0/0" ]
    protocol = "tcp"
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}
