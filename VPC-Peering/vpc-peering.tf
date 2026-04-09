resource "aws_vpc_peering_connection" "peering_1" {
  vpc_id = aws_vpc.vpc1.id
  peer_vpc_id = aws_vpc.vpc2.id
  auto_accept = true
  tags = local.tags
}
