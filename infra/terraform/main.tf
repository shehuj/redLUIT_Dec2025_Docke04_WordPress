terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration is in backend.tf
  # Run ./setup-backend.sh first to create S3 bucket and DynamoDB table
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "WordPress-Swarm"
      ManagedBy   = "Terraform"
      Environment = var.environment
      Repository  = "redLUIT_Dec2025_Docke04_WordPress"
    }
  }
}

# Data source for latest Ubuntu 22.04 LTS AMI
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

# Generate SSH key pair using TLS provider
resource "tls_private_key" "swarm_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair from generated public key
resource "aws_key_pair" "swarm_key" {
  key_name   = "${var.project_name}-swarm-key"
  public_key = tls_private_key.swarm_key.public_key_openssh

  tags = {
    Name = "${var.project_name}-swarm-key"
  }
}
