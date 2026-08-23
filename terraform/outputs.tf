output "instance_public_ip" {
  description = "Public IP of the EC2 web instance"
  value       = aws_instance.web.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "security_group_id" {
  value = aws_security_group.web_sg.id
}
