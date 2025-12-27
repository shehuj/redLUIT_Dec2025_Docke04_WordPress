#!/bin/bash
# Quick fix script to update UFW rules on existing nodes
# Run this if you have already deployed infrastructure but Swarm nodes can't join

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}UFW Quick Fix for Swarm Nodes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if swarm-key.pem exists
if [ ! -f "swarm-key.pem" ]; then
    echo -e "${RED}Error: swarm-key.pem not found${NC}"
    echo "Please run this from the project root directory"
    exit 1
fi

# Get manager IP from terraform
if [ ! -f ".deploy_vars" ]; then
    echo -e "${YELLOW}Getting manager IP from Terraform...${NC}"
    cd infra/terraform
    MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
    WORKER_IPS=$(terraform output -json swarm_worker_public_ips | jq -r '.[]')
    cd ../..
    echo "MANAGER_IP=$MANAGER_IP" > .deploy_vars
else
    source .deploy_vars
    cd infra/terraform
    WORKER_IPS=$(terraform output -json swarm_worker_public_ips | jq -r '.[]')
    cd ../..
fi

echo -e "${GREEN}Manager IP: $MANAGER_IP${NC}"
echo -e "${GREEN}Worker IPs: $(echo $WORKER_IPS | tr '\n' ' ')${NC}"
echo ""

# Function to fix UFW on a node
fix_node() {
    local IP=$1
    local NAME=$2

    echo -e "${BLUE}Fixing UFW on $NAME ($IP)...${NC}"

    ssh -i swarm-key.pem -o StrictHostKeyChecking=no ubuntu@${IP} bash << 'ENDSSH'
        echo "Adding UFW rule for VPC traffic..."
        sudo ufw allow from 10.0.0.0/16 comment 'Allow all traffic from VPC'

        echo "Checking if Docker is in error state..."
        SWARM_STATE=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "inactive")

        if [ "$SWARM_STATE" = "error" ]; then
            echo "Resetting Swarm error state..."
            sudo docker swarm leave --force 2>/dev/null || true
        fi

        echo "Reloading UFW..."
        sudo ufw reload

        echo "Restarting Docker..."
        sudo systemctl restart docker

        sleep 5

        echo "Current Swarm state: $(docker info --format '{{.Swarm.LocalNodeState}}')"
ENDSSH

    echo -e "${GREEN}✅ Fixed $NAME${NC}"
    echo ""
}

# Fix manager
echo -e "${YELLOW}Step 1: Fixing Manager Node${NC}"
fix_node "$MANAGER_IP" "Manager"

# Fix workers
echo -e "${YELLOW}Step 2: Fixing Worker Nodes${NC}"
for WORKER_IP in $WORKER_IPS; do
    fix_node "$WORKER_IP" "Worker"
done

# Wait a bit for Docker to stabilize
echo -e "${YELLOW}Waiting for Docker to stabilize...${NC}"
sleep 10

# Try to join workers again
echo -e "${YELLOW}Step 3: Attempting to join workers to Swarm${NC}"

# Get join token from manager
echo "Getting worker join token..."
JOIN_TOKEN=$(ssh -i swarm-key.pem -o StrictHostKeyChecking=no ubuntu@${MANAGER_IP} 'docker swarm join-token -q worker')
MANAGER_PRIVATE_IP=$(ssh -i swarm-key.pem -o StrictHostKeyChecking=no ubuntu@${MANAGER_IP} "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")

echo -e "${GREEN}Manager private IP: $MANAGER_PRIVATE_IP${NC}"

for WORKER_IP in $WORKER_IPS; do
    echo -e "${BLUE}Joining worker $WORKER_IP to Swarm...${NC}"

    ssh -i swarm-key.pem -o StrictHostKeyChecking=no ubuntu@${WORKER_IP} bash << ENDSSH
        CURRENT_STATE=\$(docker info --format '{{.Swarm.LocalNodeState}}')

        if [ "\$CURRENT_STATE" != "active" ]; then
            echo "Joining Swarm..."
            docker swarm join --token ${JOIN_TOKEN} ${MANAGER_PRIVATE_IP}:2377 || {
                echo "Join command issued, checking status in 10 seconds..."
                sleep 10
            }
        else
            echo "Already joined to Swarm"
        fi

        echo "Final state: \$(docker info --format '{{.Swarm.LocalNodeState}}')"
ENDSSH

    echo ""
done

# Verify cluster
echo -e "${YELLOW}Step 4: Verifying Swarm Cluster${NC}"
echo ""
ssh -i swarm-key.pem -o StrictHostKeyChecking=no ubuntu@${MANAGER_IP} 'docker node ls'

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}UFW Fix Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "If workers still show as down, wait 30 seconds and check again:"
echo "  ssh -i swarm-key.pem ubuntu@${MANAGER_IP} 'docker node ls'"
echo ""
