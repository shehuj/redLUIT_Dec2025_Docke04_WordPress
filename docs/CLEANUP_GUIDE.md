# WordPress Docker Swarm Cleanup Guide

## Overview

This guide covers how to safely clean up your WordPress Docker Swarm deployment, with options ranging from removing just the application stacks to completely destroying all infrastructure.

## Quick Start

### Option 1: Using the Cleanup Script (Recommended)

```bash
# See all options
./scripts/cleanup.sh --help

# Remove stacks but keep data (safest)
./scripts/cleanup.sh --preserve-data

# Complete cleanup with backup first
./scripts/cleanup.sh --backup-first

# Dry run to see what would be removed
./scripts/cleanup.sh --dry-run
```

### Option 2: Using Ansible Directly

```bash
# Basic cleanup (preserves data and secrets)
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/cleanup.yml

# Complete cleanup
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/cleanup.yml \
  -e preserve_data=false \
  -e preserve_secrets=false
```

## Cleanup Levels

### Level 1: Stack Removal Only (Default)

**What gets removed:**
- WordPress application stack
- Monitoring stack (Prometheus, Grafana)
- Docker configs
- Overlay networks

**What's preserved:**
- Data volumes (WordPress files, MySQL database)
- Docker secrets
- Swarm mode active
- Infrastructure (EC2 instances)

```bash
./scripts/cleanup.sh --preserve-data
```

**Use case:** Redeploying with updated configurations

---

### Level 2: Include Secrets Removal

**Additional removals:**
- MySQL passwords
- Slack webhook URLs
- Other Docker secrets

```bash
./scripts/cleanup.sh --preserve-data --remove-secrets
```

**Use case:** Security cleanup or complete reconfiguration

---

### Level 3: Full Application Cleanup

**Additional removals:**
- WordPress data volume (`wp_data`)
- MySQL database volume (`mysql_data`)
- Prometheus metrics (`prometheus_data`)
- Grafana dashboards (`grafana_data`)

```bash
./scripts/cleanup.sh --remove-secrets
```

**Use case:** Starting fresh deployment

---

### Level 4: Leave Swarm Mode

**Additional actions:**
- Node leaves Docker Swarm cluster
- Swarm-specific features disabled

```bash
./scripts/cleanup.sh --leave-swarm
```

**Use case:** Decommissioning the cluster

---

### Level 5: Complete Infrastructure Destruction

**Additional removals:**
- EC2 instances (managers + workers)
- VPC and networking
- Security groups
- All AWS resources

```bash
./scripts/cleanup.sh --full-destroy --remove-secrets
```

**Use case:** Project termination

---

## Detailed Options

### Preserve Data (`--preserve-data`)

**Keeps:**
- `/var/lib/docker/volumes/wordpress-app_wp_data`
- `/var/lib/docker/volumes/wordpress-app_mysql_data`
- `/var/lib/docker/volumes/monitoring_prometheus_data`
- `/var/lib/docker/volumes/monitoring_grafana_data`

**Benefits:**
- WordPress content and uploads preserved
- Database intact for restoration
- Historical metrics retained
- Fast redeployment

**When to use:**
- Testing configuration changes
- Updating Docker images
- Troubleshooting stack issues

---

### Remove Secrets (`--remove-secrets`)

**Removes:**
- `mysql_root_password`
- `mysql_password`
- `slack_webhook_url`

**Considerations:**
- Need to recreate secrets for redeployment
- Security best practice for decommissioning
- Prevents accidental reuse of old credentials

**When to use:**
- Security compliance requirements
- Rotating all credentials
- Permanent shutdown

---

### Backup First (`--backup-first`)

**Actions:**
1. Creates backup of MySQL database
2. Exports WordPress files
3. Saves to S3 (if configured)
4. Proceeds with cleanup

```bash
./scripts/cleanup.sh --backup-first
```

**When to use:**
- Always recommended for production
- Before major changes
- Compliance requirements

---

### Leave Swarm (`--leave-swarm`)

**Effects:**
- Node exits swarm cluster
- Swarm commands become unavailable
- Requires `docker swarm init` to rejoin

**Manager nodes:** Uses `--force` flag

**Worker nodes:** Graceful leave

**When to use:**
- Decommissioning infrastructure
- Converting to standalone Docker
- Complete cluster shutdown

---

### Full Destroy (`--full-destroy`)

