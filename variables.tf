variable "aws_region" { default = "us-east-1" }
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "allowed_cidrs" { default = ["10.0.0.0/16"] }
variable "ami_id" {}
variable "instance_type" { default = "t3.medium" }
variable "key_name" {}