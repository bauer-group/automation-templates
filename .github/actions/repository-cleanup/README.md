# 🧹 Repository Cleanup Action

The Repository Cleanup Action provides comprehensive, configurable repository maintenance capabilities with enterprise-grade safety features and extensive reporting.

[![Action Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/bauer-group/automation-templates)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![BAUER GROUP](https://img.shields.io/badge/BAUER-GROUP-orange.svg)](https://github.com/bauer-group)

## 🌟 Features

- **🛡️ Safety First**: Built-in safety measures, dry-run capability, and comprehensive validation
- **⚙️ Configurable Operations**: Selective cleanup of releases, tags, branches, PRs, workflow runs, and issues
- **📅 Age-Based Filtering**: Cleanup items based on configurable age thresholds
- **🎯 Pattern Matching**: Advanced include/exclude pattern support with regex
- **🔒 Branch Protection**: Comprehensive branch protection with configurable rules
- **📊 Detailed Reporting**: Comprehensive reports with statistics, summaries, and recommendations
- **🚀 Performance Optimized**: Batched operations with rate limiting and timeout handling
- **🔧 Enterprise Ready**: Supports large repositories with robust error handling

## 📋 Table of Contents

- [Quick Start](#-quick-start)
- [Input Parameters](#-input-parameters)
- [Output Values](#-output-values)
- [Usage Examples](#-usage-examples)
- [Configuration Profiles](#-configuration-profiles)
- [Safety Features](#-safety-features)
- [Performance Tuning](#-performance-tuning)
- [Troubleshooting](#-troubleshooting)
- [Best Practices](#-best-practices)

## 🚀 Quick Start

### Basic Usage (Safe Default)

```yaml
- name: 🧹 Clean Repository
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cleanup-workflow-runs: true
    max-age-days: 365
    dry-run: true  # Always start with dry run
```

### Production Usage

```yaml
- name: 🧹 Repository Cleanup
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    # Authentication
    github-token: ${{ secrets.GITHUB_TOKEN }}
    repository: ${{ github.repository }}
    
    # Operations
    cleanup-releases: false
    cleanup-tags: false
    cleanup-branches: true
    cleanup-pull-requests: true
    cleanup-workflow-runs: true
    cleanup-issues: false
    
    # Configuration
    max-age-days: 365
    protected-branches: 'main,master,develop,staging'
    
    # Execution
    dry-run: false
    batch-size: 25
    batch-delay: 3
```

## 📝 Input Parameters

### 🔧 Repository Configuration

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `repository` | string | No | `${{ github.repository }}` | Target repository in `owner/repo` format |
| `github-token` | string | Yes | - | GitHub token with required permissions |

### 🧹 Cleanup Operations

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `cleanup-releases` | boolean | No | `false` | Delete repository releases |
| `cleanup-tags` | boolean | No | `false` | Delete repository tags |
| `cleanup-branches` | boolean | No | `false` | Delete branches (respects protection) |
| `cleanup-pull-requests` | boolean | No | `false` | Close open pull requests |
| `cleanup-workflow-runs` | boolean | No | `false` | Delete workflow run history |
| `cleanup-issues` | boolean | No | `false` | Close open issues |

### 📅 Age-Based Filtering

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `max-age-days` | number | No | `0` | Only cleanup items older than specified days (0 = no limit) |

### 🛡️ Protection Settings

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `protected-branches` | string | No | `main,master,develop,staging` | Comma-separated list of protected branches |
| `force-delete` | boolean | No | `false` | Force delete protected items (use with caution) |

### 🔀 Pull Request Handling

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `pr-action` | string | No | `close` | PR action: `close` or `comment-and-close` |
| `pr-comment` | string | No | Default message | Custom comment before closing PRs |

### 🎯 Pattern Filtering

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `include-patterns` | string | No | `[]` | JSON array of regex patterns to include |
| `exclude-patterns` | string | No | `[]` | JSON array of regex patterns to exclude |

### ⚙️ Execution Configuration

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `dry-run` | boolean | No | `true` | Perform dry run without making changes |
| `batch-size` | number | No | `50` | Items to process per batch (1-100) |
| `batch-delay` | number | No | `2` | Delay in seconds between batches |
| `skip-confirmation` | boolean | No | `false` | Skip interactive confirmation prompts |

### 📊 Logging and Reporting

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `verbose` | boolean | No | `false` | Enable detailed logging |
| `log-format` | string | No | `text` | Log format: `text` or `json` |

## 📤 Output Values

| Output | Type | Description |
|--------|------|-------------|
| `cleanup-summary` | string | Detailed cleanup summary (JSON format) |
| `items-processed` | number | Total number of items processed |
| `items-deleted` | number | Total number of items deleted |
| `items-skipped` | number | Total number of items skipped |
| `errors-count` | number | Number of errors encountered |
| `execution-time` | number | Total execution time in seconds |

## 🎯 Usage Examples

### Conservative Cleanup (Production Safe)

```yaml
- name: 🛡️ Conservative Cleanup
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cleanup-workflow-runs: true  # Only cleanup workflow runs
    max-age-days: 730  # 2 years
    protected-branches: 'main,master,develop,staging,production'
    dry-run: false
    batch-size: 10
    batch-delay: 5
```

### Development Environment Cleanup

```yaml
- name: 🔧 Development Cleanup
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cleanup-branches: true
    cleanup-pull-requests: true
    cleanup-workflow-runs: true
    max-age-days: 90  # 3 months
    protected-branches: 'main,master,develop,staging'
    include-patterns: '["feature/.*", "bugfix/.*", "temp/.*"]'
    pr-action: 'comment-and-close'
    pr-comment: 'This PR is being closed as part of development environment cleanup.'
```

### Aggressive Cleanup (Archived Repositories)

```yaml
- name: 🔥 Aggressive Cleanup
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cleanup-releases: true
    cleanup-tags: true
    cleanup-branches: true
    cleanup-pull-requests: true
    cleanup-workflow-runs: true
    cleanup-issues: true
    max-age-days: 180  # 6 months
    protected-branches: 'main,master'
    exclude-patterns: '[".*critical.*", "v[0-9]+\\.[0-9]+\\.[0-9]+$"]'
    batch-size: 50
    batch-delay: 2
```

### Pattern-Based Cleanup

```yaml
- name: 🎯 Pattern-Based Cleanup
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    cleanup-branches: true
    include-patterns: |
      [
        "feature/.*",
        "bugfix/.*",
        "experiment/.*",
        "temp/.*"
      ]
    exclude-patterns: |
      [
        ".*keep.*",
        ".*important.*",
        ".*demo.*"
      ]
    max-age-days: 30
```

## ⚙️ Configuration Profiles

The action supports predefined configuration profiles for common use cases:

### 🛡️ Conservative Profile
- **Use Case**: Production repositories, active development
- **Operations**: Workflow runs only
- **Age Limit**: 2 years
- **Safety**: Maximum protection, extensive exclusions

### 🔥 Aggressive Profile
- **Use Case**: Archived repositories, storage recovery
- **Operations**: All cleanup operations
- **Age Limit**: 6 months
- **Safety**: Minimal protection, focused on space recovery

### 🔧 Development Profile
- **Use Case**: Development/staging environments
- **Operations**: Branches, PRs, workflow runs
- **Age Limit**: 3 months
- **Safety**: Development-focused protection

### 🔄 Maintenance Profile
- **Use Case**: Scheduled maintenance
- **Operations**: Balanced cleanup approach
- **Age Limit**: 1 year
- **Safety**: Standard protection with automation support

## 🛡️ Safety Features

### Built-in Safety Measures

1. **Dry Run Default**: All operations default to dry run mode
2. **Branch Protection**: Comprehensive branch protection rules
3. **Age Validation**: Age-based filtering prevents accidental recent deletions
4. **Pattern Matching**: Include/exclude patterns for precise control
5. **Batch Processing**: Controlled batching prevents rate limiting
6. **Error Handling**: Comprehensive error handling with detailed reporting

### Safety Recommendations

```yaml
# Always start with dry run
dry-run: true

# Use conservative age limits
max-age-days: 365  # 1 year or more

# Protect important branches
protected-branches: 'main,master,develop,staging,production'

# Use exclude patterns for important items
exclude-patterns: '[".*keep.*", ".*important.*", ".*stable.*"]'

# Start with small batch sizes
batch-size: 10
batch-delay: 5
```

### Validation Checks

The action performs comprehensive validation:

- Repository format validation
- Numerical parameter validation
- JSON pattern validation  
- Permission verification
- Rate limit checking
- Emergency stop conditions

## 🚀 Performance Tuning

### Batch Configuration

```yaml
# For small repositories or careful processing
batch-size: 10
batch-delay: 5

# For large repositories and faster processing
batch-size: 50
batch-delay: 2

# For maximum speed (use with caution)
batch-size: 100
batch-delay: 1
```

### Rate Limit Management

The action automatically handles GitHub API rate limits:

- Monitors rate limit headers
- Implements exponential backoff
- Provides detailed rate limit reporting
- Adjusts batch timing dynamically

### Performance Guidelines

| Repository Size | Batch Size | Batch Delay | Expected Duration |
|----------------|------------|-------------|-------------------|
| Small (<1000 items) | 25 | 3s | 5-15 minutes |
| Medium (1000-5000) | 50 | 2s | 15-30 minutes |
| Large (5000+) | 75 | 2s | 30+ minutes |

## 🔧 Troubleshooting

### Common Issues

#### Permission Denied
```
Error: Resource not accessible by integration
```

**Solution**: Ensure GitHub token has required permissions:
- `contents: write`
- `issues: write`
- `pull-requests: write`
- `actions: write`

#### Rate Limiting
```
Error: API rate limit exceeded
```

**Solutions**:
- Increase `batch-delay`
- Reduce `batch-size`
- Use GitHub App token for higher limits

#### Pattern Matching Issues
```
Error: Invalid regex pattern
```

**Solutions**:
- Escape special characters in patterns
- Test patterns with online regex tools
- Use simple string matching when possible

#### Large Repository Timeouts
```
Error: Operation timed out
```

**Solutions**:
- Increase `batch-delay`
- Reduce `batch-size`
- Run cleanup in smaller chunks

### Debug Mode

Enable debug logging for troubleshooting:

```yaml
- name: 🧹 Repository Cleanup (Debug)
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    verbose: true
    log-format: 'json'
    # ... other parameters
```

### Emergency Recovery

If cleanup goes wrong:

1. **Stop the workflow** immediately
2. **Review the cleanup report** for what was deleted
3. **Check repository backups** if available
4. **Restore from backups** if necessary
5. **Adjust configuration** before retry

## 📋 Best Practices

### 1. Always Test First

```yaml
# Always start with dry run
- name: 🔍 Test Cleanup
  uses: bauer-group/automation-templates/.github/actions/repository-cleanup@main
  with:
    dry-run: true  # Test configuration first
    # ... configuration
```

### 2. Use Conservative Settings

```yaml
# Conservative approach for production
- name: 🛡️ Safe Cleanup
  with:
    max-age-days: 730  # 2 years minimum
    batch-size: 10     # Small batches
    batch-delay: 5     # Longer delays
```

### 3. Implement Progressive Cleanup

```yaml
# Step 1: Workflow runs only
cleanup-workflow-runs: true

# Step 2: Add PRs after validation
cleanup-pull-requests: true

# Step 3: Add branches after careful review
cleanup-branches: true
```

### 4. Monitor and Review

```yaml
# Enable comprehensive reporting
generate-report: true
verbose: true

# Review reports before proceeding
```

### 5. Use Appropriate Profiles

Choose the right profile for your use case:
- **Conservative**: Active production repositories
- **Development**: Development/staging environments
- **Maintenance**: Regular automated cleanup
- **Aggressive**: Archived repositories only

## 📞 Support and Contributing

### Getting Help

1. **Documentation**: Check this README and examples
2. **Issues**: Open issues in the automation templates repository  
3. **Discussions**: Use GitHub Discussions for questions
4. **Enterprise Support**: Contact BAUER GROUP for enterprise support

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Update documentation
5. Submit a pull request

### License

This action is licensed under the MIT License. See [LICENSE](../../../LICENSE) for details.

---

## 📊 Action Metadata

**Version**: v1.0.0  
**Author**: BAUER GROUP  
**License**: MIT  
**Repository**: [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)

**Supported Runners**:
- ubuntu-latest ✅
- windows-latest ✅  
- macos-latest ✅

**Required Permissions**:
- contents: write
- issues: write
- pull-requests: write
- actions: write

**API Rate Limits**: Automatically managed with intelligent batching and backoff

---

*For the latest documentation and updates, visit the [BAUER GROUP Automation Templates](https://github.com/bauer-group/automation-templates) repository.*