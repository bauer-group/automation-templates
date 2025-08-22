# 🧹 Repository Cleanup Examples

This directory contains comprehensive examples for using the Repository Cleanup Module across different scenarios and use cases.

## 📚 Available Examples

| Example | Description | Risk Level | Use Case |
|---------|-------------|------------|----------|
| **`conservative-cleanup.yml`** | Safe cleanup for production repositories | 🟢 Low | Active production repos |
| **`aggressive-cleanup.yml`** | Comprehensive cleanup for archived projects | 🔴 High | Archived/decommissioned repos |
| **`development-cleanup.yml`** | Development environment maintenance | 🟡 Medium | Dev/staging environments |
| **`scheduled-maintenance.yml`** | Regular automated maintenance | 🟡 Medium | Scheduled housekeeping |
| **`emergency-cleanup.yml`** | Emergency storage recovery | 🚨 Critical | Storage emergencies |
| **`custom-cleanup.yml`** | Fully customized cleanup operations | 🟡 Medium | Specific requirements |
| **`multi-repository-cleanup.yml`** | Organization-wide cleanup | 🟡 Medium | Multiple repositories |
| **`conditional-cleanup.yml`** | Cleanup with advanced conditions | 🟢 Low | Smart automated cleanup |

## 🎯 Quick Start Guide

### 1. Choose Your Cleanup Profile

Select the appropriate example based on your needs:

- **New to cleanup?** Start with `conservative-cleanup.yml`
- **Archived repository?** Use `aggressive-cleanup.yml`
- **Development environment?** Use `development-cleanup.yml`
- **Regular maintenance?** Use `scheduled-maintenance.yml`
- **Storage emergency?** Use `emergency-cleanup.yml`

### 2. Copy and Customize

```bash
# Copy the example to your repository
cp github/workflows/examples/repository-cleanup/conservative-cleanup.yml .github/workflows/cleanup.yml

# Customize the configuration
vim .github/workflows/cleanup.yml
```

### 3. Test with Dry Run

Always test your cleanup configuration with a dry run first:

```yaml
with:
  dry-run: true  # Always start with dry run
```

### 4. Execute Live Cleanup

Once you're satisfied with the dry run results:

```yaml
with:
  dry-run: false  # Execute actual cleanup
```

## 🛡️ Safety Guidelines

### Before Running Any Cleanup:

1. **🔍 Always start with dry-run: true**
2. **📋 Review the configuration profile**
3. **🛡️ Verify protected branches list**
4. **📊 Check the age thresholds**
5. **🔒 Ensure you have proper permissions**

### Best Practices:

- **Test on a fork or test repository first**
- **Start with conservative profiles**
- **Review cleanup reports carefully**
- **Keep backups of important data**
- **Monitor the cleanup process**

## ⚙️ Configuration Profiles

Each example uses a predefined configuration profile:

```yaml
# Available profiles
config-profile: 'conservative'  # 🛡️ Safe for production
config-profile: 'aggressive'    # 🔥 Comprehensive cleanup
config-profile: 'development'   # 🔧 Dev environment focused
config-profile: 'maintenance'   # 🔄 Regular housekeeping
config-profile: 'emergency'     # 🚨 Critical situations
```

## 📊 Understanding Cleanup Operations

### Available Operations:

| Operation | Description | Impact | Reversible |
|-----------|-------------|--------|------------|
| **Releases** | Delete old releases | Medium | ❌ No |
| **Tags** | Delete old tags | Medium | ❌ No |
| **Branches** | Delete stale branches | High | ❌ No |
| **Pull Requests** | Close old PRs | Low | ✅ Yes |
| **Workflow Runs** | Delete run history | Low | ❌ No |
| **Issues** | Close old issues | Low | ✅ Yes |

### Age-Based Filtering:

```yaml
# Configure age thresholds
max-age-days: 365    # Only cleanup items older than 1 year
max-age-days: 0      # No age limit (cleanup everything)
```

## 🔧 Advanced Configuration

### Custom Patterns:

```yaml
# Include specific patterns
include-patterns: '["feature/.*", "bugfix/.*"]'

# Exclude specific patterns  
exclude-patterns: '[".*keep.*", ".*important.*"]'
```

### Branch Protection:

```yaml
# Protect specific branches from deletion
protected-branches: 'main,master,develop,staging,production'
```

### Performance Tuning:

```yaml
# Adjust for performance
batch-size: 25        # Items per batch
batch-delay: 3        # Seconds between batches
```

## 📈 Monitoring and Reporting

### Cleanup Reports:

All examples generate comprehensive reports including:

- **📊 Operation statistics**
- **⏱️ Execution time**
- **🗑️ Items processed/deleted/skipped**
- **❌ Errors encountered**
- **💾 Storage savings**

### Monitoring:

```yaml
# Enable verbose logging
verbose: true

# Generate detailed reports
generate-report: true
```

## 🚨 Emergency Procedures

### If Something Goes Wrong:

1. **Stop the workflow immediately**
2. **Check the cleanup report**
3. **Restore from backups if needed**
4. **Contact repository administrators**
5. **Review and adjust configuration**

### Emergency Contacts:

- **Repository Issues:** Open an issue in the automation templates repository
- **Critical Problems:** Contact your system administrators
- **Security Concerns:** Follow your organization's security procedures

## 📞 Support and Troubleshooting

### Common Issues:

1. **Permission Denied**
   - Ensure `GITHUB_TOKEN` has proper permissions
   - Check repository admin access

2. **Rate Limiting**
   - Increase `batch-delay` parameter
   - Reduce `batch-size` parameter

3. **Unexpected Deletions**
   - Review `include-patterns` and `exclude-patterns`
   - Check `protected-branches` configuration

### Getting Help:

- Review the [Repository Cleanup Action Documentation](../../actions/repository-cleanup/README.md)
- Check the [Module Workflow Documentation](../../workflows/modules-repository-cleanup.yml)
- Browse the [Configuration Profiles](../../config/repository-cleanup/)
- Open an issue in the automation templates repository

## 🔄 Version History

- **v1.0.0** - Initial release with comprehensive cleanup capabilities
- Configuration profiles and safety features
- Multi-repository support and advanced filtering
- Emergency procedures and recovery options

---

*For the latest documentation and updates, visit the [BAUER GROUP Automation Templates](https://github.com/bauer-group/automation-templates) repository.*