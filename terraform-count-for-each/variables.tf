variable "bucket_name" {
  type = list(string)
  default = [ "terraform-bucket-iac-102938092810380", "terraform-bucket-iac-102938092810380lkj", "terraform-bucket-iac-1029380928103883lksd" ]
}
#
variable "servers_type" {
  type = map(object({
    instance_type = string
    associate_public_ip_address = bool
  })
  )
  default = {
    server1 = {
    instance_type = "t2.micro",
    associate_public_ip_address = true
    },
    server2 = {
    instance_type = "t3.micro",
    associate_public_ip_address = false
    },
    server3 = {
    instance_type = "t2.small",
    associate_public_ip_address = true
    }
  }
}
