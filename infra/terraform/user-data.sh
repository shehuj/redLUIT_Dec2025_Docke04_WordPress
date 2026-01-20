#!/bin/bash
# User data script for EC2 instance initialization
# This runs once at instance launch before Ansible configuration

set -e

# Set hostname
hostnamectl set-hostname ${hostname}
echo "127.0.0.1 ${hostname}" >> /etc/hosts

# Update system packages
apt-get update
apt-get upgrade -y

# Install Python for Ansible (if not present)
apt-get install -y python3 python3-pip

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Signal completion
touch /var/log/user-data-complete.log
echo "User data script completed at $(date)" >> /var/log/user-data-complete.log
