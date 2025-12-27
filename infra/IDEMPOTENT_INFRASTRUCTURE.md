# Idempotent Infrastructure Guide

## Overview

This infrastructure setup is designed to be **fully idempotent**, meaning you can run it multiple times safely without creating duplicate resources or errors.

## Problem: VPC Limit Exceeded

If you see this error:
```
Error: creating EC2 VPC: operation error EC2: CreateVpc,
api error VpcLimitExceeded: The maximum number of VPCs has been reached.
```

This happens when:
1. **No backend configured** - Terraform doesn't remember previous runs
2. **Orphaned resources** - VPCs created but not tracked in state
3. **Multiple deployments** - Each run tries to create new VPCs

## Solution: Remote State Backend

We use **S3 + DynamoDB** for remote state storage, which provides:
- ✅ **Persistent state** - Remembers all resources across runs
- ✅ **State locking** - Prevents concurrent modifications
- ✅ **Idempotency** - Only creates what doesn't exist
- ✅ **Team collaboration** - Shared state for CI/CD

## Setup Instructions

### Step 1: Setup Backend (One-time)

The backend infrastructure (S3 bucket + DynamoDB table) must be created first:

```bash
cd infra/terraform

# Setup backend infrastructure
./setup-backend.sh

# Output:
# ✅ S3 bucket created (or already exists)
# ✅ Versioning enabled
# ✅ Encryption enabled
# ✅ Public access blocked
# ✅ DynamoDB table created (or already exists)
```

**What it creates:**
- S3 bucket: `ec2-shutdown-lambda-bucket`
- DynamoDB table: `dyning_table`
- Bucket versioning, encryption, and lifecycle policies

**Idempotency:** Safe to run multiple times - it checks if resources exist first.

### Step 2: Clean Up Existing Resources (If needed)

If you hit the VPC limit, you have three options:

#### Option A: Delete Unused VPCs (Recommended if orphaned)

```bash
# Check what VPCs exist
./cleanup-existing-resources.sh

# This shows:
# - All VPCs in your region
# - Which ones belong to this project
# - Commands to delete them

# To delete a VPC (use AWS Console or CLI):
aws ec2 delete-vpc --vpc-id vpc-xxxxx --region us-east-1
```

**Note:** You may need to delete resources inside the VPC first (subnets, internet gateways, etc.)

#### Option B: Import Existing Resources (If you want to keep them)

```bash
# Initialize Terraform with backend
terraform init

# Import existing VPC
terraform import aws_vpc.main vpc-xxxxx

# Import other resources
terraform import aws_internet_gateway.main igw-xxxxx
terraform import aws_subnet.public[0] subnet-xxxxx
# ... continue for all resources

# Verify
terraform plan  # Should show no changes if imported correctly
```

#### Option C: Use Different Region

Update `variables.tf` or create `terraform.tfvars`:

```hcl
aws_region = "us-west-2"  # Different region
```

### Step 3: Initialize Terraform

```bash
# Initialize with backend
terraform init

# If migrating from local state:
terraform init -migrate-state

# Verify configuration
terraform validate
```

### Step 4: Deploy Infrastructure

```bash
# Plan - see what will be created
terraform plan

# Apply - create infrastructure
terraform apply

# Output shows what's created/updated/destroyed
```

## How Idempotency Works

### 1. Remote State Storage

```
┌─────────────────┐
│ First Run       │
│ terraform apply │
└────────┬────────┘
         │
         ↓
┌─────────────────────────────┐
│ Creates:                    │
│ - VPC                       │
│ - Subnets                   │
│ - EC2 instances             │
│ Saves state to S3           │
└────────┬────────────────────┘
         │
         ↓
┌─────────────────┐
│ Second Run      │
│ terraform apply │
└────────┬────────┘
         │
         ↓
┌─────────────────────────────┐
│ Reads state from S3         │
│ Compares with AWS           │
│ No changes needed ✅        │
│ "No changes detected"       │
└─────────────────────────────┘
```

### 2. State Locking

```
┌──────────────┐      ┌──────────────┐
│ CI/CD Job 1  │      │ CI/CD Job 2  │
└──────┬───────┘      └──────┬───────┘
       │                     │
       ↓                     ↓
  terraform apply       terraform apply
       │                     │
       ↓                     ↓
  ┌─────────────────────────────┐
  │ DynamoDB State Lock         │
  │ Job 1: Acquired lock ✅     │
  │ Job 2: Waiting... ⏳        │
  └─────────────────────────────┘
       │                     │
       ↓                     ↓
  Job 1 completes         Lock released
  Lock released           Job 2 acquires lock
                         Job 2 runs
```

### 3. Terraform Plan Detection

```bash
# First run
$ terraform plan
Plan: 15 to add, 0 to change, 0 to destroy

$ terraform apply
Apply complete! Resources: 15 added, 0 changed, 0 destroyed

# Second run (idempotent)
$ terraform plan
No changes. Your infrastructure matches the configuration.

$ terraform apply
Apply complete! Resources: 0 added, 0 changed, 0 destroyed
```

### 4. Workflow Integration

