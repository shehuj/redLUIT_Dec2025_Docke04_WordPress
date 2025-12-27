output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "swarm_manager_public_ip" {
  description = "Public IP of Swarm manager node"
  value       = aws_instance.swarm_manager.public_ip
}

output "private_key_pem" {
  description = "Private key in PEM format for SSH access"
  value       = tls_private_key.swarm_key.private_key_pem
  sensitive   = true
}

output "swarm_manager_private_ip" {
  description = "Private IP of Swarm manager node"
  value       = aws_instance.swarm_manager.private_ip
}

output "swarm_worker_public_ips" {
  description = "Public IPs of Swarm worker nodes"
  value       = aws_instance.swarm_worker[*].public_ip
}

output "swarm_worker_private_ips" {
  description = "Private IPs of Swarm worker nodes"
  value       = aws_instance.swarm_worker[*].private_ip
}

output "swarm_manager_id" {
  description = "Instance ID of Swarm manager"
  value       = aws_instance.swarm_manager.id
}

output "swarm_worker_ids" {
  description = "Instance IDs of Swarm workers"
  value       = aws_instance.swarm_worker[*].id
}

output "security_group_manager_id" {
  description = "Security group ID for manager node"
  value       = aws_security_group.swarm_manager.id
}

output "security_group_worker_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.swarm_worker.id
}

# Ansible inventory format output
output "ansible_inventory" {
  description = "Ansible inventory in INI format"
  value = templatefile("${path.module}/inventory-template.tpl", {
    manager_ip = aws_instance.swarm_manager.public_ip
    worker_ips = aws_instance.swarm_worker[*].public_ip
  })
}
