#
output "alb-dns" {
  value = aws_lb.nginx-lb.dns_name
}
#
# output "db-endponit" {
#   value = aws_db_instance.db_1.endpoint
# }
#
output "docdb_endpoint" {
  value = aws_docdb_cluster_instance.docdb_instance.endpoint 
}