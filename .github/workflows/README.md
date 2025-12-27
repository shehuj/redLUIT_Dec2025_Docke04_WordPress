# GitHub Actions Workflows Documentation

This directory contains all GitHub Actions workflows for the WordPress on Docker Swarm project. The workflow system implements a **fully automated, two-stage CI/CD pipeline** that separates infrastructure provisioning from application deployment for safety, cost efficiency, and clarity.

## Workflow Architecture

### Two-Stage Pipeline Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline Flow                       │
└─────────────────────────────────────────────────────────────┘

PR to 'dev' Branch                    Merge to 'main' Branch
       │                                       │
       ▼                                       ▼
┌──────────────────┐                  ┌──────────────────┐
│  Validate Code   │                  │ Check Infra      │
│  - Tests         │                  │ Exists           │
│  - Terraform fmt │                  │                  │
│  - Ansible syntax│                  └─────────┬────────┘
└────────┬─────────┘                            │
         │                                      ▼
         ▼                            ┌──────────────────┐
┌──────────────────┐                  │ Deploy           │
│ Provision Infra  │                  │ Monitoring Stack │
│ - Terraform      │                  │                  │
│ - Generate keys  │                  └─────────┬────────┘
└────────┬─────────┘                            │
         │                                      ▼
         ▼                            ┌──────────────────┐
┌──────────────────┐                  │ Deploy           │
│ Configure Swarm  │                  │ WordPress Stack  │
│ - Ansible        │                  │                  │
│ - Join workers   │                  └─────────┬────────┘
└────────┬─────────┘                            │
         │                                      ▼
         ▼                            ┌──────────────────┐
┌──────────────────┐                  │ Health Check     │
│ Comment PR       │                  │ & Rollback       │
│ ✅ Ready         │                  └──────────────────┘
└──────────────────┘

PR Closed
    │
    ▼
