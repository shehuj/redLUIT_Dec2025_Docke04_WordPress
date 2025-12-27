#!/bin/bash
# One-Command Deployment Script
# Automates the entire deployment process

set -e

# Colors for output
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="wordpress-swarm"

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_requirements() {
    print_header "Checking Requirements"

    local missing=0

    # Check Terraform
    if command -v terraform &> /dev/null; then
        print_success "Terraform installed: $(terraform version | head -n1)"
    else
        print_error "Terraform not installed"
        missing=1
    fi

    # Check Ansible
    if command -v ansible &> /dev/null; then
        print_success "Ansible installed: $(ansible --version | head -n1)"
    else
        print_error "Ansible not installed"
        missing=1
    fi

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        print_success "AWS CLI installed: $(aws --version)"
    else
        print_error "AWS CLI not installed"
        missing=1
    fi

    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker installed: $(docker --version)"
    else
        print_warning "Docker not installed (optional for local testing)"
    fi

    if [ $missing -eq 1 ]; then
        print_error "Missing required tools. Please install them first."
        exit 1
    fi
}

check_aws_credentials() {
    print_header "Checking AWS Credentials"

    if aws sts get-caller-identity &> /dev/null; then
        print_success "AWS credentials configured"
        aws sts get-caller-identity
    else
        print_error "AWS credentials not configured"
        print_info "Run: aws configure"
        exit 1
    fi
}

check_env_vars() {
    print_header "Checking Environment Variables"

    local missing=0

    # Required for deployment
    if [ -z "$SSH_PUBLIC_KEY" ]; then
        print_warning "SSH_PUBLIC_KEY not set"
        print_info "Set with: export SSH_PUBLIC_KEY=\$(cat ~/.ssh/id_rsa.pub)"
        missing=1
    else
        print_success "SSH_PUBLIC_KEY is set"
    fi

    # Required for application
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        print_warning "MYSQL_ROOT_PASSWORD not set"
        missing=1
    else
        print_success "MYSQL_ROOT_PASSWORD is set"
    fi

    if [ -z "$MYSQL_PASSWORD" ]; then
        print_warning "MYSQL_PASSWORD not set"
        missing=1
    else
        print_success "MYSQL_PASSWORD is set"
    fi

    # Optional
    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        print_warning "SLACK_WEBHOOK_URL not set (optional for alerts)"
    else
        print_success "SLACK_WEBHOOK_URL is set"
    fi

    if [ $missing -eq 1 ]; then
        print_error "Missing required environment variables"
        cat << 'EOF'

Export required variables:
  export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
  export MYSQL_ROOT_PASSWORD="your_secure_password"
  export MYSQL_PASSWORD="your_app_password"
  export SLACK_WEBHOOK_URL="https://hooks.slack.com/..." # optional

Or create .env file:
  cat > .env << 'ENVFILE'
  export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
  export MYSQL_ROOT_PASSWORD="change_this_password"
  export MYSQL_PASSWORD="change_this_too"
  export SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
  ENVFILE

Then run: source .env

EOF
        exit 1
    fi
}

setup_backend() {
    print_header "Setting Up Terraform Backend"

    cd infra/terraform

    if [ -f "setup-backend.sh" ]; then
        chmod +x setup-backend.sh
        ./setup-backend.sh
    else
        print_error "Backend setup script not found"
        exit 1
    fi

    cd ../..
}

deploy_infrastructure() {
    print_header "Deploying Infrastructure"

    cd infra/terraform

    # Initialize Terraform
    print_info "Initializing Terraform..."
    terraform init -reconfigure

    # Create tfvars if it doesn't exist
    if [ ! -f "terraform.tfvars" ]; then
        print_info "Creating terraform.tfvars..."
        cat > terraform.tfvars << EOF
aws_region = "${AWS_REGION}"
project_name = "${PROJECT_NAME}"
ssh_public_key = "${SSH_PUBLIC_KEY}"
EOF
    fi

    # Plan
    print_info "Running Terraform plan..."
    terraform plan -out=tfplan

    # Apply
    print_info "Applying infrastructure changes..."
    terraform apply tfplan

    # Get outputs
    print_success "Infrastructure deployed!"
    terraform output

    # Save outputs for later
    MANAGER_IP=$(terraform output -raw swarm_manager_public_ip)
    echo "MANAGER_IP=$MANAGER_IP" > ../../.deploy_vars

    cd ../..
}

