resource "aws_db_subnet_group" "db_subnet" {
  subnet_ids = aws_subnet.db_subnet[*].id
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-subnet-group"
  })
}
###
resource "aws_db_instance" "zory_db" {
  identifier     = "${var.name_prefix}-db"
  engine         = "postgres"
  engine_version = "18.4"          
  instance_class = "db.t3.small"

  allocated_storage     = 20
  max_allocated_storage = 100       
  storage_type          = "gp3"

  db_name  = "<database-name>"
  username = var.db_uername
  password = var.db_password   
       

  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible = true
  multi_az            = false        

  backup_retention_period = 15
  backup_window            = "03:00-04:00"
  maintenance_window        = "mon:04:30-mon:05:30"

  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = var.db_final_snapshot_name

  storage_encrypted = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-instance"
  })
}