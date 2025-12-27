# Ansible Role: swarm-init

Initializes Docker Swarm cluster and joins manager and worker nodes.

## Requirements

- Ubuntu 20.04 LTS or 22.04 LTS
- Ansible 2.15 or higher
- Docker Engine installed (use docker-engine role)
- sudo/root access

## Role Variables

Available variables (see `defaults/main.yml`):

```yaml
# Swarm initialization
swarm_advertise_addr: "{{ ansible_default_ipv4.address }}"
swarm_listen_addr: "0.0.0.0:2377"

# Expected node counts
swarm_manager_expected_count: 1
swarm_worker_expected_count: 2

# Join settings
swarm_join_retries: 3
swarm_join_delay: 10
```

## Dependencies

- docker-engine role

## Example Playbook

```yaml
- hosts: swarm
  become: yes
  roles:
    - docker-engine
    - swarm-init
```

## What This Role Does

1. Checks if Swarm is already initialized
2. Initializes Swarm on first manager node
3. Retrieves join tokens (manager and worker)
4. Joins additional managers to cluster
5. Joins worker nodes to cluster
6. Verifies cluster health
7. Labels nodes appropriately

## Cluster Topology

- **Manager Nodes**: Control plane, handle orchestration
- **Worker Nodes**: Run application containers

Minimum recommended:
- 1 manager node (3 for HA)
- 2 worker nodes (for redundancy)

## Swarm Ports

Ensure these ports are open (handled by security-hardening role):
- TCP 2377: Cluster management
- TCP/UDP 7946: Node communication
- UDP 4789: Overlay network

## Handlers

- `restart docker for swarm` - Restarts Docker daemon

## Idempotency

This role is idempotent:
- Won't reinitialize if Swarm already exists
- Won't rejoin if node already in cluster
- Can be run multiple times safely

## License

MIT

## Author Information

Created for WordPress on Docker Swarm infrastructure project.
