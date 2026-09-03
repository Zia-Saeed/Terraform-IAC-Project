####
resource "aws_db_subnet_group" "db_sg" {
  name = "aurora-postgres-prod-subnet-group"
  subnet_ids = aws_subnet.db_subnets[*].id
  description = "Database Subnet Group Ids"
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-auro-db-subnet-group"
  })
}
####
resource "aws_kms_key" "db_key" {
  deletion_window_in_days = 30
  enable_key_rotation = true
  description = "Database Encryption Key"
}
####
resource "aws_rds_cluster_parameter_group" "rds_pr_gr" {
  family = "aurora-postgresql16"
  name = "aurora-pg16-prod-cluster-pg"
  description = "paramter group or prod db for ssl and logs"
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
  parameter {
    name  = "log_connections"
    value = "1"
  }
  parameter {
    name  = "log_disconnections"
    value = "1"
  }
}
####
resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier = "${var.name_prefix}-prod-db-micro-services"
  engine_mode = var.db_engine_mode
  engine_version = var.db_engine_version
  engine = var.db_engine
  database_name = var.db_name
  master_username = var.db_username
  master_password = var.db_password
  db_subnet_group_name = aws_db_subnet_group.db_sg.name
  vpc_security_group_ids = [ aws_security_group.db_sg.id ]
  ####
  storage_encrypted = true
  kms_key_id = aws_kms_key.db_key.id
  ####
  deletion_protection = false
  skip_final_snapshot = true
  ####
  backtrack_window = 30
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-auraro-cluster"
  })
}

####
resource "aws_rds_cluster_instance" "db_instance" {
  count = 3 
  identifier = "${var.name_prefix}-aurora-postgres-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  engine = aws_rds_cluster.aurora_cluster.engine
  instance_class = "db.t4g.micro"
  engine_version = aws_rds_cluster.aurora_cluster.engine_version
  ####
  publicly_accessible = true
  auto_minor_version_upgrade = true
  ####
  performance_insights_enabled = true
  performance_insights_kms_key_id = aws_kms_key.db_key.id
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn
  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aurora-rds-instance-${count.index}"
  })
}

####
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "aurora-postgres-prod-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}
####
resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring_attach" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}