# CI/CD Workflow Architecture

## Overview

This repository implements a fully automated, two-stage CI/CD pipeline that separates infrastructure provisioning from application deployment for safety, cost efficiency, and clarity.

## Workflow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CI/CD Pipeline Flow                          │
└─────────────────────────────────────────────────────────────────┘

 PR to 'dev' Branch                    Merge to 'main' Branch
        │                                       │
        ▼                                       ▼
┌───────────────────┐                  ┌───────────────────┐
│  Validate Code    │                  │ Check Infra       │
│  - Tests          │                  │ Exists            │
│  - Linting        │                  │                   │
│  - Terraform fmt  │                  └─────────┬─────────┘
│  - Ansible syntax │                            │
└─────────┬─────────┘                            │ Infrastructure
          │                                      │ Must Exist!
          ▼                                      ▼
┌───────────────────┐                  ┌───────────────────┐
│ Provision         │                  │ Validate Stacks   │
│ Infrastructure    │                  │ - YAML syntax     │
│ - Terraform apply │                  │ - Secrets check   │
│ - Create VPC      │                  └─────────┬─────────┘
│ - Launch EC2      │                            │
└─────────┬─────────┘                            ▼
          │                            ┌───────────────────┐
          ▼                            │ Deploy Monitoring │
┌───────────────────┐                  │ - Prometheus      │
│ Configure Swarm   │                  │ - Grafana         │
│ - Install Docker  │                  │ - AlertManager    │
│ - Setup UFW       │                  └─────────┬─────────┘
│ - Init Swarm      │                            │
│ - Join workers    │                            ▼
└─────────┬─────────┘                  ┌───────────────────┐
          │                            │ Deploy WordPress  │
          ▼                            │ - MySQL           │
┌───────────────────┐                  │ - WordPress       │
│ Comment PR        │                  │ - Create secrets  │
│ ✅ Ready to merge │                  └─────────┬─────────┘
└───────────────────┘                            │
                                                 ▼
                                       ┌───────────────────┐
                                       │ Health Check      │
                                       │ - Verify services │
                                       │ - Rollback on fail│
                                       └─────────┬─────────┘
                                                 │
 PR Closed                                       ▼
        │                              ┌───────────────────┐
        ▼                              │ Summary Report    │
