output "bucket_name" {
  value = [for bucket in  aws_s3_bucket.my_buckets: 
    {
        name = "bucket-name: ${bucket.bucket}"
    }
  ]
}
output "servers_pub_ipaddress" {
  value = [for ip in aws_instance.ec2_servers: 
    "public-ip-addresses-of-server:${ip.public_ip}"
  ]
}