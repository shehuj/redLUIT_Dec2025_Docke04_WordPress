# Ansible Role: security-hardening

Applies security hardening measures to Docker Swarm cluster nodes including firewall configuration, fail2ban, and SSH hardening.

## Requirements

- Ubuntu 20.04 LTS or 22.04 LTS
- Ansible 2.15 or higher
- sudo/root access

## Role Variables

Available variables (see `defaults/main.yml`):

```yaml
# UFW Firewall
ufw_enabled: true
ssh_port: 22

# Docker Swarm ports
swarm_management_port: 2377
swarm_node_communication_port: 7946
swarm_overlay_network_port: 4789

# Additional ports
additional_allowed_ports:
  - 80    # HTTP
  - 443   # HTTPS
  - 3000  # Grafana
  - 9090  # Prometheus

# Fail2ban
fail2ban_enabled: true
fail2ban_maxretry: 5

# SSH hardening
ssh_permit_root_login: "no"
ssh_password_authentication: "no"
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: swarm
  become: yes
  roles:
    - security-hardening
```

## What This Role Does

1. Configures UFW firewall
2. Opens required Docker Swarm ports
3. Opens application ports (HTTP, HTTPS, monitoring)
4. Installs and configures fail2ban
5. Hardens SSH configuration
6. Enables automatic security updates
7. Configures kernel security parameters

## Handlers

- `restart ufw` - Restarts UFW firewall
- `restart ssh` - Restarts SSH service
- `restart fail2ban` - Restarts fail2ban service

## Security Ports

### Docker Swarm
- TCP 2377: Cluster management
- TCP/UDP 7946: Node communication
- UDP 4789: Overlay network traffic

### Applications
- TCP 80: HTTP (WordPress)
- TCP 443: HTTPS (WordPress with SSL)
- TCP 3000: Grafana dashboard
- TCP 9090: Prometheus
- TCP 9093: AlertManager

## License

MIT

## Author Information

Created for WordPress on Docker Swarm infrastructure project.
