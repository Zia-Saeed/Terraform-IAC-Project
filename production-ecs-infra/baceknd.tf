terraform {
  backend "s3" {
    bucket = ""
    encrypt = true
    key = "<path to statefile>"
    region = "region"
    use_lockfile = true
  }
}
