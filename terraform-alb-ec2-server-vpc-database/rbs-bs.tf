#
resource "aws_security_group" "sg_for_db" {
  vpc_id = aws_vpc.vpc_1.id
  name = "aws-database-sg-group"
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    security_groups = [ aws_security_group.sg_for_servers.id ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}
#
resource "aws_db_subnet_group" "rds_subnets" {
  name = "rds-subnet-group"
  subnet_ids = [ aws_subnet.rds_subnet_1.id, aws_subnet.rds_subnet_2.id ]
  tags = {
    Name = "${var.resouce_name}-rds-subnet-group"
    Project = var.project_name
    Environment = var.environment_name
  }
}
#
resource "aws_db_instance" "my_db_instance" {
  instance_class = "db.t3.micro"
  identifier = "demo-rds"
  db_subnet_group_name = aws_db_subnet_group.rds_subnets.name
  storage_type = "gp3"
  allocated_storage = 20
  engine = "postgres"
  engine_version = "16.12"
  username = var.db_username
  password = var.db_password
  vpc_security_group_ids = [ aws_security_group.sg_for_db.id ]
  publicly_accessible = false
  multi_az = false
  backup_retention_period = 7
#   skip_final_snapshot = false
#   final_snapshot_identifier = "kljasdlkfj-asdlkfnlkasd-afdaslkdjf"
#   deletion_protection = true
  depends_on = [ aws_vpc.vpc_1, aws_internet_gateway.ig_1, aws_db_subnet_group.rds_subnets, ]
}