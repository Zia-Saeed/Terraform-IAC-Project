# ==============================================================================
# AWS VPC Networking Architecture (3-Tier)
# ==============================================================================
# This file defines the core networking infrastructure for the application.
# It implements a standard 3-tier architecture:
# 1. Public Tier: Internet Gateway, Load Balancers, NAT Gateways
# 2. Private Tier: Application Services (ECS/Fargate)
# 3. Database Tier: Managed Databases (DocumentDB), isolated from internet
#
# CIDR Block: 192.168.0.0/16 (Provides 65,536 IP addresses)
# Region: us-east-1 (Implicit via provider or resource config)
# ==============================================================================

# ------------------------------------------------------------------------------
# Virtual Private Cloud (VPC)
# ------------------------------------------------------------------------------
# The logical network boundary for all resources.
resource "aws_vpc" "vpc_1" {
  # CIDR Block: Defines the IP range for the VPC.
  # Ensure this does not overlap with on-premise networks if using Direct Connect/VPN.
  cidr_block = "192.168.0.0/16"
  
  # DNS Support: Required for ECS Service Discovery and internal DNS resolution.
  enable_dns_support = true
  
  # DNS Hostnames: Required for assigning public DNS names to instances (if needed)
  # and crucial for certain AWS services integration.
  enable_dns_hostnames = true
  
  tags = {
    Name        = "${var.resource_name}-VPC-1"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# Internet Gateway (IGW)
# ------------------------------------------------------------------------------
# Allows traffic between the VPC and the public internet.
# Attached to Public Subnets via Route Table.
resource "aws_internet_gateway" "ig_1" {
  vpc_id = aws_vpc.vpc_1.id
  
  # Note: Implicit dependency on VPC exists via vpc_id. 
  # Explicit depends_on is generally unnecessary here but harmless.
  # depends_on = [aws_vpc.vpc_1]
  
  tags = {
    Name        = "${var.resource_name}-Ig-1"
    Environment = var.env_name
    Project     = var.project_name
  }
}

# ------------------------------------------------------------------------------
# Public Subnets
# ------------------------------------------------------------------------------
# Hosts resources that need direct internet access:
# - Application Load Balancer (ALB)
# - NAT Gateway (for private subnet internet egress)
# - Bastion Hosts (if any)
resource "aws_subnet" "pub_subnets" {
  vpc_id            = aws_vpc.vpc_1.id
  count             = length(var.pub_subnets_cidr)
  cidr_block        = var.pub_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index]
  
  # MapPublicIpOnLaunch is false by default, but ALB/NAT manage their own IPs.
  # If you launch EC2 here, set map_public_ip_on_launch = true.
  
  tags = {
    Name        = "${var.resource_name}-public-subnet-${count.index}"
    Environment = var.env_name
    Project     = var.project_name
    # Tagging subnet type helps automation scripts identify tier
    Type        = "Public"
  }
}

# ------------------------------------------------------------------------------
# Private Subnets (Application Tier)
# ------------------------------------------------------------------------------
# Hosts resources that should NOT be directly accessible from the internet:
# - ECS Fargate Tasks (Backend Services)
# - Internal Microservices
# Traffic egresses via NAT Gateway for updates/external API calls.
resource "aws_subnet" "pri_subnets" {
  vpc_id            = aws_vpc.vpc_1.id
  count             = length(var.pri_subnets_cidr)
  cidr_block        = var.pri_subnets_cidr[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name        = "${var.resource_name}-private-subnet-${count.index}"
    Environment = var.env_name
    Project     = var.project_name
    Type        = "Private"
  }
}

# ------------------------------------------------------------------------------
# Public Route Table
# ------------------------------------------------------------------------------
# Directs internet-bound traffic from Public Subnets to the Internet Gateway.
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.vpc_1.id
  
  # Default Route: All non-local traffic (0.0.0.0/0) goes to IGW
  route {
    gateway_id = aws_internet_gateway.ig_1.id
    cidr_block = "0.0.0.0/0"
  }
  
  tags = {
    Name        = "${var.resource_name}-public-route-table"
    Project     = var.project_name
    Environment = var.env_name
    Type        = "Public"
  }
}

# ------------------------------------------------------------------------------
# Associate Public Subnets with Public Route Table
# ------------------------------------------------------------------------------
resource "aws_route_table_association" "pub_rt_asc" {
  count            = length(aws_subnet.pub_subnets)
  route_table_id   = aws_route_table.pub_rt.id
  subnet_id        = aws_subnet.pub_subnets[count.index].id
}

# ------------------------------------------------------------------------------
# Elastic IP (EIP) for NAT Gateway
# ------------------------------------------------------------------------------
# A static public IP address for the NAT Gateway.
# Required because NAT Gateway needs a fixed public IP to perform SNAT.
resource "aws_eip" "eip_1" {
  domain = "vpc" # Must be 'vpc' for VPC-based EIPs
  
  # Note: EIPs are regional resources, not dependent on IGW directly.
  # depends_on = [aws_internet_gateway.ig_1] # Optional
  tags = {
    Name = "${var.resource_name}-eip-1"
  }
}

