# Terraform Backend Configuration
# This stores state remotely in S3 with DynamoDB locking for idempotency

terraform {
  backend "s3" {
    # S3 bucket for state storage (created by setup-backend.sh)
    # IMPORTANT: Must be globally unique - update with your own prefix
    bucket = "wordpress-swarm-terraform-state"
    key    = "wordpress-swarm/terraform.tfstate"
    region = "us-east-1"

    # Enable encryption at rest
    encrypt = true

    # DynamoDB table for state locking (prevents concurrent modifications)
    dynamodb_table = "wordpress-swarm-terraform-lock"

    # Workspace isolation
    workspace_key_prefix = "workspaces"
  }
}

# NOTE: Backend cannot use variables, so values are hardcoded
# S3 bucket names must be globally unique across ALL AWS accounts
# To customize:
# 1. Choose a unique bucket name (e.g., "yourcompany-wordpress-swarm-terraform-state")
# 2. Update bucket/table names in BOTH backend.tf and setup-backend.sh (must match!)
# 3. Run: ./setup-backend.sh to create S3 bucket and DynamoDB table
# 4. Run: terraform init -reconfigure to initialize backend
