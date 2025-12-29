#!/bin/bash

# Manual Cleanup Script for WordPress Docker Swarm Deployment
# This script provides an interactive way to clean up Docker Swarm resources
#
# Usage:
#   ./scripts/cleanup.sh [OPTIONS]
#
# Options:
#   --preserve-data       Keep volumes (WordPress data, database)
#   --remove-secrets      Remove Docker secrets
#   --leave-swarm         Leave Docker Swarm mode
#   --backup-first        Backup before cleanup
#   --full-destroy        Remove everything including infrastructure
#   --dry-run            Show what would be removed without doing it
#   -h, --help           Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PRESERVE_DATA=false
PRESERVE_SECRETS=true
LEAVE_SWARM=false
BACKUP_BEFORE=false
FULL_DESTROY=false
DRY_RUN=false
INVENTORY_FILE="infra/ansible/inventory/hosts"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display help
show_help() {
    cat << EOF
WordPress Docker Swarm Cleanup Script

This script helps you clean up Docker Swarm resources safely.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --preserve-data        Keep volumes (WordPress data, MySQL database)
                          Default: Remove volumes

    --remove-secrets      Remove Docker secrets (mysql passwords, etc.)
                          Default: Preserve secrets

    --leave-swarm         Leave Docker Swarm mode completely
                          Default: Keep swarm active

    --backup-first        Run backup before cleanup
                          Default: No backup

    --full-destroy        Remove everything including Terraform infrastructure
                          WARNING: This destroys AWS resources
                          Default: Keep infrastructure

    --dry-run            Show what would be removed without doing it
                          Default: false

    -h, --help           Show this help message

EXAMPLES:
    # Remove stacks but preserve data
    $0 --preserve-data

    # Complete cleanup including data (with backup)
    $0 --backup-first

    # Full cleanup including leaving swarm
    $0 --leave-swarm

    # See what would be removed
    $0 --dry-run

    # Nuclear option: destroy everything
    $0 --full-destroy --remove-secrets

CLEANUP LEVELS:
    Level 1 (Default):       Remove stacks, configs, networks
    Level 2 (--remove-secrets): + Remove secrets
    Level 3 (No --preserve-data): + Remove volumes
    Level 4 (--leave-swarm):  + Leave swarm mode
    Level 5 (--full-destroy): + Destroy infrastructure

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --preserve-data)
            PRESERVE_DATA=true
            shift
            ;;
        --remove-secrets)
            PRESERVE_SECRETS=false
            shift
            ;;
        --leave-swarm)
            LEAVE_SWARM=true
            shift
            ;;
        --backup-first)
            BACKUP_BEFORE=true
            shift
            ;;
        --full-destroy)
            FULL_DESTROY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Display banner
echo "=========================================="
echo "WordPress Docker Swarm Cleanup Tool"
echo "=========================================="
echo ""

# Check if running from project root
if [[ ! -f "$PROJECT_ROOT/infra/ansible/playbooks/cleanup.yml" ]]; then
    print_error "cleanup.yml not found. Are you in the project root?"
    exit 1
fi

# Check if inventory exists
if [[ ! -f "$PROJECT_ROOT/$INVENTORY_FILE" ]]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    print_info "Please create inventory or update INVENTORY_FILE variable"
    exit 1
fi

# Display configuration
print_info "Cleanup Configuration:"
echo "  Preserve Data: $(if $PRESERVE_DATA; then echo 'YES'; else echo 'NO'; fi)"
echo "  Preserve Secrets: $(if $PRESERVE_SECRETS; then echo 'YES'; else echo 'NO'; fi)"
echo "  Leave Swarm: $(if $LEAVE_SWARM; then echo 'YES'; else echo 'NO'; fi)"
echo "  Backup Before: $(if $BACKUP_BEFORE; then echo 'YES'; else echo 'NO'; fi)"
echo "  Full Destroy: $(if $FULL_DESTROY; then echo 'YES'; else echo 'NO'; fi)"
echo "  Dry Run: $(if $DRY_RUN; then echo 'YES'; else echo 'NO'; fi)"
echo ""

