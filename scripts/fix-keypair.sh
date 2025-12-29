#!/bin/bash
# Quick fix for duplicate key pair error
# Deletes existing key pair and allows Terraform to recreate it

set -e

PROJECT_NAME="${PROJECT_NAME:-wordpress-swarm}"
AWS_REGION="${AWS_REGION:-us-east-1}"
KEY_NAME="${PROJECT_NAME}-swarm-key"

echo "=========================================="
echo "EC2 Key Pair Cleanup Script"
echo "=========================================="
echo "Project: $PROJECT_NAME"
echo "Region: $AWS_REGION"
echo "Key Name: $KEY_NAME"
echo ""

# Check if key pair exists
echo "Checking if key pair exists..."
if aws ec2 describe-key-pairs \
    --key-names "$KEY_NAME" \
    --region "$AWS_REGION" \
    --output text &> /dev/null; then

    echo "✓ Key pair '$KEY_NAME' found"
    echo ""

    read -p "Delete existing key pair? (yes/no): " -r
    echo ""

    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deleting key pair..."
        aws ec2 delete-key-pair \
            --key-name "$KEY_NAME" \
            --region "$AWS_REGION"

        echo "✓ Key pair deleted successfully"
        echo ""
        echo "You can now run 'terraform apply' to recreate it"
    else
        echo "Cancelled. Key pair not deleted."
        echo ""
        echo "Alternative: Import into Terraform state:"
        echo "  terraform import aws_key_pair.swarm_key $KEY_NAME"
    fi
else
    echo "✗ Key pair '$KEY_NAME' not found"
    echo "No action needed - Terraform can create it"
fi
