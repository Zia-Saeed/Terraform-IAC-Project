variable "bucket_name" {
  type = string
  # Add your bucket name here
  default     = "<bucket name>"
  description = "S3 bucket to host Portfolio Website"
}

variable "resource_name" {
  type        = string
  default     = "Portfolio-Website"
  description = "Resource Name"
}

# 
variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Region Value"
}
