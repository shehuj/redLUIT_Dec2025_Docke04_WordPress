# Terraform Quick Start Guide

## Fixing VPC Limit Error

If you're seeing the VPC limit error, follow these steps:

### 1. Setup Backend (One-time, required)

```bash
cd infra/terraform

# Setup S3 + DynamoDB backend
./setup-backend.sh
```

**This creates:**
- S3 bucket for state storage
- DynamoDB table for state locking
- Enables versioning and encryption

### 2. Check Existing VPCs

```bash
# Run the cleanup helper
./cleanup-existing-resources.sh
```

**This shows:**
- How many VPCs you have
- Which VPCs belong to this project
- Options to fix the issue

### 3. Choose Resolution Path

#### Path A: Delete Unused VPCs (If you have orphaned VPCs)

```bash
# Use AWS Console or CLI to delete unused VPCs
aws ec2 delete-vpc --vpc-id vpc-xxxxx --region us-east-1

# Note: Delete resources inside VPC first if needed
```

#### Path B: Import Existing VPC (If you want to reuse)

```bash
# Initialize Terraform
terraform init

# Import existing resources
terraform import aws_vpc.main vpc-xxxxx
# Continue importing other resources...

# Verify
terraform plan  # Should show minimal changes
```

#### Path C: Use Different Region

Create `terraform.tfvars`:
```hcl
aws_region = "us-west-2"
```

### 4. Initialize and Deploy

```bash
# Initialize Terraform with backend
terraform init

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

## Quick Commands

```bash
# Setup backend (one-time)
./setup-backend.sh

# Initialize
terraform init

# Check what exists
./cleanup-existing-resources.sh

# Validate configuration
terraform validate

# See what will be created
terraform plan

# Deploy
terraform apply

# Destroy everything
terraform destroy
```

## Workflow Integration

### For CI/CD

The workflows handle backend setup automatically. Just ensure:

1. ✅ AWS credentials are in GitHub secrets
2. ✅ Backend will be created on first run
3. ✅ Subsequent runs will reuse existing infrastructure

### For Local Development

1. Run `./setup-backend.sh` once
2. Run `terraform init` once
3. Work normally with `terraform plan` and `terraform apply`

## Idempotency Verification

To verify idempotency:

```bash
# First run
terraform apply
# Output: Created X resources

# Second run immediately after
terraform apply
# Output: No changes. Infrastructure matches configuration.
```

## Troubleshooting

### "Backend not initialized"
```bash
terraform init
```

### "State lock held"
```bash
# Force unlock if previous run crashed
terraform force-unlock <lock-id>
```

### "Resource already exists"
```bash
# Import the resource
terraform import aws_vpc.main vpc-xxxxx
```

### "VPC limit exceeded"
- Follow cleanup guide above
- Delete unused VPCs
- Or import existing ones
- Or use different region

## Next Steps

After infrastructure is deployed:

1. Note the manager IP from outputs
2. Add to GitHub secrets as `SWARM_MANAGER_HOST`
3. Run deployment workflow
4. Access your application

## Files Reference

- `backend.tf` - Backend configuration
- `setup-backend.sh` - Backend setup script
- `cleanup-existing-resources.sh` - Cleanup helper
- `terraform.tfvars.example` - Configuration template
- `main.tf` - Main configuration
- `vpc.tf` - VPC resources
- `ec2.tf` - EC2 instances
- `security-groups.tf` - Security groups

## Support

See `IDEMPOTENT_INFRASTRUCTURE.md` for detailed documentation.
