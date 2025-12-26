#!/usr/bin/env bash
set -euo pipefail

# Script to install Docker Engine on Ubuntu (22.04/24.04) and prepare for container deployments

# 1. Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "❌ This script must be run as root or via sudo."
  exit 1
fi

echo "✅ Starting Docker installation and setup..."

# 2. Update package index and install prerequisites
apt-get update -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  apt-transport-https

# 3. Add Docker’s official GPG key and repository
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine, CLI, containerd, Buildx, Compose plugin
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Enable and start Docker service
systemctl enable docker
systemctl start docker

# 6. Optionally add the default user (e.g., ubuntu) to the 'docker' group
#    so that you can run docker commands without sudo.
if id ubuntu &> /dev/null; then
  usermod -aG docker ubuntu
  echo "✅ Added user 'ubuntu' to docker group."
fi

# 7. Confirm installation
docker --version
echo "✅ Docker installation completed successfully."

# 8. (Optional) Pull a test container to validate
# docker run --rm hello-world

echo "🎉 EC2 instance is ready for Docker container deployments."