# Branch Protection Management

**Automated GitHub branch protection rules with enterprise-grade security policies**

## 🛡️ Overview

This directory contains professional tools for managing GitHub branch protection rules at scale. The solution provides automated setup, validation, and maintenance of branch protection policies across repositories and organizations.

## 📦 Components

### Core Protection Script
- **Automated rule deployment**: Standardized protection rules
- **Multi-repository support**: Bulk protection rule management  
- **Validation framework**: Verify protection rule compliance
- **Policy enforcement**: Organization-wide security standards

### Configuration Management
- **Template-based rules**: Reusable protection configurations
- **Environment-specific policies**: Development, staging, production rules
- **Compliance reporting**: Audit and compliance verification
- **Exception handling**: Managed policy exceptions

## 🚀 Quick Start

### Basic Protection Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Configure your protection rules
cp config.example.json config.json
# Edit config.json with your settings

# Apply protection rules
python protect_main.py --config config.json

# Verify protection status
python protect_main.py --validate --config config.json
```

### Automated Deployment

```bash
# Deploy protection rules across organization
./protect-main.sh --org your-org --apply-all

# Validate compliance
./run_protection.sh --validate --report compliance-report.json
```

## 🔧 Configuration

### Protection Rule Templates

```json
{
  "branch_protection": {
    "main": {
      "required_status_checks": {
        "strict": true,
        "contexts": [
          "continuous-integration",
          "security-scan", 
          "license-compliance"
        ]
      },
      "enforce_admins": true,
      "required_pull_request_reviews": {
        "required_approving_review_count": 2,
        "dismiss_stale_reviews": true,
        "require_code_owner_reviews": true,
        "restrict_pushes": true
      },
      "restrictions": {
        "users": [],
        "teams": ["core-team", "security-team"]
      }
    }
  }
}
```

## 🛡️ Security Features

### Comprehensive Protection
- **Required status checks**: Automated CI/CD validation
- **Code review enforcement**: Mandatory peer reviews
- **Admin enforcement**: Rules apply to repository administrators
- **Signed commits**: Cryptographic commit verification

### Advanced Policies
- **Linear history**: Prevent merge commits and force pushes
- **Conversation resolution**: Require discussion resolution
- **Auto-merge restrictions**: Control automated merging
- **Branch restrictions**: Limit who can push to protected branches

## 📊 Management Operations

### Bulk Operations

```bash
# Apply rules to all repositories  
python protect_main.py --bulk --org your-org

# Update existing protection rules
python protect_main.py --update --repositories repo1,repo2,repo3

# Remove protection rules (with confirmation)
python protect_main.py --remove --repository repo-name --confirm
```

### Validation and Auditing

```bash
# Validate current protection status
python protect_main.py --validate --output validation-report.json

# Generate compliance report
python protect_main.py --audit --format json --output audit-report.json

# Check for policy drift
python protect_main.py --drift-detection --baseline baseline-config.json
```

## 🔄 Automation Integration

### GitHub Actions Integration

```yaml
name: Branch Protection Management

on:
  schedule:
    - cron: '0 6 * * 1'  # Weekly validation
  workflow_dispatch:
    inputs:
      operation:
        type: choice
        options: [validate, apply, audit]

jobs:
  protection-management:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.12'
          
      - name: Install dependencies
        run: pip install -r requirements.txt
        
      - name: Execute protection management
        run: |
          python protect_main.py \
            --${{ inputs.operation || 'validate' }} \
            --config config.json \
            --token ${{ secrets.GITHUB_TOKEN }}
```

## 🏛️ Enterprise Features

### Multi-Organization Support
- **Cross-org policies**: Consistent rules across organizations
- **Centralized management**: Single source of truth for policies
- **Delegated administration**: Team-specific policy management
- **Inheritance rules**: Organization → team → repository hierarchy

### Compliance and Governance
- **Policy templates**: Pre-built compliance frameworks
- **Audit trails**: Complete change history
- **Exception tracking**: Managed policy deviations
- **Reporting**: Executive and technical reports

## 🔧 Troubleshooting

### Common Issues

1. **Permission errors**: Verify GitHub token has admin:org scope
2. **API rate limits**: Implement proper rate limiting and pagination
3. **Policy conflicts**: Check for conflicting protection rules
4. **Validation failures**: Review protection rule syntax

### Debug Commands

```bash
# Test GitHub connectivity
python protect_main.py --test-connection

# Validate configuration file
python protect_main.py --validate-config config.json

# Dry run policy application
python protect_main.py --dry-run --repository test-repo

# Generate debug report
python protect_main.py --debug --output debug-report.json
```

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation**: [Branch Protection Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)
- **Enterprise Support**: Contact your GitHub Enterprise administrator

---

*This branch protection solution enforces enterprise-grade security policies and compliance requirements.*