┌───────────────────┐                  │ ✅ Deployment OK  │
│ Cleanup Infra     │                  └───────────────────┘
│ - Terraform       │
│   destroy         │
│ - Comment PR      │
└───────────────────┘
```

## Workflows

### 1. PR to Dev - Infrastructure Provisioning

**File:** `.github/workflows/pr-dev-provision.yml`

**Trigger:** Pull request to `dev` branch

**Purpose:** Provision and validate infrastructure before deployment

**Stages:**

1. **Validate (1-2 min)**
   - Run pytest tests
   - Check Terraform formatting
   - Validate Ansible syntax
   - Ensure code quality

2. **Provision Infrastructure (5-7 min)**
   - Setup Terraform backend (S3 + DynamoDB)
   - Run `terraform apply` to create:
     - VPC with public subnets
     - 1 Manager + 2 Worker EC2 instances
     - Security groups
     - SSH key pairs (.pem)
   - Generate and upload SSH key artifact
   - Generate Ansible inventory

3. **Configure Swarm (3-5 min)**
   - Wait for instances to boot
   - Run Ansible playbook to:
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
- SSH key available as artifact
- Manager/Worker IPs saved
- Swarm cluster operational

### 2. Main - Deploy Application Stacks

**File:** `.github/workflows/main-deploy-stacks.yml`

**Trigger:**
- Push to `main` branch (after PR merge)
- Changes to `stack-app/**` or `stack-monitoring/**`

**Purpose:** Deploy application stacks to existing infrastructure

**Stages:**

1. **Pre-flight Checks (30 sec)**
   - Verify infrastructure exists
   - Get manager IP from Terraform state
   - Retrieve SSH key
   - Fail if no infrastructure found

2. **Validate Stacks (15 sec)**
   - Check YAML syntax
   - Verify required secrets configured
   - Validate stack definitions

3. **Deploy Monitoring (2-3 min)**
   - Copy stack files to manager
   - Create Slack webhook secret
   - Deploy monitoring stack:
     - Prometheus
     - Grafana
     - AlertManager
     - cAdvisor
     - Node Exporter
   - Verify services are running

4. **Deploy Application (3-5 min)**
   - Copy stack files to manager
   - Create database secrets
   - Deploy WordPress stack:
     - MySQL database
     - WordPress (3 replicas)
   - Verify services are running

5. **Health Check & Rollback (1 min)**
   - Check all services are healthy
   - If any service fails:
     - Automatically rollback failed services
     - Report error
   - Generate deployment summary

**Outputs:**
- WordPress URL
- Grafana URL (port 3000)
- Prometheus URL (port 9090)
- Service health status

### 3. PR Closed - Cleanup Infrastructure

**File:** `.github/workflows/pr-dev-cleanup.yml`

**Trigger:** PR to `dev` closed

**Purpose:** Automatically teardown infrastructure to save costs

**Stages:**

1. **Confirm Cleanup**
   - Auto-confirm if PR closed
   - Require "DESTROY" input if manual

2. **Destroy Infrastructure (3-5 min)**
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
- ❌ Terraform apply fails → Stop, report error, preserve state
- ❌ Ansible fails → Retry once, then fail with details
- ❌ Swarm join fails → Reset error state, retry

**Deployment Stage:**
- ❌ Stack validation fails → Stop, report error
- ❌ Service fails to start → Rollback to previous version
- ❌ Health check fails → Report, attempt rollback

### Manual Intervention

If automation fails, you can:

1. **Check workflow logs:** Detailed error messages in GitHub Actions
2. **SSH to manager:** Download key artifact, connect manually
3. **Run fix script:** `./fix-ufw.sh` for common issues
4. **Manual cleanup:** `terraform destroy` if auto-cleanup fails

## Cost Management

### Active Infrastructure Costs
- **During PR Review:** ~$110/month (prorated for PR duration)
- **PR Open 1 day:** ~$3.67
- **PR Open 1 week:** ~$25.67

### Automatic Cost Control
- ✅ Infrastructure destroyed when PR closes
- ✅ No lingering resources
- ✅ State preserved for audit

### Manual Cost Control
```bash
# List active resources
terraform state list

# Manually destroy
terraform destroy

# Check AWS Console
# Verify no orphaned resources
```

## Idempotency

All operations are idempotent:

- ✅ **Terraform:** Detects changes, only applies differences
- ✅ **Ansible:** Checks state, only modifies if needed
- ✅ **Docker Swarm:** Joins only if not already active
- ✅ **Stack Deploy:** Updates existing stacks without recreation

Safe to run multiple times!

## Best Practices

### Development Workflow

```bash
# 1. Create feature branch from main
git checkout -b feature/my-feature main

# 2. Make changes to stacks or code
# Edit stack-app/docker-stack.yml or stack-monitoring/monitoring-stack.yml

# 3. Create PR to dev for infrastructure testing
git push origin feature/my-feature
# Create PR: feature/my-feature → dev

# 4. Wait for infrastructure provisioning (10-15 min)
# Check PR comments for manager IP

# 5. Test changes (if needed)
# Download SSH key from artifacts
ssh -i swarm-key.pem ubuntu@MANAGER_IP

# 6. Merge PR to dev (optional intermediate step)
# Infrastructure stays active

# 7. Create PR from dev to main for production
# Create PR: dev → main

# 8. Merge to main
# Stacks automatically deploy to existing infrastructure

# 9. Close dev PR to cleanup infrastructure
# Infrastructure automatically destroyed
```

### Emergency Procedures

**Failed Deployment:**
```bash
# 1. Check service logs
ssh -i swarm-key.pem ubuntu@MANAGER_IP
docker service logs levelop-wp_wordpress
docker service logs levelop-wp_mysql

# 2. Manual rollback
docker service rollback levelop-wp_wordpress
docker service rollback levelop-wp_mysql

# 3. Remove stack and redeploy
docker stack rm levelop-wp
sleep 30
docker stack deploy -c docker-stack.yml levelop-wp
```

**Stuck Infrastructure:**
```bash
# 1. Check Terraform state
cd infra/terraform
terraform state list

# 2. Force destroy specific resource
terraform destroy -target=aws_instance.swarm_worker[0]

# 3. Full destroy
terraform destroy

# 4. Clean state (last resort)
terraform state rm <resource>
```

## Monitoring the Pipeline

### GitHub Actions UI
- **Actions tab:** View all workflow runs
- **PR checks:** See status directly in PR
- **Artifacts:** Download SSH keys, logs
- **Summary:** Quick overview of results

### PR Comments
- Automatically posted on:
  - Infrastructure provisioned ✅
  - Infrastructure failed ❌
  - Cleanup complete 🗑️

### Logs
- Detailed logs for each job
- Service health checks
- Terraform plan/apply output
- Ansible playbook verbose output

## Security Considerations

### Secrets Management
- **GitHub Secrets:** Store AWS credentials, passwords
- **Docker Secrets:** Store at runtime on Swarm
- **SSH Keys:** Generated per deployment, expired after 7 days

### Network Security
- Security groups limit access
- UFW firewall on all nodes
- SSH key-only authentication
- VPC isolation

### Audit Trail
- All changes tracked in git
- Terraform state in S3 with versioning
- DynamoDB state locking
- GitHub Actions logs preserved

## Troubleshooting

See the [Troubleshooting Guide](TROUBLESHOOTING.md) for common issues and solutions.
