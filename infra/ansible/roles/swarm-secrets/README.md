# Ansible Role: swarm-secrets

Creates and manages Docker Swarm secrets for the WordPress application stack.

## Requirements

- Ubuntu 20.04 LTS or 22.04 LTS
- Ansible 2.15 or higher
- Docker Swarm initialized (use swarm-init role)
- Must be run on manager node
- sudo/root access

## Role Variables

Available variables (see `defaults/main.yml`):

```yaml
swarm_secrets:
  - name: mysql_root_password
    value: "{{ lookup('env', 'MYSQL_ROOT_PASSWORD') }}"

  - name: mysql_password
    value: "{{ lookup('env', 'MYSQL_PASSWORD') }}"

  - name: slack_webhook_url
    value: "{{ lookup('env', 'SLACK_WEBHOOK_URL') }}"

swarm_secrets_force_recreate: false
```

## Dependencies

- swarm-init role (Swarm must be initialized)

## Example Playbook

```yaml
- hosts: swarm_managers
  become: yes
  environment:
    MYSQL_ROOT_PASSWORD: "{{ mysql_root_password }}"
    MYSQL_PASSWORD: "{{ mysql_password }}"
    SLACK_WEBHOOK_URL: "{{ slack_webhook }}"
  roles:
    - swarm-secrets
```

## What This Role Does

1. Checks if secrets already exist (idempotent)
2. Creates MySQL root password secret
3. Creates MySQL user password secret
4. Creates Slack webhook URL secret
5. Verifies secrets are created successfully

## Secrets Created

| Secret Name | Purpose | Used By |
|-------------|---------|---------|
| `mysql_root_password` | MySQL root password | MySQL container |
| `mysql_password` | MySQL app user password | MySQL & WordPress |
| `slack_webhook_url` | Slack alerts webhook | AlertManager |

## Security Best Practices

1. **Never commit secrets to git**
2. **Use environment variables** in CI/CD
3. **Use Ansible Vault** for local runs
4. **Rotate secrets regularly**

### Using Ansible Vault

```bash
# Create encrypted vars file
ansible-vault create secrets.yml

# Add to secrets.yml:
mysql_root_password: your_secure_password
mysql_password: your_app_password
slack_webhook: https://hooks.slack.com/...

# Run playbook with vault
ansible-playbook -i inventory site.yml --ask-vault-pass
```

### Using Environment Variables (CI/CD)

```yaml
# In GitHub Actions
environment:
  MYSQL_ROOT_PASSWORD: ${{ secrets.MYSQL_ROOT_PASSWORD }}
  MYSQL_PASSWORD: ${{ secrets.MYSQL_PASSWORD }}
  SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

## Idempotency

This role is idempotent:
- Won't recreate existing secrets
- Safe to run multiple times
- Only creates missing secrets

## Verification

After running, verify secrets:

```bash
docker secret ls
# Should show:
# - mysql_root_password
# - mysql_password
# - slack_webhook_url
```

## License

MIT

## Author Information

Created for WordPress on Docker Swarm infrastructure project.
