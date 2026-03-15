# ==============================================================================
# Amazon DocumentDB (MongoDB-Compatible) Cluster Configuration
# ==============================================================================
# This file provisions a managed DocumentDB cluster with associated subnet 
# group and security group. DocumentDB provides MongoDB wire-protocol 
# compatibility while offering AWS-managed scalability, backups, and high 
# availability for the backend application's database layer.
# ==============================================================================

# ------------------------------------------------------------------------------
# DocumentDB Subnet Group
# ------------------------------------------------------------------------------
# Defines which subnets the DocumentDB cluster can deploy into.
# Best practice: Use private subnets in multiple AZs for high availability.
resource "aws_docdb_subnet_group" "doc_db_subnet" {
  name       = "docdb-subnet-group"
  
  # Reference database subnets (typically private subnets dedicated to data tier)
  subnet_ids = [for subnet in aws_subnet.db_subnets : subnet.id]
  
  tags = {
    Name = "${var.resource_name}-mongo-db-subnet"
  }
  
  # Optional: Explicit dependency on VPC (usually implicit via subnet_ids)
  # depends_on = [aws_vpc.vpc_1]
}

# ------------------------------------------------------------------------------
# Security Group for DocumentDB
# ------------------------------------------------------------------------------
# Controls network access to the DocumentDB cluster.
# Follows principle of least privilege: ONLY the ECS service SG can connect.
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.vpc_1.id
  name   = "${var.resource_name}-db-sg"  # Added name for easier identification

  # Ingress Rule: Allow MongoDB default port (27017) ONLY from ECS service SG
  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    # SECURITY: Reference ECS service security group instead of CIDR block
    # This ensures only containers in the ECS service can reach the database
    security_groups = [aws_security_group.sg_ecs_service.id]
  }

  # Egress Rule: Allow all outbound traffic
  # Required for database to perform internal AWS operations, patches, backups
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.resource_name}-db-sg"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# DocumentDB Cluster (Primary Resource)
# ------------------------------------------------------------------------------
# Defines the managed cluster configuration: credentials, backups, networking.
# This is a multi-AZ cluster by default when deployed across multiple subnets.
resource "aws_docdb_cluster" "doc_db_cluster" {
  cluster_identifier = var.db_cluster_identifier
  
  # Engine type: DocumentDB (MongoDB 4.0 or 5.0 compatible)
  engine = "docdb"
  
  # ⚠️  SECURITY WARNING: Hardcoded credentials in Terraform state
  # BEST PRACTICE: Use AWS Secrets Manager or SSM Parameter Store instead
  # Example: master_password = data.aws_secretsmanager_secret_version.db_password.secret_string
  master_username = var.db_username
  master_password = var.db_password
  
  # Networking configuration
  db_subnet_group_name   = aws_docdb_subnet_group.doc_db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  # Backup Configuration
  backup_retention_period = 7               # Retain automated backups for 7 days
  preferred_backup_window = "03:00-04:00"   # Backup during low-traffic window (UTC)
  
  # Lifecycle Management
  skip_final_snapshot = true  # ⚠️  WARNING: Set to false in production to retain final backup on destroy
  # deletion_protection = true  # ✅  RECOMMENDED: Enable to prevent accidental cluster deletion
  
  # Optional enhancements (uncomment as needed):
  # storage_encrypted   = true                      # Encrypt data at rest (recommended)
  # kms_key_id         = aws_kms_key.docdb.arn     # Use customer-managed KMS key
  # port               = 27017                      # Explicitly set port (default: 27017)
  # apply_immediately  = true                       # Apply changes immediately vs. maintenance window
}

# ------------------------------------------------------------------------------
# DocumentDB Cluster Instance (Compute Node)
# ------------------------------------------------------------------------------
# Defines the individual instance(s) that provide compute capacity for the cluster.
# DocumentDB separates storage (cluster) from compute (instances) for scalability.
resource "aws_docdb_cluster_instance" "docdb_instance" {
  identifier = var.db_instance
  
  # Reference the parent cluster defined above
  cluster_identifier = aws_docdb_cluster.doc_db_cluster.id
  
  # Instance class: db.t3.medium (2 vCPU, 4 GiB RAM)
  # Choose based on workload: db.r5/large for memory-intensive, db.c5 for CPU-intensive
  # See: https://docs.aws.amazon.com/documentdb/latest/developerguide/db-instance-classes.html
  instance_class = "db.t3.medium"
  
  # Optional: Explicit dependency if application deployment should wait for DB readiness
  # depends_on = [aws_ecs_service.be_service]
  
  # Optional enhancements (uncomment as needed):
  # auto_minor_version_upgrade = true   # Auto-apply minor engine patches (recommended)
  # apply_immediately          = true   # Apply changes immediately
  # promotion_tier             = 1      # For read replicas: lower = promoted first during failover
}

# ==============================================================================
# Architecture & Best Practices Summary
# ==============================================================================
# 
# ┌─────────────────────────────────────────────────────────┐
# │ Network Topology                                          │
# │                                                           │
# │  ┌─────────────┐     ┌─────────────┐                    │
# │  │ Public Subnet│     │Private Subnet│                   │
# │  │ - ALB        │────▶│ - ECS Tasks  │                   │
# │  └─────────────┘     │ - DocumentDB │◀── Security Group │
# │                      └─────────────┘    (ECS SG only)   │
# └─────────────────────────────────────────────────────────┘
#
# 🔐 Security Recommendations:
# • Use AWS Secrets Manager for db_password (avoid plaintext in state)
# • Enable deletion_protection = true in production
# • Set skip_final_snapshot = false to retain backup on destroy
# • Enable storage_encrypted = true with KMS for data-at-rest encryption
# • Rotate credentials regularly via Secrets Manager rotation
#
# 📈 Scaling Recommendations:
# • Add read replicas: Create additional aws_docdb_cluster_instance resources
# • Monitor CloudWatch metrics: CPUUtilization, DatabaseConnections, FreeableMemory
# • Use parameter groups for fine-tuned MongoDB-compatible settings
#
# 💰 Cost Considerations:
# • db.t3.medium: ~$0.10/hour per instance (us-east-1, on-demand)
# • Backup storage beyond retention period incurs additional charges
# • Consider Reserved Instances for long-running production clusters
# ==============================================================================
