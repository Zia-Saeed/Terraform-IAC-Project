terraform {
  backend "s3" {
    region = "<region>"
    bucket = "<remote backend bucket name>"
    key = "<path to statefile>"
    encrypt = true
    use_lockfile = true
  }
}