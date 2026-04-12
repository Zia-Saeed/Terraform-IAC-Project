terraform {
  backend "s3" {
    bucket = ""
    key = "terraform/lambda-s3/state/file"
    use_lockfile = true
    encrypt = true
    region = "us-east-1"
  }
}