# Docker Swarm Troubleshooting Guide

## Overview

This guide helps diagnose and fix common Docker Swarm issues, particularly worker nodes failing to join the cluster.

---

## Issue: Workers Fail to Join Swarm

### Symptoms

```
FAILED - RETRYING: Verify worker joined successfully (6 retries left)
fatal: [swarm-worker-1]: FAILED! => {
  "stdout": "error",
  "stdout_lines": ["error"]
}
```

Worker nodes show `LocalNodeState: error` instead of `active`.

### Root Causes & Solutions

#### 1. Ansible Variable Scope Issue (FIXED)

**Problem:**
Worker join token was registered only on manager node with `run_once: true`, making it unavailable to worker nodes.

**Fix Applied:**
Changed token access in `infra/ansible/roles/swarm-init/tasks/main.yml`:

```yaml
# Before (BROKEN)
- name: Join worker to Swarm
  ansible.builtin.command: >
    docker swarm join
    --token {{ worker_token.stdout }}
    {{ manager_ip }}:2377

# After (FIXED)
- name: Join worker to Swarm
  ansible.builtin.command: >
    docker swarm join
    --token {{ hostvars[groups['swarm_managers'][0]]['worker_token']['stdout'] }}
    {{ hostvars[groups['swarm_managers'][0]]['ansible_default_ipv4']['address'] }}:2377
```

**Verification:**
```bash
# The join command should now succeed
ansible-playbook -i infra/ansible/inventory/hosts infra/ansible/playbooks/swarm-setup.yml
```

---

#### 2. Security Group Misconfiguration

**Problem:**
Port 2377 (Swarm management port) is not open from workers to manager.

**Check:**
```bash
# From worker node, test connectivity
nc -zv <manager-ip> 2377

# If it fails, check security groups
aws ec2 describe-security-groups \
  --group-ids <manager-sg-id> \
  --query 'SecurityGroups[].IpPermissions'
```

**Required Rules:**

Manager security group must allow:
- **Port 2377/tcp** from worker security group (Swarm management)
- **Port 7946/tcp** from worker security group (Node communication)
- **Port 7946/udp** from worker security group (Node communication)
- **Port 4789/udp** from worker security group (Overlay network)

Worker security group must allow:
- **Port 7946/tcp** from manager security group
- **Port 7946/udp** from manager security group
- **Port 4789/udp** from manager security group

**Fix:**
The security groups in `infra/terraform/security-groups.tf` are already correctly configured with these rules (lines 189-263).

**Verification:**
```bash
# Apply Terraform changes
cd infra/terraform
terraform plan
terraform apply
```

---

#### 3. Previous Swarm Membership

**Problem:**
Worker node was previously part of a swarm and needs to leave before joining a new one.

**Symptoms:**
```
Error response from daemon: This node is already part of a swarm.
Use "docker swarm leave" to leave this swarm and join another one.
```

**Fix:**
The playbook now automatically handles this (lines 10-26 in swarm-init/tasks/main.yml):

```yaml
- name: Leave swarm if in error state
  ansible.builtin.command: docker swarm leave --force
  when: swarm_status.stdout == 'error'
```

**Manual Fix:**
```bash
# SSH to worker node
ssh ubuntu@<worker-ip>

# Force leave swarm
sudo docker swarm leave --force

# Verify status
docker info | grep "Swarm:"
# Should show: Swarm: inactive

# Re-run Ansible playbook
```

---

#### 4. Docker Daemon Issues

**Problem:**
Docker daemon is not running or in an unhealthy state.

**Check:**
```bash
# SSH to worker node
ssh ubuntu@<worker-ip>

# Check Docker status
systemctl status docker

# Check Docker version
docker version

# Check Docker info
docker info
```

**Fix:**
```bash
# Restart Docker daemon
sudo systemctl restart docker

# Check logs
journalctl -u docker -n 50 --no-pager

# If corrupted, reinstall
sudo apt-get remove docker-ce docker-ce-cli containerd.io
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

---

#### 5. Network Connectivity Issues

**Problem:**
Network routes, ACLs, or VPC configuration blocking communication.

**Check:**
```bash
# From worker node
ping <manager-ip>
nc -zv <manager-ip> 2377
traceroute <manager-ip>

# Check routes
ip route

# Check iptables
sudo iptables -L -n
```

**Common issues:**
- VPC CIDR blocks don't overlap
- Subnets are in different availability zones (should work but check route tables)
- Network ACLs blocking traffic (in addition to security groups)
- NAT gateway misconfiguration

**Fix:**
Verify VPC configuration in `infra/terraform/vpc.tf`:
```bash
cd infra/terraform
terraform show | grep -A 20 "aws_vpc.main"
terraform show | grep -A 20 "aws_subnet"
```

---

## Diagnostic Commands

The enhanced playbook now runs these diagnostics automatically on failure:

### 1. Docker Swarm Info
```bash
docker info | grep -A 10 Swarm
```

Expected output when healthy:
```
Swarm: active
  NodeID: <node-id>
  Is Manager: false
  ClusterID: <cluster-id>
  Managers: 1
  Nodes: 3
  LocalNodeState: active
