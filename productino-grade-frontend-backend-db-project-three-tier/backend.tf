terraform {
  backend "s3" {
    # s3 bucket for terraform state file storage
    bucket = "<s3-bucket-name>"
    encrypt = true
    use_lockfile = true
    key = "ecs/statefile"
    region = "us-east-1"
  }
}