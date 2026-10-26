terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "terraform_runner_role" {
  name = "terraform-controller-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project   = "Terraform-Controller-Lab"
    ManagedBy = "Terraform-Outer"
  }
}

resource "aws_iam_role_policy" "nested_s3_policy" {
  name = "nested-terraform-s3-policy"
  role = aws_iam_role.terraform_runner_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutBucketTagging",
          "s3:GetBucketTagging",
          "s3:DeleteBucketTagging"
        ]
        Resource = "arn:aws:s3:::nested-tf-bucket-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "runner_profile" {
  name = "terraform-controller-instance-profile"
  role = aws_iam_role.terraform_runner_role.name
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tf-runner-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/tf-runner-key.pem"
  file_permission = "0400"
}

resource "aws_security_group" "runner_sg" {
  name        = "terraform-runner-sg"
  description = "SSH from your specified public IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from your specified public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project   = "Terraform-Controller-Lab"
    ManagedBy = "Terraform-Outer"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  nested_bucket_name = "nested-tf-bucket-${random_id.bucket_suffix.hex}"
  nested_main_tf = <<-EOT
    terraform {
      required_version = ">= 1.5.0"
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.40"
        }
      }
    }

    provider "aws" {
      region = "${var.aws_region}"
    }

    resource "aws_s3_bucket" "test_bucket" {
      bucket        = "${local.nested_bucket_name}"
      force_destroy = true

      tags = {
        Project   = "Terraform-Controller-Lab"
        ManagedBy = "Terraform-Nested"
      }
    }

    output "bucket_name" {
      value = aws_s3_bucket.test_bucket.bucket
    }
  EOT
}

resource "aws_instance" "terraform_runner" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = null
  vpc_security_group_ids      = [aws_security_group.runner_sg.id]
  key_name                    = aws_key_pair.generated_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.runner_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    aws_region        = var.aws_region
    nested_bucket_name = local.nested_bucket_name
    nested_main_tf    = local.nested_main_tf
  })

  user_data_replace_on_change = true

  tags = {
    Name      = "terraform-controller-instance"
    Project   = "Terraform-Controller-Lab"
    ManagedBy = "Terraform-Outer"
  }

  depends_on = [
    aws_iam_role_policy.nested_s3_policy,
    aws_iam_instance_profile.runner_profile
  ]
}
