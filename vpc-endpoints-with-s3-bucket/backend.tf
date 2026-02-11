terraform {
  backend "s3" {
    bucket = "<bucketname-for-statefile>"
    encrypt = true
    key = "tf/file"
    use_lockfile = true
    region = "us-east-1"
  }
}