terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Latest Ubuntu 22.04 LTS AMI, resolved dynamically instead of hardcoding an AMI ID
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Security Groups ---

resource "aws_security_group" "bastion_sg" {
  name        = "${var.project_name}-bastion-sg"
  description = "Allow SSH from trusted CIDR only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from trusted CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # The bastion also acts as a NAT instance, so it must accept traffic
  # originating in the private subnet in order to forward it outbound.
  ingress {
    description = "Forwarded traffic from the private subnet (NAT instance role)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.private_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-bastion-sg"
    Project = var.project_name
  }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-private-sg"
  description = "Allow SSH only from bastion, HTTP only from within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    description = "HTTP from within the VPC (for SSH-tunnel demo access)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web-private-sg"
    Project = var.project_name
  }
}

# --- Instances ---

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true

  # Required for the NAT instance role: by default EC2 drops packets whose
  # source and destination are both other hosts. A NAT device must forward them.
  source_dest_check = false

  # Turn the bastion into a NAT device for the private subnet.
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-nat.conf
    sysctl -p /etc/sysctl.d/99-nat.conf

    iptables -t nat -A POSTROUTING -s ${var.private_subnet_cidr} -j MASQUERADE

    # Persist the rule so it survives a reboot
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y iptables-persistent
    netfilter-persistent save
  EOF

  tags = {
    Name         = "B-bastion-jumphost-public-nat"
    Project      = var.project_name
    Environment  = var.environment
    Role         = "bastion"
    Architecture = "bastion"
    Branch       = "feature/bastion-host"
  }

  # The AMI data source uses most_recent = true, so Canonical publishing a new
  # Ubuntu image would otherwise force this instance to be destroyed and
  # rebuilt. New builds still get the latest AMI; existing ones stay put.
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = false

  # Tags are what the Ansible dynamic inventory plugin will filter on later.
  # Architecture distinguishes this from the single-server setup on main.
  tags = {
    Name         = "B-bastion-appserver-private-noip"
    Project      = var.project_name
    Environment  = var.environment
    Role         = "web"
    Architecture = "bastion"
    Branch       = "feature/bastion-host"
  }

  # The bastion must exist (and be configured as a NAT device) before this
  # instance has any outbound path for provisioning.
  depends_on = [aws_instance.bastion]

  lifecycle {
    ignore_changes = [ami]
  }
}
