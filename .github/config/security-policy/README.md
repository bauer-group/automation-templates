# 🛡️ Security Policy Configuration

This directory contains configuration files for the automated security policy management system.

## Overview

The security policy configuration system allows you to centrally manage the core settings for your `SECURITY.MD` generation, including policy versioning, review cycles, template paths, and version support display.

## Configuration Files

### `config.yml`

Streamlined configuration file controlling the essential aspects of security policy management.

## Quick Configuration Changes

### Update Policy Version

```yaml
# In .github/config/security-policy/config.yml
policy:
  version: "1.1.0"  # Bump to new version
```

### Change Review Cycle

```yaml
# In .github/config/security-policy/config.yml
policy:
  review_cycle: 6  # Review every 6 months instead of 12
```

### Customize Template Paths

```yaml
# In .github/config/security-policy/config.yml
template:
  path: "docs/SECURITY.template.MD"     # Source template
  output: "SECURITY.MD"                 # Generated output
```

### Adjust Version Display

```yaml
# In .github/config/security-policy/config.yml
version_support:
  show_previous_versions: 3  # Show only 3 previous versions instead of 5
```

## Configuration Structure

The configuration contains only the essential settings that are actually used by the security policy generation system:

### Policy Management
- **Version**: Current policy version (semantic versioning: x.y.z)
- **Review Cycle**: Time between policy reviews (in months)

### Template Settings
- **Template Path**: Location of the SECURITY.template.MD file
- **Output Path**: Where to generate the final SECURITY.MD file

### Version Support
- **Previous Versions**: How many old versions to show in the support table

## Available Configuration Options

### `policy.version`
- **Type**: String
- **Format**: Semantic versioning (x.y.z)
- **Default**: "1.0.0"
- **Usage**: Sets the policy version displayed in the generated SECURITY.MD

### `policy.review_cycle`
- **Type**: Number
- **Unit**: Months
- **Default**: 12
- **Usage**: Calculates the next review date (current date + review_cycle months)

### `template.path`
- **Type**: String
- **Default**: "docs/SECURITY.template.MD"
- **Usage**: Path to the security policy template file

### `template.output`
- **Type**: String
- **Default**: "SECURITY.MD"
- **Usage**: Path where the generated security policy will be saved

### `version_support.show_previous_versions`
- **Type**: Number
- **Default**: 5
- **Usage**: Number of previous repository versions to display in the support table

## Complete Configuration Example

```yaml
# 🛡️ Security Policy Configuration
# Configuration for automatic SECURITY.MD generation and management

# Policy Version Management
policy:
  # Current policy version (semantic versioning: x.y.z)
  version: "1.0.0"
  
  # Policy review cycle (in months)
  review_cycle: 12

# Template Configuration
template:
  # Path to security policy template
  path: "docs/SECURITY.template.MD"
  
  # Output path for generated security policy
  output: "SECURITY.MD"

# Version Support Configuration
version_support:
  # Number of previous versions to show in support table
  show_previous_versions: 5
```

## Usage Examples

### Basic Policy Update

1. **Edit the configuration**:
   ```bash
   vim .github/config/security-policy/config.yml
   ```

2. **Update policy version**:
   ```yaml
   policy:
     version: "1.1.0"
   ```

3. **Commit and push**:
   ```bash
   git add .github/config/security-policy/config.yml
   git commit -m "security: bump policy version to 1.1.0"
   git push
   ```

4. **Automatic generation**: The workflow will automatically regenerate `SECURITY.MD`

### Manual Trigger with Override

```bash
# Override policy version via workflow dispatch
gh workflow run security-management.yml \
  -f policy-version="2.0.0" \
  -f force-update=true
```

## How It Works

### Configuration Loading

1. **Action reads config**: Loads `.github/config/security-policy/config.yml`
2. **Extracts values**: Parses YAML and extracts policy version, review cycle, etc.
3. **Applies overrides**: Workflow inputs can override config values
4. **Uses in generation**: Values are used to generate SECURITY.MD

### Override Hierarchy

Configuration values can be overridden in this order (highest priority first):

1. **Workflow inputs** (`policy-version`, `template-path`, `output-path`)
2. **Config file values** (this config file)  
3. **Default values** (hardcoded in action)

## Automatic Updates

The security policy is automatically updated when:

1. **Repository version changes** (new tags)
2. **Template file changes** (`docs/SECURITY.template.MD`)
3. **Configuration changes** (this config file)

## Manual Updates

You can manually trigger updates via:

1. **GitHub Actions UI**: Use workflow_dispatch
2. **GitHub CLI**: `gh workflow run security-management.yml`
3. **API**: GitHub REST API workflow dispatch

## Best Practices

### Version Management

1. **Semantic Versioning**: Use proper semantic versioning for policy changes
   - **Major (x.0.0)**: Breaking changes, new structure
   - **Minor (x.y.0)**: New policies, additional requirements
   - **Patch (x.y.z)**: Clarifications, corrections

2. **Review Schedule**: Set appropriate review cycles based on your organization's needs

### Configuration Management

1. **Keep it simple**: Only configure what you actually need to change
2. **Version control**: Always commit configuration changes with descriptive messages
3. **Test changes**: Use manual triggers to test configuration changes

## Troubleshooting

### Common Issues

1. **Config not loading**: Check YAML syntax and file path
2. **Version format errors**: Ensure semantic versioning format (x.y.z)
3. **Template not found**: Verify template path is correct
4. **Dates not calculating**: Check review_cycle value (should be a number)

### Debug Commands

```bash
# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('.github/config/security-policy/config.yml'))"

# Test workflow manually
gh workflow run security-management.yml -f force-update=true
```

### What's Not in Config

These settings are **not** configurable and are handled elsewhere:

- **Workflow triggers**: Defined in `.github/workflows/security-management.yml`
- **Commit messages**: Hardcoded in the workflow
- **Validation rules**: Built into the action
- **Contact information**: Stored in the template file
- **Response times**: Part of the static policy content

---

**🛡️ Centralized configuration makes security policy management simple and consistent!**