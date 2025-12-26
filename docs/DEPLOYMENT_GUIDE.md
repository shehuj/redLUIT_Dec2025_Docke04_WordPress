# Deployment Guide

Complete step-by-step guide for deploying the WordPress + MySQL stack with monitoring to Docker Swarm.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Deploy Monitoring Stack](#deploy-monitoring-stack)
4. [Deploy Application Stack](#deploy-application-stack)
5. [Verification](#verification)
6. [WordPress Configuration](#wordpress-configuration)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements

**Minimum Configuration:**
- 1 Docker Swarm manager node
- 2 GB RAM per node
- 20 GB disk space
- 2 CPU cores

**Recommended Configuration:**
- 1 manager node + 2 worker nodes
- 4 GB RAM per node
- 50 GB disk space (with room for data growth)
- 4 CPU cores per node

### Software Requirements

- Docker Engine 20.10 or later
- Docker Compose 2.x (for local testing)
- SSH access to Swarm manager
- Git (for cloning the repository)

### Network Requirements

- All nodes must communicate on Docker Swarm ports:
  - TCP 2377 (cluster management)
  - TCP/UDP 7946 (node communication)
  - UDP 4789 (overlay network traffic)
- Exposed ports for services:
  - 80 (WordPress)
  - 3000 (Grafana)
  - 9090 (Prometheus)
  - 9093 (AlertManager)

## Initial Setup

### Step 1: Initialize Docker Swarm

On the manager node:

```bash
docker swarm init --advertise-addr <MANAGER-IP>
```

Save the join token output for adding worker nodes.

### Step 2: Add Worker Nodes (Optional but Recommended)

On each worker node:

```bash
docker swarm join --token <WORKER-TOKEN> <MANAGER-IP>:2377
```

Verify nodes:

```bash
docker node ls
```

Expected output:
```
ID                    HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
abc123... *           manager1   Ready     Active         Leader
def456...             worker1    Ready     Active
ghi789...             worker2    Ready     Active
```

### Step 3: Clone Repository

On the manager node:

```bash
git clone https://github.com/your-org/redLUIT_Dec2025_Docke04_WordPress.git
cd redLUIT_Dec2025_Docke04_WordPress
```

### Step 4: Create Docker Secrets

Create all required secrets before deployment:

```bash
# MySQL root password (use strong password!)
echo "$(openssl rand -base64 32)" | docker secret create mysql_root_password -

# MySQL WordPress user password
echo "$(openssl rand -base64 32)" | docker secret create mysql_password -

# Slack webhook URL for AlertManager
echo "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" | \
  docker secret create slack_webhook_url -
```

**Important:** Save these passwords securely! You'll need the WordPress password for database access.

Verify secrets were created:

```bash
docker secret ls
```

Expected output:
```
ID                NAME                  CREATED         UPDATED
abc123...         mysql_root_password   10 seconds ago  10 seconds ago
def456...         mysql_password        5 seconds ago   5 seconds ago
ghi789...         slack_webhook_url     2 seconds ago   2 seconds ago
```

## Deploy Monitoring Stack

Deploy monitoring stack first to create the `mon_net` overlay network that the application stack depends on.

### Step 1: Navigate to Monitoring Directory

```bash
cd stack-monitoring
```

### Step 2: Review Configuration Files

Verify configurations are correct:

```bash
# Check Prometheus config
cat prometheus.yml

# Check alert rules
cat alert.rules.yml

# Check AlertManager config
cat alertmanager.yml
```

### Step 3: Deploy Monitoring Stack

```bash
docker stack deploy -c monitoring-stack.yml monitoring
```

### Step 4: Verify Monitoring Services

```bash
# Check stack deployment
docker stack ps monitoring

# Wait for services to be Running
watch -n 2 'docker service ls | grep monitoring'
```

Expected services:
- monitoring_prometheus (1/1)
- monitoring_grafana (1/1)
- monitoring_alertmanager (1/1)
- monitoring_cadvisor (3/3 on 3-node cluster)
- monitoring_node_exporter (3/3 on 3-node cluster)

### Step 5: Verify mon_net Network

```bash
docker network ls | grep mon_net
```

This network must exist before deploying the application stack.

## Deploy Application Stack

### Step 1: Navigate to Application Directory

```bash
cd ../stack-app
```

### Step 2: Review Configuration

```bash
cat docker-stack.yml
```

Verify:
- MySQL and WordPress are connected to `mon_net` (external network)
- Secrets are properly referenced
- Health checks are configured

### Step 3: Deploy Application Stack

```bash
docker stack deploy -c docker-stack.yml levelop-wp
```

### Step 4: Monitor Deployment

```bash
# Watch service startup
docker stack ps levelop-wp --no-trunc

# Check service status
docker service ls | grep levelop-wp
```

Expected services:
- levelop-wp_mysql (1/1)
- levelop-wp_wordpress (3/3)

### Step 5: Wait for Health Checks

Services may take 30-60 seconds to become healthy:

```bash
# Watch until all services show "Running"
watch -n 5 'docker service ps levelop-wp'
```

## Verification

### Verify All Services Running

```bash
docker service ls
```

Expected output (on 3-node cluster):
```
NAME                        REPLICAS   IMAGE
levelop-wp_mysql            1/1        mysql:8.0
levelop-wp_wordpress        3/3        wordpress:latest
monitoring_prometheus       1/1        prom/prometheus:latest
monitoring_grafana          1/1        grafana/grafana:latest
monitoring_alertmanager     1/1        prom/alertmanager:latest
monitoring_cadvisor         3/3        gcr.io/cadvisor/cadvisor:v0.45.0
monitoring_node_exporter    3/3        prom/node-exporter:latest
```

### Test WordPress Access

```bash
# Get the Swarm manager IP
MANAGER_IP=$(docker node inspect self --format '{{.Status.Addr}}')

# Test WordPress
curl -I http://$MANAGER_IP:80
```

Expected: `HTTP/1.1 302 Found` (redirect to WordPress setup)

### Test Monitoring Access

```bash
# Test Prometheus
curl -I http://$MANAGER_IP:9090

# Test Grafana
curl -I http://$MANAGER_IP:3000

# Test AlertManager
curl -I http://$MANAGER_IP:9093
```

All should return `HTTP/1.1 200 OK`

### Check Prometheus Targets

Access Prometheus: `http://<manager-ip>:9090/targets`

All targets should be "UP":
- prometheus (1/1 up)
- cadvisor (3/3 up on 3-node cluster)
- node_exporter (3/3 up)

### Check Container Logs

```bash
# WordPress logs
docker service logs levelop-wp_wordpress --tail 50

# MySQL logs
docker service logs levelop-wp_mysql --tail 50

# Prometheus logs
docker service logs monitoring_prometheus --tail 50
```

Look for errors or warnings.

## WordPress Configuration

### Step 1: Access WordPress Setup

Open browser: `http://<manager-ip>:80`

### Step 2: Complete WordPress Installation

1. Select language
2. Enter site information:
   - Site Title: Your Site Name
   - Username: admin (or custom)
   - Password: Generate strong password
   - Email: your@email.com
3. Click "Install WordPress"

### Step 3: Login to WordPress

Use the credentials from setup.

### Step 4: Verify Database Connection

WordPress should show the dashboard without database errors.

### Step 5: Test Content Creation

1. Create a test post
2. Verify it appears on the site
3. Ensures persistent storage is working

## Post-Deployment Configuration

### Configure Grafana

1. Access Grafana: `http://<manager-ip>:3000`
2. Login: admin/admin (change on first login)
3. Add Prometheus data source:
   - Name: Prometheus
   - URL: `http://prometheus:9090`
   - Access: Server (default)
4. Import dashboards:
   - Docker Swarm dashboard (ID: 609)
   - cAdvisor dashboard (ID: 14282)
   - Node Exporter dashboard (ID: 1860)

### Test Alert Rules

Trigger a test alert:

```bash
# Stop a service temporarily
docker service scale levelop-wp_wordpress=0

# Wait 2-3 minutes, then check AlertManager
# Open: http://<manager-ip>:9093
```

You should see `InstanceDown` or `ServiceNotAtDesiredReplicas` alerts.

Restore service:

```bash
docker service scale levelop-wp_wordpress=3
```

### Configure Backup Script

See `docs/BACKUP_RESTORE.md` for automated backup setup.

## Troubleshooting

### Services Not Starting

**Check service logs:**
```bash
docker service logs <service-name> --tail 100
```

**Common issues:**
- Secrets not created
- Insufficient resources
- Network connectivity issues

**Solution:**
```bash
# Recreate secrets if needed
docker secret rm mysql_password
echo "new-password" | docker secret create mysql_password -

# Check node resources
docker node ls
docker node inspect <node-id>
```

### WordPress Database Connection Errors

**Symptoms:**
- "Error establishing a database connection"

**Solution:**
```bash
# Check MySQL is running
docker service ps levelop-wp_mysql

# Check secrets exist
docker secret ls | grep mysql

# Verify backend network
docker network inspect levelop-wp_backend

# Check MySQL logs
docker service logs levelop-wp_mysql --tail 100
```

### Monitoring Metrics Not Appearing

**Check Prometheus targets:**
```bash
curl http://<manager-ip>:9090/api/v1/targets
```

**Verify mon_net network:**
```bash
# Check network exists
docker network ls | grep mon_net

# Verify services are connected
docker service inspect levelop-wp_mysql | grep -A 5 Networks
docker service inspect monitoring_prometheus | grep -A 5 Networks
```

**Solution:**
```bash
# Redeploy monitoring stack
docker stack rm monitoring
sleep 30
docker stack deploy -c stack-monitoring/monitoring-stack.yml monitoring

# Redeploy app stack
docker stack rm levelop-wp
sleep 30
docker stack deploy -c stack-app/docker-stack.yml levelop-wp
```

### Alerts Not Reaching Slack

**Check AlertManager config:**
```bash
docker service logs monitoring_alertmanager --tail 50
```

**Verify secret:**
```bash
docker secret ls | grep slack_webhook_url
```

**Test webhook manually:**
```bash
WEBHOOK_URL="your-slack-webhook-url"
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test from Docker Swarm"}' \
  $WEBHOOK_URL
```

If test fails, webhook URL is incorrect.

### Performance Issues

**Check resource usage:**
```bash
# On each node
docker stats --no-stream

# Check service constraints
docker service inspect <service-name> | grep -A 10 Resources
```

**Scale WordPress:**
```bash
docker service scale levelop-wp_wordpress=5
```

**Add resource limits (edit docker-stack.yml):**
```yaml
deploy:
  resources:
    limits:
      cpus: '0.50'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

## Next Steps

1. Configure SSL/TLS with Traefik or nginx reverse proxy
2. Set up automated backups (see `docs/BACKUP_RESTORE.md`)
3. Configure Grafana dashboards
4. Set up log aggregation with Loki
5. Implement automated scaling policies
6. Configure external load balancer for production

## Production Checklist

Before going to production, verify:

- [ ] All secrets use strong, randomly generated passwords
- [ ] Backup strategy implemented and tested
- [ ] SSL/TLS configured for WordPress
- [ ] Grafana default password changed
- [ ] Alert notifications tested and working
- [ ] Resource limits tuned for workload
- [ ] Multiple nodes in Swarm cluster
- [ ] DNS configured for WordPress domain
- [ ] Monitoring dashboards configured
- [ ] WordPress plugins and themes updated
- [ ] MySQL performance tuned
- [ ] Log rotation configured

---

**Need help?** See the main [README.md](../README.md) or open an issue.
