[swarm_managers]
swarm-manager-1 ansible_host=${manager_ip} ansible_user=ubuntu

[swarm_workers]
%{ for idx, ip in worker_ips ~}
swarm-worker-${idx + 1} ansible_host=${ip} ansible_user=ubuntu
%{ endfor ~}

[swarm:children]
swarm_managers
swarm_workers

[swarm:vars]
ansible_python_interpreter=/usr/bin/python3
