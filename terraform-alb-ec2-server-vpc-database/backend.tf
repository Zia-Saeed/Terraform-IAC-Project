terraform {
  backend "s3" {
    bucket = "mybucket-for-terraform-vpc-practise123456"
    key = "tf/key/db"
    encrypt = true
    region = "us-east-1"
    use_lockfile = true
  }
}
