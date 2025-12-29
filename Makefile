# WordPress Docker Swarm Makefile
# Convenience commands for common operations

.PHONY: help deploy cleanup backup restore health check-status

# Default target
help:
	@echo "WordPress Docker Swarm Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy              Deploy WordPress application"
	@echo "  deploy-monitoring   Deploy monitoring stack"
	@echo "  deploy-all          Deploy everything"
	@echo ""
	@echo "Cleanup:"
	@echo "  cleanup-safe        Remove stacks, keep data (SAFE)"
	@echo "  cleanup             Remove stacks and data"
	@echo "  cleanup-full        Complete teardown including infrastructure"
	@echo "  cleanup-dry-run     Preview what would be removed"
	@echo ""
	@echo "Operations:"
	@echo "  backup              Backup WordPress and database"
	@echo "  restore             Restore from backup"
	@echo "  health              Run health checks"
	@echo "  rollback            Rollback to previous version"
	@echo ""
	@echo "Monitoring:"
	@echo "  check-status        Check Docker Swarm status"
	@echo "  logs-wordpress      Show WordPress logs"
	@echo "  logs-mysql          Show MySQL logs"
	@echo "  logs-monitoring     Show monitoring stack logs"
	@echo ""
	@echo "Infrastructure:"
	@echo "  tf-plan             Terraform plan"
	@echo "  tf-apply            Terraform apply"
	@echo "  tf-destroy          Terraform destroy"

# Ansible inventory
INVENTORY := infra/ansible/inventory/hosts
PLAYBOOKS := infra/ansible/playbooks

# Deployment targets
deploy:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/site.yml

deploy-monitoring:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/site.yml --tags monitoring

deploy-all: deploy

# Cleanup targets
cleanup-safe:
	@echo "Running safe cleanup (preserving data)..."
	./scripts/cleanup.sh --preserve-data

cleanup:
	@echo "Running cleanup (removing data)..."
	@echo "WARNING: This will remove data volumes!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./scripts/cleanup.sh --backup-first; \
	fi

cleanup-full:
	@echo "Running full cleanup (destroying infrastructure)..."
	@echo "WARNING: This will destroy all AWS resources!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		./scripts/cleanup.sh --full-destroy --remove-secrets; \
	fi

cleanup-dry-run:
	./scripts/cleanup.sh --dry-run

# Operations
backup:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/backup.yml

restore:
	@echo "Available backups:"
	@ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/restore.yml --list-tasks
	@read -p "Enter backup date (YYYY-MM-DD): " backup_date; \
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/restore.yml -e backup_date=$$backup_date

health:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/health-check.yml

rollback:
	ansible-playbook -i $(INVENTORY) $(PLAYBOOKS)/rollback.yml

# Monitoring
check-status:
	@echo "Checking Docker Swarm status..."
	@ansible swarm_managers -i $(INVENTORY) -a "docker node ls" -b
	@echo ""
	@echo "Checking stacks..."
	@ansible swarm_managers -i $(INVENTORY) -a "docker stack ls" -b
	@echo ""
	@echo "Checking services..."
	@ansible swarm_managers -i $(INVENTORY) -a "docker service ls" -b

logs-wordpress:
	@echo "Recent WordPress logs:"
	@ansible swarm_managers -i $(INVENTORY) -a "docker service logs wordpress-app_wordpress --tail 50" -b

logs-mysql:
	@echo "Recent MySQL logs:"
	@ansible swarm_managers -i $(INVENTORY) -a "docker service logs wordpress-app_mysql --tail 50" -b

logs-monitoring:
	@echo "Recent Prometheus logs:"
	@ansible swarm_managers -i $(INVENTORY) -a "docker service logs monitoring_prometheus --tail 30" -b
	@echo ""
	@echo "Recent Grafana logs:"
	@ansible swarm_managers -i $(INVENTORY) -a "docker service logs monitoring_grafana --tail 30" -b

# Infrastructure management
tf-plan:
	cd infra/terraform && terraform plan

tf-apply:
	cd infra/terraform && terraform apply

tf-destroy:
	@echo "WARNING: This will destroy all infrastructure!"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd infra/terraform && terraform destroy; \
	fi

# Quick commands for development
dev-up: deploy-all
	@echo "Development environment is up!"
	@echo "Access WordPress: http://<manager-ip>"
	@echo "Access Grafana: http://<manager-ip>:3000"

dev-down: cleanup-safe
	@echo "Development environment shut down (data preserved)"

dev-reset: cleanup deploy
	@echo "Development environment reset with fresh data"
