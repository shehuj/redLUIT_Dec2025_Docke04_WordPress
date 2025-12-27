#!/usr/bin/env python3
"""Test suite for repository structure and configuration validation."""

import yaml
from pathlib import Path
import pytest


def test_app_stack_exists():
    """Verify application stack file exists."""
    assert Path("stack-app/docker-stack.yml").exists()


def test_monitoring_stack_exists():
    """Verify monitoring stack file exists."""
    assert Path("stack-monitoring/monitoring-stack.yml").exists()


def test_prometheus_config_exists():
    """Verify Prometheus configuration exists."""
    assert Path("stack-monitoring/prometheus.yml").exists()


def test_app_stack_valid_yaml():
    """Verify application stack is valid YAML."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        assert config is not None
        assert "services" in config
        assert "mysql" in config["services"]
        assert "wordpress" in config["services"]


def test_monitoring_stack_valid_yaml():
    """Verify monitoring stack is valid YAML."""
    with open("stack-monitoring/monitoring-stack.yml") as f:
        config = yaml.safe_load(f)
        assert config is not None
        assert "services" in config
        assert "prometheus" in config["services"]
        assert "grafana" in config["services"]


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


def test_mon_net_connected_to_app():
    """Verify monitoring network is connected to application services."""
    with open("stack-app/docker-stack.yml") as f:
        config = yaml.safe_load(f)
        mysql = config["services"]["mysql"]
        wordpress = config["services"]["wordpress"]
        assert "mon_net" in mysql["networks"]
        assert "mon_net" in wordpress["networks"]


def test_prometheus_uses_configs():
    """Verify Prometheus uses Docker configs instead of local mounts."""
    with open("stack-monitoring/monitoring-stack.yml") as f:
        config = yaml.safe_load(f)
        prometheus = config["services"]["prometheus"]
        assert "configs" in prometheus
        assert "configs" in config
        assert "prometheus_config" in config["configs"]


def test_alertmanager_uses_secrets():
    """Verify AlertManager uses secrets for Slack webhook."""
    with open("stack-monitoring/monitoring-stack.yml") as f:
        config = yaml.safe_load(f)
        alertmanager = config["services"]["alertmanager"]
        assert "secrets" in alertmanager
        assert "slack_webhook_url" in alertmanager["secrets"]


def test_prometheus_config_valid_yaml():
    """Verify Prometheus configuration is valid YAML."""
    with open("stack-monitoring/prometheus.yml") as f:
        config = yaml.safe_load(f)
        assert config is not None
        assert "scrape_configs" in config
        assert len(config["scrape_configs"]) > 0


def test_alert_rules_valid_yaml():
    """Verify alert rules are valid YAML."""
    with open("stack-monitoring/alert.rules.yml") as f:
        config = yaml.safe_load(f)
        assert config is not None
        assert "groups" in config
        assert len(config["groups"]) > 0


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
        ".github/workflows/deploy.yml",
        ".github/workflows/infrastructure.yml",
        ".github/workflows/pr-validation.yml",
        ".github/workflows/main-deployment.yml",
        ".github/workflows/python.yml"
    ]
    for workflow in workflows:
        assert Path(workflow).exists(), f"Workflow {workflow} is missing"


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