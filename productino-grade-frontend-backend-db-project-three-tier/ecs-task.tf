# This task definition is referenced by the ECS Service to launch containers.
# ==============================================================================

resource "aws_ecs_task_definition" "aws_be_task_defination" {
  # NOTE: Typo "defination" should be "definition" for consistency
  
  # Family groups different revisions of the same task definition together
  family = "be-express-app"
  
  # awsvpc mode gives each task its own elastic network interface (ENI)
  # Required for Fargate launch type
  network_mode = "awsvpc"
  
  # Specifies compatibility requirements - Fargate requires this field
  requires_compatibilities = ["FARGATE"]
  
  # CPU units for the task (2048 = 2 vCPUs)
  # Must be one of the valid Fargate CPU/memory combinations
  cpu = "2048"
  
  # Memory in MiB for the task (4096 = 4 GB)
  # Must match a valid Fargate configuration pair with the CPU value
  memory = "4096"
  
  # IAM role that allows ECS agent to pull images and send logs to CloudWatch
  execution_role_arn = aws_iam_role.ecs_task_exec_role.arn
  
  # IAM role that the application container assumes to access AWS services
  # (e.g., S3, DynamoDB) - follows principle of least privilege
  task_role_arn = aws_iam_role.ecs_task_role.arn
  
  # Container definitions in JSON format (using jsonencode for HCL2 compatibility)
  container_definitions = jsonencode([
    {
      name              = "be-app"
      # WARNING: Using 'latest' tag is not recommended for production
      # Use immutable image tags (e.g., SHA digest or semantic version) for reproducibility
      image   = "825765392987.dkr.ecr.us-east-1.amazonaws.com/backend/product-service:latest"
      essential = true  # If this container fails, the entire task fails
      
      # Resource allocation for this specific container (can be less than task total)
      cpu    = 2048
      memory = 4096
      
      # Logging configuration: sends stdout/stderr to CloudWatch Logs
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.be_cloud_logs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"  # Creates log streams like: ecs/be-app/<task-id>
        }
      }
      
      # Environment variables injected into the container at runtime
      environment = [
        {
          name  = "NODE_ENV"
          value = "development"  # WARNING: Consider using "production" for prod environments
        },
        
        # ----------------------------------------------------------------------------
        # MongoDB Connection String Options (Commented Examples)
        # ----------------------------------------------------------------------------
        # Option 1: Basic TLS connection (commented out)
        # {
        #     name = "MONGO_URI"
        #     value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster_instance.docdb_instance.endpoint}:27017/crud_db?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
        # },
        
        # Option 2: TLS with CA certificate for DocumentDB (commented out)
        # {
        #     name  = "MONGO_URI"
        #     value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster_instance.docdb_instance.endpoint}:27017/crud_db?tls=true&tlsCAFile=/app/certs/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
        # },
        
        # Option 3: Active connection with SCRAM-SHA-1 authentication (CURRENTLY ACTIVE)
        {
          name  = "MONGO_URI"
          # SECURITY NOTE: Credentials are interpolated from Terraform variables.
          # Ensure var.db_username and var.db_password are passed securely (e.g., via AWS Secrets Manager)
          # and never committed to version control in plaintext.
          value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster_instance.docdb_instance.endpoint}:27017/crud_db?tls=true&tlsCAFile=/app/certs/global-bundle.pem&authSource=admin&authMechanism=SCRAM-SHA-1&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
        },
        
        # CORS configuration for API security
        {
          name  = "CORS_ORIGINS"
          value = "http://localhost:3000,http://localhost:5173"  # Update for production domains
        },
        
        # Rate limiting configuration (express-rate-limit middleware)
        {
          name  = "RATE_LIMIT_WINDOW_MS"
          value = "900000"  # 15 minutes in milliseconds
        },
        {
          name  = "RATE_LIMIT_MAX"
          value = "100"     # Max 100 requests per window per IP
        },
        
        # Application versioning for API routing/compatibility
        {
          name  = "API_VERSION"
          value = "v1"
        },
        
        # AWS configuration for S3 integration
        {
          name  = "AWS_REGION"
          value = "us-east-1"
        },
        {
          name  = "S3_BUCKET_NAME"
          value = var.s3_bucket_name  # Injected from Terraform variable
        }
      ]
      
      # Port mappings: exposes container port to the task's ENI
      portMappings = [
        {
          containerPort = 3000  # Port the Express app listens on inside container
          hostPort      = 3000  # Port on the ENI (must match for awsvpc mode)
          protocol      = "tcp"
        }
      ]
    }
  ])
  
  # Explicit dependencies (currently commented out)
  # Uncomment if you need to ensure these resources exist before task definition creation:
  # depends_on = [
  #   aws_docdb_cluster.doc_db-cluster,
  #   aws_docdb_cluster_instance.docdb_instance,
  #   aws_s3_bucket.be_s3_bucket
  # ]
}

