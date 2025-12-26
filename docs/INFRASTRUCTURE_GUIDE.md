# Infrastructure Provisioning Guide

Complete guide for provisioning AWS infrastructure for the Docker Swarm cluster using Terraform and Ansible.

## Overview

The infrastructure consists of:
- **VPC**: Isolated network with public/private subnets across 2 AZs
- **EC2 Instances**: 1 manager + 2 workers (t3.medium, Ubuntu 22.04 LTS)
- **Security Groups**: Swarm communication, HTTP/HTTPS, monitoring ports
- **NAT Gateway**: Outbound internet access for private subnets

## Prerequisites

### Required GitHub Secrets

Configure these in your GitHub repository (Settings → Secrets and variables → Actions):

**AWS Credentials:**
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key

**SSH Keys:**
- `SSH_PUBLIC_KEY` - Public key for EC2 instances
- `SSH_PRIVATE_KEY` - Private key for Ansible/deployment

**Application Secrets (reused):**
- `MYSQL_ROOT_PASSWORD`
- `MYSQL_PASSWORD`
- `SLACK_WEBHOOK_URL`

## Automated Provisioning (GitHub Actions)

### Workflow Triggers

**⭐ Recommended: PR to dev branch**
1. Create PR to dev branch with infrastructure changes
2. Workflow automatically runs validation
3. If all validations pass, provisioning starts automatically
4. Review infrastructure in dev environment
5. Merge to main when ready for production

```bash
git checkout -b infra-update
# Make changes to infra/
git add infra/
git commit -m "Update infrastructure configuration"
git push origin infra-update
# Create PR to dev branch → Workflow runs automatically
```

**Production deployment:**
```bash
# After PR is approved and merged to dev
git checkout main
git merge dev
git push origin main  # Provisions production infrastructure
```

**Manual trigger:** GitHub → Actions → Infrastructure Provisioning → Run workflow

### Workflow Execution Order

```
PR to dev → validate-terraform ┐
            validate-ansible   ├─→ ALL PASS? → provision → configure
            compliance-checks  ┘
```

**Important**: Provisioning only runs after ALL validation jobs succeed.

### Workflow Jobs

1. **validate-terraform**: Validates Terraform syntax and runs plan
2. **validate-ansible**: Validates Ansible playbooks with ansible-lint
3. **compliance-checks**: Runs infrastructure compliance tests
4. **provision-infrastructure**: Provisions AWS resources (runs only after all validations pass)
5. **configure-swarm**: Configures Swarm cluster (runs only after provisioning succeeds)

### Post-Provisioning

After successful provisioning:
1. Copy manager IP from workflow output
2. Update GitHub secret: `SWARM_MANAGER_HOST` with the manager IP
3. Run deploy workflow to deploy WordPress and monitoring stacks

## Manual Provisioning

### Step 1: Configure Terraform Variables

Create `infra/terraform/terraform.tfvars`:

```hcl
aws_region         = "us-east-1"
project_name       = "wordpress-swarm"
environment        = "production"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# SECURITY: Restrict to your IP
allowed_ssh_cidrs = ["YOUR_IP/32"]

ssh_public_key = "ssh-rsa AAAAB3... your-public-key"

manager_instance_type = "t3.medium"
worker_instance_type  = "t3.medium"
worker_count          = 2
```

### Step 2: Provision Infrastructure

```bash
cd infra/terraform

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply changes
terraform apply
```

### Step 3: Generate Ansible Inventory

```bash
# Output inventory to file
terraform output -raw ansible_inventory > ../ansible/inventory/hosts.ini
```

### Step 4: Configure Swarm with Ansible

```bash
cd ../ansible

# Export secrets
export MYSQL_ROOT_PASSWORD="your-secret"
export MYSQL_PASSWORD="your-secret"
export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."

# Run playbook
ansible-playbook -i inventory/hosts.ini playbooks/site.yml -v

# Verify cluster
ssh ubuntu@<MANAGER_IP> 'docker node ls'
```

## Security Hardening

The Ansible `security-hardening` role applies:
- **SSH**: Disable password auth, disable root login, key-only access
- **Firewall (UFW)**: Allow SSH (22), Swarm ports (2377, 7946, 4789), HTTP/HTTPS (80, 443), monitoring (9090, 3000, 9093)

## Cost Estimation

**Monthly AWS costs (us-east-1):**
- 3 × t3.medium instances: ~$100
- NAT Gateway: ~$33
- Data transfer: ~$10-50
- **Total: ~$143-183/month**

## Troubleshooting

### Terraform Errors

**Invalid AWS credentials:**
```
Solution: Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY secrets
```

### Ansible Errors

**SSH connection failed:**
```
Solution:
1. Verify SSH_PRIVATE_KEY matches SSH_PUBLIC_KEY
2. Check security group allows SSH from GitHub Actions IPs
3. Wait 60s for instances to boot
```

## Infrastructure Cleanup

### ⚠️ Destroying Infrastructure (Manual Trigger Only)

The cleanup workflow destroys all provisioned AWS resources. This is a **DESTRUCTIVE** operation.

**GitHub Actions (Recommended):**

1. Navigate to: **GitHub → Actions → Infrastructure Cleanup → Run workflow**
2. Enter confirmation: Type `DESTROY` exactly
3. Select action:
   - **plan-destroy**: Show what will be destroyed (safe, no changes)
   - **destroy**: Actually destroy resources (destructive!)
4. Click "Run workflow"

**Workflow behavior:**
- Shows destroy plan with all resources to be removed
- Requires typing "DESTROY" as confirmation
- Waits 10 seconds before executing (final warning)
- Destroys all resources: EC2, VPC, security groups, key pairs
- Verifies destruction completed

**Manual cleanup with Terraform:**

```bash
cd infra/terraform

# Review what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy

# Confirm by typing: yes
```

### What Gets Destroyed

When you run cleanup, ALL of the following are permanently deleted:
- ✗ VPC and all networking (subnets, IGW, NAT gateway, route tables)
- ✗ All EC2 instances (manager + workers)
- ✗ All security groups
- ✗ SSH key pairs
- ✗ **All data on instances** (WordPress data, MySQL data, monitoring data)

### Post-Cleanup Actions

After destroying infrastructure:
1. Verify in AWS Console all resources are gone
2. Check for orphaned resources (EBS snapshots, Elastic IPs)
3. Remove `SWARM_MANAGER_HOST` from GitHub secrets
4. Clean up local Terraform state if needed:
   ```bash
   cd infra/terraform
   rm -rf .terraform terraform.tfstate*
   ```

### Cost Savings

Destroying infrastructure stops all AWS charges:
- **Before**: ~$143-183/month
- **After**: $0/month (assuming no orphaned resources)

## Next Steps

1. Update `SWARM_MANAGER_HOST` secret with manager IP
2. Run deployment workflow: `git push origin main`
3. Access services:
   - WordPress: http://<manager_ip>
   - Prometheus: http://<manager_ip>:9090
   - Grafana: http://<manager_ip>:3000
