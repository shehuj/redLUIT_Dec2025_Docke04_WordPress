# Terraform Backend Configuration
# This stores state remotely in S3 with DynamoDB locking for idempotency

terraform {
  backend "s3" {
    # S3 bucket for state storage (created by setup-backend.sh)
    bucket = "wordpress-swarm-terraform-state"
    key    = "infrastructure/terraform.tfstate"
    region = "us-east-1"

    # Enable encryption at rest
    encrypt = true

    # DynamoDB table for state locking (prevents concurrent modifications)
    dynamodb_table = "wordpress-swarm-terraform-locks"

    # Workspace isolation
    workspace_key_prefix = "workspaces"
  }
}

# NOTE: Backend cannot use variables, so values are hardcoded
# To customize:
# 1. Update bucket name above
# 2. Run: ./setup-backend.sh to create S3 bucket and DynamoDB table
# 3. Run: terraform init -migrate-state to migrate existing state
