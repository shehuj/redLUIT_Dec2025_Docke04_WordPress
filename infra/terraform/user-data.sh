#!/bin/bash
# Instance initialization script

# Set hostname
hostnamectl set-hostname ${hostname}

# Update system packages
apt-get update

# Install Python3 for Ansible
apt-get install -y python3 python3-pip

# Create ubuntu user if it doesn't exist (should already exist on Ubuntu AMI)
if ! id -u ubuntu >/dev/null 2>&1; then
    useradd -m -s /bin/bash ubuntu
    usermod -aG sudo ubuntu
fi

# Ensure SSH directory exists for ubuntu user
mkdir -p /home/ubuntu/.ssh
chown ubuntu:ubuntu /home/ubuntu/.ssh
chmod 700 /home/ubuntu/.ssh