```

### 2. Connectivity Test
```bash
nc -zv <manager-ip> 2377
```

Expected: `Connection to <manager-ip> 2377 port [tcp/*] succeeded!`

### 3. Docker Version
```bash
docker version --format '{{.Server.Version}}'
```

### 4. Recent Docker Logs
```bash
journalctl -u docker -n 20 --no-pager
```

### 5. Node List (from manager)
```bash
docker node ls
```

Expected output:
```
ID                            HOSTNAME          STATUS    AVAILABILITY
abc123... *  swarm-manager-1   Ready     Active           Leader
def456...    swarm-worker-1    Ready     Active
ghi789...    swarm-worker-2    Ready     Active
```

---

## Manual Debugging Steps

### Step 1: Verify Infrastructure

```bash
# Check EC2 instances are running
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=wordpress-swarm" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=wordpress-swarm" \
  --query 'SecurityGroups[].[GroupId,GroupName]' \
  --output table
```

### Step 2: Test SSH Access

```bash
# Get IPs from Terraform
cd infra/terraform
terraform output

# SSH to manager
ssh -i ~/.ssh/your-key.pem ubuntu@<manager-ip>

# SSH to workers
ssh -i ~/.ssh/your-key.pem ubuntu@<worker-ip>
```

### Step 3: Check Docker on Each Node

```bash
# On manager
docker info | grep -A 5 Swarm
docker node ls

# On each worker
docker info | grep -A 5 Swarm
```

### Step 4: Test Network Connectivity

```bash
# From worker-1 to manager
nc -zv <manager-private-ip> 2377
nc -zv <manager-private-ip> 7946
nc -zv <manager-private-ip> 4789

# From worker-2 to manager
nc -zv <manager-private-ip> 2377

# From worker-1 to worker-2
nc -zv <worker-2-private-ip> 7946
```

### Step 5: Manual Swarm Join

```bash
# On manager, get token
WORKER_TOKEN=$(docker swarm join-token -q worker)
MANAGER_IP=$(hostname -I | awk '{print $1}')
echo "Join command: docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"

# On worker
docker swarm join --token <token> <manager-ip>:2377

# Check status
docker info | grep "Swarm:"
```

---

## Ansible Debugging

### Enable Verbose Output

```bash
# Run with verbose mode
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml \
  -vvv

# Run with step-by-step confirmation
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml \
  --step
```

### Check Inventory

```bash
# Verify inventory is correct
ansible-inventory -i infra/ansible/inventory/hosts --list

# Test connectivity
ansible all -i infra/ansible/inventory/hosts -m ping

# Check gathered facts
ansible swarm_managers -i infra/ansible/inventory/hosts -m setup
```

### Run Specific Tasks

```bash
# Run only swarm-init role
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml \
  --tags swarm-init

# Start from specific task
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml \
  --start-at-task "Join worker to Swarm"
```

---

## Common Error Messages

### Error: "This node is already part of a swarm"

**Cause:** Node has existing swarm membership

**Fix:**
```bash
docker swarm leave --force
```

### Error: "Timeout was reached"

**Cause:** Manager not reachable on port 2377

**Fix:**
1. Check security groups (port 2377/tcp)
2. Verify manager IP address
3. Check network ACLs
4. Test connectivity: `nc -zv <manager-ip> 2377`

### Error: "manager is not running"

**Cause:** Manager swarm not initialized

**Fix:**
```bash
# On manager node
docker swarm init --advertise-addr <private-ip>
```

### Error: "rpc error: code = Unavailable"

**Cause:** Docker daemon issues or network problems

**Fix:**
```bash
# Restart Docker
sudo systemctl restart docker

# Check logs
journalctl -u docker -n 50
```

---

## Verification Checklist

After fixing issues, verify:

- [ ] Manager shows `Swarm: active` and `Is Manager: true`
- [ ] Workers show `Swarm: active` and `Is Manager: false`
- [ ] Manager can list all nodes: `docker node ls`
- [ ] All nodes show STATUS: Ready, AVAILABILITY: Active
- [ ] Port 2377 reachable from workers to manager
- [ ] Ports 7946 (tcp/udp) bidirectional
- [ ] Port 4789 (udp) bidirectional
- [ ] Security groups correctly configured
- [ ] Ansible playbook completes successfully

---

## Prevention

### Best Practices

1. **Infrastructure as Code**
   - Use Terraform for consistent infrastructure
   - Version control security groups
   - Document required ports

2. **Automated Testing**
   - Test connectivity before join
   - Verify swarm status after changes
   - Include health checks in deployment

3. **Monitoring**
   - Alert on swarm node status changes
   - Monitor Docker daemon health
   - Track failed join attempts

4. **Documentation**
   - Keep network diagrams updated
   - Document security group rules
   - Maintain runbooks for common issues

---

## Getting Help

If issues persist:

1. **Check Logs:**
   ```bash
   # Docker daemon logs
   journalctl -u docker -n 100 --no-pager

   # Swarm-specific logs
   docker service logs <service-name>
   ```

2. **Gather Information:**
   ```bash
   # Create debug bundle
   docker info > docker-info.txt
   docker node ls > nodes.txt
   ip route > routes.txt
   iptables -L -n > iptables.txt
   ```

3. **Review Documentation:**
   - [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
   - [Swarm Networking](https://docs.docker.com/network/overlay/)
   - Project README.md

4. **Community Support:**
   - Docker Forums
   - Stack Overflow (tag: docker-swarm)
   - GitHub Issues

---

## Summary

The worker join failure was caused by incorrect variable access in the Ansible playbook. The fix ensures workers can properly retrieve the join token from the manager node using hostvars.

**Key Changes:**
1. Fixed token access: `{{ hostvars[groups['swarm_managers'][0]]['worker_token']['stdout'] }}`
2. Added connectivity tests before join
3. Enhanced diagnostics on failure
4. Better error messages and troubleshooting guidance

All changes committed and pushed to dev branch.
