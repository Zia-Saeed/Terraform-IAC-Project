variable "region" {
  default = "us-east-1"
  type = string
  description = "Region For AWS Resource"
}
###
variable "name_prefix" {
  default = "prod-iac"
  type = string
}
###
variable "vpc_cidr_block" {
  default = "192.168.0.0/16"
  type = string
  description = "VPC cidr block value"
}
#
variable "availability_zones" {
  type = list(string)
  default = [
    "us-east-1a", "us-east-1b", "us-east-1c"
  ]
  description = "Values for availability zones values"
}
####
variable "pub_cidr_value" {
  type = list(string)
  default = [ 
    "", ""
   ]
  description = ""
}
####
variable "pri_cidr_value" {
  type = list(string)
  default = [
    "", "" 
    ]
  description = ""
}