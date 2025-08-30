# GitHub Repository Cleanup Management

**Automated cleanup tools for maintaining clean and efficient GitHub repositories**

## 🧹 Overview

This directory provides professional tools for automated GitHub repository maintenance and cleanup operations. The solution helps organizations maintain clean, efficient, and compliant repositories by automating routine cleanup tasks.

## 📦 Components

### Core Cleanup Scripts
- **Automated branch cleanup**: Remove stale and merged branches
- **Release artifact management**: Clean up old releases and artifacts
- **Issue and PR cleanup**: Archive completed and stale items
- **Workflow run management**: Clean up old workflow runs

### Cross-Platform Support
- **Python implementation**: `github_cleanup.py` - Full-featured cleanup engine
- **PowerShell version**: `github-cleanup.ps1` - Windows-native implementation
- **Bash script**: `github-cleanup.sh` - Unix/Linux compatibility
- **Batch file**: `github-cleanup.bat` - Windows legacy support

## 🚀 Quick Start

### Python Implementation (Recommended)

```bash
# Install dependencies
pip install -r requirements.txt

# Configure authentication
export GITHUB_TOKEN=ghp_your_token_here

# Run basic cleanup
python github_cleanup.py --repository owner/repo --cleanup-branches

# Advanced cleanup with dry-run
python github_cleanup.py --organization org-name --all-repositories --dry-run
```

### PowerShell Implementation

```powershell
# Set authentication
$env:GITHUB_TOKEN = "ghp_your_token_here"

# Run cleanup
.\github-cleanup.ps1 -Repository "owner/repo" -CleanupBranches -CleanupReleases

# Organization-wide cleanup
.\github-cleanup.ps1 -Organization "org-name" -All -DryRun
```

## 🔧 Configuration

### Environment Variables

```bash
# Authentication
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxx    # GitHub PAT with repo/admin scope
GITHUB_API_URL=https://api.github.com     # GitHub API endpoint

# Cleanup Policies
BRANCH_RETENTION_DAYS=30                  # Keep branches for 30 days
RELEASE_RETENTION_COUNT=10                # Keep last 10 releases
WORKFLOW_RETENTION_DAYS=90                # Keep workflow runs for 90 days
ARTIFACT_RETENTION_DAYS=30                # Keep artifacts for 30 days

# Safety Settings
DRY_RUN=true                              # Enable dry-run by default
REQUIRE_CONFIRMATION=true                 # Require manual confirmation
BACKUP_BEFORE_DELETE=true                 # Create backups before deletion
```

### Cleanup Configuration File

```json
{
  "cleanup_policies": {
    "branches": {
      "enabled": true,
      "retention_days": 30,
      "exclude_patterns": ["main", "develop", "release/*", "hotfix/*"],
      "require_merge_status": true,
      "delete_merged_only": true
    },
    "releases": {
      "enabled": true,
      "retention_count": 10,
      "keep_latest": true,
      "delete_draft_releases": true,
      "archive_old_releases": false
    },
    "workflow_runs": {
      "enabled": true,
      "retention_days": 90,
      "keep_successful_runs": true,
      "delete_failed_runs_after": 30
    },
    "artifacts": {
      "enabled": true,
      "retention_days": 30,
      "size_limit_mb": 100,
      "keep_latest_per_workflow": true
    }
  }
}
```

## 🛡️ Safety Features

### Dry-Run Mode
- **Preview operations**: See what would be deleted without making changes
- **Impact assessment**: Understand cleanup scope before execution
- **Safety validation**: Verify cleanup operations are safe
- **Rollback planning**: Generate rollback instructions

### Backup and Recovery
- **Automatic backups**: Create backups before destructive operations
- **Metadata preservation**: Save branch metadata and commit history
- **Recovery procedures**: Documented recovery processes
- **Audit trails**: Complete record of cleanup operations

### Confirmation Mechanisms
- **Interactive confirmation**: Manual approval for destructive operations
- **Multi-factor authentication**: Additional verification for sensitive operations
- **Approval workflows**: Team-based approval for organization cleanups
- **Emergency stops**: Ability to halt cleanup operations

## 📊 Cleanup Operations

### Branch Management

```bash
# Clean up merged branches
python github_cleanup.py --repository owner/repo --cleanup-branches --merged-only

# Remove stale branches (older than 30 days)
python github_cleanup.py --repository owner/repo --cleanup-branches --older-than 30

# Interactive branch cleanup
python github_cleanup.py --repository owner/repo --cleanup-branches --interactive

# Exclude specific patterns
python github_cleanup.py --repository owner/repo --cleanup-branches \
  --exclude "main,develop,release/*,hotfix/*"
```

### Release Management

