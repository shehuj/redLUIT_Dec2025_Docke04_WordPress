# Infrastructure Workflow Execution

## Workflow Execution Order

The infrastructure workflow follows a strict dependency chain to ensure safety and validation before provisioning:

```
PR to dev branch → Triggers infrastructure.yml
                    ↓
    ┌───────────────┼───────────────┐
    ↓               ↓               ↓
validate-terraform  validate-ansible  compliance-checks
    │               │               │
    └───────────────┼───────────────┘
                    ↓
        ALL validations must PASS
                    ↓
        provision-infrastructure
        (Terraform applies changes)
                    ↓
        configure-swarm
        (Ansible configures cluster)
                    ↓
            ✅ Complete
```

## Job Dependencies

### Job 1-3: Validation (Run in Parallel)
- **validate-terraform**: Checks Terraform syntax and runs plan
- **validate-ansible**: Validates Ansible playbooks and roles
- **compliance-checks**: Runs infrastructure compliance tests

### Job 4: Provisioning (Runs After All Validations Pass)
- **provision-infrastructure**
  - Depends on: `[validate-terraform, validate-ansible, compliance-checks]`
  - Only runs if ALL validation jobs succeed
  - Provisions AWS infrastructure with Terraform

### Job 5: Configuration (Runs After Provisioning)
- **configure-swarm**
  - Depends on: `provision-infrastructure`
  - Only runs if provisioning succeeds
  - Configures Swarm cluster with Ansible

## Trigger Conditions

### PR to dev branch
- ✅ Runs validation jobs
- ✅ Runs provisioning if validations pass
- ✅ Provisions infrastructure in dev/test environment

### Push to main branch
- ✅ Runs validation jobs
- ✅ Runs provisioning if validations pass
- ✅ Provisions infrastructure in production environment

### Manual dispatch
- ✅ Can trigger manually with workflow_dispatch
- ✅ Select action: plan, apply, or destroy

## Safety Features

1. **Validation First**: No provisioning without validation
2. **Job Dependencies**: Strict execution order enforced
3. **Conditional Execution**: Jobs only run on appropriate triggers
4. **Approval Required**: PR review before merge to main
5. **Rollback Safe**: Terraform state preserved for recovery

## Example Workflow Run

```
PR opened to dev branch
  ↓
[Job 1] validate-terraform ✅ (30s)
[Job 2] validate-ansible ✅ (45s)
[Job 3] compliance-checks ✅ (20s)
  ↓
All validations passed ✅
  ↓
[Job 4] provision-infrastructure ✅ (5m)
  - Terraform plan
  - Terraform apply
  - Generate Ansible inventory
  ↓
[Job 5] configure-swarm ✅ (3m)
  - Install Docker
  - Initialize Swarm
  - Create secrets
  - Apply security hardening
  ↓
Infrastructure ready! 🎉
```

## Failure Handling

### If Validation Fails
- ❌ Provisioning jobs are skipped
- 🔍 Review validation logs
- 🔧 Fix issues and push new commit
- 🔄 Workflow runs again automatically

### If Provisioning Fails
- ❌ Configure-swarm is skipped
- 🔍 Review Terraform logs
- 🔧 Fix issues or rollback with terraform destroy
- 🔄 Push fix and re-run

### If Configuration Fails
- ⚠️ Infrastructure exists but not configured
- 🔍 Review Ansible logs
- 🔧 Fix playbooks and re-run manually or push fix
- 🔄 Workflow will re-run Ansible on next push

## Best Practices

1. **Test in PR**: Always test infrastructure changes in PR to dev first
2. **Review Logs**: Check all job logs even if they pass
3. **Small Changes**: Make incremental infrastructure changes
4. **Terraform Plan**: Review Terraform plan output before merge
5. **Rollback Plan**: Keep previous working state for rollback
