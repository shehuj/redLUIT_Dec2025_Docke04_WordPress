# Cleanup Flow Implementation Summary

## Overview

A comprehensive manual cleanup system has been implemented for the WordPress Docker Swarm deployment. The system provides safe, flexible cleanup options ranging from simple stack removal to complete infrastructure destruction.

## What Was Created

### 1. Ansible Playbook
**File:** `infra/ansible/playbooks/cleanup.yml`

**Features:**
- Removes Docker stacks (wordpress-app, monitoring)
- Manages secrets, configs, volumes, and networks
- Optional backup before cleanup
- Optional swarm mode exit
- Comprehensive verification and reporting

**Variables:**
- `preserve_data` (default: false) - Keep data volumes
- `preserve_secrets` (default: true) - Keep Docker secrets
- `leave_swarm` (default: false) - Exit swarm mode
- `backup_before` (default: false) - Backup before cleanup

### 2. Interactive Shell Script
**File:** `scripts/cleanup.sh`

**Features:**
- User-friendly command-line interface
- Color-coded output for warnings and errors
- Multiple confirmation prompts
- Dry-run mode
- Full infrastructure destruction option
- Integrates with Terraform

**Options:**
```bash
--preserve-data      # Keep volumes (WordPress data, MySQL database)
--remove-secrets     # Remove Docker secrets
--leave-swarm        # Leave Docker Swarm mode
--backup-first       # Run backup before cleanup
--full-destroy       # Destroy infrastructure (Terraform)
--dry-run           # Preview changes without executing
```

### 3. Comprehensive Documentation
**Files:**
- `docs/CLEANUP_GUIDE.md` - Complete guide (450+ lines)
- `docs/CLEANUP_QUICK_REFERENCE.md` - Quick reference card

**Contents:**
- 5 cleanup levels explained
- Safety features and confirmations
- Common scenarios with examples
- Troubleshooting section
- Recovery procedures
- Cost implications
- Best practices

### 4. Makefile
**File:** `Makefile`

**Convenience commands:**
```bash
make cleanup-safe       # Safe cleanup (preserve data)
make cleanup            # Full cleanup (with confirmation)
make cleanup-full       # Complete teardown
make cleanup-dry-run    # Preview changes
make backup             # Backup data
make restore            # Restore from backup
make health             # Run health checks
```

## Cleanup Levels

### Level 1: Stack Removal (Default + --preserve-data)
**Removes:**
- WordPress application stack
- Monitoring stack
- Docker configs
- Overlay networks

**Preserves:**
- Data volumes
- Secrets
- Swarm mode
- Infrastructure

**Command:**
```bash
./scripts/cleanup.sh --preserve-data
# OR
make cleanup-safe
```

### Level 2: Include Secrets
**Additional:**
- Removes Docker secrets

**Command:**
```bash
./scripts/cleanup.sh --preserve-data --remove-secrets
```

### Level 3: Full Application Cleanup (Default)
**Additional:**
- Removes all data volumes

**Command:**
```bash
./scripts/cleanup.sh
# OR
make cleanup
```

### Level 4: Leave Swarm
**Additional:**
- Node exits Docker Swarm

**Command:**
```bash
./scripts/cleanup.sh --leave-swarm
```

### Level 5: Complete Destruction
**Additional:**
- Destroys Terraform infrastructure
- Removes EC2 instances
- Deletes VPC and networking

**Command:**
```bash
./scripts/cleanup.sh --full-destroy --remove-secrets
# OR
make cleanup-full
```

## Usage Examples

### Quick Start

```bash
# See all options
./scripts/cleanup.sh --help

# Safe cleanup (recommended first try)
./scripts/cleanup.sh --preserve-data

# Preview what would be removed
./scripts/cleanup.sh --dry-run
```

### Common Scenarios

#### 1. Redeploy Application with Same Data
```bash
# Remove stacks, keep data
./scripts/cleanup.sh --preserve-data

# Deploy again
ansible-playbook -i infra/ansible/inventory/hosts infra/ansible/playbooks/site.yml
```

#### 2. Fresh Start
```bash
# Backup first, then clean everything
./scripts/cleanup.sh --backup-first

# Deploy fresh
ansible-playbook -i infra/ansible/inventory/hosts infra/ansible/playbooks/site.yml
```

#### 3. Weekend Shutdown (Dev Environment)
```bash
# Friday evening
./scripts/cleanup.sh --preserve-data

# Monday morning
make deploy
```

#### 4. Complete Project Teardown
```bash
# Nuclear option
./scripts/cleanup.sh --full-destroy --remove-secrets
```

## Safety Features

### Multiple Confirmation Prompts

1. **Initial confirmation:**
   ```
   Do you want to proceed? (yes/no):
   ```

2. **Volume deletion warning:**
   ```
   ⚠️  WARNING: You are about to delete the following volumes:
   - wordpress-app_mysql_data (WordPress database)
   - wordpress-app_wp_data (WordPress files)

   This will PERMANENTLY DELETE all data

   Press Ctrl+C to abort or Enter to continue
   ```

3. **Infrastructure destruction:**
   ```
   Type 'DESTROY' to confirm infrastructure destruction:
   ```

### Dry Run Mode

Test cleanup without making changes:
```bash
./scripts/cleanup.sh --dry-run
```

Shows:
- Resources that would be removed
- Actions that would be taken
- All warnings and confirmations

## Resources Managed

### Docker Stacks
- `wordpress-app`
- `monitoring`

