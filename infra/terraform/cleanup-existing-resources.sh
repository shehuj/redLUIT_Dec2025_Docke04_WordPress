#!/bin/bash
# Cleanup or Import Existing AWS Resources
# Helps resolve VPC limit and other resource conflicts

set -e

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-wordpress-swarm}"

echo "🔍 Checking for existing resources that may conflict..."
echo ""

# Function to list VPCs
list_vpcs() {
    echo "📋 Existing VPCs in $AWS_REGION:"
    aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0],State]' \
        --output table
    echo ""
}

# Function to list VPC count
check_vpc_limit() {
    VPC_COUNT=$(aws ec2 describe-vpcs --region "$AWS_REGION" --query 'length(Vpcs)' --output text)
    echo "📊 Current VPC count: $VPC_COUNT"
    echo "   Default limit: 5 VPCs per region"
    echo ""
}

# Function to find WordPress Swarm VPCs
find_project_vpcs() {
    echo "🔎 Looking for $PROJECT_NAME VPCs..."
    aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=*${PROJECT_NAME}*" \
        --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
        --output table
    echo ""
}

# Function to show deletion command
show_delete_commands() {
    echo "🗑️  To delete a VPC (if not managed by Terraform):"
    echo ""
    echo "   # List all resources in the VPC first:"
    echo "   aws ec2 describe-vpc-attribute --vpc-id vpc-xxxxx --attribute enableDnsHostnames"
    echo ""
    echo "   # Delete VPC (this will fail if resources exist inside):"
    echo "   aws ec2 delete-vpc --vpc-id vpc-xxxxx --region $AWS_REGION"
    echo ""
    echo "   # Or use AWS Console to delete VPC and all its resources"
    echo ""
}

# Function to import existing VPC to Terraform
show_import_commands() {
    echo "📥 To import an existing VPC into Terraform state:"
    echo ""
    echo "   # 1. Identify the VPC ID from the list above"
    echo "   # 2. Run terraform import command:"
    echo "   terraform import aws_vpc.main vpc-xxxxx"
    echo ""
    echo "   # 3. Import other resources similarly:"
    echo "   terraform import aws_internet_gateway.main igw-xxxxx"
    echo "   terraform import aws_subnet.public[0] subnet-xxxxx"
    echo ""
    echo "   # 4. Verify with terraform plan"
    echo "   terraform plan"
    echo ""
}

# Main execution
echo "=================================================="
echo "  AWS Resource Cleanup/Import Helper"
echo "=================================================="
echo ""

check_vpc_limit
list_vpcs
find_project_vpcs

echo "=================================================="
echo "  Options to resolve VPC limit:"
echo "=================================================="
echo ""
echo "Option 1: Delete unused VPCs"
show_delete_commands

echo "Option 2: Import existing $PROJECT_NAME VPC"
show_import_commands

echo "Option 3: Request VPC limit increase"
echo "   - Go to AWS Service Quotas console"
echo "   - Request increase for VPC quota"
echo ""

echo "Option 4: Use different region"
echo "   - Update variables.tf or terraform.tfvars"
echo "   - Set aws_region to a different region"
echo ""

echo "=================================================="
echo "  Recommended approach for idempotency:"
echo "=================================================="
echo ""
echo "1. ✅ Setup backend (run ./setup-backend.sh)"
echo "2. ✅ Initialize Terraform (terraform init)"
echo "3. ✅ Use terraform import for existing resources"
echo "4. ✅ Or delete unused VPCs/resources"
echo "5. ✅ Run terraform plan to verify"
echo "6. ✅ Run terraform apply to sync state"
echo ""
