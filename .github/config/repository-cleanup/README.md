# 🧹 Repository Cleanup Configuration

This directory contains configuration profiles for the Repository Cleanup Module, providing predefined settings for different cleanup scenarios.

## 📂 Configuration Files

| File | Description | Use Case |
|------|-------------|----------|
| **`conservative.yml`** | Safe, minimal cleanup | Production repositories, active projects |
| **`aggressive.yml`** | Comprehensive cleanup | Archived projects, cleanup operations |
| **`development.yml`** | Development-focused cleanup | Development/staging environments |
| **`maintenance.yml`** | Scheduled maintenance | Regular housekeeping tasks |
| **`emergency.yml`** | Emergency cleanup | Storage issues, critical cleanup |

## 🎯 Configuration Profiles

### 🛡️ Conservative Profile
- **Purpose:** Minimal risk cleanup for active repositories
- **Age Limit:** 2 years
- **Operations:** Workflow runs, old releases only
- **Protection:** Extensive branch and tag protection
- **Use Case:** Production repositories, active development

### 🔥 Aggressive Profile  
- **Purpose:** Comprehensive cleanup for archived repositories
- **Age Limit:** 6 months
- **Operations:** All cleanup operations enabled
- **Protection:** Minimal protection (main/master only)
- **Use Case:** Archived projects, major cleanup operations

### 🔧 Development Profile
- **Purpose:** Development environment maintenance
- **Age Limit:** 90 days
- **Operations:** PRs, workflow runs, feature branches
- **Protection:** Protects main development branches
- **Use Case:** Development/staging environments

### 🔄 Maintenance Profile
- **Purpose:** Regular scheduled maintenance
- **Age Limit:** 1 year
- **Operations:** Workflow runs, merged PRs, old releases
- **Protection:** Standard branch protection
- **Use Case:** Scheduled housekeeping workflows

### 🚨 Emergency Profile
- **Purpose:** Emergency space recovery
- **Age Limit:** 30 days
- **Operations:** All operations with minimal protection
- **Protection:** Only main/master branches
- **Use Case:** Storage issues, critical situations

## ⚙️ Configuration Structure

Each configuration file contains:

```yaml
# Profile metadata
profile:
  name: "Profile Name"
  description: "Profile description"
  risk_level: "low|medium|high"
  recommended_for: ["use case 1", "use case 2"]

# Cleanup operations
operations:
  releases: true/false
  tags: true/false
  branches: true/false
  pull_requests: true/false
  workflow_runs: true/false
  issues: true/false

# Filtering configuration
filters:
  max_age_days: number
  protected_branches: ["branch1", "branch2"]
  include_patterns: ["pattern1", "pattern2"]
  exclude_patterns: ["pattern1", "pattern2"]

# Execution settings
execution:
  batch_size: number
  batch_delay: number
  dry_run_default: true/false
  force_delete: true/false

# Safety settings
safety:
  require_confirmation: true/false
  max_items_per_operation: number
  emergency_stop_threshold: number
```

## 🔧 Usage Examples

### Using Conservative Profile
```yaml
jobs:
  cleanup:
    uses: ./.github/workflows/modules-repository-cleanup.yml
    with:
      config-profile: 'conservative'
      dry-run: true
```

### Using Aggressive Profile
```yaml
jobs:
  cleanup:
    uses: ./.github/workflows/modules-repository-cleanup.yml
    with:
      config-profile: 'aggressive'
      dry-run: false
      max-age-days: 180
```

### Custom Configuration Override
```yaml
jobs:
  cleanup:
    uses: ./.github/workflows/modules-repository-cleanup.yml
    with:
      config-profile: 'custom'
      cleanup-workflow-runs: true
      cleanup-releases: false
      max-age-days: 365
```

## 🛡️ Safety Recommendations

1. **Always test with dry-run first**
2. **Use conservative profile for production repositories**
3. **Review protected branches configuration**
4. **Monitor cleanup reports for unexpected deletions**
5. **Keep backups before aggressive cleanup**

## 📞 Support

For questions about repository cleanup configuration:
- Review the [Repository Cleanup Action Documentation](./.github/actions/repository-cleanup/README.md)
- Check the [Module Workflow Documentation](./.github/workflows/modules-repository-cleanup.yml)
- Open an issue in the automation templates repository