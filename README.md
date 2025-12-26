# Production WordPress with MySQL and Comprehensive Monitoring

A production-ready Docker Swarm deployment featuring WordPress and MySQL with integrated Prometheus, Grafana, and AlertManager monitoring stack. Includes automated CI/CD deployment via GitHub Actions.

## Architecture Overview

### Application Stack (stack-app/)
- **MySQL 8.0** - Database with health checks and persistent storage
  - 1 replica with automatic restart on failure
  - Secrets-based credential management
  - Health checks every 10s
  - Connected to backend and monitoring networks

- **WordPress** - Web application with high availability
  - 3 replicas for load distribution
  - Health checks every 15s
  - External access on port 80
  - Connected to frontend, backend, and monitoring networks

### Monitoring Stack (stack-monitoring/)
- **Prometheus** - Metrics collection and alerting
  - Scrapes metrics from all services
  - Alert rules for critical events
  - Data retention with persistent storage

- **Grafana** - Visualization and dashboards
  - Pre-configured data sources
  - Custom dashboards for WordPress and MySQL
  - Accessible on port 3000

- **AlertManager** - Alert routing and notifications
  - Slack integration for critical alerts
  - Alert deduplication and grouping
  - Configurable notification policies

- **cAdvisor** - Container metrics collector
  - Collects resource usage metrics
  - Runs on all Swarm nodes (global mode)

- **Node Exporter** - System metrics collector
  - Collects host-level metrics
  - Runs on all Swarm nodes (global mode)

### Network Architecture
```
┌─────────────────────────────────────────────────────────┐
│                     Docker Swarm Cluster                │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Frontend Network (overlay)                      │  │
│  │    └─ WordPress (3 replicas) :80                 │  │
│  └──────────────────────────────────────────────────┘  │
│                          │                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Backend Network (overlay)                       │  │
│  │    ├─ WordPress (3 replicas)                     │  │
│  │    └─ MySQL (1 replica)                          │  │
│  └──────────────────────────────────────────────────┘  │
│                          │                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Monitoring Network (overlay - mon_net)          │  │
│  │    ├─ Prometheus :9090                           │  │
│  │    ├─ Grafana :3000                              │  │
│  │    ├─ AlertManager :9093                         │  │
│  │    ├─ cAdvisor (global)                          │  │
│  │    ├─ Node Exporter (global)                     │  │
│  │    ├─ WordPress (3 replicas)                     │  │
│  │    └─ MySQL (1 replica)                          │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Infrastructure Provisioning

This repository includes **automated infrastructure provisioning** using Terraform and Ansible to create a production-grade Docker Swarm cluster on AWS EC2.

### Automated Provisioning Features
- **Terraform**: Provisions AWS VPC, EC2 instances (1 manager + 2 workers), security groups
- **Ansible**: Installs Docker, initializes Swarm, creates secrets, applies security hardening
- **GitHub Actions**: Automated workflow for infrastructure deployment
- **Security**: SSH hardening, UFW firewall, encrypted volumes

### Quick Start - Infrastructure

1. **Configure GitHub Secrets** (Settings → Secrets and variables → Actions):
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
   - `SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY`
   - `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `SLACK_WEBHOOK_URL`

2. **Trigger Infrastructure Workflow**:
   ```bash
   # Make changes to infra/ directory and push to main
   git push origin main
   ```

3. **Update Deployment Secret**:
   - After provisioning, update `SWARM_MANAGER_HOST` secret with manager IP from workflow output

For detailed infrastructure provisioning guide, see [docs/INFRASTRUCTURE_GUIDE.md](docs/INFRASTRUCTURE_GUIDE.md).

For security hardening details, see [docs/SECURITY_HARDENING.md](docs/SECURITY_HARDENING.md).

## Prerequisites

### Option 1: Automated Infrastructure (Recommended)
Use the infrastructure provisioning workflow to automatically create:
- AWS VPC with public/private subnets
- 3 EC2 instances (1 manager + 2 workers, Ubuntu 22.04, t3.medium)
- Security groups for Swarm communication
- Docker installation and Swarm initialization
- Cost: ~$143-183/month