┌──────────────────┐
│ Cleanup Infra    │
│ - Destroy all    │
│ - Stop costs     │
└──────────────────┘
```

## Primary Workflows

### 1. `pr-dev-provision.yml` - Infrastructure Provisioning

**Trigger:** Pull request to `dev` branch (opened, synchronize, reopened)

**Purpose:** Provision AWS infrastructure and configure Docker Swarm cluster

**Duration:** 10-15 minutes

**What it does:**
1. **Validate** (1-2 min)
   - Run pytest tests
   - Check Terraform formatting
   - Validate Ansible syntax
   - Ensure code quality

2. **Provision Infrastructure** (5-7 min)
   - Setup Terraform backend (S3 + DynamoDB)
   - Run `terraform apply` to create:
     - VPC with public subnets
     - 1 Manager + 2 Worker EC2 instances
     - Security groups
     - Auto-generate .pem SSH keys
   - Upload SSH key as artifact

3. **Configure Swarm** (3-5 min)
   - Wait for instances to boot
   - Run Ansible playbook:
     - Install Docker
     - Configure UFW firewall
     - Setup SSH hardening
     - Initialize Swarm on manager
     - Join workers to Swarm
   - Verify cluster health

4. **PR Comments**
   - ✅ Success: Manager IP, SSH instructions, next steps
   - ❌ Failure: Error details, troubleshooting steps

**Outputs:**
- Infrastructure ready for stack deployment
- SSH key available as artifact (7-day retention)
- Manager/Worker IPs saved
- Swarm cluster operational

**Manual trigger:** Available via `workflow_dispatch` with `force_recreate` option

**Idempotency:** Safe to re-run; Terraform detects changes, Ansible is idempotent

---

### 2. `main-deploy-stacks.yml` - Application Stack Deployment

**Trigger:**
- Push to `main` branch
- Changes to `stack-app/**` or `stack-monitoring/**`

**Purpose:** Deploy application stacks to existing infrastructure

**Duration:** 5-8 minutes

**Prerequisites:** Infrastructure must exist (provisioned via PR to dev)

**What it does:**
1. **Pre-flight Checks** (30 sec)
   - Verify infrastructure exists
   - Get manager IP from Terraform state
   - Retrieve SSH key
   - **Fails if no infrastructure found**

2. **Validate Stacks** (15 sec)
   - Check YAML syntax
   - Verify required secrets configured

3. **Deploy Monitoring** (2-3 min)
   - Copy stack files to manager
   - Create Slack webhook secret
   - Deploy monitoring stack:
     - Prometheus
     - Grafana
     - AlertManager
     - cAdvisor (global)
     - Node Exporter (global)
   - Verify services are running

4. **Deploy Application** (3-5 min)
   - Copy stack files to manager
   - Create database secrets
   - Deploy WordPress stack:
     - MySQL database (1 replica)
     - WordPress (3 replicas)
   - Verify services are running

5. **Health Check & Rollback** (1 min)
   - Check all services are healthy
   - If any service fails:
     - Automatically rollback failed services
     - Report error
   - Generate deployment summary

**Outputs:**
- WordPress URL: `http://<manager_ip>`
- Grafana URL: `http://<manager_ip>:3000` (admin/admin)
- Prometheus URL: `http://<manager_ip>:9090`
- Service health status

**Manual trigger:** Available via `workflow_dispatch` with options:
- `deploy_monitoring` - Deploy monitoring stack (default: true)
- `deploy_app` - Deploy application stack (default: true)

**Idempotency:** Docker stack deploy updates existing services, secrets only created if missing

---

### 3. `pr-dev-cleanup.yml` - Infrastructure Cleanup

**Trigger:**
- PR to `dev` closed
- Manual `workflow_dispatch`

**Purpose:** Automatically teardown infrastructure to save costs

**Duration:** 3-5 minutes

**What it does:**
1. **Confirm Cleanup**
   - Auto-confirm if PR closed
   - Require "DESTROY" input if manual

2. **Destroy Infrastructure** (3-5 min)
   - Run `terraform destroy`
   - Remove all AWS resources:
     - EC2 instances
     - VPC and subnets
     - Security groups
     - SSH key pairs
   - Verify complete destruction

3. **Comment PR**
   - ✅ Resources destroyed
   - 💰 Costs stopped
   - State preserved in S3

**Manual trigger:** Type `DESTROY` to confirm

**Cost Impact:**
- Stops ~$110/month infrastructure costs
- Terraform state preserved for audit

---

### 4. `pr-validation.yml` - PR Validation (All Branches)

**Trigger:** Pull request to any branch

**Purpose:** Quick validation of code changes without provisioning

**Duration:** 2-3 minutes

**What it does:**
- Python linting and testing
- Terraform format check
- Ansible syntax validation
- Repository structure checks

**Use case:** Validates PRs to branches other than dev (e.g., feature → feature merges)

---

### 5. `infrastructure.yml` - Manual Infrastructure Operations

**Trigger:** Manual `workflow_dispatch` only

**Purpose:** Standalone infrastructure operations for manual control

**Use cases:**
- Manual infrastructure testing
- Emergency infrastructure changes
- One-off provisioning

**Note:** For normal deployments, use the PR-based workflow instead

---

## Required GitHub Secrets

Configure these in your GitHub repository (Settings → Secrets → Actions):

### AWS Credentials
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `AWS_REGION` - AWS region (e.g., us-east-1)

### Application Secrets
- `MYSQL_ROOT_PASSWORD` - MySQL root password
- `MYSQL_PASSWORD` - WordPress database password
- `SLACK_WEBHOOK_URL` - Slack webhook for AlertManager (optional)

**Note:** SSH keys are automatically generated by Terraform. No need to provide SSH_PUBLIC_KEY or SSH_PRIVATE_KEY!

## Workflow Decision Tree

```
┌─────────────────────────────────────┐
│ What do you want to do?             │
└─────────────────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    v                         v
┌─────────────┐       ┌─────────────┐
│ Provision   │       │ Deploy      │
│ Infra       │       │ Stacks      │
└─────────────┘       └─────────────┘
    │                         │
    v                         v
Create PR to dev        Merge to main
    │                         │
pr-dev-provision.yml   main-deploy-stacks.yml
    │                         │
    ├─ Validate              ├─ Preflight check
    ├─ Provision             ├─ Deploy monitoring
    ├─ Configure Swarm       ├─ Deploy WordPress
    └─ Comment PR            └─ Health check


┌──────────────────────────────┐
│ Done testing?                 │
└──────────────────────────────┘
         │
         v
   Close dev PR
         │
         v
pr-dev-cleanup.yml
         │
         └─ Destroy all → Stop costs
```

## Development Workflow

### Standard Development Flow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes
# Edit files...

# 3. Create PR to dev
git push origin feature/my-feature
# Create PR: feature/my-feature → dev

# 4. Wait for infrastructure provisioning (10-15 min)
# ✅ pr-dev-provision.yml runs automatically
# ✅ PR comment with manager IP and SSH instructions

# 5. Test changes (optional)
# Download SSH key from workflow artifacts
ssh -i swarm-key.pem ubuntu@<manager_ip>

# 6. Merge to main to deploy stacks
# Create PR: dev → main
# ✅ main-deploy-stacks.yml runs automatically
# ✅ Monitoring + WordPress deployed

# 7. Verify deployment
# WordPress: http://<manager_ip>
# Grafana: http://<manager_ip>:3000

# 8. Close dev PR when done
# ✅ pr-dev-cleanup.yml runs automatically
# 💰 Infrastructure destroyed, costs stopped
```

### Quick Deployment (Main Only)

If infrastructure already exists from a previous PR:

```bash
# Just push to main
git checkout main
git merge dev
git push origin main

# ✅ Stacks deploy to existing infrastructure
```

## Idempotency Guarantees

All workflows are designed to be **idempotent** - safe to run multiple times.

### Terraform Idempotency
- Uses `-detailed-exitcode` to detect changes
- Only applies when changes detected
- Safe to re-run provisioning workflow

### Ansible Idempotency
- All playbooks use idempotent modules
- Checks current state before making changes
- Safe to re-run configuration

### Docker Secrets Idempotency
```bash
# Only create if doesn't exist
docker secret ls | grep -q mysql_password || \
  echo "$PASSWORD" | docker secret create mysql_password -
```

### Docker Stack Deployment Idempotency
- `docker stack deploy` updates existing services
- Doesn't recreate services unnecessarily
- Safe to re-deploy stacks

## Error Handling

### Automatic Retry Logic

**Infrastructure Provisioning:**
- SSH connection retry (2 attempts, 30s delay)
- Ansible playbook retry on failure
- Swarm join retry (6 attempts, 10s delay)

**Stack Deployment:**
- Service health check retry (12-18 attempts, 10s delay)
- Automatic rollback on service failure

### Graceful Failures

**Infrastructure Stage:**
- ❌ Terraform validation fails → Stop, report error
- ❌ Terraform apply fails → Stop, preserve state
- ❌ Ansible fails → Retry once, then fail
- ❌ Swarm join fails → Reset error state, retry

**Deployment Stage:**
- ❌ Stack validation fails → Stop, report error
- ❌ Service fails to start → Rollback to previous version
- ❌ Health check fails → Report, attempt rollback

## Cost Management

### Active Infrastructure Costs
- **During PR Review:** ~$110/month (prorated)
- **PR Open 1 day:** ~$3.67
- **PR Open 1 week:** ~$25.67

### Automatic Cost Control
- ✅ Infrastructure destroyed when PR closes
- ✅ No lingering resources
- ✅ State preserved in S3 for audit

## Troubleshooting

### Validation Failures
```bash
# Check workflow logs in GitHub Actions
# Fix issues locally and push again
# Validations run on every push to PR
```

### Infrastructure Provisioning Failures
```bash
# 1. Verify AWS credentials in secrets
# 2. Check AWS service quotas
# 3. Review Terraform state in S3
# 4. Check workflow logs for specific errors
# 5. Re-run workflow or push new commit
```

### Deployment Failures
```bash
# 1. Verify infrastructure exists (PR to dev must be open)
# 2. Check manager IP is accessible
# 3. Download SSH key from artifacts
# 4. Manually check services:
ssh -i swarm-key.pem ubuntu@<manager_ip>
docker service ls
docker service logs <service_name>
```

### Cleanup Issues
```bash
# If automatic cleanup fails:
# 1. Manually trigger pr-dev-cleanup.yml
# 2. Type "DESTROY" to confirm
# 3. Or manually destroy:
cd infra/terraform
terraform destroy
```

## Monitoring Workflow Runs

1. **GitHub Actions Tab** - View all workflow runs
2. **PR Checks** - See status directly in PR
3. **PR Comments** - Automatic updates on provision/cleanup
4. **Artifacts** - Download SSH keys (7-day retention)
5. **Job Summaries** - Detailed deployment reports

## Best Practices

### For Development
1. Always create PR to `dev` first for infrastructure changes
2. Wait for validation to pass before reviewing
3. Test infrastructure before merging to main
4. Close PR promptly after testing to stop costs

### For Production
1. Merge `dev → main` only after thorough testing
2. Monitor deployment workflow logs
3. Verify health checks pass
4. Keep infrastructure PR open if ongoing testing needed

### For Cost Optimization
1. Close dev PRs when not actively testing
2. Use manual trigger for one-off tests
3. Leverage idempotency - re-run failed workflows safely
4. Monitor AWS costs in CloudWatch

## Documentation

For detailed information, see:
- [CI/CD Workflow Guide](../../docs/CI_CD_WORKFLOW.md) - Comprehensive pipeline documentation
- [Infrastructure Guide](../../docs/INFRASTRUCTURE_GUIDE.md) - Infrastructure architecture
- [Deployment Guide](../../docs/DEPLOYMENT_GUIDE.md) - Deployment procedures
- [Main README](../../README.md) - Project overview

## Support

For issues or questions:
1. Check workflow run logs in GitHub Actions
2. Review this documentation
3. Check [CI/CD Workflow Guide](../../docs/CI_CD_WORKFLOW.md)
4. Open an issue with workflow details