# ------------------------------------------------------------------------------
# NAT Gateway
# ------------------------------------------------------------------------------
# Allows instances in Private Subnets to initiate outbound internet connections
# (e.g., pulling Docker images, accessing external APIs) while preventing
# inbound connections from the internet.
#
# ⚠️  HIGH AVAILABILITY NOTE:
# This configuration uses a SINGLE NAT Gateway in one AZ (pub_subnets[0]).
# If this AZ fails, private subnets in OTHER AZs lose internet access.
# For Production HA: Deploy one NAT Gateway per AZ and route accordingly.
resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.eip_1.id
  subnet_id     = aws_subnet.pub_subnets[0].id # Placed in first public subnet
  
  tags = {
    Name        = "${var.resource_name}-nat-1"
    Project     = var.project_name
    Environment = var.env_name
  }
}

# ------------------------------------------------------------------------------
# Private Route Table
# ------------------------------------------------------------------------------
# Directs internet-bound traffic from Private Subnets to the NAT Gateway.
resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.vpc_1.id
  
  # Default Route: All non-local traffic goes to NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }
  
  tags = {
    Name        = "${var.resource_name}-private-route-table"
    Environment = var.env_name
    Project     = var.project_name
    Type        = "Private"
  }
}

# ------------------------------------------------------------------------------
# Associate Private Subnets with Private Route Table
# ------------------------------------------------------------------------------
resource "aws_route_table_association" "pri_rt_asc" {
  count            = length(aws_subnet.pri_subnets)
  route_table_id   = aws_route_table.pri_rt.id
  subnet_id        = aws_subnet.pri_subnets[count.index].id
}

# ------------------------------------------------------------------------------
# Database Subnets (Isolated Tier)
# ------------------------------------------------------------------------------
# Hosts managed database services (DocumentDB, RDS).
# These subnets are NOT associated with a route to IGW or NAT.
# This ensures databases have NO direct internet access, enhancing security.
resource "aws_subnet" "db_subnets" {
  count             = length(var.db_subnets)
  vpc_id            = aws_vpc.vpc_1.id
  cidr_block        = var.db_subnets[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name        = "${var.resource_name}-db-subnet-${count.index}"
    Project     = var.project_name
    Environment = var.env_name
    Type        = "Database"
  }
}

# ------------------------------------------------------------------------------
# Database Route Table
# ------------------------------------------------------------------------------
# Intentionally left without internet routes (0.0.0.0/0).
# Only the local VPC route (192.168.0.0/16 -> local) exists by default.
# This isolates the database tier from the public internet and NAT.
# Access is only allowed via Security Groups from the Private App Tier.
resource "aws_route_table" "rt_db" {
  vpc_id = aws_vpc.vpc_1.id
  
  # No explicit routes defined = Isolation from Internet/NAT
  # route {
  #   gateway_id = "local"
  #   cidr_block = "192.168.0.0/16"
  # } # This local route exists automatically
}

# ------------------------------------------------------------------------------
# Associate Database Subnets with DB Route Table
# ------------------------------------------------------------------------------
resource "aws_route_table_association" "db_rt_asc" {
  count            = length(aws_subnet.db_subnets)
  route_table_id   = aws_route_table.rt_db.id
  subnet_id        = aws_subnet.db_subnets[count.index].id
}

# ==============================================================================
# Network Architecture Diagram
# ==============================================================================
#
#  Internet
#     │
#     ▼
# ┌─────────────────────────────────────────────────────────────────┐
# │ VPC: 192.168.0.0/16                                             │
# │                                                                 │
# │  ┌─────────────────────────────────────────────────────────┐   │
# │  │ Public Subnets (ALB, NAT)                               │   │
# │  │ Route: 0.0.0.0/0 → Internet Gateway                     │   │
# │  │                                                         │   │
# │  │  [ALB] ◀─────── Internet ───────▶ [NAT Gateway]         │   │
# │  └─────────────────────────────────────────────────────────┘   │
# │                          │                      │              │
# │                          ▼                      ▼              │
# │  ┌─────────────────────────────────────────────────────────┐   │
# │  │ Private Subnets (ECS/Fargate)                           │   │
# │  │ Route: 0.0.0.0/0 → NAT Gateway                          │   │
# │  │                                                         │   │
# │  │  [ECS Tasks] ──────▶ [NAT] (for updates/external)       │   │
# │  └─────────────────────────────────────────────────────────┘   │
# │                          │                                      │
# │                          ▼                                      │
# │  ┌─────────────────────────────────────────────────────────┐   │
# │  │ Database Subnets (DocumentDB)                           │   │
# │  │ Route: Local VPC Only (No Internet/NAT)                 │   │
# │  │                                                         │   │
# │  │  [DocumentDB Cluster] ◀─── Security Group ──── [ECS]    │   │
# │  └─────────────────────────────────────────────────────────┘   │
# │                                                                 │
# └─────────────────────────────────────────────────────────────────┘
#
# ==============================================================================
# Security & Cost Considerations
# ==============================================================================
# 🔐 Security:
# • DB Subnets have no internet route (Isolation).
# • Private Subnets cannot be reached directly from internet (No IGW route).
# • Public Access is limited to ALB (controlled via Security Groups).
#
# 💰 Cost:
# • NAT Gateway costs ~$0.045/hour + data processing fees.
# • Single NAT Gateway saves money but reduces AZ resilience.
# • Consider VPC Endpoints (S3, DynamoDB) to bypass NAT for AWS services.
#
# 🔄 High Availability:
# • Subnets are spread across multiple AZs (via count/variables).
# • ALB spans all Public AZs.
# • ECS Service spans all Private AZs.
# • NAT Gateway is single-AZ (Bottleneck for Private AZ resilience).
# ==============================================================================
