#
variable "name_prefix" {
  type = string
  default = "<project-name>"
  description = "Prefix Value for the resource"
}
#
variable "region" {
  type = string
  default = "ap-south-1"
  description = "value"
}
#
variable "vpc_cidr" {
  type = string
  default = "192.168.0.0/16"
  description = "Value for Prod VPC CIDR Block"
}
#
variable "public_subnet_group_cidr" {
  type = list(string)
  default = [ "192.168.0.0/24", "192.168.16.0/24" ]
  description = "Value for Public Subnets CIDR Block"
}
#
variable "private_subnet_group_cidr" {
  type = list(string)
  default = [ "192.168.32.0/24", "192.168.48.0/24" ]
}
#
variable "availability_zones" {
  type = list(string)
  default = [ "ap-south-1a", "ap-south-1b" ]
  description = "Value for Availability Zones Values"
}
#
variable "http_backend_image_url" {
  type = string
  default = "ecr-image-url"
  description = "ECR url Backend Image"
}
#
variable "logs_retentation" {
  type = number
  default = 14
  description = "Cloud Watch Logs Group Retention Period"
}
#
variable "certificate_arn" {
  type = string
  default = "ACM cert arn"
  description = "Certificate ARN"
}
#
variable "account_id" {
  type = string
  default = "047719637331"
  description = "AWS account ID"
}
#
variable "db_final_snapshot_name" {
  type = string
  default = "prod-db-final-snapshot-before-deletion"
  description = "Final Snapshot Name for zory prod db"
}
#
variable "db_uername" {
  type = string
  default = "postgresqlprod"
  description = "DB username for prod zory database"
}
variable "db_password" {
  type = string
  default = ""
  description = "db password for prod db"
}
####
variable "env_vars" {
  type = list(map(string))
  default = [
        
    ]
}