**Destroys:**
1. Docker stacks and services
2. Volumes and networks
3. Secrets and configs
4. Leaves swarm mode
5. **Terraform infrastructure**
   - EC2 instances
   - Load balancers
   - VPC and subnets
   - Security groups
   - All AWS resources

**Requires confirmation:** Type `DESTROY` to proceed

```bash
./scripts/cleanup.sh --full-destroy --remove-secrets
```

**When to use:**
- Project cancellation
- Environment teardown
- Cost optimization

---

## Safety Features

### Confirmation Prompts

The cleanup script includes multiple safety checks:

1. **Configuration Review**
   ```
   Cleanup Configuration:
     Preserve Data: NO
     Preserve Secrets: NO
     Leave Swarm: YES
     Full Destroy: YES

   Do you want to proceed? (yes/no):
   ```

2. **Volume Removal Warning**
   ```
   ⚠️  WARNING: You are about to delete the following volumes:
   - wordpress-app_mysql_data (WordPress database)
   - wordpress-app_wp_data (WordPress files)

   This will PERMANENTLY DELETE all data

   Press Ctrl+C to abort or Enter to continue
   ```

3. **Infrastructure Destruction**
   ```
   Type 'DESTROY' to confirm infrastructure destruction:
   ```

### Dry Run Mode

Test cleanup without making changes:

```bash
./scripts/cleanup.sh --dry-run
```

**Shows:**
- Resources that would be removed
- Actions that would be taken
- Warnings and confirmations

**Safe for:**
- Understanding impact
- Documentation
- Auditing

---

## Common Cleanup Scenarios

### Scenario 1: Redeploy Application

**Goal:** Update WordPress or stack configuration

```bash
# Remove stacks, keep data
./scripts/cleanup.sh --preserve-data

# Redeploy
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/site.yml
```

---

### Scenario 2: Fresh Start with Same Infrastructure

**Goal:** Clean slate, reuse servers

```bash
# Backup first, then complete cleanup
./scripts/cleanup.sh --backup-first --remove-secrets

# Recreate secrets
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml

# Deploy fresh
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/site.yml
```

---

### Scenario 3: Migrate to Different Infrastructure

**Goal:** Move to new servers

```bash
# On old infrastructure
./scripts/cleanup.sh --backup-first --full-destroy

# On new infrastructure
# Provision new infrastructure
terraform apply

# Deploy from backup
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/restore.yml
```

---

### Scenario 4: Complete Teardown

**Goal:** Shut down everything

```bash
# Nuclear option
./scripts/cleanup.sh --full-destroy --remove-secrets
```

---

## Manual Cleanup Steps

If you prefer to run commands manually:

### 1. Remove Stacks

```bash
# SSH to manager node
ssh ubuntu@<manager-ip>

# List stacks
docker stack ls

# Remove application stack
docker stack rm wordpress-app

# Remove monitoring stack
docker stack rm monitoring

# Wait for removal
sleep 15

# Verify
docker stack ls
```

### 2. Remove Configs

```bash
docker config rm prometheus_config prometheus_rules alertmanager_config
```

### 3. Remove Secrets (Optional)

```bash
docker secret rm mysql_root_password mysql_password slack_webhook_url
```

### 4. Remove Volumes (Destructive!)

```bash
# List volumes
docker volume ls

# Remove specific volumes
docker volume rm wordpress-app_mysql_data
docker volume rm wordpress-app_wp_data
docker volume rm monitoring_prometheus_data
docker volume rm monitoring_grafana_data
```

### 5. Remove Networks

```bash
docker network rm wordpress-app_frontend
docker network rm wordpress-app_backend
docker network rm mon_net
```

### 6. Leave Swarm (Optional)

```bash
# On manager (force required)
docker swarm leave --force

# On workers
docker swarm leave
```

### 7. Destroy Infrastructure (Optional)

```bash
# On your local machine
cd infra/terraform
terraform destroy
```

---

## Verification

After cleanup, verify resources are removed:

```bash
# Check stacks
docker stack ls
# Expected: No stacks or only ingress

# Check services
docker service ls
# Expected: No services

# Check volumes
docker volume ls
# Expected: Only system volumes if data was removed

# Check networks
docker network ls
# Expected: Only default networks (bridge, host, none)

# Check swarm status
docker info | grep Swarm
# Expected: "Swarm: inactive" if left swarm

# Check AWS resources
aws ec2 describe-instances --filters "Name=tag:Project,Values=wordpress-swarm"
# Expected: No instances if full destroy
```

