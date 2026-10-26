variable "aws_region" {
  type        = string
  description = "AWS region for the controller and nested bucket"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 controller instance type"
  default     = "t3.micro"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "Your public IPv4 address with /32, for example 203.0.113.10/32"
  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0)) && can(regex("/32$", var.allowed_ssh_cidr))
    error_message = "Use one IPv4 address in CIDR format ending in /32."
  }
}
