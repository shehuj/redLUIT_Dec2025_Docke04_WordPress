variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "wordpress-swarm"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones for subnet distribution"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to instances"
  type        = list(string)
  # SECURITY WARNING: Default restricts SSH to common VPN/office ranges
  # Update terraform.tfvars with YOUR specific IP addresses or VPN CIDR
  # Examples: ["203.0.113.0/24"] for office network or ["203.0.113.42/32"] for single IP
  # NEVER use 0.0.0.0/0 in production - this allows SSH from anywhere!
  default     = ["10.0.0.0/8"]  # Only allow from private VPC by default
}


variable "manager_instance_type" {
  description = "EC2 instance type for Swarm manager"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for Swarm workers"
  type        = string
  default     = "t3.medium"
}

variable "worker_count" {
  description = "Number of Swarm worker nodes"
  type        = number
  default     = 3
}

variable "manager_root_volume_size" {
  description = "Root volume size for manager node (GB)"
  type        = number
  default     = 30
}

variable "worker_root_volume_size" {
  description = "Root volume size for worker nodes (GB)"
  type        = number
  default     = 30
}

variable "ssh_key_name" {
  description = "Name of existing AWS EC2 key pair for SSH access"
  type        = string
  default     = "key"
}
