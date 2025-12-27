#!/bin/bash
# Setup Terraform Backend Infrastructure
# Creates S3 bucket and DynamoDB table for remote state management

set -e

# Configuration
BUCKET_NAME="wordpress-swarm-terraform-state"
DYNAMODB_TABLE="wordpress-swarm-terraform-locks"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "🚀 Setting up Terraform backend infrastructure..."
echo ""
echo "Configuration:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  Region: $AWS_REGION"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please configure AWS CLI."
    exit 1
fi

echo "✅ AWS credentials verified"
echo ""

# Create S3 bucket for state storage
echo "📦 Creating S3 bucket for state storage..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ S3 bucket '$BUCKET_NAME' already exists (idempotent)"
else
    if [ "$AWS_REGION" = "us-east-1" ]; then
        # us-east-1 doesn't require LocationConstraint
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    echo "✅ S3 bucket created"
fi

# Enable versioning (idempotent)
echo "🔄 Enabling bucket versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
echo "✅ Versioning enabled"

# Enable encryption (idempotent)
echo "🔒 Enabling bucket encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'
echo "✅ Encryption enabled"

# Block public access (idempotent)
echo "🚫 Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "✅ Public access blocked"

# Enable lifecycle policy for old versions (idempotent)
echo "♻️  Setting lifecycle policy..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration '{
        "Rules": [{
            "Id": "DeleteOldVersions",
            "Status": "Enabled",
            "NoncurrentVersionExpiration": {
                "NoncurrentDays": 90
            }
        }]
    }'
echo "✅ Lifecycle policy set"

# Create DynamoDB table for state locking
echo "🔐 Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" &>/dev/null; then
    echo "✅ DynamoDB table '$DYNAMODB_TABLE' already exists (idempotent)"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION" \
        --tags Key=Project,Value=WordPress-Swarm Key=ManagedBy,Value=Terraform

    echo "⏳ Waiting for table to be active..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION"
    echo "✅ DynamoDB table created"
fi

# Enable point-in-time recovery (idempotent)
echo "💾 Enabling point-in-time recovery..."
aws dynamodb update-continuous-backups \
    --table-name "$DYNAMODB_TABLE" \
    --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true \
    --region "$AWS_REGION" 2>/dev/null || echo "⚠️  Point-in-time recovery already enabled"
echo "✅ Point-in-time recovery enabled"

echo ""
echo "✅ Backend infrastructure setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Backend is configured in backend.tf"
echo "   2. Run 'terraform init' to initialize backend"
echo "   3. If you have existing state, run 'terraform init -migrate-state'"
echo ""
echo "🔧 Backend configuration:"
echo "   bucket         = \"$BUCKET_NAME\""
echo "   dynamodb_table = \"$DYNAMODB_TABLE\""
echo "   region         = \"$AWS_REGION\""
echo ""
