#____________ STATEFILE CONFIG ____________ #
terraform {
  backend "s3" {
    # Add your s3 backed bucket here
    bucket       = "<s3-backend-bucket>"
    key          = "portfolio/wesbite/terraform/statefile"
    encrypt      = true
    region       = "us-east-1"
    use_lockfile = true
  }
}