Workflows automatically:
1. Setup backend (idempotent)
2. Initialize Terraform with backend
3. Run plan to detect changes
4. Only apply if changes detected

```yaml
- name: Setup Terraform Backend (Idempotent)
  run: ./setup-backend.sh  # Safe to run every time

- name: Terraform Init with Backend
  run: terraform init -reconfigure

- name: Terraform Plan
  run: terraform plan -detailed-exitcode
  # Exit code 0 = no changes
  # Exit code 2 = changes detected

- name: Terraform Apply
  if: plan shows changes
  run: terraform apply
```

## Troubleshooting

### Issue: "Backend configuration changed"

```bash
# Solution: Reconfigure backend
terraform init -reconfigure
```

### Issue: "State lock already held"

```bash
# Check who has the lock
aws dynamodb get-item \
  --table-name wordpress-swarm-terraform-locks \
  --key '{"LockID": {"S": "wordpress-swarm-terraform-state/infrastructure/terraform.tfstate"}}'

# If stale lock (from crashed job), force unlock
terraform force-unlock <lock-id>
```

### Issue: "Resource already exists"

```bash
# Import the resource
terraform import <resource_type>.<resource_name> <resource_id>

# Example:
terraform import aws_vpc.main vpc-12345678
```

### Issue: State and reality differ

```bash
# Refresh state from AWS
terraform refresh

# Or reimport specific resources
terraform import aws_vpc.main vpc-12345678
```

## Backend Configuration Files

### backend.tf
- Contains S3 backend configuration
- Automatically used by Terraform

### backend-config.tfbackend
- Alternative configuration file
- Use with: `terraform init -backend-config=backend-config.tfbackend`

### setup-backend.sh
- Creates S3 bucket and DynamoDB table
- Idempotent - safe to run multiple times
- Configures bucket encryption, versioning, lifecycle

### cleanup-existing-resources.sh
- Helper to find and manage existing resources
- Shows commands to delete or import
- Lists all VPCs and project resources

## Best Practices

### 1. Always Use Backend

```bash
# ✅ Good - uses backend
terraform init
terraform apply

# ❌ Bad - no backend, state stored locally
terraform init -backend=false
terraform apply
```

### 2. Let CI/CD Handle Backend Setup

The workflows automatically run `setup-backend.sh` before `terraform init`, so you don't need to do it manually in CI/CD.

### 3. Import Existing Resources

If you created resources manually or in a previous run without state:

```bash
# Find resource IDs
aws ec2 describe-vpcs
aws ec2 describe-instances

# Import them
terraform import aws_vpc.main vpc-xxxxx
terraform import aws_instance.manager i-xxxxx
```

### 4. Use Workspaces for Environments

```bash
# Create workspace for staging
terraform workspace new staging
terraform apply

# Switch to production
terraform workspace select production
terraform apply

# Each workspace has separate state
```

### 5. Regular State Backups

The S3 bucket has versioning enabled, so you can recover previous states:

```bash
# List all state versions
aws s3api list-object-versions \
  --bucket wordpress-swarm-terraform-state \
  --prefix infrastructure/

# Restore specific version
aws s3api get-object \
  --bucket wordpress-swarm-terraform-state \
  --key infrastructure/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate
```

## Workflow Integration

### Local Development

```bash
# 1. Setup backend once
./setup-backend.sh

# 2. Initialize
terraform init

# 3. Work normally
terraform plan
terraform apply
```

### CI/CD (GitHub Actions)

The workflows handle everything automatically:

1. **PR to dev** - Runs plan without applying
2. **Merge to main** - Runs full pipeline with backend

Backend setup is automatic and idempotent.

## Cost Considerations

### Backend Costs (Minimal)

- **S3 Storage**: ~$0.023/GB/month
- **S3 Requests**: ~$0.005/1000 requests
- **DynamoDB**: ~$0.25/month (5 RCU + 5 WCU)

**Estimated monthly cost:** < $1

### Infrastructure Costs

- **EC2 instances**: Based on instance types
- **EBS volumes**: Based on volume sizes
- **Data transfer**: Based on usage
- **NAT Gateway**: ~$32/month

## Security

### Backend Security

- ✅ Encryption at rest (AES256)
- ✅ Bucket versioning enabled
- ✅ Public access blocked
- ✅ IAM-based access control
- ✅ State locking prevents conflicts
- ✅ Point-in-time recovery enabled

### Best Practices

1. **Never commit state files** - Use `.gitignore`
2. **Restrict S3 access** - Use IAM policies
3. **Enable MFA delete** - Prevent accidental deletion
4. **Audit state access** - Enable S3 access logging

## Summary

✅ **Setup backend once:** `./setup-backend.sh`
✅ **Initialize Terraform:** `terraform init`
✅ **Run normally:** `terraform plan` → `terraform apply`
✅ **Idempotent:** Safe to run multiple times
✅ **Team-ready:** Shared state, state locking
✅ **CI/CD-ready:** Automatic backend setup in workflows

The VPC limit issue is now resolved because Terraform remembers what it created and reuses existing resources instead of creating new ones.
