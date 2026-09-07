###
resource "aws_iam_role" "cluster_role" {
  name = "eksclusterpolicypractiseforeks"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
            Service = "eks.amazonaws.com"
        }
    }]
  })
}
###
resource "aws_iam_role_policy_attachment" "cluster_awseks_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = aws_iam_role.cluster_role.name
}
###
resource "aws_iam_role_policy_attachment" "cluster_awseks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role = aws_iam_role.cluster_role.name
}
###
resource "aws_iam_role" "node_group_role" {
  name = "eksnodegrouppolicypratiseforeks"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
            Service = "ec2.amazonaws.com"
        }
    }]
  })
}
###
resource "aws_iam_role_policy_attachment" "node_aws_eks_worker_node_policy" {
  role = aws_iam_role.node_group_role.name 
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
###
resource "aws_iam_role_policy_attachment" "node_aws_eks_cni_policy" {
  role = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
###
resource "aws_iam_role_policy_attachment" "node_aws_ec2_ecr_readonly" {
  role = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
###
resource "aws_cloudwatch_log_group" "eks" {
  name = "/aws/eks/${var.name_prefix}-${var.cluster_name}/cluster"
  retention_in_days = 90
}
###
resource "aws_eks_cluster" "prod_cluster" {
  name = "${var.name_prefix}-${var.cluster_name}"
  version = var.cluster_version
  role_arn = aws_iam_role.cluster_role.arn
  enabled_cluster_log_types = [ 
    "api", "audit", "authenticator", "controllerManager", "scheduler"
   ]
  vpc_config {
    subnet_ids = aws_subnet.private_subnets[*].id
    endpoint_private_access = true
    endpoint_public_access = true
    public_access_cidrs = var.admin_allowed_cidrs
    security_group_ids = [  ]
  }
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }
  depends_on = [ 
    aws_iam_role_policy_attachment.cluster_awseks_policy,
    aws_iam_role_policy_attachment.cluster_awseks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks,
    aws_vpc.vpc_1
   ]
   tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-cluster-for-practise-eks"
   })
   
}
#####
resource "aws_eks_node_group" "cluster_nodes" {
  node_role_arn = aws_iam_role.node_group_role.arn
  cluster_name = aws_eks_cluster.prod_cluster.name
  subnet_ids = aws_subnet.private_subnets[*].id
  node_group_name = "${var.name_prefix}-${var.cluster_name}"
  capacity_type = var.cluster_nodes_capacity_type
  scaling_config {
    max_size = var.cluster_nodes_max_size
    min_size = var.cluster_node_min_size
    desired_size = var.cluster_nodes_desired_size
  }
  instance_types = [ var.nodes_instance_type ]
  update_config {
    max_unavailable = 1
  }
  depends_on = [ 
    aws_vpc.vpc_1,
    aws_iam_role.node_group_role,
    aws_iam_role_policy_attachment.node_aws_eks_cni_policy,
    aws_iam_role_policy_attachment.node_aws_ec2_ecr_readonly,
    aws_iam_role_policy_attachment.node_aws_eks_cni_policy,
    aws_iam_role_policy_attachment.node_aws_eks_worker_node_policy,
   ]
   disk_size = var.nodes_disk_size
   tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-node"
   })
   
}