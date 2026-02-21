# ALB dns name 
output "alb_dns_value" {
  value = aws_lb.alb_for_servers.dns_name
}
# Server 1 ip
output "server_1_ip" {
  value = aws_instance.server_1.public_ip
}
# Server 2 ip
output "server_2_ip" {
  value = aws_instance.server_2.public_ip
}
# Database Endpoint
output "db_endpoint"{
  value = aws_db_instance.my_db_instance.endpoint
  description = "RDS instance endpint"
}