# GitHub Actions Workflows Documentation

This directory contains all GitHub Actions workflows for the WordPress on Docker Swarm project. The workflow system is designed to be **idempotent**, **comprehensive**, and **production-ready**.

## Workflow Architecture

### Primary Workflows (Recommended)

#### 1. `pr-validation.yml` - Pull Request Validation
**Trigger:** Pull requests to `dev` branch
**Purpose:** Comprehensive validation of all changes before merging

**What it does:**
- ✅ Python linting and testing (flake8, pytest)
- ✅ Compliance checks (file structure, configurations)
- ✅ Terraform validation and planning
- ✅ Ansible syntax checking and linting
- ✅ Docker stack validation
- ✅ Summary report of all validations

**Manual trigger:** Available via workflow_dispatch

**Idempotency:** All checks are read-only and idempotent

---

#### 2. `main-deployment.yml` - Main Deployment Pipeline
**Trigger:** Merge to `main` branch
**Purpose:** Complete deployment pipeline with validations → infrastructure → deployment

**Pipeline stages:**
1. **Validations** (Stage 1)
   - Run all tests and compliance checks
   - Validate Docker stack configurations

2. **Infrastructure** (Stage 2)
   - Validate Terraform and Ansible configurations
   - Provision infrastructure (only if changes detected)
   - Configure Swarm cluster (only if infrastructure changed)

3. **Deployment** (Stage 3)
   - Build and push Docker images
   - Deploy monitoring stack
   - Deploy application stack
   - Verify deployment

**Manual trigger options:**
- `skip_tests` - Skip validation stage (not recommended)
- `skip_infra` - Skip infrastructure provisioning
- `infra_action` - Choose plan/apply/skip for infrastructure

**Idempotency features:**
- Terraform only applies when changes detected
- Ansible runs are idempotent by design
- Docker secrets only created if they don't exist
- Docker stack deploy updates existing services

---

### Standalone Workflows (For specific operations)

#### 3. `infrastructure.yml` - Infrastructure Provisioning (Standalone)
**Trigger:**
- PRs to `dev` (validation only)
- Manual workflow_dispatch

**Purpose:** Standalone infrastructure operations for testing or manual provisioning

**Manual trigger options:**
- `action` - plan/apply/destroy
- `environment` - production/staging/development

**When to use:**
- Testing infrastructure changes
- Manual infrastructure provisioning
- Emergency infrastructure operations

**Note:** For production deployments, use `main-deployment.yml` instead

---

#### 4. `deploy.yml` - Swarm Deploy + Monitoring (Standalone)
**Trigger:** Manual workflow_dispatch only

**Purpose:** Standalone deployment for testing or hotfixes

**Manual trigger options:**
- `force_rebuild` - Force rebuild and push Docker images
- `stack_to_deploy` - both/app/monitoring

**When to use:**
- Testing deployments
- Deploying only monitoring stack
- Hotfix deployments
- Rollback scenarios

**Note:** For production deployments, use `main-deployment.yml` instead

---

### Legacy Workflows (Backwards compatibility)

#### 5. `python.yml` - Python Tests (Legacy)
**Status:** Deprecated - use `pr-validation.yml` instead
**Trigger:** PRs to `dev` (limited paths), manual

#### 6. `compliance.yml` - Compliance Checks (Legacy)
**Status:** Deprecated - use `pr-validation.yml` instead
**Trigger:** PRs to `dev` (limited paths), manual

---

## Workflow Decision Tree

```
┌─────────────────────────────────────┐
│ What do you want to do?             │
└─────────────────────────────────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
    v                         v
┌─────────┐            ┌──────────┐
│ PR to   │            │ Deploy   │
│ dev     │            │ to prod  │
└─────────┘            └──────────┘
    │                         │
    v                         v
pr-validation.yml    main-deployment.yml
    │                         │
    ├─ Python tests          ├─ Run validations
    ├─ Compliance            ├─ Provision infra
    ├─ Terraform             ├─ Deploy stacks
    ├─ Ansible               └─ Verify
    └─ Docker


┌──────────────────────────────┐
│ Manual/Testing operations    │
└──────────────────────────────┘
         │
    ┌────┴─────┐
    │          │
    v          v
infrastructure.yml  deploy.yml
    │                  │
    └─ Infra only     └─ Deploy only
```

