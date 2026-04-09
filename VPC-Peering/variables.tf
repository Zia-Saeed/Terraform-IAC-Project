variable "vpc1_cidr" {
  type = string
  default = "192.168.0.0/16"
}

variable "vpc2_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "vpc1_subnets" {
  type = list(string)
  default = [ "192.168.1.0/24", "192.168.2.0/24" ]
}

variable "vpc2_subnets" {
  type = list(string)
  default = [ "10.0.1.0/24", "10.0.2.0/24" ]
}

variable "resource_name" {
  type = string
  default = "VPC-Peering"
}

variable "availability_zone" {
  type = list(string)
  default = [ "us-east-1a", "us-east-1b" ]
}