# Warnings for destructive operations
if ! $PRESERVE_DATA; then
    print_warning "Data volumes will be DELETED permanently!"
fi

if ! $PRESERVE_SECRETS; then
    print_warning "Docker secrets will be REMOVED!"
fi

if $LEAVE_SWARM; then
    print_warning "Node will LEAVE Docker Swarm mode!"
fi

if $FULL_DESTROY; then
    print_error "Infrastructure will be DESTROYED (EC2 instances, VPC, etc.)"
fi

# Confirmation prompt
if ! $DRY_RUN; then
    echo ""
    read -p "Do you want to proceed? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cleanup cancelled"
        exit 0
    fi
fi

# Check for Ansible
if ! command -v ansible-playbook &> /dev/null; then
    print_error "ansible-playbook not found. Please install Ansible:"
    echo "  pip install ansible"
    exit 1
fi

# Build Ansible command
ANSIBLE_CMD="ansible-playbook -i $INVENTORY_FILE infra/ansible/playbooks/cleanup.yml"
ANSIBLE_CMD="$ANSIBLE_CMD -e preserve_data=$PRESERVE_DATA"
ANSIBLE_CMD="$ANSIBLE_CMD -e preserve_secrets=$PRESERVE_SECRETS"
ANSIBLE_CMD="$ANSIBLE_CMD -e leave_swarm=$LEAVE_SWARM"
ANSIBLE_CMD="$ANSIBLE_CMD -e backup_before=$BACKUP_BEFORE"

if $DRY_RUN; then
    ANSIBLE_CMD="$ANSIBLE_CMD --check"
fi

# Execute cleanup playbook
print_info "Running cleanup playbook..."
echo ""

cd "$PROJECT_ROOT"

if $DRY_RUN; then
    print_warning "DRY RUN MODE - No changes will be made"
fi

if $ANSIBLE_CMD; then
    print_success "Docker Swarm cleanup completed!"
else
    print_error "Cleanup playbook failed"
    exit 1
fi

# Full infrastructure destruction
if $FULL_DESTROY && ! $DRY_RUN; then
    echo ""
    print_warning "Proceeding with infrastructure destruction..."
    echo ""

    read -p "Type 'DESTROY' to confirm infrastructure destruction: " -r
    echo ""

    if [[ $REPLY == "DESTROY" ]]; then
        if [[ -d "$PROJECT_ROOT/infra/terraform" ]]; then
            print_info "Running Terraform destroy..."
            cd "$PROJECT_ROOT/infra/terraform"

            if terraform destroy -auto-approve; then
                print_success "Infrastructure destroyed successfully"
            else
                print_error "Terraform destroy failed"
                exit 1
            fi
        else
            print_warning "Terraform directory not found, skipping infrastructure destroy"
        fi
    else
        print_info "Infrastructure destruction cancelled"
    fi
fi

# Final summary
echo ""
echo "=========================================="
print_success "Cleanup Complete!"
echo "=========================================="
echo ""
print_info "Summary of actions:"
echo "  ✓ Docker stacks removed"
echo "  ✓ Docker configs removed"
echo "  ✓ Docker networks cleaned up"

if ! $PRESERVE_SECRETS; then
    echo "  ✓ Docker secrets removed"
fi

if ! $PRESERVE_DATA; then
    echo "  ✓ Data volumes removed"
else
    echo "  ℹ Data volumes preserved (can be reused)"
fi

if $LEAVE_SWARM; then
    echo "  ✓ Left Docker Swarm mode"
fi

if $FULL_DESTROY && ! $DRY_RUN; then
    echo "  ✓ Infrastructure destroyed"
fi

echo ""
print_info "Next steps:"

if $PRESERVE_DATA; then
    echo "  - Data volumes are preserved and can be reused"
    echo "  - To remove them manually: docker volume rm <volume_name>"
fi

if $PRESERVE_SECRETS; then
    echo "  - Secrets are preserved and can be reused"
    echo "  - To remove them manually: docker secret rm <secret_name>"
fi

if ! $FULL_DESTROY; then
    echo "  - To destroy infrastructure: $0 --full-destroy"
fi

echo "  - To verify cleanup: docker stack ls && docker volume ls"
echo ""
