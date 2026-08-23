variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the existing AWS key pair (created manually in EC2 console)"
  type        = string
  default     = "fa1-key"
}

variable "project_name" {
  description = "Used for tagging and dynamic inventory filtering"
  type        = string
  default     = "lost-and-found"
}

variable "environment" {
  description = "Environment tag (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into the instance. Restrict this to your own IP for safety."
  type        = string
  default     = "0.0.0.0/0"
}
