#!/usr/bin/env python3
"""Infrastructure compliance tests."""

import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent


def test_infra_directory_exists():
    """Test that infrastructure directory exists."""
    assert (REPO_ROOT / "infra").exists(), "infra directory not found"


def test_terraform_directory_exists():
    """Test that Terraform directory exists."""
    assert (REPO_ROOT / "infra" / "terraform").exists(), "Terraform directory not found"


def test_ansible_directory_exists():
    """Test that Ansible directory exists."""
    assert (REPO_ROOT / "infra" / "ansible").exists(), "Ansible directory not found"


def test_terraform_required_files():
    """Test that all required Terraform files exist."""
    terraform_dir = REPO_ROOT / "infra" / "terraform"
    required_files = [
        "main.tf",
        "variables.tf",
        "outputs.tf",
        "vpc.tf",
        "security-groups.tf",
        "ec2.tf",
        "user-data.sh",
        "terraform.tfvars.example",
    ]

    for file in required_files:
        assert (terraform_dir / file).exists(), f"Required Terraform file not found: {file}"


def test_ansible_configuration_exists():
    """Test that Ansible configuration exists."""
    ansible_dir = REPO_ROOT / "infra" / "ansible"
    assert (ansible_dir / "ansible.cfg").exists(), "ansible.cfg not found"


def test_ansible_inventory_exists():
    """Test that Ansible inventory structure exists."""
    inventory_dir = REPO_ROOT / "infra" / "ansible" / "inventory"
    assert inventory_dir.exists(), "inventory directory not found"
    assert (inventory_dir / "hosts.ini").exists(), "hosts.ini not found"
    assert (inventory_dir / "group_vars").exists(), "group_vars directory not found"


def test_ansible_required_roles():
    """Test that all required Ansible roles exist."""
    roles_dir = REPO_ROOT / "infra" / "ansible" / "roles"
    required_roles = [
        "docker-engine",
        "security-hardening",
        "swarm-init",
        "swarm-secrets",
    ]

    for role in required_roles:
        role_path = roles_dir / role
        assert role_path.exists(), f"Required Ansible role not found: {role}"
        assert (role_path / "tasks" / "main.yml").exists(), f"Role {role} missing tasks/main.yml"


def test_ansible_playbooks_exist():
    """Test that Ansible playbooks exist."""
    playbooks_dir = REPO_ROOT / "infra" / "ansible" / "playbooks"
    assert playbooks_dir.exists(), "playbooks directory not found"
    assert (playbooks_dir / "site.yml").exists(), "site.yml playbook not found"
    assert (playbooks_dir / "swarm-setup.yml").exists(), "swarm-setup.yml playbook not found"


def test_infrastructure_workflow_exists():
    """Test that infrastructure workflow exists."""
    workflow_file = REPO_ROOT / ".github" / "workflows" / "infrastructure.yml"
    assert workflow_file.exists(), "infrastructure.yml workflow not found"


def test_infrastructure_cleanup_workflow_exists():
    """Test that infrastructure cleanup workflow exists."""
    workflow_file = REPO_ROOT / ".github" / "workflows" / "infrastructure-cleanup.yml"
    assert workflow_file.exists(), "infrastructure-cleanup.yml workflow not found"


def test_group_vars_files_exist():
    """Test that group_vars files exist."""
    group_vars_dir = REPO_ROOT / "infra" / "ansible" / "inventory" / "group_vars"
    required_files = ["all.yml", "swarm_managers.yml", "swarm_workers.yml"]

    for file in required_files:
        assert (group_vars_dir / file).exists(), f"group_vars file not found: {file}"
