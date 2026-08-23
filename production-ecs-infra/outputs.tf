#
output "alb_dns" {
  value = aws_lb.zory_alb.dns_name
}
#
