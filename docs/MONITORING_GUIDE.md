# Monitoring Guide

Comprehensive guide for monitoring WordPress and MySQL using Prometheus, Grafana, and AlertManager.

## Table of Contents

1. [Overview](#overview)
2. [Accessing Monitoring Services](#accessing-monitoring-services)
3. [Prometheus](#prometheus)
4. [Grafana](#grafana)
5. [AlertManager](#alertmanager)
6. [Metrics Collection](#metrics-collection)
7. [Custom Dashboards](#custom-dashboards)
8. [Alert Configuration](#alert-configuration)

## Overview

The monitoring stack provides comprehensive observability for the WordPress deployment:

- **Prometheus** - Collects and stores metrics
- **Grafana** - Visualizes metrics with dashboards
- **AlertManager** - Routes alerts to Slack
- **cAdvisor** - Collects container metrics
- **Node Exporter** - Collects host system metrics

### Architecture

```
┌─────────────────────────────────────────────────┐
│  Application Services (WordPress, MySQL)        │
│  └─ Expose metrics on mon_net network           │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  cAdvisor (container metrics)                   │
│  └─ Scrapes Docker API for container stats      │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  Node Exporter (host metrics)                   │
│  └─ Collects CPU, memory, disk, network         │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  Prometheus                                     │
│  ├─ Scrapes all exporters every 15s             │
│  ├─ Evaluates alert rules every 15s             │
│  └─ Stores time-series data                     │
└─────────────────────┬───────────────────────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼                           ▼
┌───────────────┐         ┌─────────────────┐
│  Grafana      │         │  AlertManager   │
│  (Dashboards) │         │  (Alerts)       │
└───────────────┘         └────────┬────────┘
                                   │
                          ┌────────▼────────┐
                          │  Slack Channel  │
                          └─────────────────┘
```

## Accessing Monitoring Services

All services are accessible via the Swarm manager IP:

```bash
# Get manager IP
MANAGER_IP=$(docker node inspect self --format '{{.Status.Addr}}')

echo "Prometheus: http://$MANAGER_IP:9090"
echo "Grafana: http://$MANAGER_IP:3000"
echo "AlertManager: http://$MANAGER_IP:9093"
```

## Prometheus

### Web Interface

Access: `http://<manager-ip>:9090`

### Key Features

**1. Targets**

View all scrape targets: `Status → Targets`

All targets should show "UP":
- prometheus (1/1)
- cadvisor (N/N where N = node count)
- node_exporter (N/N)

**2. Graph Queries**

Example queries:

```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total{name=~"levelop-wp.*"}[5m])

# Container memory usage
container_memory_usage_bytes{name=~"levelop-wp.*"}

# Service replica count
count(container_spec_replicas_running{name="levelop-wp_wordpress"})

# MySQL connections
mysql_global_status_threads_connected

# WordPress response time
http_request_duration_seconds{job="wordpress"}
```

**3. Alerts**

View active alerts: `Alerts` tab

Current alert rules:
- InstanceDown - Instance unreachable for 2+ minutes
- ContainerUnhealthy - Container health check failing
- ServiceNotAtDesiredReplicas - Service scaled incorrectly

### Configuration

Located at: `stack-monitoring/prometheus.yml`

**Scrape Intervals:**
- Global scrape interval: 15s
- Global evaluation interval: 15s

**Jobs:**
- prometheus - Self-monitoring
- cadvisor - Container metrics (port 8080)
- node_exporter - Host metrics (port 9100)
- docker-swarm - Service metrics (port 9323)
- mysql_exporter - MySQL metrics (port 9104)

### Storage

Prometheus data is stored in Docker volume: `prometheus_data`

**Default retention:** 15 days

To change retention, edit monitoring-stack.yml:

```yaml
services:
  prometheus:
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'  # 30 days
```

## Grafana

### Initial Setup

1. Access: `http://<manager-ip>:3000`
2. Login: `admin` / `admin`
3. Change password when prompted
4. Configure data sources

### Add Prometheus Data Source

1. Navigate to: `Configuration → Data Sources`
2. Click: `Add data source`
3. Select: `Prometheus`
4. Configure:
   - Name: `Prometheus`
   - URL: `http://prometheus:9090`
   - Access: `Server (default)`
5. Click: `Save & Test`

Should show: "Data source is working"

### Import Dashboards

#### 1. Docker Swarm Dashboard

- Dashboard ID: **609**
- URL: https://grafana.com/grafana/dashboards/609

Import steps:
1. Click `+` → `Import`
2. Enter dashboard ID: `609`
3. Click `Load`
4. Select Prometheus data source
5. Click `Import`

Provides:
- Service status
- Container count
- CPU/Memory usage per service
- Network I/O

#### 2. cAdvisor Dashboard

- Dashboard ID: **14282**
- URL: https://grafana.com/grafana/dashboards/14282

Shows:
- Per-container CPU usage
- Memory usage and limits
- Network traffic
- Disk I/O

#### 3. Node Exporter Dashboard

- Dashboard ID: **1860**
- URL: https://grafana.com/grafana/dashboards/1860

Shows:
- Host CPU usage
- Memory and swap
- Disk space and I/O
- Network interfaces
- System load

### Custom Dashboard Variables

Create variables for dynamic filtering:

1. Go to dashboard settings → Variables
2. Add variable:
   - Name: `container`
   - Type: Query
   - Data source: Prometheus
   - Query: `label_values(container_name)`
   - Multi-value: true

Use in panels:
```promql
container_cpu_usage_seconds_total{container_name=~"$container"}
```

### Alerting in Grafana

Configure notification channels:

1. `Alerting → Notification channels`
2. Add channel:
   - Type: Slack
   - Webhook URL: Your Slack webhook
   - Channel: #alerts
3. Test notification

Create dashboard alerts:
1. Edit panel
2. Alert tab
3. Create alert rule
4. Select notification channel

## AlertManager

### Web Interface

Access: `http://<manager-ip>:9093`

### Configuration

Located at: `stack-monitoring/alertmanager.yml`

Current config sends all alerts to Slack:

```yaml
route:
  receiver: "slack-notifications"

receivers:
  - name: "slack-notifications"
    slack_configs:
      - send_resolved: true
        channel: "#alerts"
        api_url: "${SLACK_WEBHOOK_URL}"
```

### Customizing Alert Routing

Edit `alertmanager.yml` for advanced routing:

```yaml
route:
  receiver: "default"
  group_by: ['alertname', 'cluster']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

  routes:
    # Critical alerts to PagerDuty
    - match:
        severity: critical
      receiver: pagerduty
      continue: true

    # Warning alerts to Slack
    - match:
        severity: warning
      receiver: slack-notifications

receivers:
  - name: "default"
    slack_configs:
      - channel: "#general-alerts"
        api_url: "${SLACK_WEBHOOK_URL}"

  - name: "slack-notifications"
    slack_configs:
      - channel: "#alerts"
        api_url: "${SLACK_WEBHOOK_URL}"

  - name: "pagerduty"
    pagerduty_configs:
      - service_key: "<your-key>"
```

### Silencing Alerts

Temporarily silence alerts:

1. Access AlertManager UI
2. Click "Silences"
3. Create silence:
   - Matchers: `alertname="InstanceDown"`
   - Duration: 1h
   - Creator: Your name
   - Comment: Planned maintenance

## Metrics Collection

### Container Metrics (cAdvisor)

**Available metrics:**

```promql
# CPU usage
container_cpu_usage_seconds_total

# Memory usage
container_memory_usage_bytes
container_memory_max_usage_bytes

# Network
container_network_receive_bytes_total
container_network_transmit_bytes_total

# Filesystem
container_fs_usage_bytes
container_fs_limit_bytes
```

### Host Metrics (Node Exporter)

**Available metrics:**

```promql
# CPU
node_cpu_seconds_total
node_load1, node_load5, node_load15

# Memory
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes

# Disk
node_filesystem_size_bytes
node_filesystem_free_bytes
node_disk_io_time_seconds_total

# Network
node_network_receive_bytes_total
node_network_transmit_bytes_total
```

### Service Health

**Health check status:**

```promql
# Check if services are healthy
up{job="docker-swarm"}

# Replica count
container_spec_replicas_desired
container_spec_replicas_running
```

## Custom Dashboards

### Create WordPress Performance Dashboard

1. Create new dashboard
2. Add panels:

**Panel 1: WordPress Replicas**
```promql
count(container_last_seen{name=~"levelop-wp_wordpress.*"})
```

**Panel 2: WordPress CPU Usage**
```promql
rate(container_cpu_usage_seconds_total{name=~"levelop-wp_wordpress.*"}[5m]) * 100
```

**Panel 3: WordPress Memory**
```promql
container_memory_usage_bytes{name=~"levelop-wp_wordpress.*"} / 1024 / 1024
```

**Panel 4: MySQL Connections**
```promql
mysql_global_status_threads_connected
```

**Panel 5: Request Rate**
```promql
rate(container_network_receive_bytes_total{name=~"levelop-wp_wordpress.*"}[5m])
```

### Create MySQL Performance Dashboard

**Query Performance:**
```promql
rate(mysql_global_status_queries[5m])
```

**Slow Queries:**
```promql
rate(mysql_global_status_slow_queries[5m])
```

**Buffer Pool Usage:**
```promql
mysql_global_status_innodb_buffer_pool_bytes_data /
mysql_global_variables_innodb_buffer_pool_size * 100
```

## Alert Configuration

### Current Alert Rules

Located at: `stack-monitoring/alert.rules.yml`

**1. InstanceDown**
```yaml
- alert: InstanceDown
  expr: up == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Instance {{ $labels.instance }} down"
    description: "No metrics from {{ $labels.job }} on {{ $labels.instance }} for > 2m"
```

**2. ContainerUnhealthy**
```yaml
- alert: ContainerUnhealthy
  expr: increase(container_healthcheck_status_unhealthy[5m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Unhealthy container detected"
```

**3. ServiceNotAtDesiredReplicas**
```yaml
- alert: ServiceNotAtDesiredReplicas
  expr: sum(container_spec_replicas_desired - container_spec_replicas_running) > 0
  for: 3m
  labels:
    severity: critical
```

### Add Custom Alerts

Edit `alert.rules.yml`:

**High Memory Usage:**
```yaml
- alert: HighMemoryUsage
  expr: |
    (container_memory_usage_bytes{name=~"levelop-wp.*"} /
     container_spec_memory_limit_bytes{name=~"levelop-wp.*"}) > 0.9
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Container {{ $labels.name }} high memory usage"
    description: "Memory usage is above 90% for 5 minutes"
```

**High CPU Usage:**
```yaml
- alert: HighCPUUsage
  expr: |
    rate(container_cpu_usage_seconds_total{name=~"levelop-wp.*"}[5m]) > 0.8
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Container {{ $labels.name }} high CPU usage"
    description: "CPU usage is above 80% for 10 minutes"
```

**Disk Space Low:**
```yaml
- alert: DiskSpaceLow
  expr: |
    (node_filesystem_avail_bytes{mountpoint="/"} /
     node_filesystem_size_bytes{mountpoint="/"}) < 0.1
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Disk space low on {{ $labels.instance }}"
    description: "Less than 10% disk space available"
```

### Reload Configuration

After editing alert rules:

```bash
# Reload Prometheus configuration
docker service update --force monitoring_prometheus

# Verify rules loaded
curl http://<manager-ip>:9090/api/v1/rules
```

## Best Practices

1. **Set meaningful thresholds** - Tune alert thresholds based on actual workload
2. **Use appropriate `for` durations** - Avoid alert fatigue from transient issues
3. **Severity levels** - Use critical/warning/info consistently
4. **Alert descriptions** - Include actionable information
5. **Dashboard organization** - Group related panels together
6. **Regular review** - Review and update dashboards/alerts monthly
7. **Test alerts** - Regularly test alert routing
8. **Document custom metrics** - Maintain documentation for custom queries

## Troubleshooting

### Prometheus Not Scraping Targets

```bash
# Check Prometheus logs
docker service logs monitoring_prometheus --tail 50

# Verify network connectivity
docker exec $(docker ps -qf "name=monitoring_prometheus") \
  wget -O- http://cadvisor:8080/metrics
```

### Grafana Can't Reach Prometheus

```bash
# Verify both on mon_net
docker service inspect monitoring_prometheus | grep Networks
docker service inspect monitoring_grafana | grep Networks

# Test from Grafana container
docker exec $(docker ps -qf "name=monitoring_grafana") \
  wget -O- http://prometheus:9090/api/v1/query?query=up
```

### Alerts Not Firing

```bash
# Check AlertManager logs
docker service logs monitoring_alertmanager --tail 50

# Verify Prometheus can reach AlertManager
curl http://<manager-ip>:9090/api/v1/alertmanagers
```

---

**Need help?** See the main [README.md](../README.md) or open an issue.
