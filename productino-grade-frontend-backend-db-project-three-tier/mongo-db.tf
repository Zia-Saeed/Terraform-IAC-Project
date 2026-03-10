#
resource "aws_docdb_subnet_group" "doc_db_subnet" {
  name = "docdb-subnet-group"
  subnet_ids = [for subnet in aws_subnet.db_subnets : subnet.id ]
  tags = {
    Name = "${var.resource_name}-mongo-db-subnet"
  }
  # depends_on = [ aws_vpc.vpc_1 ]
}
#
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.vpc_1.id
  ingress {
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    security_groups = [ aws_security_group.sg_ecs_service.id ]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  tags = {
    Name = "${var.resource_name}-db-sg"
    Environment = var.env_name
    Project = var.project_name
  }
}
#
resource "aws_docdb_cluster" "doc_db_cluster" {
  cluster_identifier = var.db_cluster_identifier
  engine = "docdb"
  master_username = var.db_username
  master_password = var.db_password
  db_subnet_group_name = aws_docdb_subnet_group.doc_db_subnet.name
  vpc_security_group_ids = [ aws_security_group.db_sg.id ]
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"
  skip_final_snapshot = true
  # deletion_protection = true

}
#
resource "aws_docdb_cluster_instance" "docdb_instance" {
  identifier = var.db_instance
  cluster_identifier = aws_docdb_cluster.doc_db_cluster.id
  instance_class = "db.t3.medium"
  # depends_on = [ aws_ecs_service.be_service ]
  
}