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

# Convenience outputs for WordPress access
output "wordpress_url" {
  description = "WordPress application URL"
  value       = "http://${aws_instance.swarm_manager.public_ip}"
}

output "ssh_connection_manager" {
  description = "SSH command to connect to manager"
  value       = "ssh -i swarm-key.pem ubuntu@${aws_instance.swarm_manager.public_ip}"
}

output "deployment_summary" {
  description = "Quick deployment summary"
  value = <<-EOT
    ╔════════════════════════════════════════════════════════════════╗
    ║          WordPress Swarm Deployment Summary                    ║
    ╠════════════════════════════════════════════════════════════════╣
    ║ WordPress URL: http://${aws_instance.swarm_manager.public_ip}
    ║ Manager IP:    ${aws_instance.swarm_manager.public_ip}
    ║ Worker Count:  ${length(aws_instance.swarm_worker)}
    ║ VPC CIDR:      ${aws_vpc.main.cidr_block}
    ║                                                                ║
    ║ SSH Access:                                                    ║
    ║   terraform output -raw private_key > swarm-key.pem            ║
    ║   chmod 600 swarm-key.pem                                      ║
    ║   ssh -i swarm-key.pem ubuntu@${aws_instance.swarm_manager.public_ip}
    ║                                                                ║
    ║ Next Steps:                                                    ║
    ║   1. Access WordPress at the URL above                         ║
    ║   2. Complete WordPress installation wizard                    ║
    ║   3. Install security plugins                                  ║
    ║   4. Configure backups                                         ║
    ╚════════════════════════════════════════════════════════════════╝
  EOT
}

/*
# Public IP of the swarm manager
output "swarm_manager_public_ip" {
  description = "Public IP of the Swarm manager"
  value       = aws_instance.swarm_manager.public_ip
}

# Private IP of the swarm manager
output "swarm_manager_private_ip" {
  description = "Private IP of the Swarm manager"
  value       = aws_instance.swarm_manager.private_ip
}

# All worker public IPs (list)
output "swarm_worker_public_ips" {
  description = "Public IPs of all Swarm workers"
  value       = aws_instance.swarm_worker[*].public_ip
}

# All worker private IPs (list)
output "swarm_worker_private_ips" {
  description = "Private IPs of all Swarm workers"
  value       = aws_instance.swarm_worker[*].private_ip
}

# Ansible inventory string (already in your logs)
output "ansible_inventory" {
  description = "Generated Ansible inventory"
  value       = local.ansible_inventory
}

# (Optional) Combined instance IDs
output "swarm_instance_ids" {
  description = "All Swarm instance IDs"
  value       = concat([aws_instance.swarm_manager.id], aws_instance.swarm_worker[*].id)
}
*/