# CI/CD Workflow Strategy

This document describes the branching and deployment strategy for the WordPress + MySQL Docker Swarm project.

## Branching Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                     Development Flow                         │
└─────────────────────────────────────────────────────────────┘

  feature/xyz                dev                    main
      │                      │                       │
      │                      │                       │
      │                      │                       │
      ├─── PR ──────────────►│                       │
      │   (Compliance +      │                       │
      │    Python Tests)     │                       │
      │                      │                       │
      │                      ├─── Push ─────────────►│
      │                      │  (All checks pass)    │
      │                      │                       │
      │                      │                       ├─── Deploy
      │                      │                       │   (Swarm)
      │                      │                       │
```

## Branch Structure

### `dev` Branch
- **Purpose:** Development and testing
- **Protection:** Require PR reviews
- **Triggers:**
  - Python tests on push
  - Compliance checks on PR
  - Python tests on PR

### `main` Branch
- **Purpose:** Production deployment
- **Protection:**
  - Require PR from dev
  - All checks must pass
- **Triggers:**
  - Deploy to Swarm on merge

## Workflow Files

### 1. deploy.yml - Production Deployment

**Trigger:** Push to `main` branch only

**Path Filters:**
- `stack-app/**`
- `stack-monitoring/**`
- `.github/workflows/deploy.yml`

**Jobs:**
1. Build and push Docker images to Docker Hub
2. SSH to Swarm manager
3. Create/verify Docker secrets
4. Deploy monitoring stack (creates mon_net)
5. Deploy application stack

**When it runs:**
```bash
# After merging dev to main
git checkout main
git merge dev
git push origin main  # ✅ Triggers deployment
```

**When it doesn't run:**
```bash
# Direct push to main (should be blocked by branch protection)
git checkout main
git commit -m "Direct commit"
git push origin main  # ⚠️ Should be prevented by branch protection

# Changes to non-deployment files
git checkout main
echo "docs update" >> README.md
git commit -am "Update docs"
git push origin main  # ❌ Deployment skipped (no stack changes)
```

### 2. compliance.yml - Repository Compliance

**Trigger:** Pull request to `dev` branch

**Jobs:**
1. Setup Python 3.12
2. Install dependencies from requirements.txt
3. Run compliance checks (check_required_files.py)

**When it runs:**
```bash
# Create feature branch
git checkout -b feature/add-backup-script dev

# Make changes and push
git push origin feature/add-backup-script

# Create PR to dev
# PR created → ✅ Triggers compliance checks
```

**What it checks:**
- Required files exist (README.md, .gitignore, requirements.txt)
- All expected repository structure is present

### 3. python.yml - Python Tests

**Trigger:**
- Pull request to `dev` branch
- Push to `dev` branch

**Jobs:**
1. Setup Python 3.12
2. Install dependencies (flake8, pytest, requirements.txt)
3. Lint with flake8
4. Run pytest tests

**When it runs:**
```bash
# On PR to dev
git checkout -b feature/new-test dev
git push origin feature/new-test
# Create PR → ✅ Triggers Python tests

# On push to dev (after PR merge)
git checkout dev
git merge feature/new-test
git push origin dev  # ✅ Triggers Python tests
```

## Complete Development Workflow

### Step 1: Create Feature Branch

```bash
# Start from dev
git checkout dev
git pull origin dev

# Create feature branch
git checkout -b feature/add-mysql-monitoring
```

### Step 2: Make Changes

```bash
# Edit files
vim stack-monitoring/prometheus.yml

# Commit changes
git add stack-monitoring/prometheus.yml
git commit -m "Add MySQL exporter to Prometheus"

# Push to remote
git push origin feature/add-mysql-monitoring
```

### Step 3: Create Pull Request to dev

**On GitHub:**
1. Go to repository
2. Click "Pull requests" → "New pull request"
3. Base: `dev` ← Compare: `feature/add-mysql-monitoring`
4. Create pull request

**Automatically triggers:**
- ✅ Compliance Checks workflow
- ✅ Python Tests workflow

**Wait for checks to pass:**
```
✅ Compliance Checks - All required files present
✅ Python Tests - All tests passed (19/19)
```

### Step 4: Merge to dev

**After approval and passing checks:**
```bash
# Merge PR on GitHub
# OR via command line:
git checkout dev
git merge feature/add-mysql-monitoring
git push origin dev
```

**Triggers:**
- ✅ Python Tests workflow (on push to dev)

### Step 5: Promote to Production

**When ready to deploy:**

```bash
# Ensure dev is stable
git checkout dev
git pull origin dev

# Merge to main
git checkout main
git pull origin main
git merge dev

# Push to main
git push origin main
```

**Triggers:**
- ✅ Deploy workflow (if stack files changed)
- Deploys to Docker Swarm production cluster

### Step 6: Verify Deployment

```bash
# Check workflow status
# GitHub → Actions → "Swarm Deploy + Monitoring"

# Verify services on Swarm
ssh swarm-manager
docker service ls
docker stack ps levelop-wp
docker stack ps monitoring
```

## Workflow Trigger Summary

| Workflow | Trigger | Branch | Purpose |
|----------|---------|--------|---------|
| **deploy.yml** | `push` | `main` | Deploy to production Swarm |
| **deploy.yml** | `workflow_dispatch` | manual | Manual deployment |
| **compliance.yml** | `pull_request` | `dev` | Validate repository structure |
| **python.yml** | `pull_request` | `dev` | Run tests before merge |
| **python.yml** | `push` | `dev` | Continuous validation |

## Path-Based Deployment

The deploy.yml workflow only runs when these paths change:

```yaml
paths:
  - 'stack-app/**'           # Application stack config
  - 'stack-monitoring/**'     # Monitoring stack config
  - '.github/workflows/deploy.yml'  # Workflow itself
```

**Example scenarios:**

| Change | Deploy Triggered? |
|--------|-------------------|
| Update `stack-app/docker-stack.yml` | ✅ Yes |
| Update `stack-monitoring/prometheus.yml` | ✅ Yes |
| Update `.github/workflows/deploy.yml` | ✅ Yes |
| Update `README.md` | ❌ No |
| Update `docs/DEPLOYMENT_GUIDE.md` | ❌ No |
| Update `tests/test_repo.py` | ❌ No |
| Update `.gitignore` | ❌ No |

## Branch Protection Rules (Recommended)

### For `dev` Branch

**GitHub Settings → Branches → Add rule:**
- Branch name pattern: `dev`
- ✅ Require pull request reviews before merging (1 approval)
- ✅ Require status checks to pass before merging
  - `compliance-checks`
  - `python312`
- ✅ Require branches to be up to date before merging
- ❌ Allow force pushes

### For `main` Branch

**GitHub Settings → Branches → Add rule:**
- Branch name pattern: `main`
- ✅ Require pull request reviews before merging (1+ approvals)
- ✅ Require status checks to pass before merging
  - `python312` (from dev)
  - `compliance-checks` (from dev)
- ✅ Require branches to be up to date before merging
- ✅ Include administrators
- ❌ Allow force pushes
- ❌ Allow deletions

## Hotfix Workflow

For urgent production fixes:

```bash
# Create hotfix from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-patch

# Make fix
vim stack-app/docker-stack.yml
git commit -am "Fix security vulnerability"

# Push and create PR to main
git push origin hotfix/critical-security-patch

# Create PR: main ← hotfix/critical-security-patch
# Manual workflow_dispatch to deploy immediately if needed

# After deployment, merge back to dev
git checkout dev
git merge hotfix/critical-security-patch
git push origin dev
```

## Rollback Strategy

If deployment fails:

```bash
# Option 1: Revert merge commit on main
git checkout main
git revert HEAD
git push origin main  # Triggers redeployment

# Option 2: Manual workflow dispatch with previous commit
# GitHub → Actions → Swarm Deploy + Monitoring → Run workflow
# Select commit SHA from before failed deployment
```

## Best Practices

1. **Never commit directly to main** - Always use PRs from dev
2. **Test on dev first** - Ensure all checks pass before merging to main
3. **Small, frequent merges** - Deploy often with small changes
4. **Use descriptive commit messages** - Helps with rollbacks
5. **Tag releases** - Tag main branch after successful deployments
6. **Monitor deployments** - Watch GitHub Actions and Swarm logs
7. **Hotfix responsibly** - Use hotfix workflow only for critical issues

## Tagging Releases

After successful deployment:

```bash
git checkout main
git pull origin main

# Create annotated tag
git tag -a v1.0.0 -m "Production release v1.0.0 - WordPress + Monitoring"
git push origin v1.0.0

# List tags
git tag -l
```

## Troubleshooting

### Deployment Didn't Trigger

**Check:**
1. Did you push to `main`? (not `dev`)
2. Did you modify files in `stack-app/` or `stack-monitoring/`?
3. Are there any workflow errors in GitHub Actions?

**Solution:**
```bash
# Manually trigger deployment
# GitHub → Actions → Swarm Deploy + Monitoring → Run workflow
```

### Compliance Checks Failed

**Common causes:**
- Missing required files
- YAML syntax errors

**Solution:**
```bash
# Run checks locally
python tests/check_required_files.py
```

### Tests Failed on PR

**Solution:**
```bash
# Run tests locally
pip install -r requirements.txt
pytest tests/

# Fix issues and push again
git add .
git commit -m "Fix test failures"
git push origin feature/my-branch
```

## Workflow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    Complete CI/CD Flow                        │
└──────────────────────────────────────────────────────────────┘

Developer              dev Branch           main Branch        Swarm
    │                      │                     │               │
    │                      │                     │               │
    ├── Create PR ────────►│                     │               │
    │                      │                     │               │
    │                      ├─ Run Compliance     │               │
    │                      ├─ Run Python Tests   │               │
    │                      │                     │               │
    │                      ◄── ✅ All Pass       │               │
    │                      │                     │               │
    ├── Merge PR ─────────►│                     │               │
    │                      │                     │               │
    │                      ├─ Run Python Tests   │               │
    │                      │   (on push)         │               │
    │                      │                     │               │
    │                      ◄── ✅ Pass           │               │
    │                      │                     │               │
    ├── Create PR ─────────┼────────────────────►│               │
    │   (dev → main)       │                     │               │
    │                      │                     │               │
    ├── Merge PR ─────────────────────────────►  │               │
    │                      │                     │               │
    │                      │                     ├─ Deploy ─────►│
    │                      │                     │               │
    │                      │                     │               ├─ Create Secrets
    │                      │                     │               ├─ Deploy Monitoring
    │                      │                     │               ├─ Deploy App
    │                      │                     │               │
    │                      │                     ◄───── ✅ ──────┤
    │                      │                     │               │
    ◄──────────── Deployment Complete ◄─────────┤               │
    │                      │                     │               │
```

---

**Last Updated:** December 2025
**Repository:** redLUIT_Dec2025_Docke04_WordPress
