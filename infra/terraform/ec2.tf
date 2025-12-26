# Swarm Manager Node
resource "aws_instance" "swarm_manager" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.manager_instance_type
  key_name      = aws_key_pair.swarm_key.key_name

  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.swarm_manager.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.manager_root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    hostname = "swarm-manager-1"
  })

  tags = {
    Name = "${var.project_name}-swarm-manager-1"
    Role = "swarm-manager"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Swarm Worker Nodes
resource "aws_instance" "swarm_worker" {
  count = var.worker_count

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.worker_instance_type
  key_name      = aws_key_pair.swarm_key.key_name

  subnet_id                   = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids      = [aws_security_group.swarm_worker.id]
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.worker_root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user-data.sh", {
    hostname = "swarm-worker-${count.index + 1}"
  })

  tags = {
    Name = "${var.project_name}-swarm-worker-${count.index + 1}"
    Role = "swarm-worker"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

variable "manager_instance_type" {
  description = "Instance type for the Swarm manager node"
  type        = string
  default     = "t3.medium"
  
}

variable "worker_instance_type" {
  description = "Instance type for the Swarm worker nodes"
  type        = string
  default     = "t3.small"
}

variable "manager_root_volume_size" {
  description = "Root volume size (in GB) for the Swarm manager node"
  type        = number
  default     = 20
}

variable "worker_root_volume_size" {
  description = "Root volume size (in GB) for the Swarm worker nodes"
  type        = number
  default     = 15
}

variable "worker_count" {
  description = "Number of Swarm worker nodes to create"
  type        = number
  default     = 2
}

variable "project_name" {
  description = "Project name for tagging resources"
  type        = string
  default     = "redLUIT"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}