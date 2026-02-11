#
variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
  description = "CIDR block values for VPC"
}
#
variable "resource_name" {
  type = string
  default = "vpc-with-s3-bucket"
  description = "Name of the resources"
}
#
variable "project_name" {
  type = string
  default = "Implicit Dependency between s3 bucket and vpc"
}
#
variable "environment_name" {
  type = string
  default = "practise"
}
#
variable "region_value" {
  type = string
  default = "us-east-1"
}