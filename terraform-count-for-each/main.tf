resource "aws_s3_bucket" "my_buckets" {
    count = length(var.bucket_name)
    bucket = var.bucket_name[count.index]
}
resource "aws_instance" "ec2_servers" {
  ami = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  for_each = var.servers_type
  instance_type = each.value.instance_type
  associate_public_ip_address = each.value.associate_public_ip_address
}