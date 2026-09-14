terraform {
  backend "s3" {
    bucket = "mybucket-for-terraform-vpc-practise123456"
    encrypt = true
    key = "eks/terraform/statefile"
    use_lockfile = true
    region = "us-east-1"
  }
}