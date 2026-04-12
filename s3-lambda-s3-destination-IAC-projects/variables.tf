variable "region" {
  default = "us-east-1"
  type = string
}
#
variable "s3_source_name" {
  default = "bucket-for-lambda-source-event-sender"
  type = string
}
#
variable "resource" {
  type = string
  default = "Lambda-Event-Project-TF"
}