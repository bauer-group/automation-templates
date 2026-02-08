# Docker Image Maintenance

Automated Docker base image maintenance with automatic semantic releases.

| Solution | Complexity | Features | Best For |
|----------|------------|----------|----------|
| **Dependabot** | Simple | Native GitHub, no app install | Simple projects |
| **Renovate** | Advanced | Grouping, flexible rules | Complex projects |

## Quick Comparison

| Feature | Dependabot | Renovate |
|---------|------------|----------|
| App Installation | Not required | Required |
| PR Grouping | No (1 PR per image) | Yes |
| Schedule Options | Limited | Very flexible |
| Custom Rules | Basic | Advanced |
| Dependency Dashboard | No | Yes |

## Important: Semantic Release Compatibility

For automatic **PATCH** releases on base image updates, the commit message prefix must be `fix(docker)`:

| Commit Prefix | Semantic Release | Version Change |
|---------------|------------------|----------------|
| `fix(docker)` | PATCH | `1.0.0` → `1.0.1` |
| `chore(docker)` | No release | - |
| `feat(docker)` | MINOR | `1.0.0` → `1.1.0` |

Both configurations below use `fix(docker)` to ensure automatic releases.

---

## Complete Automation Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Dependabot or  │────▶│   Creates PR    │────▶│  Docker Build   │
│  Renovate Bot   │     │  fix(docker):   │     │  Validates PR   │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Docker Image   │◀────│ Semantic Release│◀────│  Auto-Merged    │
│  Push to GHCR   │     │  Creates PATCH  │     │  to main        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

---

## Option 1: Dependabot (Simple)

The simplest solution using GitHub's native Dependabot.

### Setup

#### 1. Create Dependabot Configuration

Create `.github/dependabot.yml` in your repository:

```yaml
version: 2
updates:
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "sunday"
      time: "06:30"
      timezone: "Etc/UTC"
    labels:
      - "dependencies"
      - "docker"
      - "automated"
    commit-message:
      prefix: "fix(docker)"
    open-pull-requests-limit: 5
```

Or copy the complete template from:
`.github/config/docker-maintenance-dependabot/dependabot.yml`

#### 2. Create Maintenance Workflow

Create `.github/workflows/docker-maintenance.yml`:

```yaml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths:
      - 'Dockerfile'
      - 'src/Dockerfile'

permissions:
  contents: write
  pull-requests: write

jobs:
  maintenance:
    name: Auto-merge Dependabot PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

#### 3. Enable Auto-Merge and Branch Protection

1. Go to **Settings** → **General** → **Pull Requests** → Enable **"Allow auto-merge"**
2. Go to **Settings** → **Branches** → Add branch protection rule for `main`
3. Enable **"Require status checks to pass before merging"** and select relevant checks

### Workflow Options

| Input            | Description                | Default  |
|------------------|----------------------------|----------|
| `merge-method`   | squash, merge, or rebase   | `squash` |
| `auto-approve`   | Automatically approve PRs  | `true`   |

### Examples

See `github/workflows/examples/docker-maintenance-dependabot/`:

- [simple-dependabot-maintenance.yml](../../github/workflows/examples/docker-maintenance-dependabot/simple-dependabot-maintenance.yml)

---

## Option 2: Renovate (Advanced)

More powerful solution with grouping and advanced rules.

### Setup

#### 1. Install Renovate GitHub App

Install [Renovate GitHub App](https://github.com/apps/renovate) on your repository.

#### 2. Create Renovate Configuration

Create `renovate.json` in your repository root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>bauer-group/automation-templates//.github/config/docker-maintenance-renovate/docker-maintenance"
  ]
}
```

The preset includes:
- `commitMessagePrefix: "fix(docker):"` for semantic release compatibility
- Schedule: Sundays at 06:30 UTC
- Auto-merge for patch and minor updates
- Manual review required for major updates

#### 3. Create Maintenance Workflow

Create `.github/workflows/docker-maintenance.yml`:

