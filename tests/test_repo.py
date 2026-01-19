#!/usr/bin/env python3
"""Test suite for repository structure and configuration validation."""

import yaml
from pathlib import Path
import pytest


def test_app_stack_exists():
    """Verify application stack file exists."""
    assert Path("stack-app/docker-stack.yml").exists()




def test_app_stack_valid_yaml():
    """Verify application stack is valid YAML."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        assert config is not None
        assert "services" in config
        assert "mysql" in config["services"]
        assert "wordpress" in config["services"]


def test_mysql_uses_secrets():
    """Verify MySQL service uses secrets for credentials."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        mysql = config["services"]["mysql"]
        assert "secrets" in mysql
        assert "mysql_root_password" in mysql["secrets"]
        assert "mysql_password" in mysql["secrets"]


def test_wordpress_health_check():
    """Verify WordPress has health check configured."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        wordpress = config["services"]["wordpress"]
        assert "healthcheck" in wordpress
        assert "test" in wordpress["healthcheck"]


def test_mysql_health_check():
    """Verify MySQL has health check configured."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        mysql = config["services"]["mysql"]
        assert "healthcheck" in mysql
        assert "test" in mysql["healthcheck"]


def test_networks_configured():
    """Verify application networks are properly configured."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        mysql = config["services"]["mysql"]
        wordpress = config["services"]["wordpress"]

        # Verify MySQL has backend network
        assert "networks" in mysql
        assert "backend" in mysql["networks"]

        # Verify WordPress has frontend and backend networks
        assert "networks" in wordpress
        assert "frontend" in wordpress["networks"]
        assert "backend" in wordpress["networks"]

        # Verify networks are defined
        assert "networks" in config
        assert "frontend" in config["networks"]
        assert "backend" in config["networks"]


def test_required_files_exist():
    """Verify all required repository files exist."""
    required_files = [
        "README.md",
        ".gitignore",
        ".dockerignore",
        "requirements.txt",
        "LICENSE"
    ]
    for file in required_files:
        assert Path(file).exists(), f"Required file {file} is missing"


def test_workflows_exist():
    """Verify GitHub Actions workflows exist."""
    workflows = [
        ".github/workflows/pr-validation.yml",
        ".github/workflows/main-deployment.yml"
    ]
    for workflow in workflows:
        assert Path(workflow).exists(), f"Workflow {workflow} is missing"


def test_readme_has_security_section():
    """Verify README contains security documentation."""
    with open("README.md") as f:
        content = f.read()
        assert "## Security Policy" in content, "README missing Security Policy section"
        assert "## Changelog" in content, "README missing Changelog section"
        assert "Reporting a Vulnerability" in content, "README missing vulnerability reporting"
        assert "Version 2.0.0" in content, "README missing version 2.0.0 changelog"


def test_wordpress_replicas():
    """Verify WordPress has multiple replicas for HA."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        wordpress = config["services"]["wordpress"]
        assert "deploy" in wordpress
        assert "replicas" in wordpress["deploy"]
        assert wordpress["deploy"]["replicas"] >= 2


def test_mysql_single_replica():
    """Verify MySQL has single replica (not designed for multi-master)."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        mysql = config["services"]["mysql"]
        assert "deploy" in mysql
        assert "replicas" in mysql["deploy"]
        assert mysql["deploy"]["replicas"] == 1