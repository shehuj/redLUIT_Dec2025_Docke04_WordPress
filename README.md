# WordPress on Docker Swarm - Production Infrastructure

[![PR Validation](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/pr-validation.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/pr-validation.yml)
[![Deploy](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/main-deployment.yml/badge.svg)](https://github.com/YOUR_USERNAME/YOUR_REPO/actions/workflows/main-deployment.yml)

Production-ready WordPress deployment on AWS using Docker Swarm, Terraform, and Ansible with comprehensive security scanning and validation.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS VPC                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                  Public Subnets                       │  │
│  │                                                       │  │
│  │  ┌─────────────────┐                                 │  │
│  │  │  Swarm Manager  │◄───── SSH (restricted)          │  │
│  │  │  - Docker Swarm │                                 │  │
│  │  │  - Secrets      │                                 │  │
│  │  └────────┬────────┘                                 │  │
│  │           │                                          │  │
│  │           │ Swarm Management                         │  │
│  │           │                                          │  │
│  │  ┌────────▼────────┐     ┌─────────────────┐        │  │
│  │  │  Swarm Worker 1 │     │  Swarm Worker 2 │        │  │
│  │  │  - WordPress    │     │  - WordPress    │        │  │
│  │  │  - MySQL        │     │  - MySQL        │        │  │
│  │  └─────────────────┘     └─────────────────┘        │  │
│  │           │                       │                  │  │
│  │           └───────────┬───────────┘                  │  │
│  │                       │                              │  │
│  │                       ▼                              │  │
│  │                  HTTP/HTTPS                          │  │
│  │                (Port 80/443)                         │  │
│  └───────────────────────────────────────────────────────┘  │
│                         │                                    │
│                         ▼                                    │
│                   Internet Gateway                           │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
                    Public Internet
```

## Features

### Infrastructure
- **AWS Infrastructure**: Fully automated with Terraform
  - VPC with public subnets across multiple AZs
  - EC2 instances with encrypted EBS volumes
  - Security groups with least-privilege access
  - Auto-generated SSH keys
  - S3 backend with state locking

- **Docker Swarm Cluster**:
  - 1 manager node + 2 worker nodes
  - High availability with 3 WordPress replicas
  - MySQL with persistent storage
  - Overlay networks for service communication
  - Docker secrets for credential management

### Security
- **Hardened SSH**: Password auth disabled, key-only access
- **fail2ban**: Automatic IP blocking after failed attempts
- **UFW Firewall**: Restrictive rules, VPC-only traffic allowed
- **Encrypted Storage**: EBS volumes encrypted at rest
- **Secrets Management**: Docker secrets for sensitive data
- **Security Scanning**: 
  - Trivy for vulnerability scanning
  - TruffleHog for secret detection
  - Semgrep for SAST
  - OWASP dependency checking

### CI/CD
- **PR Validation Workflow**:
  - YAML syntax validation
  - Terraform validation & format check
  - Ansible syntax check & linting
  - Python tests with pytest
  - Shell script validation with shellcheck
  - Trivy security scans (filesystem + Docker images)
  - Secret scanning with TruffleHog
  - Static Application Security Testing (SAST)

- **Main Deployment Workflow**:
  - Automated infrastructure provisioning
  - Ansible configuration management
  - WordPress + MySQL stack deployment
  - Comprehensive deployment summary

## Prerequisites

- AWS Account with appropriate permissions
- GitHub repository with secrets configured
- Terraform >= 1.6.0
- Ansible >= 2.15.0
- Python >= 3.11

## Quick Start

### 1. Fork and Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

### 2. Configure GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtn...` |
| `MYSQL_ROOT_PASSWORD` | MySQL root password | `SuperSecureRootPass123!` |
| `MYSQL_PASSWORD` | WordPress DB password | `SecureDBPass456!` |

### 3. Configure Terraform Variables

1. Copy the example variables file:
   ```bash
   cp infra/terraform/terraform.tfvars.example infra/terraform/terraform.tfvars
   ```

2. Edit `terraform.tfvars`:
   ```hcl
   aws_region = "us-east-1"
   project_name = "wordpress-swarm"
   
   # CRITICAL: Update with YOUR IP address
   # Find your IP: curl ifconfig.me
   allowed_ssh_cidrs = ["YOUR.IP.ADDRESS/32"]
   ```

3. **IMPORTANT**: Update the S3 backend bucket name in both files:
   - `infra/terraform/backend.tf`
   - `infra/terraform/setup-backend.sh`
   
   Choose a globally unique name (e.g., `yourcompany-wordpress-terraform-state`)

### 4. Deploy via GitHub Actions

#### Option A: Deploy on PR Merge (Recommended)

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-changes
   ```

2. Make changes and push:
   ```bash
   git add .
   git commit -m "My changes"
   git push origin feature/my-changes
   ```

3. Create a Pull Request to `main`
   - GitHub Actions will run all validation and security scans
   - Review the results in the PR checks

4. Merge the PR
   - Automatic deployment to AWS will begin
   - Monitor progress in Actions tab

#### Option B: Manual Deployment

1. Go to **Actions** tab in GitHub
2. Select **Deploy WordPress Infrastructure**
3. Click **Run workflow**
4. Choose `deploy` action
5. Monitor deployment progress

### 5. Access WordPress

After deployment completes:

1. Find the manager IP in the GitHub Actions summary
2. Access WordPress:
   ```
   http://MANAGER_IP
   ```
3. Complete WordPress installation wizard

## Manual Deployment (Local)

### Prerequisites

```bash
# Install required tools
brew install terraform ansible python@3.11  # macOS
# or
sudo apt install terraform ansible python3.11  # Ubuntu
```

### Step 1: Setup Terraform Backend

```bash
cd infra/terraform
./setup-backend.sh
```

### Step 2: Provision Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Configure Swarm Cluster

```bash
cd ../ansible

# Extract SSH key
terraform output -raw private_key > ~/.ssh/swarm-key.pem
chmod 600 ~/.ssh/swarm-key.pem

# Generate inventory
terraform output -raw ansible_inventory > inventory/hosts.ini

# Run Ansible
ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

### Step 4: Deploy WordPress Stack

```bash
# SSH to manager
MANAGER_IP=$(terraform output -raw manager_public_ip)
ssh -i ~/.ssh/swarm-key.pem ubuntu@$MANAGER_IP

# Create secrets
echo "your_root_password" | docker secret create mysql_root_password -
echo "your_db_password" | docker secret create mysql_password -

# Deploy stack
docker stack deploy -c /path/to/docker-stack.yml wordpress

# Verify
docker service ls
docker stack ps wordpress
```

## Security Best Practices

### Before Production

- [ ] Update `allowed_ssh_cidrs` with specific IP addresses (NEVER use `0.0.0.0/0`)
- [ ] Use strong passwords for MySQL (min 16 chars, mixed case, numbers, special chars)
- [ ] Implement SSL/TLS certificates (Let's Encrypt or AWS Certificate Manager)
- [ ] Set up CloudFront for CDN and DDoS protection
- [ ] Configure automated backups to S3
- [ ] Enable AWS CloudTrail for audit logging
- [ ] Implement AWS Backup for disaster recovery
- [ ] Use AWS Secrets Manager for secrets rotation
- [ ] Set up CloudWatch alarms for monitoring
- [ ] Configure VPC Flow Logs

### Ongoing Maintenance

- [ ] Regularly update Docker images for security patches
- [ ] Monitor fail2ban logs for attack attempts
- [ ] Review security scan results in PR checks
- [ ] Rotate secrets every 90 days
- [ ] Test disaster recovery procedures quarterly
- [ ] Monitor AWS billing for unexpected costs
- [ ] Keep Terraform and Ansible versions current

## CI/CD Workflow Details

### Pull Request Workflow

When you open a PR, the following checks run automatically:

1. **YAML Validation**: Validates all YAML syntax
2. **Terraform Validation**: Checks Terraform configuration
3. **Ansible Validation**: Validates Ansible playbooks and roles
4. **Security Scans**:
   - Trivy scans filesystem and Docker images
   - TruffleHog scans for leaked secrets
   - Semgrep performs static analysis
5. **Tests**: Runs Python tests with pytest
6. **Shell Script Validation**: Shellcheck for bash scripts

**All checks must pass before merging!**

### Main Deployment Workflow

On merge to `main`:

1. **Terraform Apply**: Provisions AWS infrastructure
2. **Ansible Configure**: Configures Swarm cluster
3. **Deploy WordPress**: Deploys Docker stack
4. **Summary**: Provides access URLs and status

## Troubleshooting

### Deployment Fails at Terraform Step

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check Terraform state
cd infra/terraform
terraform state list

# Force unlock if stuck
terraform force-unlock LOCK_ID
```

### Ansible Connection Issues

```bash
# Test SSH connectivity
ssh -i ~/.ssh/swarm-key.pem ubuntu@MANAGER_IP

# Verify security group allows SSH from your IP
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

### WordPress Not Accessible

```bash
# SSH to manager
ssh -i ~/.ssh/swarm-key.pem ubuntu@MANAGER_IP

# Check services
docker service ls
docker service ps wordpress_wordpress
docker service logs wordpress_wordpress

# Check firewall
sudo ufw status
```

### MySQL Connection Errors

```bash
# Check MySQL service
docker service ps wordpress_mysql
docker service logs wordpress_mysql

# Verify secrets exist
docker secret ls

# Recreate secrets if needed
docker secret rm mysql_password
echo "new_password" | docker secret create mysql_password -
docker service update --secret-rm mysql_password --secret-add mysql_password wordpress_wordpress
```

## Cost Estimation

Based on us-east-1 pricing (as of 2026):

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| t3.medium EC2 | 3 | $0.0416/hr | ~$90 |
| EBS gp3 (30GB) | 3 | $0.08/GB | ~$7 |
| S3 (state) | 1 | $0.023/GB | <$1 |
| Data Transfer | ~100GB | $0.09/GB | ~$9 |
| **Total** | | | **~$107/month** |

### Cost Optimization

- Use Reserved Instances for 30-40% savings
- Use t3.small for dev environments ($0.0208/hr)
- Delete stacks when not in use
- Use `terraform destroy` workflow for cleanup

## Repository Structure

```
.
├── .github/workflows/      # CI/CD pipelines
│   ├── pr-validation.yml   # PR validation & security scans
│   └── main-deployment.yml # Main branch deployment
├── infra/
│   ├── terraform/          # AWS infrastructure
│   │   ├── main.tf
│   │   ├── vpc.tf
│   │   ├── ec2.tf
│   │   ├── security-groups.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── backend.tf
│   └── ansible/            # Configuration management
│       ├── playbooks/
│       ├── roles/
│       └── inventory/
├── stack-app/              # Docker Compose stack
│   └── docker-stack.yml    # WordPress + MySQL
├── tests/                  # Python tests
└── README.md              # This file
```

## Destroying Infrastructure

### Via GitHub Actions

1. Go to **Actions** → **Deploy WordPress Infrastructure**
2. Click **Run workflow**
3. Choose `destroy` action
4. Confirm and monitor

### Via Command Line

```bash
cd infra/terraform
terraform destroy
```

**WARNING**: This will permanently delete all resources including data!

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all tests pass locally
5. Submit a Pull Request
6. Wait for security scans to complete
7. Address any findings

## License

MIT License - See [LICENSE](LICENSE) file

## Support

- **Issues**: https://github.com/YOUR_USERNAME/YOUR_REPO/issues
- **Discussions**: https://github.com/YOUR_USERNAME/YOUR_REPO/discussions

## Security

If you discover a security vulnerability, please email security@example.com instead of using the issue tracker.

## Changelog

### v2.0.0 - Production Ready
- Removed monitoring stack (Prometheus, Grafana, AlertManager)
- Simplified to WordPress + MySQL only
- Added comprehensive security scanning to PR workflow
- Separated PR validation from deployment
- Enhanced security hardening with fail2ban
- Fixed insecure default CIDR blocks
- Added encrypted EBS volumes
- Improved documentation

### v1.0.0 - Initial Release
- Basic WordPress deployment on Docker Swarm
- Terraform + Ansible automation
- Basic CI/CD workflows