```bash
# Keep only last 10 releases
python github_cleanup.py --repository owner/repo --cleanup-releases --keep-count 10

# Remove draft releases
python github_cleanup.py --repository owner/repo --cleanup-releases --drafts-only

# Archive old releases
python github_cleanup.py --repository owner/repo --cleanup-releases --archive-old
```

### Workflow and Artifact Cleanup

```bash
# Clean up old workflow runs
python github_cleanup.py --repository owner/repo --cleanup-workflows --older-than 90

# Remove large artifacts
python github_cleanup.py --repository owner/repo --cleanup-artifacts --size-limit 100MB

# Clean up failed workflow runs
python github_cleanup.py --repository owner/repo --cleanup-workflows --failed-only
```

## 🔄 Automation Integration

### Scheduled Cleanup

```yaml
name: Repository Cleanup

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly cleanup on Sunday at 2 AM
  workflow_dispatch:
    inputs:
      cleanup_type:
        type: choice
        options: [branches, releases, workflows, artifacts, all]
      dry_run:
        type: boolean
        default: true

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
          
      - name: Install dependencies
        run: pip install -r requirements.txt
        
      - name: Run cleanup
        run: |
          python github_cleanup.py \
            --repository ${{ github.repository }} \
            --cleanup-${{ inputs.cleanup_type || 'all' }} \
            ${{ inputs.dry_run && '--dry-run' || '' }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Organization-Wide Cleanup

```bash
# Clean up all repositories in organization
python github_cleanup.py --organization your-org --all-repositories \
  --cleanup-branches --cleanup-releases --dry-run

# Parallel cleanup for large organizations
python github_cleanup.py --organization your-org --all-repositories \
  --cleanup-all --parallel --workers 10

# Generate cleanup report
python github_cleanup.py --organization your-org --all-repositories \
  --report-only --output cleanup-report.json
```

## 📈 Monitoring and Reporting

### Cleanup Reports

```bash
# Generate detailed cleanup report
python github_cleanup.py --repository owner/repo --report \
  --output cleanup-report.html --format html

# JSON report for automation
python github_cleanup.py --organization your-org --all-repositories \
  --report --output org-cleanup.json --format json

# CSV report for analysis
python github_cleanup.py --repository owner/repo --report \
  --output cleanup-metrics.csv --format csv
```

### Metrics and Analytics

- **Storage savings**: Calculate storage space reclaimed
- **Performance improvements**: Measure repository performance gains
- **Compliance metrics**: Track policy compliance across repositories
- **Cleanup trends**: Historical cleanup operation analysis

## 🏛️ Enterprise Features

### Policy Management
- **Organization policies**: Centralized cleanup policies
- **Repository-specific rules**: Custom rules per repository
- **Compliance enforcement**: Automated policy enforcement
- **Exception management**: Controlled policy exceptions

### Multi-Organization Support
- **Enterprise-wide cleanup**: Cleanup across multiple organizations
- **Federated policies**: Consistent policies across organizations
- **Centralized reporting**: Unified cleanup reporting
- **Delegated administration**: Team-based cleanup management

### Integration Capabilities
- **Webhook support**: Real-time cleanup triggers
- **API integration**: Programmatic cleanup management
- **Third-party tools**: Integration with governance platforms
- **Custom plugins**: Extensible cleanup operations

## 🔧 Troubleshooting

### Common Issues

1. **Permission errors**: Verify GitHub token has required scopes
2. **Rate limiting**: Implement proper rate limiting and retry logic
3. **Large repositories**: Use pagination and chunked operations
4. **Network timeouts**: Configure appropriate timeout values

### Debug Commands

```bash
# Test authentication
python github_cleanup.py --test-auth

# Validate configuration
python github_cleanup.py --validate-config cleanup-config.json

# Debug mode with verbose logging
python github_cleanup.py --debug --verbose --repository owner/repo

# Generate debug report
python github_cleanup.py --debug-report --output debug-info.json
```

### Recovery Procedures

```bash
# Restore from backup
python github_cleanup.py --restore --backup-file backup-20240101.json

# Undo last cleanup operation
python github_cleanup.py --undo --operation-id cleanup-20240101-001

# Emergency recovery mode
python github_cleanup.py --emergency-recovery --repository owner/repo
```

## 📚 Documentation

- [Cleanup Policies Guide](./docs/cleanup-policies.md)
- [Safety and Recovery](./docs/safety-recovery.md)
- [API Reference](./docs/api-reference.md)
- [Best Practices](./docs/best-practices.md)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation**: [GitHub Repository Management](https://docs.github.com/en/repositories)
- **Enterprise Support**: Contact your GitHub Enterprise administrator

---

*This cleanup solution helps maintain efficient and compliant GitHub repositories through automated maintenance operations.*
