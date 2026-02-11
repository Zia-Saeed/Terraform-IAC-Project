terraform {
  backend "s3" {
    bucket = "<backend-aws-s3-bucket-name>"
    key = "<path-to-state-file>"
    encrypt = true
    region = "us-east-1"
    use_lockfile = true
  }
}