configure_swarm() {
    print_header "Configuring Docker Swarm"

    source .deploy_vars

    cd infra/ansible

    # Wait for instances
    print_info "Waiting for instances to be ready (60s)..."
    sleep 60

    # Test connectivity
    print_info "Testing SSH connectivity..."
    ansible all -m ping -i inventory/hosts.ini

    # Run playbook
    print_info "Running Ansible playbook..."
    ANSIBLE_HOST_KEY_CHECKING=False \
    ansible-playbook -i inventory/hosts.ini playbooks/site.yml -v

    print_success "Swarm cluster configured!"

    cd ../..
}

deploy_stacks() {
    print_header "Deploying Application Stacks"

    source .deploy_vars

    # Copy stack files to manager
    print_info "Copying stack files to manager..."
    scp -o StrictHostKeyChecking=no -r stack-monitoring ubuntu@${MANAGER_IP}:~/
    scp -o StrictHostKeyChecking=no -r stack-app ubuntu@${MANAGER_IP}:~/

    # Deploy stacks
    print_info "Deploying stacks..."
    ssh -o StrictHostKeyChecking=no ubuntu@${MANAGER_IP} << 'ENDSSH'
    # Deploy monitoring first
    cd ~/stack-monitoring
    docker stack deploy -c monitoring-stack.yml monitoring

    # Wait a bit
    sleep 10

    # Deploy app
    cd ~/stack-app
    docker stack deploy -c docker-stack.yml levelop-wp

    # Show status
    docker stack ls
    docker service ls
ENDSSH

    print_success "Application stacks deployed!"
}

verify_deployment() {
    print_header "Verifying Deployment"

    source .deploy_vars

    print_info "Swarm cluster status:"
    ssh ubuntu@${MANAGER_IP} 'docker node ls'

    echo ""
    print_info "Services:"
    ssh ubuntu@${MANAGER_IP} 'docker service ls'

    echo ""
    print_info "Secrets:"
    ssh ubuntu@${MANAGER_IP} 'docker secret ls'

    echo ""
    print_success "Deployment complete!"
    print_info "WordPress: http://${MANAGER_IP}"
    print_info "Grafana: http://${MANAGER_IP}:3000"
    print_info "Prometheus: http://${MANAGER_IP}:9090"
}

# Main execution
main() {
    print_header "WordPress on Docker Swarm - Automated Deployment"

    # Check everything before starting
    check_requirements
    check_aws_credentials
    check_env_vars

    # Confirm deployment
    echo ""
    read -p "Ready to deploy? This will create AWS resources. (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi

    # Run deployment steps
    setup_backend
    deploy_infrastructure
    configure_swarm
    deploy_stacks
    verify_deployment

    print_header "Deployment Summary"
    source .deploy_vars
    cat << EOF
✅ All deployment steps completed successfully!

Access your deployment:
  WordPress:  http://${MANAGER_IP}
  Grafana:    http://${MANAGER_IP}:3000 (admin/admin)
  Prometheus: http://${MANAGER_IP}:9090

Next steps:
  1. Complete WordPress setup in browser
  2. Configure Grafana dashboards
  3. Set up DNS/domain if needed
  4. Configure SSL certificate

To destroy:
  cd infra/terraform
  terraform destroy

For help:
  cat README.md
  cat docs/DEPLOYMENT_GUIDE.md

EOF
}

# Run main function
main "$@"