```yaml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths:
      - 'Dockerfile'
      - 'src/Dockerfile'

permissions:
  contents: write
  pull-requests: write

jobs:
  maintenance:
    name: Auto-merge Renovate PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-renovate.yml@main
    with:
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

#### 4. Enable Auto-Merge and Branch Protection

1. Go to **Settings** → **General** → **Pull Requests** → Enable **"Allow auto-merge"**
2. Go to **Settings** → **Branches** → Add branch protection rule for `main`
3. Enable **"Require status checks to pass before merging"** and select relevant checks

### Workflow Options

| Input            | Description                | Default                  |
|------------------|----------------------------|--------------------------|
| `merge-method`   | squash, merge, or rebase   | `squash`                 |
| `auto-approve`   | Automatically approve PRs  | `true`                   |
| `allowed-actors` | Comma-separated bot actors | `renovate[bot],renovate` |

### Renovate Features

#### PR Grouping

All Docker updates grouped into single PR:

```json
{
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "groupName": "docker-base-images"
    }
  ]
}
```

#### Dependency Dashboard

Renovate creates an issue showing:
- Pending updates
- Open PRs
- Update history
- Manual triggers

#### Custom Schedule

```json
{
  "schedule": ["after 6:30am on sunday"],
  "timezone": "Etc/UTC"
}
```

### Examples

See `github/workflows/examples/docker-maintenance-renovate/`:

1. [simple-docker-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/simple-docker-maintenance.yml)
2. [comprehensive-docker-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/comprehensive-docker-maintenance.yml)
3. [multi-registry-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/multi-registry-maintenance.yml)
4. [custom-schedule-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/custom-schedule-maintenance.yml)

---

## Combining with Docker Release

For full automation (like PDF-Toolbox), combine maintenance with release workflow:

```yaml
# .github/workflows/docker-maintenance.yml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths:
      - 'src/Dockerfile'

permissions:
  contents: write
  pull-requests: write

jobs:
  maintenance:
    name: Auto-merge Dependabot PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

```yaml
# .github/workflows/docker-release.yml (triggered after merge)
name: Docker Release

on:
  push:
    branches: [main]
    paths:
      - 'src/**'

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit

  docker:
    needs: release
    if: needs.release.outputs.new-release-published == 'true'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: true
    secrets: inherit
```

**Result:** Base image update → PR merged → PATCH release → Docker image rebuilt and pushed.

---

## Troubleshooting

### Auto-Merge Not Triggering

The workflow completes but the PR is not merged.

**Cause:** GitHub's auto-merge requires **branch protection with required status checks**. Without required checks, auto-merge has nothing to wait for and may not behave as expected.

**Fix:**

1. Go to **Settings** → **Branches** → **Branch protection rules** for `main`
2. Enable **"Require status checks to pass before merging"**
3. Select the relevant checks (e.g., Docker build validation)

### No Semantic Release Created

| Problem | Solution |
|---------|----------|
| Commit prefix is `chore(docker)` | Change to `fix(docker)` in dependabot.yml or renovate.json |
| Semantic release not configured | Add `modules-semantic-release.yml` workflow |

### Auto-Merge Not Working

1. Enable auto-merge in repository settings
2. Check branch protection rules allow auto-merge
3. Verify workflow is present and running
4. Check GitHub Actions logs for errors

### Dependabot Not Creating PRs

1. Verify `.github/dependabot.yml` exists
2. Check Settings → Security → Dependabot is enabled
3. Verify `package-ecosystem: "docker"` is configured
4. Check `directory` points to folder with Dockerfile

### Renovate Not Creating PRs

1. Check if Renovate App is installed
2. Check Dependency Dashboard issue for status
3. Verify `renovate.json` syntax

---

## Security Considerations

- **CI must pass**: Auto-merge only after all checks succeed
- **Auto-approve optional**: Can be disabled for manual review
- **Audit trail**: All updates tracked in PRs and git history
- **Major updates**: Require manual review (Renovate only)

## Related Documentation

- [Docker Build Workflow](./docker-build.md)
- [Semantic Release Workflow](./semantic-release.md)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Renovate Documentation](https://docs.renovatebot.com/)
