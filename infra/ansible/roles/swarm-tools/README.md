# Swarm Tools Role

This Ansible role installs additional tools for Docker Swarm management and monitoring.

## Tools Installed

### Docker Compose
- **Version**: Configurable (default: 2.24.5)
- **Purpose**: Multi-container application orchestration
- **Installation**: System-wide at `/usr/local/bin/docker-compose`

### Portainer
- **Version**: Latest (configurable)
- **Purpose**: Web-based Docker management UI
- **Deployment**: As a Docker Swarm service on manager nodes
- **Ports**:
  - 9443 (HTTPS web interface)
  - 9000 (HTTP web interface)
  - 8000 (Edge agent tunnel)
  - 9001 (Agent port)

## Requirements

- Docker Swarm cluster must be initialized
- `community.docker` Ansible collection
- Manager node for Portainer deployment

## Role Variables

```yaml
# Docker Compose version
docker_compose_version: "2.24.5"

# Portainer configuration
portainer_enabled: true
portainer_version: "latest"
portainer_agent_port: 9001
portainer_web_port: 9443
portainer_data_volume: "portainer_data"
```

## Dependencies

- `docker-engine` role (Docker must be installed)

## Example Playbook

```yaml
- hosts: swarm
  become: true
  roles:
    - swarm-tools
```

## Post-Installation

### Accessing Portainer

1. Navigate to `https://<manager-ip>:9443`
2. Create an admin account on first access
3. Connect to the local Swarm environment
4. Accept the self-signed certificate warning

### Using Docker Compose

```bash
docker-compose --version
docker-compose -f docker-compose.yml up -d
```

## Security Notes

- Portainer uses a self-signed certificate by default
- The web interface is exposed on port 9443
- Create a strong admin password on first access
- Consider using a reverse proxy with proper SSL/TLS in production

## License

MIT
