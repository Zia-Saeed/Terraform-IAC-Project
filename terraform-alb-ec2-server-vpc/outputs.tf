output "alb_dns_value" {
  value = aws_lb.alb_for_servers.dns_name
}
output "server_1_ip" {
  value = aws_instance.server_1.public_ip
}
output "server_2_ip" {
  value = aws_instance.server_2.public_ip
}