# Fixing EC2 Key Pair Duplicate Error

## Error Message

```
Error: importing EC2 Key Pair (wordpress-swarm-swarm-key): operation error EC2: ImportKeyPair,
https response error StatusCode: 400, RequestID: ...,
api error InvalidKeyPair.Duplicate: The keypair already exists

with aws_key_pair.swarm_key,
on main.tf line 55, in resource "aws_key_pair" "swarm_key":
55: resource "aws_key_pair" "swarm_key" {
```

## Root Cause

The EC2 key pair `wordpress-swarm-swarm-key` already exists in AWS, but Terraform doesn't have it in its state file. This happens when:

1. The key pair was created in a previous Terraform run that didn't complete
2. The key pair was created manually
3. The Terraform state was lost or deleted
4. You're running Terraform in a different workspace/state

## Solutions

### Solution 1: Delete Existing Key Pair (Recommended)

**⚠️ Warning:** This will delete the existing key pair. Any EC2 instances using this key will need to use a new key for future SSH access.

#### Using the Fix Script

```bash
# Run the automated fix script
./scripts/fix-keypair.sh

# Follow the prompts
# Type 'yes' to delete the existing key pair

# Then run Terraform again
cd infra/terraform
terraform apply
```

#### Manual Method

```bash
# Delete the key pair
aws ec2 delete-key-pair \
  --key-name wordpress-swarm-swarm-key \
  --region us-east-1

# Verify deletion
aws ec2 describe-key-pairs \
  --key-names wordpress-swarm-swarm-key \
  --region us-east-1
# Should return: An error occurred (InvalidKeyPair.NotFound)

# Run Terraform again
cd infra/terraform
terraform apply
```

---

### Solution 2: Import Existing Key Pair

**⚠️ Note:** This only works if:
- The existing key pair has the same public key as what Terraform will generate
- You're okay with keeping the existing key pair

This approach is **NOT recommended** because Terraform generates a new random key pair each time, so the public keys won't match.

```bash
# Try to import (likely will fail due to key mismatch)
cd infra/terraform
terraform import aws_key_pair.swarm_key wordpress-swarm-swarm-key
```

---

### Solution 3: Use Different Key Pair Name

Change the project name to use a different key pair name.

**Edit `infra/terraform/terraform.tfvars`:**

```hcl
project_name = "wordpress-swarm-v2"  # Changed from wordpress-swarm
```

**Then apply:**

```bash
cd infra/terraform
terraform apply
```

---

### Solution 4: Clean State and Recreate (Nuclear Option)

**⚠️ DANGER:** This will destroy ALL infrastructure managed by this Terraform state.

```bash
cd infra/terraform

# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Destroy all infrastructure
terraform destroy

# Delete the key pair manually (if terraform destroy didn't remove it)
aws ec2 delete-key-pair \
  --key-name wordpress-swarm-swarm-key \
  --region us-east-1

# Recreate everything
terraform apply
```

---

## Recommended Steps

### For Development/Testing

```bash
# 1. Delete the existing key pair
./scripts/fix-keypair.sh

# 2. Apply Terraform
cd infra/terraform
terraform apply

# 3. Continue with deployment
cd ../..
ansible-playbook -i infra/ansible/inventory/hosts \
  infra/ansible/playbooks/swarm-setup.yml
```

### For Production

```bash
# 1. Check what resources exist
aws ec2 describe-key-pairs --region us-east-1

# 2. Check Terraform state
cd infra/terraform
terraform state list

# 3. If key pair exists in AWS but not in state, import it
# (Only if you're sure it's the correct key)
terraform import aws_key_pair.swarm_key wordpress-swarm-swarm-key

# OR delete and recreate (safer)
aws ec2 delete-key-pair \
  --key-name wordpress-swarm-swarm-key \
  --region us-east-1

terraform apply
```

---

## Prevention

The Terraform configuration has been updated with lifecycle management to prevent this issue:

```hcl
resource "aws_key_pair" "swarm_key" {
  key_name   = "${var.project_name}-swarm-key"
  public_key = tls_private_key.swarm_key.public_key_openssh

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [tags["CreatedAt"]]
  }
}
```

### Best Practices

1. **Use Remote State**
   - Store Terraform state in S3 with locking (already configured)
   - Never commit `.tfstate` files to git

2. **Workspace Isolation**
   ```bash
   # Use Terraform workspaces for different environments
   terraform workspace new dev
   terraform workspace new prod
   ```

3. **State Backup**
   ```bash
   # Before major changes
   cd infra/terraform
   terraform state pull > terraform.tfstate.backup
   ```

4. **Import Existing Resources**
   ```bash
   # If you manually created resources, import them
   terraform import <resource_type>.<resource_name> <resource_id>
   ```

---

## Verification

After applying the fix:

```bash
# Check key pair exists in AWS
aws ec2 describe-key-pairs \
  --key-names wordpress-swarm-swarm-key \
  --region us-east-1

# Check key pair in Terraform state
cd infra/terraform
terraform state show aws_key_pair.swarm_key

# Test SSH with new key (after EC2 instances are created)
ssh -i <(terraform output -raw private_key_pem) \
  ubuntu@<instance-ip>
```

---

## Troubleshooting

### Still Getting Error After Deletion

**Check for Multiple Regions:**

```bash
# List key pairs in all regions
for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
  echo "Checking $region..."
  aws ec2 describe-key-pairs \
    --region $region \
    --query 'KeyPairs[?KeyName==`wordpress-swarm-swarm-key`]' \
    --output table
done
```

**Check Terraform Backend:**

```bash
# Verify S3 backend is accessible
cd infra/terraform
terraform init -reconfigure

# Pull latest state
terraform state pull
```

### Key Pair Deleted But Terraform Still Errors

```bash
# Refresh Terraform state
terraform refresh

# Or force unlock if state is locked
terraform force-unlock <lock-id>
```

### Permission Issues

```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check IAM permissions for EC2 key pairs
aws iam get-user-policy \
  --user-name <your-user> \
  --policy-name <policy-name>
```

---

## Quick Reference

```bash
# Delete existing key pair
aws ec2 delete-key-pair --key-name wordpress-swarm-swarm-key --region us-east-1

# OR use the fix script
./scripts/fix-keypair.sh

# Then apply Terraform
cd infra/terraform
terraform apply

# Verify
terraform state show aws_key_pair.swarm_key
```

---

## Related Issues

- [AWS Key Pair Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html)
- [Terraform Import Documentation](https://www.terraform.io/docs/cli/import/index.html)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)

---

## Summary

**Fastest Fix:**

```bash
./scripts/fix-keypair.sh  # Delete existing key pair
cd infra/terraform && terraform apply
```

This issue has been fixed in the codebase with lifecycle management. The fix script provides an automated way to resolve the duplicate key pair error.
