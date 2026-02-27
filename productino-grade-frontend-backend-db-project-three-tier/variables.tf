#
variable "resource_name" {
  type = string
  default = "Resouce"
  description = "Resources Name"
}
#
variable "env_name" {
  type = string
  default = "staging"
  description = "Development Name"
}
#
variable "project_name" {
  type = string
  default = "TIAC-Practise"
  description = "Project Name For Resouces"
}
#
variable "pub_subnets_cidr" {
  type = list(string)
  default = [ "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24" ]
  description = "Cidr Block Values for Public Subnets"
}
#
variable "pri_subnets_cidr" {
  type = list(string)
  default = [ "192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24" ]
  description = "Cidr Block Values for Private Subnets "
}
#
variable "availability_zones" {
  type = list(string)
  default = [ "us-east-1a", "us-east-1b", "us-east-1c" ]
  description = "Availability Zones values"
}
#
variable "db_subnets" {
  type = list(string)
  default = [ "192.168.7.0/24", "192.168.8.0/24", "192.168.9.0/24" ]
  description = "Subnet Group for db instance"
}
#
variable "db_username" {
  type = string
  default = "Dumyuser"
  description = "Username of db instance"
}
#
variable "db_password" {
  sensitive = true
  description = "db instance password"
}
#
variable "db_instance_size" {
  type = string
  default = "db.t3.micro"
  description = "Databse instance size "
}
