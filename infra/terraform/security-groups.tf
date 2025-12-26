# Security Group for Swarm Managers
resource "aws_security_group" "swarm_manager" {
  name_prefix = "${var.project_name}-swarm-manager-"
  description = "Security group for Docker Swarm manager nodes"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Docker Swarm management port
  ingress {
    description     = "Docker Swarm management"
    from_port       = 2377
    to_port         = 2377
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_worker.id]
    self            = true
  }

  # Docker Swarm communication (TCP)
  ingress {
    description     = "Docker Swarm node communication TCP"
    from_port       = 7946
    to_port         = 7946
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_worker.id]
    self            = true
  }

  # Docker Swarm communication (UDP)
  ingress {
    description     = "Docker Swarm node communication UDP"
    from_port       = 7946
    to_port         = 7946
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_worker.id]
    self            = true
  }

  # Docker overlay network
  ingress {
    description     = "Docker overlay network"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_worker.id]
    self            = true
  }

  # WordPress HTTP
  ingress {
    description = "WordPress HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # WordPress HTTPS
  ingress {
    description = "WordPress HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Grafana
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # AlertManager
  ingress {
    description = "AlertManager"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = var.allowed_monitoring_cidrs
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-swarm-manager-sg"
    Role = "swarm-manager"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for Swarm Workers
resource "aws_security_group" "swarm_worker" {
  name_prefix = "${var.project_name}-swarm-worker-"
  description = "Security group for Docker Swarm worker nodes"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Docker Swarm communication (TCP)
  ingress {
    description     = "Docker Swarm node communication TCP"
    from_port       = 7946
    to_port         = 7946
    protocol        = "tcp"
    security_groups = [aws_security_group.swarm_manager.id]
    self            = true
  }

  # Docker Swarm communication (UDP)
  ingress {
    description     = "Docker Swarm node communication UDP"
    from_port       = 7946
    to_port         = 7946
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_manager.id]
    self            = true
  }

  # Docker overlay network
  ingress {
    description     = "Docker overlay network"
    from_port       = 4789
    to_port         = 4789
    protocol        = "udp"
    security_groups = [aws_security_group.swarm_manager.id]
    self            = true
  }

  # WordPress HTTP (if WordPress runs on workers)
  ingress {
    description = "WordPress HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-swarm-worker-sg"
    Role = "swarm-worker"
  }

  lifecycle {
    create_before_destroy = true
  }
}
