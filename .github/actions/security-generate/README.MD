# 🛡️ Security Policy Generator Action

Professional GitHub Action for automatically generating `SECURITY.MD` files from templates with dynamic version information, automated date calculations, and comprehensive version support tables.

## Overview

This action processes a `SECURITY.template.MD` file and generates a complete `SECURITY.MD` with:

- **Dynamic Version Tables**: Automatically builds supported versions table from Git tags
- **Date Management**: Calculates review dates (12-month cycle) and last updated timestamps
- **Template Processing**: Replaces placeholders with current repository information
- **Change Detection**: Only updates when actual changes are detected
- **Validation**: Ensures all required sections and placeholders are present

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `template-path` | Path to the SECURITY template file | No | `docs/SECURITY.template.MD` |
| `output-path` | Path where the generated SECURITY.MD should be saved | No | `SECURITY.MD` |
| `force-update` | Force update even if no changes detected | No | `false` |
| `custom-version` | Custom version to use instead of auto-detected | No | `` |
| `policy-version` | Security policy version (semantic versioning: x.y.z) | No | `1.0.0` |

## Outputs

| Output | Description |
|--------|-------------|
| `security_updated` | Whether the SECURITY.MD file was updated |
| `changes_detected` | Whether changes were detected in the template |
| `validation_passed` | Whether validation checks passed |
| `current_version` | The current version that was used |
| `policy_version` | The policy version that was used |
| `next_review_date` | The calculated next review date |

## Template Placeholders

The action processes the following placeholders in your `SECURITY.template.MD`:

| Placeholder | Description | Example Output |
|-------------|-------------|----------------|
| `{{CURRENT_VERSION}}` | Current repository version (from latest tag) | `v0.18.0` |
| `{{LAST_UPDATED}}` | Current timestamp | `2025-08-22 15:30:00 UTC` |
| `{{NEXT_REVIEW}}` | Next review date (+12 months) | `August 2026` |
| `{{POLICY_VERSION}}` | Security policy version | `1.0.0` |
| `{{SUPPORTED_VERSIONS_TABLE}}` | Complete version support table | See below |

### Version Support Table Format

The action automatically generates a table like this:

```markdown
| Version | Support Status | Security Updates |
|---------|---------------|------------------|
| v0.18.0 (current) | ✅ Full Support | ✅ Yes |
| v0.17.0 | ❌ End of Life | ❌ No |
| v0.16.0 | ❌ End of Life | ❌ No |
| v0.15.0 | ❌ End of Life | ❌ No |
```

## Example Usage

### Basic Usage

```yaml
- name: 🛡️ Generate Security Policy
  uses: bauer-group/automation-templates/.github/actions/security-generate@main
  with:
    template-path: 'docs/SECURITY.template.MD'
    output-path: 'SECURITY.MD'
```

### Advanced Usage with Custom Settings

```yaml
- name: 🛡️ Generate Security Policy
  uses: bauer-group/automation-templates/.github/actions/security-generate@main
  with:
    template-path: 'docs/SECURITY.template.MD'
    output-path: 'SECURITY.MD'
    force-update: true
    custom-version: 'v1.0.0'
    policy-version: '2.0.0'
```

### Conditional Usage

```yaml
- name: 🛡️ Generate Security Policy
  id: security-gen
  uses: bauer-group/automation-templates/.github/actions/security-generate@main
  with:
    template-path: 'docs/SECURITY.template.MD'
    output-path: 'SECURITY.MD'
    force-update: ${{ startsWith(github.ref, 'refs/tags/') }}

- name: 📊 Security Policy Results
  if: steps.security-gen.outputs.security_updated == 'true'
  run: |
    echo "✅ Security policy updated!"
    echo "Version: ${{ steps.security-gen.outputs.current_version }}"
    echo "Policy Version: ${{ steps.security-gen.outputs.policy_version }}"
    echo "Next Review: ${{ steps.security-gen.outputs.next_review_date }}"
```

## Template Creation

### 1. Create Template File

Create `docs/SECURITY.template.MD` with your security policy content:

