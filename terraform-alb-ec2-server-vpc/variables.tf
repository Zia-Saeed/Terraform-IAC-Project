#
variable "cidr_block_for_vpc" {
  default = ["192.168.0.0/16", "10.0.0.0/16", "172.16.0.0/16"]
  type = list(string)
}
#
variable "regions_selection" {
  default = ["us-east-1", "us-west-1"]
  type = set(string)
}
#
variable "resources_tags" {
  type = map(string)
  default = {
    Project = "Terraform-Practise",
    Environment = "Staging"
  }
}
#
variable "config" {
  type = object({
    region = string,
    monitoring = bool,
    instance_count = number
  })
  default = {
    region = "us-east-1",
    monitoring = true
    instance_count = 2
  }
}
#
variable "ingress_value" {
  type = tuple([ string, number, number, list(string) ])
  default = [ "tcp", 80, 80, [ "0.0.0.0/0" ] ]
}
# ingress_value[3][0]
#
variable "resouce_name" {
  type = string
  default = "Terrafrom-IAC"
}

variable "environment_name" {
  default = "testing"
  type = string
}
#
variable "project_name" {
  default = "Terraform-practise"
  type = string
}
#
variable "ec2_server_os_id" {
  default = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  type = string
}
#
variable "ec2_server_type" {
  default = "t2.micro"
  type = string
}
#
variable "cidr_block" {
  type = list(string)
  default = [ "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24", "192.168.4.0/24", "192.168.5.0/24", "192.168.6.0/24" ]
}