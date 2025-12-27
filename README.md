# WordPress on Docker Swarm with Complete Monitoring

**Production-ready, fully automated deployment of WordPress with MySQL and comprehensive monitoring stack on AWS using Docker Swarm.**

[![Infrastructure](https://img.shields.io/badge/Infrastructure-Terraform-623CE4)](infra/terraform)
[![Configuration](https://img.shields.io/badge/Configuration-Ansible-EE0000)](infra/ansible)
[![CI/CD](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF)](.github/workflows)
[![Platform](https://img.shields.io/badge/Platform-Docker_Swarm-2496ED)](https://docs.docker.com/engine/swarm/)

## ✨ Features

- **🚀 One-Command Deployment** - Deploy entire infrastructure with `./deploy.sh`
- **🔄 Fully Idempotent** - Safe to run multiple times
- **☁️ AWS Infrastructure** - Automated provisioning with Terraform
- **🎯 High Availability** - Multi-node Swarm cluster
- **📊 Complete Monitoring** - Prometheus, Grafana, AlertManager
- **🔒 Security Hardening** - UFW firewall, SSH hardening, secrets management
- **⚙️ CI/CD Ready** - GitHub Actions workflows for automated deployment
- **📝 Comprehensive Docs** - Extensive documentation and guides

## 🏗️ Architecture

### Infrastructure
- **1 Manager Node** - Swarm orchestration (t3.medium)
- **2 Worker Nodes** - Application workload (t3.medium)
- **VPC & Networking** - Custom VPC with public/private subnets
- **Security Groups** - Least privilege access control

### Application Stack
- **WordPress** (3 replicas) - High-availability web application
- **MySQL 8.0** (1 replica) - Database with persistent storage
- **Secrets Management** - Docker Swarm secrets for credentials

### Monitoring Stack
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Dashboards and visualization
- **AlertManager** - Alert routing to Slack
- **cAdvisor** - Container metrics (global)
- **Node Exporter** - System metrics (global)

### Network Topology
```
┌────────────────────────────────────────────────────────────┐
│                    Docker Swarm Cluster                    │
│                                                            │
│  Frontend Network ──> WordPress (port 80)                 │
│  Backend Network  ──> WordPress <─> MySQL                 │
│  Monitoring Network ──> All services + monitoring stack   │
└────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites
```bash
# Required tools
- Terraform >= 1.6.0
- Ansible >= 8.0.0
- AWS CLI
- Python 3.12+
- Docker (for local testing)

# AWS Account with:
- IAM user with EC2, VPC permissions
- Configured AWS credentials
```

### Option 1: One-Command Deployment (Recommended)

```bash
# 1. Clone repository
git clone <repo-url>
cd redLUIT_Dec2025_Docke04_WordPress

# 2. Set environment variables
export AWS_REGION="us-east-1"
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
export MYSQL_ROOT_PASSWORD="your_secure_password"
export MYSQL_PASSWORD="your_app_password"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..." # optional

# 3. Validate setup
./validate.sh

# 4. Deploy everything
./deploy.sh

# That's it! 🎉
```

### Option 2: Step-by-Step Deployment

```bash
# 1. Setup Terraform backend
cd infra/terraform
./setup-backend.sh
terraform init

# 2. Deploy infrastructure
terraform plan
terraform apply

# 3. Configure Swarm cluster
cd ../ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml

# 4. Deploy stacks
# SSH to manager and run:
docker stack deploy -c stack-monitoring/monitoring-stack.yml monitoring
docker stack deploy -c stack-app/docker-stack.yml levelop-wp
```

### Option 3: CI/CD Deployment

```bash
# 1. Configure GitHub Secrets
Settings → Secrets → Actions:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY
  - SSH_PUBLIC_KEY
  - SSH_PRIVATE_KEY
  - MYSQL_ROOT_PASSWORD
  - MYSQL_PASSWORD
  - SLACK_WEBHOOK_URL

# 2. Push to main branch
git push origin main

# 3. GitHub Actions deploys automatically
# Watch: Actions tab → Main Deployment Pipeline
```

## 📋 Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy.sh` | One-command full deployment | `./deploy.sh` |
| `validate.sh` | Pre-flight validation | `./validate.sh` |
| `destroy.sh` | Destroy all infrastructure | `./destroy.sh` |

## 🔧 Configuration

### Environment Variables

Create `.env` file (optional):
```bash
export AWS_REGION="us-east-1"
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
export MYSQL_ROOT_PASSWORD="change_this_password"
export MYSQL_PASSWORD="change_this_too"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

Then: `source .env`

### Terraform Variables

Edit `infra/terraform/terraform.tfvars`:
```hcl
aws_region = "us-east-1"
project_name = "wordpress-swarm"
manager_instance_type = "t3.medium"
worker_instance_type = "t3.medium"
worker_count = 2
```

### Ansible Variables

Edit `infra/ansible/inventory/group_vars/all.yml`:
```yaml
docker_version: "latest"
swarm_manager_expected_count: 1
swarm_worker_expected_count: 2
```

## 📊 Access Services

After deployment:

| Service | URL | Credentials |
|---------|-----|-------------|
| WordPress | `http://<MANAGER_IP>` | Setup on first visit |
| Grafana | `http://<MANAGER_IP>:3000` | admin / admin |
| Prometheus | `http://<MANAGER_IP>:9090` | No auth |
| AlertManager | `http://<MANAGER_IP>:9093` | No auth |

Get manager IP:
```bash
cd infra/terraform
terraform output swarm_manager_public_ip
```

## 🛠️ Management

### Check Cluster Status
```bash
ssh ubuntu@<MANAGER_IP> 'docker node ls'
ssh ubuntu@<MANAGER_IP> 'docker service ls'
ssh ubuntu@<MANAGER_IP> 'docker stack ps levelop-wp'
```

### View Logs
```bash
ssh ubuntu@<MANAGER_IP> 'docker service logs levelop-wp_wordpress'
ssh ubuntu@<MANAGER_IP> 'docker service logs levelop-wp_mysql'
```

### Scale Services
```bash
ssh ubuntu@<MANAGER_IP> 'docker service scale levelop-wp_wordpress=5'
```

### Update Service
```bash
ssh ubuntu@<MANAGER_IP> 'docker service update --image wordpress:latest levelop-wp_wordpress'
```

## 🔄 Workflows

### GitHub Actions Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `main-deployment.yml` | Push to main | Full deployment pipeline |
| `pr-validation.yml` | PR to dev/main | Validation and testing |
| `infrastructure.yml` | Manual | Standalone infra operations |
| `infrastructure-cleanup.yml` | Manual | Destroy infrastructure |
| `deploy.yml` | Manual | Standalone deployment |

### Deployment Pipeline

```
Push to main
    ↓
Validations (tests, linting, compliance)
    ↓
Infrastructure (Terraform + Ansible)
    ↓
Deployment (Docker stacks)
    ↓
Verification
```

## 🔒 Security

- **SSH Hardening** - Key-only auth, root login disabled
- **UFW Firewall** - Minimal open ports
- **Docker Secrets** - Encrypted credential storage
- **Security Groups** - Network access control
- **Encrypted Volumes** - EBS encryption enabled
- **fail2ban** - Brute force protection
- **Auto Updates** - Security patches applied automatically

## 📁 Directory Structure

```
.
├── deploy.sh                 # One-command deployment
├── validate.sh               # Pre-flight validation
├── destroy.sh                # Infrastructure cleanup
├── README.md                 # This file
│
├── .github/workflows/        # CI/CD workflows
│   ├── main-deployment.yml   # Main pipeline
│   ├── pr-validation.yml     # PR checks
│   ├── infrastructure.yml    # Infra operations
│   └── infrastructure-cleanup.yml
│
├── infra/                    # Infrastructure code
│   ├── terraform/            # AWS provisioning
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── vpc.tf
│   │   ├── ec2.tf
│   │   ├── security-groups.tf
│   │   └── setup-backend.sh
│   │
│   └── ansible/              # Configuration management
│       ├── playbooks/
│       ├── roles/
│       │   ├── docker-engine/
│       │   ├── security-hardening/
│       │   ├── swarm-init/
│       │   └── swarm-secrets/
│       └── inventory/
│
├── stack-app/                # WordPress stack
│   └── docker-stack.yml
│
├── stack-monitoring/         # Monitoring stack
│   ├── monitoring-stack.yml
│   ├── prometheus.yml
│   ├── alert.rules.yml
│   └── alertmanager.yml
│
├── tests/                    # Validation tests
│   ├── test_infrastructure.py
│   └── test_repo.py
│
└── docs/                     # Documentation
    ├── DEPLOYMENT_GUIDE.md
    ├── INFRASTRUCTURE_GUIDE.md
    ├── MONITORING_GUIDE.md
    └── SECURITY_HARDENING.md
```

## 🧪 Testing

### Run Validation
```bash
./validate.sh
```

### Run Tests
```bash
pytest tests/ -v
```

### Syntax Check
```bash
# Terraform
cd infra/terraform
terraform validate

# Ansible
cd infra/ansible
ansible-playbook playbooks/site.yml --syntax-check

# Docker Compose
docker compose -f stack-app/docker-stack.yml config
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) | Detailed deployment instructions |
| [INFRASTRUCTURE_GUIDE.md](docs/INFRASTRUCTURE_GUIDE.md) | Infrastructure architecture |
| [MONITORING_GUIDE.md](docs/MONITORING_GUIDE.md) | Monitoring setup and dashboards |
| [SECURITY_HARDENING.md](docs/SECURITY_HARDENING.md) | Security best practices |
| [IDEMPOTENT_INFRASTRUCTURE.md](infra/IDEMPOTENT_INFRASTRUCTURE.md) | Idempotency details |
| [Ansible README](infra/ansible/README.md) | Ansible configuration |
| [Terraform QUICK_START](infra/terraform/QUICK_START.md) | Terraform quick start |

## 🗑️ Cleanup

### Destroy Everything
```bash
./destroy.sh
```

### Or manually:
```bash
cd infra/terraform
terraform destroy
```

### Post-Cleanup
- Verify in AWS Console all resources deleted
- Check for orphaned EBS snapshots
- Remove GitHub secrets if not reusing

## 🐛 Troubleshooting

### SSH Connection Fails
```bash
# Check security group
# Verify SSH key is correct
chmod 600 ~/.ssh/id_rsa
ssh -i ~/.ssh/id_rsa ubuntu@<MANAGER_IP>
```

### Terraform Errors
```bash
# Re-initialize
terraform init -reconfigure

# Check state
terraform state list

# Import existing resources
terraform import aws_vpc.main vpc-xxxxx
```

### Ansible Fails
```bash
# Test connectivity
ansible all -m ping -i inventory/hosts.ini

# Run with verbosity
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -vvv
```

### Service Not Starting
```bash
# Check service status
docker service ps <service_name> --no-trunc

# View logs
docker service logs <service_name>

# Inspect service
docker service inspect <service_name>
```

## 💰 Cost Estimate

AWS resources (us-east-1):
- EC2 instances (3x t3.medium): ~$100/month
- EBS volumes (3x 30GB): ~$9/month
- NAT Gateway: ~$32/month
- Data transfer: Variable

**Total: ~$150/month** (can be reduced with Reserved Instances)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📝 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Acknowledgments

- Docker Swarm documentation
- Terraform AWS provider
- Ansible community
- Prometheus & Grafana projects

## 📞 Support

- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)
- **Documentation**: [docs/](docs/)

---

**Made with ❤️ for production deployments**

**Quick Links:**
- [Deploy Now](#quick-start)
- [View Workflows](.github/workflows/)
- [Read Docs](docs/)
- [Report Issue](../../issues/new)
