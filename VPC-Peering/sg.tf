resource "aws_security_group" "sg_1" {
  vpc_id = aws_vpc.vpc1.id
  ingress {
    from_port = 0
    to_port = 0
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    # security_groups = [ aws_security_group.sg_2 ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
#
resource "aws_security_group" "sg_2" {
  vpc_id = aws_vpc.vpc2.id
  ingress {
    from_port = 0
    to_port = 0
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    # security_groups = [ aws_security_group.sg_1 ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
