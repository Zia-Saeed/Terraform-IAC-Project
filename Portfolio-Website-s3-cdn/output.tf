# ______________ OUTPUTS _____________ # 
output "cnd_url" {
  value = "https://${aws_cloudfront_distribution.static_site.domain_name}"
}
# ============ bucket arn ==============
output "bucket_arn" {
  value = aws_s3_bucket.s3_portfolio.arn
}