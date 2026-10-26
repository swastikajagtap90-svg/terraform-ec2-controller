output "controller_public_ip" {
  description = "Public IPv4 address of the Terraform controller EC2 instance"
  value       = aws_instance.terraform_runner.public_ip
}

output "ssh_command" {
  description = "SSH command for the controller"
  value       = "ssh -i ./tf-runner-key.pem ubuntu@${aws_instance.terraform_runner.public_ip}"
}

output "nested_bucket_name" {
  description = "Name of the S3 bucket the inner Terraform configuration will create when run"
  value       = local.nested_bucket_name
}