### Docker Secrets
- `mysql_root_password`
- `mysql_password`
- `slack_webhook_url`

### Docker Configs
- `prometheus_config`
- `prometheus_rules`
- `alertmanager_config`

### Docker Volumes
- `wordpress-app_mysql_data` (MySQL database)
- `wordpress-app_wp_data` (WordPress files)
- `monitoring_prometheus_data` (Metrics)
- `monitoring_grafana_data` (Dashboards)

### Docker Networks
- `wordpress-app_frontend`
- `wordpress-app_backend`
- `mon_net`

### Infrastructure (with --full-destroy)
- EC2 instances (managers + workers)
- VPC and subnets
- Security groups
- Load balancers
- All AWS resources managed by Terraform

## File Structure

```
redLUIT_Dec2025_Docke04_WordPress/
├── infra/
│   └── ansible/
│       └── playbooks/
│           └── cleanup.yml              # Ansible playbook
├── scripts/
│   └── cleanup.sh                       # Interactive script
├── docs/
│   ├── CLEANUP_GUIDE.md                 # Complete documentation
│   └── CLEANUP_QUICK_REFERENCE.md       # Quick reference
├── Makefile                             # Convenience commands
└── CLEANUP_IMPLEMENTATION_SUMMARY.md    # This file
```

## Integration with Existing Tools

### Works With

1. **Backup Playbook**
   ```bash
   ./scripts/cleanup.sh --backup-first
   ```

2. **Restore Playbook**
   ```bash
   # After cleanup, restore from backup
   ansible-playbook -i infra/ansible/inventory/hosts \
     infra/ansible/playbooks/restore.yml \
     -e backup_date=2025-12-28
   ```

3. **Terraform**
   ```bash
   # Cleanup includes Terraform destroy
   ./scripts/cleanup.sh --full-destroy
   ```

4. **Makefile**
   ```bash
   make cleanup-safe    # Uses cleanup.sh
   make backup          # Before cleanup
   make health          # After redeployment
   ```

## Verification

After cleanup, verify with:

```bash
# Check stacks
docker stack ls

# Check volumes
docker volume ls | grep -E "(wp_data|mysql_data)"

# Check swarm status
docker info | grep "Swarm:"

# Check AWS instances (if full destroy)
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=wordpress-swarm" \
  --query 'Reservations[].Instances[].State.Name'
```

## Time Estimates

| Operation | Duration |
|-----------|----------|
| Stack removal only | 30 seconds |
| With volume removal | 1-2 minutes |
| Full cleanup | 2-3 minutes |
| Infrastructure destroy | 5-10 minutes |

## Cost Impact

| Cleanup Level | Monthly Cost After |
|---------------|-------------------|
| Stack removal only | ~$150-300 (instances running) |
| Full cleanup | ~$150-300 (instances running) |
| Infrastructure destroy | $0 (everything removed) |

## Best Practices

### ✅ DO

1. **Always backup production before cleanup**
   ```bash
   ./scripts/cleanup.sh --backup-first
   ```

2. **Use dry-run to preview**
   ```bash
   ./scripts/cleanup.sh --dry-run
   ```

3. **Preserve data during testing**
   ```bash
   ./scripts/cleanup.sh --preserve-data
   ```

4. **Verify cleanup completion**
   ```bash
   docker stack ls && docker volume ls
   ```

### ❌ DON'T

1. Don't remove volumes in production without backup
2. Don't force leave swarm on worker nodes (only managers need --force)
3. Don't run full destroy without double-checking environment
4. Don't cleanup during business hours (production)

## Troubleshooting

### Common Issues

**Stack won't remove:**
```bash
# Force remove services first
docker service ls -q | xargs docker service rm
docker stack rm wordpress-app
```

**Volume in use:**
```bash
# Find what's using it
docker ps -a --filter volume=wordpress-app_mysql_data
# Stop containers
docker rm -f <container_id>
# Remove volume
docker volume rm wordpress-app_mysql_data
```

**Can't leave swarm:**
```bash
# Force leave (managers only)
docker swarm leave --force
```

## Recovery

### If Volumes Deleted Accidentally

```bash
# Restore from backup
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/restore.yml \
  -e backup_date=2025-12-28
```

### If Infrastructure Destroyed

```bash
# Reprovision
cd infra/terraform
terraform apply

# Reconfigure swarm
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml

# Restore application
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/restore.yml
```

## Next Steps

1. **Test the cleanup flow** in development:
   ```bash
   ./scripts/cleanup.sh --dry-run
   ./scripts/cleanup.sh --preserve-data
   ```

2. **Document environment-specific procedures** in your runbook

3. **Set up automated backups** before cleanup in production

4. **Create scheduled cleanup** for dev environments:
   ```bash
   # Crontab example - shutdown Friday evening
   0 18 * * 5 /path/to/scripts/cleanup.sh --preserve-data
   ```

5. **Integrate with monitoring** to alert on cleanup operations

## Summary

The cleanup flow provides:
- ✅ Safe, controlled resource removal
- ✅ Multiple safety levels
- ✅ Comprehensive documentation
- ✅ Easy manual execution
- ✅ Integration with existing tools
- ✅ Recovery procedures
- ✅ Cost optimization options

**Key Command:**
```bash
./scripts/cleanup.sh --help
```

**Documentation:**
- Complete guide: `docs/CLEANUP_GUIDE.md`
- Quick reference: `docs/CLEANUP_QUICK_REFERENCE.md`

**All changes committed and pushed to dev branch.**
