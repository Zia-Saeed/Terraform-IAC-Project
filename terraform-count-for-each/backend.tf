terraform {
    backend "s3" {
        bucket = "<backend-bucket-name>"
        key = "<path-to-statefile>"
        encrypt = true
        use_lockfile = true
        region = "us-east-1"
    }
}