# #
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "${var.project_name}-ecs-task-execution-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#         {
#             Effect = "Allow"
#             Principal = {
#             Service = "ecs-tasks.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#         }
#     ]
#   })
#     tags = {
#     Name        = "${var.project_name}-execution-role"
#     Environment = var.env_name
#   }
# }
# #
# resource "aws_iam_role_policy_attachment" "ecs-tsk-exec-policy" {
#   role = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }
# #
# resource "aws_iam_role" "tsk_role" {
#   name =  "${var.project_name}-ecs-s3-policy"
#     assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   tags = {
#     Name        = "${var.project_name}-task-role"
#     Environment = var.env_name
#   }
# }
# #
# resource "aws_iam_policy" "ecs-tsk-role-iam-policy" {
#     name = "${var.project_name}-ecs-s3-policy"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "s3:GetObject",
#           "s3:PutObject"
#         ]
#         Resource = "arn:aws:s3:::bucket-name/*"
#       }
#     ]
#   })
# }
# #
# resource "aws_iam_role_policy_attachment" "name" {
#   role = aws_iam_role.tsk_role.name
#   policy_arn = aws_iam_policy.ecs-tsk-role-iam-policy.arn
# }
#
resource "aws_ecs_task_definition" "aws_be_task_defination" {
  family = "be-express-app"
  network_mode = "awsvpc"
  requires_compatibilities = [ "FARGATE" ]
  cpu = "2048"
  memory = "4096"
  execution_role_arn = aws_iam_role.ecs_task_exec_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn
  
  container_definitions = jsonencode([
    {
        name = "be-app"
        image = "825765392987.dkr.ecr.us-east-1.amazonaws.com/backend/product-service:latest"
        essential = true
        cpu = 2048
        memory = 4096
        logConfiguration = {
            logDriver = "awslogs"
            options = {
                awslogs-group         = aws_cloudwatch_log_group.be_cloud_logs.name
                awslogs-region        = "us-east-1"
                awslogs-stream-prefix = "ecs"
            }
        }
        environment = [
            {
                name = "NODE_ENV"
                value = "development"
            },
            # {
            #     name = "MONGO_URI"
            #     value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster_instance.docdb_instance.endpoint}:27017/crud_db?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
            # },
            # {
            #     name  = "MONGO_URI"
            #     value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster_instance.docdb_instance.endpoint}:27017/crud_db?tls=true&tlsCAFile=/app/certs/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
            # },
            {
                name  = "MONGO_URI"
                value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster_instance.docdb_instance.endpoint}:27017/crud_db?tls=true&tlsCAFile=/app/certs/global-bundle.pem&authSource=admin&authMechanism=SCRAM-SHA-1&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
            },
            {
                name = "CORS_ORIGINS"
                value = "http://localhost:3000,http://localhost:5173"
            },
            {
                name = "RATE_LIMIT_WINDOW_MS"
                value = "900000"
            },
            {
                name = "RATE_LIMIT_MAX"
                value = "100"
            },
            {
                name = "API_VERSION"
                value = "v1"
            },
            {
                name = "AWS_REGION"
                value = "us-east-1"
            },
            {
                name = "S3_BUCKET_NAME"
                value = var.s3_bucket_name
            }
        ]
        portMappings = [
            {
                containerPort = 3000
                hostPort = 3000
                protocol = "tcp"
            }
        ]
    }
  ])
#   depends_on = [ aws_docdb_cluster.doc_db-cluster, aws_docdb_cluster_instance.docdb_instance, aws_s3_bucket.be_s3_bucket ]
}
# NODE_ENV=development
# PORT=3000

# # ─── MongoDB ──────────────────────────────────────────────
# MONGO_URI=mongodb://localhost:27017/crud_db

# # ─── Security ─────────────────────────────────────────────
# CORS_ORIGINS=http://localhost:3000,http://localhost:5173
# RATE_LIMIT_WINDOW_MS=900000
# RATE_LIMIT_MAX=100

# # ─── App ──────────────────────────────────────────────────
# API_VERSION=v1

# # ─── AWS S3 ───────────────────────────────────────────────
# # On ECS, credentials come automatically from the task role — do NOT add
# # AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY here.
# AWS_REGION=us-east-1
# S3_BUCKET_NAME=your-s3-bucket-name