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
    "192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"
   ]
  description = "Cidr block value for public subnets"
}
####
variable "pri_cidr_value" {
  type = list(string)
  default = [
    "192.168.10.0/24", "192.168.20.0/24", "192.168.30.0/24"
    ]
  description = "Cidr block value for private subnets"
}
###
variable "db_cidr_value" {
  type = list(string)
  default = [ 
    "192.168.100.0/24", "192.168.110.0/24", "192.168.120.0/24" 
    ]
    description = "Cidr block value for database"
}
###
variable "db_engine" {
  type = string
  default = "aurora-postgresql"
}
###
variable "db_engine_mode" {
  type = string
  default = "provisioned"
}
###
variable "db_engine_version" {
  type = string
  default = "16"
}
##
variable "db_rentention_period" {
  type = number
  default = 30
}
#
variable "db_name" {
  type = string
  default = "proddb"
}
###
variable "db_username" {
  type = string
  default = "postgresqlaurora"
}
###
variable "db_password" {
  type = string
  default = "LKJSALKJ230948KLAJSDKLJ9023"
}
###
variable "cluster_name" {
  type = string
  default = "prod-k8-cluster"
}
###
variable "cluster_version" {
  type = string
  default = "1.36"
}
###
variable "admin_allowed_cidrs" {
  type = list(string)
  description = "Public Cidr Block to Access EKS Control Plan API"
  default = [ "59.103.46.105/32" ]
}
###
variable "nodes_instance_type" {
  type = string
  description = "Node Instance Type"
  default = "t3.small"
}
###
variable "nodes_disk_size" {
  type = number
  description = "Disk Space for Node Machines"
  default = 30
}
###
variable "cluster_nodes_max_size" {
  type = number
  default = 4
  description = "Max Number for Nodes"
}
###
variable "cluster_node_min_size" {
  type = number
  default = 1
  description = "Min Number for Nodes"
}
###
variable "cluster_nodes_desired_size" {
  type = number
  default = 2
  description = "Desired Values for Cluster Nodes"
}
###
variable "cluster_nodes_capacity_type" {
  type = string
  default = "SPOT"
  description = "instance type for cluster"
}
###
variable "bucket_name" {
  type = string
  default = "product-bucket-microservices-practise-3290829038"
}
###
variable "cors_allowed_origins" {
  type = list(string)
  default = [ "*", "https://localhost:3000/", "http://localhost:3000", "https://localhost:3000", "http://localhost:3000/" ]
}
variable "noncurrent_version_expiration_days" {
  description = "How long to keep old versions of an overwritten/deleted image before permanently expiring them. Versioning protects against accidental overwrite/delete; this bounds the storage cost of keeping that protection forever."
  type        = number
  default     = 30
}