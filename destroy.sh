#!/bin/bash
# Destroy Script
# Safely destroys all AWS infrastructure

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=========================================${NC}"
echo -e "${RED}Infrastructure Destruction${NC}"
echo -e "${RED}=========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will destroy all infrastructure!${NC}"
echo ""
echo "This will delete:"
echo "  - All EC2 instances (manager + workers)"
echo "  - VPC and all networking (subnets, IGW, NAT)"
echo "  - All security groups"
echo "  - SSH key pairs"
echo "  - All data will be PERMANENTLY LOST"
echo ""
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

read -p "Type 'DESTROY' to confirm: " confirm

if [ "$confirm" != "DESTROY" ]; then
    echo -e "${GREEN}Destruction cancelled${NC}"
    exit 0
fi

echo ""
echo "Proceeding with destruction in 5 seconds..."
sleep 5

cd infra/terraform

echo "Running Terraform destroy..."
terraform destroy -auto-approve

echo ""
echo -e "${GREEN}✅ Infrastructure destroyed${NC}"
echo ""
echo "Cleanup checklist:"
echo "  □ Verify in AWS Console that all resources are gone"
echo "  □ Check for orphaned resources (EBS snapshots, etc.)"
echo "  □ Remove SWARM_MANAGER_HOST from GitHub secrets"
echo "  □ Delete .deploy_vars file if it exists"
echo ""
