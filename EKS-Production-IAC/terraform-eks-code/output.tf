output "cluster_name" {
  value = aws_eks_cluster.prod_cluster.name
}
output "db_endpoint" {
  value = aws_rds_cluster.aurora_cluster.endpoint
}
output "db_username" {
  value = aws_rds_cluster.aurora_cluster.master_username
}
output "product_service_role_arn" {
  description = "Paste into the eks.amazonaws.com/role-arn annotation on the product-service-sa ServiceAccount (shopflow namespace)"
  value       = aws_iam_role.product_service.arn
}