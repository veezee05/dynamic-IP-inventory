output "bastion_public_ip" {
  description = "Public IP of the bastion host (SSH entry point)"
  value       = aws_instance.bastion.public_ip
}

output "web_private_ip" {
  description = "Private IP of the web server (reachable only through the bastion)"
  value       = aws_instance.web.private_ip
}

output "bastion_instance_id" {
  value = aws_instance.bastion.id
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}
