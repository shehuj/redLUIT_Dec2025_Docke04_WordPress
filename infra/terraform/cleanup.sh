#!/bin/bash
# Cleanup Script - Destroys all infrastructure
# WARNING: This will DELETE all provisioned AWS resources!

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-us-east-1}"
BACKEND_BUCKET="ec2-shutdown-lambda-bucket"
BACKEND_TABLE="dyning_table"

echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          WordPress Swarm Infrastructure Cleanup                ║${NC}"
echo -e "${YELLOW}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║  WARNING: This will DESTROY all provisioned resources!        ║${NC}"
echo -e "${YELLOW}║  This action CANNOT be undone!                                 ║${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to prompt for confirmation
confirm() {
    local prompt="$1"
    local response

    read -p "$prompt (type 'yes' to confirm): " response
    if [ "$response" != "yes" ]; then
        echo -e "${RED}❌ Cleanup cancelled${NC}"
        exit 1
    fi
}

# Function to cleanup Docker resources
cleanup_docker() {
    echo -e "${YELLOW}🐳 Cleaning up Docker resources...${NC}"

    # Get manager IP
    MANAGER_IP=$(terraform output -raw swarm_manager_public_ip 2>/dev/null || echo "")

    if [ -z "$MANAGER_IP" ]; then
        echo -e "${YELLOW}⚠️  No manager IP found, skipping Docker cleanup${NC}"
        return
    fi

    # Check if SSH key is available
    if [ -z "$SSH_KEY_PATH" ]; then
        echo -e "${YELLOW}⚠️  SSH_KEY_PATH not set, skipping Docker cleanup${NC}"
        echo "   Set SSH_KEY_PATH environment variable to enable Docker cleanup"
        return
    fi

    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo -e "${RED}❌ SSH key not found at: $SSH_KEY_PATH${NC}"
        return
    fi

    echo "   Manager IP: $MANAGER_IP"
    echo "   SSH Key: $SSH_KEY_PATH"

    # SSH into manager and cleanup
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$SSH_KEY_PATH" "ubuntu@$MANAGER_IP" << 'ENDSSH' || true
        echo "Removing Docker stacks..."
        docker stack rm wordpress 2>/dev/null || true
        docker stack rm portainer 2>/dev/null || true

        # Wait for services to stop
        sleep 30

        echo "Removing all Docker services..."
        docker service rm $(docker service ls -q) 2>/dev/null || true

        echo "Pruning Docker system..."
        docker system prune -af --volumes 2>/dev/null || true

        echo "Docker cleanup complete"
ENDSSH

    echo -e "${GREEN}✅ Docker resources cleaned up${NC}"
}

# Function to destroy Terraform infrastructure
destroy_terraform() {
    echo -e "${YELLOW}🏗️  Destroying Terraform infrastructure...${NC}"

    cd "$SCRIPT_DIR"

    # Initialize Terraform
    terraform init

    # Show what will be destroyed
    echo ""
    echo -e "${YELLOW}Resources to be destroyed:${NC}"
    terraform state list 2>/dev/null || echo "No resources found"
    echo ""

    # Destroy
    terraform destroy -auto-approve

    echo -e "${GREEN}✅ Terraform infrastructure destroyed${NC}"
}

# Function to clear Terraform backend contents
cleanup_backend() {
    echo -e "${YELLOW}🗄️  Clearing Terraform backend contents...${NC}"

    # Check if bucket exists and empty it
    if aws s3api head-bucket --bucket "$BACKEND_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
        echo "   Emptying S3 bucket: $BACKEND_BUCKET"
        aws s3 rm "s3://$BACKEND_BUCKET" --recursive --region "$AWS_REGION"

        echo "   Deleting all object versions..."
        aws s3api delete-objects \
            --bucket "$BACKEND_BUCKET" \
            --delete "$(aws s3api list-object-versions \
                --bucket "$BACKEND_BUCKET" \
                --output=json \
                --region "$AWS_REGION" \
                --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" \
            2>/dev/null || true

        echo "   Deleting delete markers..."
        aws s3api delete-objects \
            --bucket "$BACKEND_BUCKET" \
            --delete "$(aws s3api list-object-versions \
                --bucket "$BACKEND_BUCKET" \
                --output=json \
                --region "$AWS_REGION" \
                --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" \
            2>/dev/null || true

        echo -e "${GREEN}   ✅ S3 bucket emptied (bucket preserved)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  S3 bucket not found${NC}"
    fi

    # Check if table exists and clear items
    if aws dynamodb describe-table --table-name "$BACKEND_TABLE" --region "$AWS_REGION" 2>/dev/null; then
        echo "   Clearing DynamoDB table items: $BACKEND_TABLE"

        # Scan and delete all items
        aws dynamodb scan --table-name "$BACKEND_TABLE" --region "$AWS_REGION" \
            --attributes-to-get "LockID" --output json | \
            jq -r '.Items[] | .LockID.S' 2>/dev/null | \
            while read -r lock_id; do
                if [ -n "$lock_id" ]; then
                    echo "   Deleting lock: $lock_id"
                    aws dynamodb delete-item \
                        --table-name "$BACKEND_TABLE" \
                        --key "{\"LockID\": {\"S\": \"$lock_id\"}}" \
                        --region "$AWS_REGION" 2>/dev/null || true
                fi
            done

        echo -e "${GREEN}   ✅ DynamoDB table cleared (table preserved)${NC}"
    else
        echo -e "${YELLOW}   ⚠️  DynamoDB table not found${NC}"
    fi

    echo -e "${GREEN}✅ Backend contents cleared (infrastructure preserved)${NC}"
}

# Main cleanup flow
main() {
    echo "This script will:"
    echo "  1. Clean up Docker resources (stacks, services, volumes)"
    echo "  2. Destroy all Terraform-managed infrastructure"
    echo "  3. Optionally clear Terraform backend contents (S3 + DynamoDB)"
    echo ""

    # First confirmation
    confirm "Are you sure you want to destroy ALL infrastructure?"

    echo ""

    # Check for AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        echo -e "${RED}❌ AWS credentials not configured${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ AWS credentials verified${NC}"

    # Step 1: Docker cleanup
    echo ""
    read -p "Clean up Docker resources? (y/n): " response
    if [ "$response" = "y" ]; then
        cleanup_docker
    else
        echo -e "${YELLOW}⏭️  Skipping Docker cleanup${NC}"
    fi

    # Step 2: Terraform destroy
    echo ""
    confirm "Proceed with Terraform destroy?"
    destroy_terraform

    # Step 3: Backend cleanup
    echo ""
    echo -e "${YELLOW}ℹ️  Backend cleanup will empty S3 bucket and clear DynamoDB items${NC}"
    echo "   The bucket and table will be preserved for future use."
    read -p "Clear Terraform backend contents (S3 + DynamoDB)? (y/n): " response
    if [ "$response" = "y" ]; then
        cleanup_backend
    else
        echo -e "${YELLOW}⏭️  Skipping backend cleanup${NC}"
    fi

    # Summary
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Cleanup Complete!                                 ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║  All infrastructure has been successfully destroyed            ║${NC}"
    echo -e "${GREEN}║  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
}

# Run main function
main
