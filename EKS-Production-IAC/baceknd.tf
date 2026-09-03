terraform {
  backend "s3" {
    encrypt = true
    key = ""
    use_lockfile = true
    
  }
}