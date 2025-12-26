# Security Hardening Guide

Security measures implemented in the Docker Swarm infrastructure.

## SSH Hardening

Applied by Ansible `security-hardening` role:

### Disabled Features
- Password authentication
- Root login
- Empty passwords

### Enabled Features
- Public key authentication only
- MaxAuthTries: 3

### Configuration
Changes made to `/etc/ssh/sshd_config`:
```
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
PermitEmptyPasswords no
MaxAuthTries 3
```

## Firewall Rules (UFW)

### Allowed Ports

**All Nodes:**
- SSH: 22/tcp

**Swarm Communication:**
- Management: 2377/tcp (manager only)
- Node communication: 7946/tcp, 7946/udp
- Overlay network: 4789/udp

**Application Services:**
- HTTP: 80/tcp
- HTTPS: 443/tcp

**Monitoring (Manager):**
- Prometheus: 9090/tcp
- Grafana: 3000/tcp
- AlertManager: 9093/tcp

## AWS Security Groups

### Manager Security Group
- SSH from allowed_ssh_cidrs (default: 0.0.0.0/0 - **change in production**)
- Swarm ports from worker security group
- HTTP/HTTPS from internet (0.0.0.0/0)
- Monitoring ports from allowed_monitoring_cidrs

### Worker Security Group
- SSH from allowed_ssh_cidrs
- Swarm ports from manager security group
- HTTP from internet (for WordPress)

## Network Isolation

- **VPC**: 10.0.0.0/16 (configurable)
- **Public Subnets**: Swarm nodes with public IPs
- **Private Subnets**: Reserved for future database isolation
- **NAT Gateway**: Outbound internet for private subnets

## Secrets Management

- **Docker Secrets**: Encrypted at rest, distributed via TLS
- **GitHub Secrets**: All sensitive values stored as GitHub secrets
- **Environment Variables**: Secrets passed to Ansible via env vars (not stored in files)

## Best Practices

1. **Restrict SSH Access**: Update `allowed_ssh_cidrs` to your IP only
2. **Restrict Monitoring**: Update `allowed_monitoring_cidrs` to your IP
3. **Rotate Secrets**: Regularly rotate Docker secrets and SSH keys
4. **Update Systems**: Enable automatic security updates
5. **Monitor Access**: Review CloudTrail logs for AWS API access
6. **Principle of Least Privilege**: IAM users should have minimal permissions

## Compliance Checks

Run compliance tests:
```bash
pytest tests/test_infrastructure.py -v
```

## Security Incident Response

If a security incident occurs:

1. **Isolate**: Remove affected node from Swarm
2. **Investigate**: Review logs and access patterns
3. **Rotate**: Rotate all secrets immediately
4. **Patch**: Apply security patches
5. **Monitor**: Increase monitoring for 30 days
