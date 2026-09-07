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
    # cidr_blocks = [ "0.0.0.0/0" ]
    security_groups = [ aws_security_group.cluster_and_nodes_sg.id ]
    protocol = "tcp"
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-sg"
  })
}
###
resource "aws_security_group" "cluster_and_nodes_sg" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "59.103.46.105/32" ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [ "59.103.46.105/32" ]
  }
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-cluster-sg"
  })
}
###