## Idempotency Guarantees

All workflows are designed to be **idempotent** - they can be run multiple times with the same result.

### Terraform Idempotency
```yaml
# Uses -detailed-exitcode to detect changes
terraform plan -detailed-exitcode
# Only applies if changes detected
if changes_detected; then terraform apply; fi
```

### Ansible Idempotency
- All Ansible playbooks use idempotent modules
- Ansible naturally handles "already configured" states
- Safe to run multiple times

### Docker Secrets Idempotency
```bash
# Only create if doesn't exist
docker secret ls | grep -q secret_name || \
  echo "$SECRET" | docker secret create secret_name -
```

### Docker Stack Deployment Idempotency
```bash
# Updates existing services, creates new ones
docker stack deploy -c stack.yml stack_name
```

## Environment Variables

Required secrets in GitHub repository settings:

### AWS Credentials
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `AWS_REGION` - Target AWS region

### SSH Keys
- `SSH_PUBLIC_KEY` - Public SSH key for EC2 instances
- `SSH_PRIVATE_KEY` - Private SSH key for accessing instances
- `SSH_USERNAME` - SSH username (default: ubuntu)

### Application Secrets
- `MYSQL_ROOT_PASSWORD` - MySQL root password
- `MYSQL_PASSWORD` - MySQL application password
- `SLACK_WEBHOOK_URL` - Slack webhook for alerts

### Docker Registry
- `DOCKERHUB_USERNAME` - DockerHub username
- `DOCKERHUB_TOKEN` - DockerHub access token

### Swarm Manager
- `SWARM_MANAGER_HOST` - IP/hostname of Swarm manager (set after infra provisioning)

## Workflow Best Practices

### For Development

1. **Create feature branch from dev**
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b feature/my-feature
   ```

2. **Make changes and commit**
   ```bash
   git add .
   git commit -m "Add new feature"
   git push origin feature/my-feature
   ```

3. **Create PR to dev**
   - `pr-validation.yml` runs automatically
   - All checks must pass before merge

4. **Merge to dev**
   - Squash and merge recommended
   - No automatic deployments on dev merge

### For Production Deployment

1. **Create PR from dev to main**
   ```bash
   git checkout main
   git pull origin main
   git merge dev
   git push origin main
   ```

2. **Merge to main triggers full pipeline**
   - `main-deployment.yml` runs automatically
   - Stages: Validations → Infrastructure → Deployment
   - Infrastructure only provisioned if changes detected
   - Deployment happens every time

### For Manual Operations

#### Infrastructure Changes Only
```
GitHub Actions → infrastructure.yml → Run workflow
- Choose action: apply
- Choose environment: production
```

#### Deployment Only
```
GitHub Actions → deploy.yml → Run workflow
- Choose stack: both/app/monitoring
- Force rebuild: yes/no
```

#### Full Pipeline with Custom Options
```
GitHub Actions → main-deployment.yml → Run workflow
- Configure skip options
- Set infrastructure action
```

## Troubleshooting

### Validation Failures
- Check `pr-validation.yml` job logs
- Fix issues locally and push again
- Re-run failed jobs if needed

### Infrastructure Provisioning Failures
- Verify AWS credentials are correct
- Check AWS service quotas
- Review Terraform state
- Use `terraform plan` locally first

### Deployment Failures
- Verify SWARM_MANAGER_HOST is correct
- Check SSH connectivity
- Verify Docker secrets exist
- Review Docker service logs on manager

### Idempotency Issues
If a workflow isn't idempotent:
1. Check the specific job that's causing issues
2. Review the condition logic in the workflow
3. Verify Terraform state is correct
4. Ensure Docker secrets aren't being recreated

## Monitoring Workflow Runs

1. **GitHub Actions tab** - View all workflow runs
2. **Pull Request checks** - See validation status
3. **Job summaries** - Review deployment details
4. **Artifacts** - Download Ansible inventory, logs, etc.

## Contributing

When modifying workflows:
1. Test changes in a feature branch
2. Use `act` or similar tools for local testing
3. Update this documentation
4. Ensure idempotency is maintained
5. Add appropriate status checks

## Support

For issues or questions:
1. Check workflow run logs
2. Review this documentation
3. Check project README.md
4. Create an issue with workflow run details
