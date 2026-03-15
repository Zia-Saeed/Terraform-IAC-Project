
# ==============================================================================
# AWS VPC Gateway Endpoint for Amazon S3
# ==============================================================================
# This resource creates a VPC Gateway Endpoint for S3, enabling private 
# connectivity between resources within the VPC (e.g., ECS tasks in private 
# subnets) and Amazon S3 without traversing the public internet.
#
# Key Benefits:
# • Security: Traffic stays within the AWS network backbone.
# • Cost: Gateway endpoints for S3 are FREE (no hourly charge or data processing fee).
# • Performance: Reduced latency compared to routing through NAT Gateway.
# • No NAT Required: ECS tasks in private subnets can access S3 without needing 
#   a NAT Gateway for this specific traffic, reducing infrastructure costs.
# ==============================================================================

resource "aws_vpc_endpoint" "s3_bucket_endpoint" {
  # Associate the endpoint with the main VPC
  vpc_id = aws_vpc.vpc_1.id
  
  # Type: "Gateway" (Required for S3 and DynamoDB)
  # Note: "Interface" endpoints create ENIs and cost money. "Gateway" endpoints 
  # are free and work by modifying route tables.
  vpc_endpoint_type = "Gateway"
  
  # Service Name: Specific to the region and service.
  # Format: com.amazonaws.<region>.<service>
  # ⚠️  NOTE: This is hardcoded to us-east-1. For multi-region setups, 
  # consider using a data source: data.aws_vpc_endpoint_service.s3.service_name
  service_name = "com.amazonaws.us-east-1.s3"
  
  # Route Table Association: CRITICAL STEP
  # Associates the endpoint with the private route table. This injects a route 
  # into the table directing S3 traffic (prefix lists) to this endpoint.
  # Without this, private subnets cannot reach S3 privately.
  route_table_ids = [aws_route_table.pri_rt.id]
  
  tags = {
    Name        = "${var.resource_name}-vpc-endpoint-for-s3-bucket"
    Resource    = var.resource_name
    Environment = var.env_name
    # Indicates this endpoint is for S3 traffic specifically
    Service     = "S3"
  }
}

# ==============================================================================
# Architecture & Traffic Flow
# ==============================================================================
#
# ┌─────────────────────────────────────────────────────────────────┐
# │ VPC (us-east-1)                                                 │
# │                                                                 │
# │  ┌───────────────────┐         ┌───────────────────┐           │
# │  │ Private Subnet    │         │ Public Subnet     │           │
# │  │ - ECS Tasks       │         │ - NAT Gateway     │           │
# │  │ - Route Table:    │         │ - IGW             │           │
# │  │   pri_rt          │         └───────────────────┘           │
# │  └─────────┬─────────┘                                         │
# │            │                                                   │
# │            ▼ (Route added automatically by VPCE)               │
# │  ┌───────────────────┐                                         │
# │  │ VPC Gateway       │                                         │
# │  │ Endpoint (S3)     │─────────────────────────────────┐       │
# │  └───────────────────┘                                 │       │
# │                                                        │       │
# │            │                                           │       │
# │            │ (Private AWS Network)                     │       │
# │            ▼                                           ▼       │
# │  ┌───────────────────┐                         ┌───────────────┐│
# │  │ Amazon S3         │                         │ Public Internet││
# │  │ (Private Access)  │                         │ (Blocked for S3)││
# │  └───────────────────┘                         └───────────────┘│
# └─────────────────────────────────────────────────────────────────┘
#
# ==============================================================================
