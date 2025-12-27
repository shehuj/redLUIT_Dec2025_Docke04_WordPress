#!/bin/bash
# Pre-flight Validation Script
# Validates all configurations before deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((ERRORS++))
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

echo "========================================="
echo "Pre-Flight Validation"
echo "========================================="
echo ""

# Check directory structure
print_check "Checking directory structure..."
for dir in infra/terraform infra/ansible stack-app stack-monitoring tests docs; do
    if [ -d "$dir" ]; then
        print_pass "Directory exists: $dir"
    else
        print_fail "Missing directory: $dir"
    fi
done

# Check required Terraform files
print_check "Checking Terraform files..."
for file in infra/terraform/main.tf infra/terraform/variables.tf infra/terraform/outputs.tf infra/terraform/backend.tf; do
    if [ -f "$file" ]; then
        print_pass "File exists: $file"
    else
        print_fail "Missing file: $file"
    fi
done

# Check Ansible files
print_check "Checking Ansible files..."
for file in infra/ansible/ansible.cfg infra/ansible/playbooks/site.yml infra/ansible/requirements.yml; do
    if [ -f "$file" ]; then
        print_pass "File exists: $file"
    else
        print_fail "Missing file: $file"
    fi
done

# Check Ansible roles
print_check "Checking Ansible roles..."
for role in docker-engine security-hardening swarm-init swarm-secrets; do
    if [ -d "infra/ansible/roles/$role" ]; then
        print_pass "Role exists: $role"
        # Check role structure
        for subdir in tasks defaults handlers meta; do
            if [ -d "infra/ansible/roles/$role/$subdir" ]; then
                print_pass "  $role/$subdir exists"
            else
                print_warn "  $role/$subdir missing"
            fi
        done
    else
        print_fail "Missing role: $role"
    fi
done

# Check stack files
print_check "Checking Docker stack files..."
if [ -f "stack-app/docker-stack.yml" ]; then
    print_pass "App stack exists"
    # Validate YAML
    if python3 -c "import yaml; yaml.safe_load(open('stack-app/docker-stack.yml'))" 2>/dev/null; then
        print_pass "App stack is valid YAML"
    else
        print_fail "App stack has YAML errors"
    fi
else
    print_fail "Missing stack-app/docker-stack.yml"
fi

if [ -f "stack-monitoring/monitoring-stack.yml" ]; then
    print_pass "Monitoring stack exists"
    if python3 -c "import yaml; yaml.safe_load(open('stack-monitoring/monitoring-stack.yml'))" 2>/dev/null; then
        print_pass "Monitoring stack is valid YAML"
    else
        print_fail "Monitoring stack has YAML errors"
    fi
else
    print_fail "Missing stack-monitoring/monitoring-stack.yml"
fi

# Check monitoring configs
print_check "Checking monitoring configurations..."
for file in stack-monitoring/prometheus.yml stack-monitoring/alert.rules.yml stack-monitoring/alertmanager.yml; do
    if [ -f "$file" ]; then
        print_pass "Config exists: $(basename $file)"
    else
        print_fail "Missing config: $file"
    fi
done

# Check workflows
print_check "Checking GitHub Actions workflows..."
for workflow in .github/workflows/main-deployment.yml .github/workflows/pr-validation.yml .github/workflows/infrastructure.yml; do
    if [ -f "$workflow" ]; then
        print_pass "Workflow exists: $(basename $workflow)"
    else
        print_fail "Missing workflow: $workflow"
    fi
done

# Check tools
print_check "Checking required tools..."
for tool in terraform ansible docker aws python3; do
    if command -v $tool &> /dev/null; then
        version=$($tool --version 2>&1 | head -n1)
        print_pass "$tool is installed: $version"
    else
        print_fail "$tool is not installed"
    fi
done

# Check Python packages
print_check "Checking Python packages..."
if python3 -c "import yaml" 2>/dev/null; then
    print_pass "PyYAML is installed"
else
    print_warn "PyYAML not installed (pip install pyyaml)"
fi

if python3 -c "import pytest" 2>/dev/null; then
    print_pass "pytest is installed"
else
    print_warn "pytest not installed (pip install pytest)"
fi

# Check AWS credentials
print_check "Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    print_pass "AWS credentials are configured"
else
    print_warn "AWS credentials not configured (run: aws configure)"
fi

# Check environment variables
print_check "Checking environment variables..."
if [ -n "$SSH_PUBLIC_KEY" ]; then
    print_pass "SSH_PUBLIC_KEY is set"
else
    print_warn "SSH_PUBLIC_KEY not set"
fi

if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
    print_pass "MYSQL_ROOT_PASSWORD is set"
else
    print_warn "MYSQL_ROOT_PASSWORD not set"
fi

if [ -n "$MYSQL_PASSWORD" ]; then
    print_pass "MYSQL_PASSWORD is set"
else
    print_warn "MYSQL_PASSWORD not set"
fi

# Check .gitignore
print_check "Checking .gitignore..."
if grep -q "\.tfstate" .gitignore 2>/dev/null; then
    print_pass ".gitignore excludes Terraform state"
else
    print_warn ".gitignore might not exclude Terraform state"
fi

if grep -q "\.env" .gitignore 2>/dev/null; then
    print_pass ".gitignore excludes .env files"
else
    print_warn ".gitignore might not exclude .env files"
fi

# Summary
echo ""
echo "========================================="
echo "Validation Summary"
echo "========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "You're ready to deploy:"
    echo "  ./deploy.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  $WARNINGS warnings${NC}"
    echo ""
    echo "You can proceed, but review warnings above."
    exit 0
else
    echo -e "${RED}❌ $ERRORS errors, $WARNINGS warnings${NC}"
    echo ""
    echo "Fix errors before deploying."
    exit 1
fi
