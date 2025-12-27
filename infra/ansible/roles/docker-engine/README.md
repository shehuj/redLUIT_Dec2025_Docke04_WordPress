# Ansible Role: docker-engine

Installs and configures Docker Engine on Ubuntu systems for Docker Swarm cluster nodes.

## Requirements

- Ubuntu 20.04 LTS or 22.04 LTS
- Ansible 2.15 or higher
- sudo/root access

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
# Docker edition to install
docker_edition: "ce"

# Docker packages to install
docker_packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin

# Users to add to docker group
docker_users:
  - ubuntu
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: swarm
  become: yes
  roles:
    - docker-engine
```

## What This Role Does

1. Updates APT package index
2. Installs prerequisite packages
3. Adds Docker GPG key and repository
4. Installs Docker Engine and related packages
5. Enables and starts Docker service
6. Adds specified users to docker group
7. Installs Docker Python library for Ansible
8. Verifies Docker installation

## Handler

s

- `restart docker` - Restarts Docker daemon
- `reload docker` - Reloads Docker daemon configuration
- `restart containerd` - Restarts containerd service

## License

MIT

## Author Information

Created for WordPress on Docker Swarm infrastructure project.
