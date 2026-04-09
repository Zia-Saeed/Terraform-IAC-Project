terraform {
  backend "s3" {
    bucket = ""
    key = "terraform/vpc/peering/statefile"
    use_lockfile = true
    encrypt = true
    region = "us-east-1"
  }
}