---

## Troubleshooting

### Stack Won't Remove

**Error:** `service X has dependent services`

**Solution:**
```bash
# Force remove all services first
docker service ls -q | xargs docker service rm

# Then remove stack
docker stack rm wordpress-app
```

---

### Volume in Use

**Error:** `volume is in use`

**Solution:**
```bash
# Check what's using it
docker ps -a --filter volume=wordpress-app_mysql_data

# Stop and remove containers
docker rm -f <container_id>

# Remove volume
docker volume rm wordpress-app_mysql_data
```

---

### Can't Leave Swarm

**Error:** `node is not part of a swarm`

**Solution:** Already left swarm, nothing to do

**Error:** `must be forced to leave`

**Solution:**
```bash
docker swarm leave --force
```

---

### Terraform Destroy Fails

**Error:** Resources still exist

**Solution:**
```bash
# Refresh state
terraform refresh

# Retry destroy
terraform destroy

# If stuck, manually remove resources from AWS Console
# Then remove from state:
terraform state rm <resource>
```

---

## Best Practices

### ✅ DO

1. **Always backup before destructive operations**
   ```bash
   ./scripts/cleanup.sh --backup-first
   ```

2. **Use dry-run to preview changes**
   ```bash
   ./scripts/cleanup.sh --dry-run
   ```

3. **Preserve data during testing**
   ```bash
   ./scripts/cleanup.sh --preserve-data
   ```

4. **Document why you're cleaning up**
   - Update changelog
   - Note in runbook
   - Team notification

5. **Verify cleanup completion**
   ```bash
   docker stack ls
   docker volume ls
   ```

### ❌ DON'T

1. **Don't remove volumes in production without backup**

2. **Don't force leave swarm on worker nodes**
   - Workers should gracefully leave
   - Only managers need `--force`

3. **Don't run full destroy without confirmation**
   - Double-check environment
   - Verify backup exists

4. **Don't cleanup during business hours**
   - Schedule maintenance windows
   - Notify stakeholders

---

## Recovery from Accidental Cleanup

### If Volumes Were Deleted

**Best case:** You have backups

```bash
# Restore from S3 backup
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/restore.yml \
  -e backup_date=2025-12-28
```

**Worst case:** No backups

- Data is permanently lost
- Restore from alternative backups (if any)
- Recreate from scratch

### If Infrastructure Was Destroyed

```bash
# Reprovision infrastructure
cd infra/terraform
terraform apply

# Wait for instances
sleep 60

# Reconfigure swarm
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml

# Restore application
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/restore.yml
```

---

## Cost Implications

### Cleanup Levels and Costs

| Level | AWS Costs | Storage Costs | Time to Restore |
|-------|-----------|---------------|-----------------|
| Stack removal | $$$ (instances running) | $ (volumes kept) | 5 minutes |
| Volume removal | $$$ (instances running) | $0 | 15 minutes |
| Leave swarm | $$$ (instances running) | $0 | 20 minutes |
| Full destroy | $0 | $0 | 45+ minutes |

### Recommendations

- **Development:** Full destroy when not in use
- **Staging:** Stack removal, keep infrastructure
- **Production:** Never full destroy without approval

---

## Automation Integration

### GitHub Actions

The cleanup flow can be triggered via workflow dispatch:

```yaml
# .github/workflows/manual-cleanup.yml
name: Manual Cleanup

on:
  workflow_dispatch:
    inputs:
      cleanup_level:
        type: choice
        options:
          - stack-only
          - full-cleanup
          - infrastructure-destroy
```

### Scheduled Cleanup (Dev Environments)

```bash
# Crontab for automatic weekend shutdown
0 18 * * 5 /path/to/scripts/cleanup.sh --preserve-data
0 8 * * 1 /path/to/scripts/deploy.sh
```

---

## Support

If cleanup fails or you need help:

1. Check logs: `docker service logs <service-name>`
2. Review troubleshooting section above
3. Contact infrastructure team
4. Create incident ticket

---

## Summary

**Quick Reference:**

```bash
# Safe cleanup (keep data)
./scripts/cleanup.sh --preserve-data

# Complete cleanup (remove data)
./scripts/cleanup.sh --backup-first

# Nuclear option (destroy everything)
./scripts/cleanup.sh --full-destroy --remove-secrets

# Test what would happen
./scripts/cleanup.sh --dry-run
```

**Remember:** Always backup production data before cleanup!