See [Infrastructure Provisioning](#infrastructure-provisioning) above.

### Option 2: Manual Docker Swarm Cluster
If you have your own infrastructure:
- Minimum: 1 manager node
- Recommended: 1 manager + 2 worker nodes
- Docker Engine 20.10+ with Swarm mode enabled

Initialize Swarm:
```bash
docker swarm init
```

Add workers (optional):
```bash
# On manager node
docker swarm join-token worker

# On worker nodes
docker swarm join --token <TOKEN> <MANAGER-IP>:2377
```

### Docker Secrets
Create required secrets on the Swarm manager before deployment:

```bash
# MySQL root password
echo "your-super-secret-root-password" | docker secret create mysql_root_password -

# MySQL WordPress user password
echo "your-super-secret-wp-password" | docker secret create mysql_password -

# Slack webhook URL for alerts
echo "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" | docker secret create slack_webhook_url -
```

Verify secrets:
```bash
docker secret ls
```

### GitHub Secrets (for CI/CD)
Configure these secrets in your GitHub repository:
- `MYSQL_ROOT_PASSWORD` - MySQL root password
- `MYSQL_PASSWORD` - WordPress database user password
- `SLACK_WEBHOOK_URL` - Slack webhook for AlertManager
- `SWARM_MANAGER_HOST` - Swarm manager hostname/IP
- `SSH_USERNAME` - SSH user for deployment
- `SSH_PRIVATE_KEY` - SSH private key for authentication
- `DOCKERHUB_USERNAME` - Docker Hub username (optional)
- `DOCKERHUB_TOKEN` - Docker Hub access token (optional)

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── deploy.yml           # Main deployment workflow
│       ├── compliance.yml       # Compliance checks on PRs
│       └── python.yml           # Python environment tests
├── stack-app/
│   └── docker-stack.yml         # WordPress + MySQL stack definition
├── stack-monitoring/
│   ├── monitoring-stack.yml     # Monitoring stack definition
│   ├── prometheus.yml           # Prometheus configuration
│   ├── alert.rules.yml          # Alert rules
│   └── alertmanager.yml         # AlertManager configuration
├── tests/
│   ├── check_required_files.py  # Repository compliance tests
│   └── test_repo.py             # Basic test suite
├── .dockerignore                # Docker build exclusions
├── .gitignore                   # Git exclusions
├── requirements.txt             # Python dependencies
└── README.md                    # This file
```

## Deployment

### Manual Deployment

#### Step 1: Create Docker Secrets
```bash
# See Prerequisites section above
```

#### Step 2: Deploy Monitoring Stack (creates mon_net network)
```bash
cd stack-monitoring
docker stack deploy -c monitoring-stack.yml monitoring
cd ..
```

#### Step 3: Deploy Application Stack
```bash
docker stack deploy -c stack-app/docker-stack.yml levelop-wp
```

#### Step 4: Verify Deployment
```bash
# Check all services
docker stack ps levelop-wp
docker stack ps monitoring

# Check service logs
docker service logs levelop-wp_wordpress
docker service logs levelop-wp_mysql
docker service logs monitoring_prometheus

# Check networks
docker network ls | grep overlay
```

### Automated Deployment (GitHub Actions)

Push to `main` branch triggers automatic deployment:

```bash
git add .
git commit -m "Deploy production changes"
git push origin main
```

The workflow will:
1. Build and tag MySQL and WordPress images
2. Push images to Docker Hub (optional)
3. SSH to Swarm manager
4. Create/verify Docker secrets
5. Deploy monitoring stack (creates mon_net network)
6. Deploy application stack (uses mon_net network)

## Accessing Services

### Application
- **WordPress:** http://your-swarm-ip:80

### Monitoring
- **Prometheus:** http://your-swarm-ip:9090
- **Grafana:** http://your-swarm-ip:3000
  - Default credentials: admin/admin (change on first login)
- **AlertManager:** http://your-swarm-ip:9093

## Monitoring and Alerts

### Prometheus Metrics

Prometheus collects metrics from:
- **Prometheus itself** (localhost:9090)
- **cAdvisor** (cadvisor:8080) - Container metrics
- **Node Exporter** (node_exporter:9100) - Host metrics
- **MySQL Exporter** (mysql:9104) - Database metrics (if configured)
- **WordPress/MySQL tasks** (tasks.mysql:9323, tasks.wordpress:9323)

### Alert Rules

Configured alerts (stack-monitoring/alert.rules.yml):

1. **InstanceDown** (Critical)
   - Triggers when any monitored instance is unreachable for 2+ minutes
   - Severity: Critical

2. **ContainerUnhealthy** (Warning)
   - Triggers when container health checks fail for 5+ minutes
   - Severity: Warning

3. **ServiceNotAtDesiredReplicas** (Critical)
   - Triggers when service has fewer running replicas than desired for 3+ minutes
   - Severity: Critical

### Slack Notifications

AlertManager sends notifications to Slack when:
- Alerts are triggered (send_resolved: true)
- Alerts are resolved
- Channel: #alerts (configurable in alertmanager.yml)

Configure your Slack webhook:
```bash
echo "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" | \
  docker secret create slack_webhook_url -
```

## Health Checks

### MySQL Health Check
- **Command:** `mysqladmin ping -h localhost`
- **Interval:** 10s
- **Timeout:** 5s
- **Retries:** 5
- **Start Period:** 30s

### WordPress Health Check
- **Command:** `curl -f http://localhost/ || exit 1`
- **Interval:** 15s
- **Timeout:** 5s
- **Retries:** 3
- **Start Period:** 30s

## Data Persistence

### Volumes
- `mysql_data` - MySQL database files (/var/lib/mysql)
- `wp_data` - WordPress content (/var/www/html)
- `prometheus_data` - Prometheus metrics storage
- `grafana_data` - Grafana dashboards and settings

Volumes are automatically managed by Docker Swarm and persist across service updates.

### Backup Strategy

Backup MySQL data:
```bash
docker exec $(docker ps -qf "name=levelop-wp_mysql") \
  mysqldump -p wordpress > backup-$(date +%Y%m%d).sql
```

Backup WordPress content:
```bash
docker run --rm \
  -v levelop-wp_wp_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/wordpress-$(date +%Y%m%d).tar.gz /data
```

## Scaling

Scale WordPress replicas:
```bash
docker service scale levelop-wp_wordpress=5
```

MySQL should remain at 1 replica (not designed for multi-master).

## Troubleshooting

### Check Service Status
```bash
docker stack ps levelop-wp --no-trunc
docker service ls
```

### View Logs
```bash
# Application logs
docker service logs -f levelop-wp_wordpress
docker service logs -f levelop-wp_mysql

# Monitoring logs
docker service logs -f monitoring_prometheus
docker service logs -f monitoring_grafana
```

### Common Issues

**WordPress can't connect to database:**
- Verify secrets exist: `docker secret ls`
- Check MySQL health: `docker service ps levelop-wp_mysql`
- Verify backend network: `docker network inspect levelop-wp_backend`

**Monitoring not collecting metrics:**
- Verify mon_net network exists: `docker network ls | grep mon_net`
- Check Prometheus targets: http://your-swarm-ip:9090/targets
- Verify services are on mon_net: `docker service inspect levelop-wp_mysql`

**Alerts not reaching Slack:**
- Verify slack_webhook_url secret exists
- Check AlertManager logs: `docker service logs monitoring_alertmanager`
- Test webhook URL manually with curl

### Reset Everything
```bash
# Remove all stacks
docker stack rm levelop-wp
docker stack rm monitoring

# Wait for cleanup
sleep 30

# Remove volumes (WARNING: Deletes all data!)
docker volume rm levelop-wp_mysql_data levelop-wp_wp_data
docker volume rm monitoring_prometheus_data monitoring_grafana_data

# Redeploy
docker stack deploy -c stack-monitoring/monitoring-stack.yml monitoring
docker stack deploy -c stack-app/docker-stack.yml levelop-wp
```

## Development and Testing

### Run Tests Locally
```bash
# Install dependencies
pip install -r requirements.txt

# Run compliance checks
python tests/check_required_files.py

# Run pytest
pytest tests/
```

### Lint YAML Files
```bash
pip install yamllint
yamllint stack-app/ stack-monitoring/
```

## Security Best Practices

- Secrets stored in Docker Swarm encrypted storage
- No plaintext passwords in repository
- Health checks prevent serving unhealthy containers
- Overlay networks isolate traffic
- Regular security updates via base image pulls
- GitHub Actions uses SSH key authentication

## Production Checklist

- [ ] Docker Swarm initialized with 3+ nodes
- [ ] All secrets created (mysql_root_password, mysql_password, slack_webhook_url)
- [ ] Slack webhook configured and tested
- [ ] Monitoring stack deployed and verified
- [ ] Application stack deployed and verified
- [ ] WordPress initial setup completed
- [ ] Grafana dashboards configured
- [ ] Backup strategy implemented
- [ ] DNS/Load balancer configured for port 80
- [ ] SSL/TLS termination configured (e.g., Traefik, nginx)
- [ ] Resource limits tuned for your workload
- [ ] Alerting tested and verified

## Future Enhancements

- Add Traefik for SSL/TLS termination and routing
- Implement automated backups with cron
- Add Redis for WordPress object caching
- Configure MySQL replication for HA
- Add Loki for log aggregation
- Implement centralized secrets management (Vault)
- Add security scanning (Trivy, Clair)
- Configure autoscaling based on metrics

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test locally
4. Submit a pull request to `main`
5. Ensure CI checks pass

## License

See LICENSE file for details.

## Support

For issues and questions:
- Open an issue in this repository
- Check Docker Swarm documentation
- Review Prometheus/Grafana documentation

---

**Last Updated:** December 2025
**Repository:** redLUIT_Dec2025_Docke04_WordPress
**Stack Version:** 3.8