```markdown
# 🛡️ Security Policy

## 🔐 Supported Versions

We actively maintain and provide security updates for supported versions:

{{SUPPORTED_VERSIONS_TABLE}}

### Version Support Policy

- **Current Version**: Full feature and security support for the latest release ({{CURRENT_VERSION}})
- **Previous Versions**: No support provided - users should upgrade to the current version
- **Security Updates**: Only applied to the current version

## 📄 Legal Notice

**Last Updated**: {{LAST_UPDATED}}  
**Next Review**: {{NEXT_REVIEW}}  
**Policy Version**: {{POLICY_VERSION}}  
**Repository Version**: {{CURRENT_VERSION}}
```

### 2. Required Placeholders

Ensure your template includes all required placeholders:

- `{{SUPPORTED_VERSIONS_TABLE}}` - Version support table
- `{{CURRENT_VERSION}}` - Current repository version
- `{{LAST_UPDATED}}` - Last update timestamp
- `{{NEXT_REVIEW}}` - Next review date
- `{{POLICY_VERSION}}` - Policy version number

## Integration with Workflows

### Complete Workflow Example

```yaml
name: 🛡️ Security Policy Management

on:
  push:
    branches: [main]
    tags: ['v*.*.*']
  pull_request:
    paths: ['docs/SECURITY.template.MD']
  workflow_dispatch:

jobs:
  generate-security-policy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 🛡️ Generate Security Policy
        id: generate
        uses: bauer-group/automation-templates/.github/actions/security-generate@main
        with:
          force-update: ${{ startsWith(github.ref, 'refs/tags/') }}

      - name: 📝 Commit Changes
        if: steps.generate.outputs.changes_detected == 'true'
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "Security Policy Bot"
          git add SECURITY.MD
          git commit -m "security: update SECURITY.MD [automated]"
          git push
```

## Features

### 🔄 Automatic Version Detection

- **Git Tags**: Automatically detects latest tag as current version
- **Fallback**: Uses `main` if no tags are available
- **Custom Override**: Supports manual version specification
- **Version History**: Includes up to 5 previous versions in support table

### 📅 Smart Date Calculation

- **Cross-Platform**: Works on Linux, macOS, and Windows runners
- **12-Month Cycle**: Automatically calculates next review date
- **UTC Timestamps**: Consistent timezone handling
- **Fallback Logic**: Robust date calculation with multiple fallback methods

### ✅ Comprehensive Validation

- **Template Validation**: Ensures all required placeholders exist
- **Structure Checking**: Validates generated output format
- **Change Detection**: Only updates when content actually changes
- **Error Handling**: Clear error messages for troubleshooting

### 🔧 Professional Features

- **Generation Comments**: Adds auto-generated file headers
- **Force Update**: Option to update regardless of changes
- **Custom Versions**: Support for manual version specification
- **Policy Versioning**: Track security policy evolution

## Troubleshooting

### Common Issues

1. **Missing Placeholders**: Ensure all required placeholders are in your template
2. **No Tags Found**: Action falls back to `main` - consider creating version tags
3. **Date Calculation Issues**: Action includes multiple fallback methods for date calculation
4. **Permission Errors**: Ensure workflow has `contents: write` permission for commits

### Debug Output

Enable debug output to troubleshoot issues:

```yaml
- name: 🛡️ Generate Security Policy
  uses: bauer-group/automation-templates/.github/actions/security-generate@main
  env:
    ACTIONS_STEP_DEBUG: true
```

## Security Considerations

- **No Secrets Required**: Action works with public repository information only
- **Template Validation**: Prevents injection through template validation
- **Read-Only Operations**: Core logic only reads Git history and processes templates
- **Secure Defaults**: Conservative defaults for all security-related settings

## Contributing

To contribute improvements to this action:

1. Fork the repository
2. Make changes to `.github/actions/security-generate/`
3. Test with the provided workflow examples
4. Submit a pull request with clear description

---

**🛡️ This action helps maintain professional, up-to-date security policies automatically!**