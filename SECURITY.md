# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.x.x   | :white_check_mark: |
| < 2.0   | :x:                |

## Security Features

### Built-in Security

- **SSH Hardening**: Password authentication disabled, key-only access
- **fail2ban**: Automatic IP blocking after failed login attempts
- **UFW Firewall**: Restrictive firewall rules
- **EBS Encryption**: All volumes encrypted at rest
- **Docker Secrets**: Secure credential management
- **Security Groups**: Least-privilege network access

### Continuous Security Scanning

Every Pull Request is automatically scanned for:

- **Vulnerabilities**: Trivy scans Docker images and filesystem
- **Secrets**: TruffleHog detects leaked credentials
- **Code Issues**: Semgrep performs static analysis
- **Dependencies**: OWASP dependency checking
- **Shell Scripts**: Shellcheck validation

## Reporting a Vulnerability

**DO NOT** create public GitHub issues for security vulnerabilities.

### How to Report

1. **Email**: Send details to security@example.com
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Depends on severity
  - Critical: 24-48 hours
  - High: 1 week
  - Medium: 2 weeks
  - Low: 1 month

### What to Expect

1. Confirmation of receipt
2. Assessment of severity and impact
3. Development of a fix
4. Coordinated disclosure
5. Credit in release notes (if desired)

## Security Best Practices

### Before Deployment

- [ ] Change default passwords to strong, unique values
- [ ] Restrict `allowed_ssh_cidrs` to specific IPs
- [ ] Review and update security group rules
- [ ] Enable AWS CloudTrail
- [ ] Set up CloudWatch alarms
- [ ] Configure AWS Backup

### After Deployment

- [ ] Immediately change WordPress admin password
- [ ] Install WordPress security plugins
- [ ] Enable WordPress auto-updates
- [ ] Configure fail2ban email alerts
- [ ] Monitor CloudWatch logs
- [ ] Review fail2ban bans regularly

### Ongoing Maintenance

- [ ] Update Docker images monthly
- [ ] Rotate secrets every 90 days
- [ ] Review security scan results in PRs
- [ ] Monitor AWS Security Hub
- [ ] Test disaster recovery quarterly
- [ ] Audit user access permissions

## Known Security Considerations

### Current Limitations

1. **HTTP Only**: HTTPS/TLS not configured by default
   - **Mitigation**: Use CloudFront or configure Let's Encrypt

2. **Public Subnets**: All nodes in public subnets
   - **Mitigation**: Restrictive security groups, future: private subnets + NAT

3. **Single MySQL Instance**: No replication
   - **Mitigation**: Automated backups, future: RDS with Multi-AZ

4. **Docker Secrets**: Stored in Swarm raft log
   - **Mitigation**: Encrypted raft log, future: AWS Secrets Manager

### Recommended Enhancements

1. **Add HTTPS**: Configure SSL/TLS certificates
2. **Add WAF**: Use AWS WAF with CloudFront
3. **Private Subnets**: Move workers to private subnets
4. **RDS**: Migrate to managed RDS with encryption
5. **Secrets Manager**: Use AWS Secrets Manager with rotation
6. **VPC Flow Logs**: Enable for network monitoring
7. **GuardDuty**: Enable AWS GuardDuty
8. **Security Hub**: Enable AWS Security Hub

## Security Scanning Tools

### Trivy
Scans for:
- CVEs in OS packages
- CVEs in Docker images
- Misconfigurations in IaC
- Secrets in code

### TruffleHog
Detects:
- AWS credentials
- API keys
- Private keys
- Tokens
- Passwords

### Semgrep
Finds:
- SQL injection
- XSS vulnerabilities
- Command injection
- Path traversal
- Insecure deserialization

## Compliance

This infrastructure implements controls from:
- CIS Docker Benchmark
- CIS AWS Foundations Benchmark
- OWASP Top 10

For specific compliance requirements (PCI-DSS, HIPAA, SOC 2), additional hardening is required.

## Security Contact

- **Email**: security@example.com
- **PGP Key**: [Link to PGP key]
- **Response SLA**: 48 hours

## Hall of Fame

We appreciate security researchers who responsibly disclose vulnerabilities:

- [Your name could be here]

Thank you for helping keep this project secure!
