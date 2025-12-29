# Cleanup Quick Reference

## One-Line Commands

```bash
# 1. Safe cleanup (keep all data)
./scripts/cleanup.sh --preserve-data

# 2. Cleanup with backup
./scripts/cleanup.sh --backup-first

# 3. Fresh start (remove data)
./scripts/cleanup.sh

# 4. Complete teardown
./scripts/cleanup.sh --full-destroy --remove-secrets

# 5. Preview changes (no execution)
./scripts/cleanup.sh --dry-run
```

## What Gets Removed

| Resource | Default | --preserve-data | --full-destroy |
|----------|---------|-----------------|----------------|
| WordPress Stack | ✅ Removed | ✅ Removed | ✅ Removed |
| Monitoring Stack | ✅ Removed | ✅ Removed | ✅ Removed |
| MySQL Data | ✅ Removed | ⛔ Kept | ✅ Removed |
| WordPress Files | ✅ Removed | ⛔ Kept | ✅ Removed |
| Metrics History | ✅ Removed | ⛔ Kept | ✅ Removed |
| Docker Secrets | ⛔ Kept | ⛔ Kept | ✅ Removed |
| Swarm Mode | ⛔ Active | ⛔ Active | ✅ Left |
| EC2 Instances | ⛔ Running | ⛔ Running | ✅ Destroyed |

## Safety Checklist

Before cleanup:
- [ ] Backup exists (if production)
- [ ] Team notified
- [ ] Maintenance window scheduled
- [ ] Verified correct environment
- [ ] Read confirmation prompts

## Common Scenarios

### Redeploy Application
```bash
./scripts/cleanup.sh --preserve-data
# ... make changes ...
ansible-playbook -i infra/ansible/inventory/hosts infra/ansible/playbooks/site.yml
```

### Fresh Installation
```bash
./scripts/cleanup.sh --backup-first
ansible-playbook -i infra/ansible/inventory/hosts infra/ansible/playbooks/site.yml
```

### Shut Down for Weekend
```bash
./scripts/cleanup.sh --preserve-data
# Monday morning:
ansible-playbook -i infra/ansible/inventory/hosts infra/ansible/playbooks/site.yml
```

### Complete Project Shutdown
```bash
./scripts/cleanup.sh --full-destroy --remove-secrets
```

## Emergency Recovery

If you accidentally removed volumes:
```bash
# Restore from backup
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/restore.yml \
  -e backup_date=2025-12-28
```

## Verification Commands

```bash
# Check stacks
docker stack ls

# Check volumes
docker volume ls | grep -E "(wp_data|mysql_data)"

# Check swarm status
docker info | grep "Swarm:"

# Check AWS instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=wordpress-swarm" --query 'Reservations[].Instances[].State.Name'
```

## Time Estimates

| Operation | Duration |
|-----------|----------|
| Stack removal | 30 seconds |
| Volume removal | 1 minute |
| Full cleanup | 2-3 minutes |
| Infrastructure destroy | 5-10 minutes |

## Cost Impact

| Action | Monthly Savings |
|--------|-----------------|
| Stop stacks | $0 (instances still running) |
| Destroy infrastructure | ~$150-300/month |

## Support

**Documentation:** See [CLEANUP_GUIDE.md](./CLEANUP_GUIDE.md)

**Issues:** Check troubleshooting section in guide

**Emergency:** Contact infrastructure team
