# 📁 Workflow Configuration Files

This directory contains configuration files for various GitHub Actions workflows and modules.

## 🔧 Configuration Files

### Release Management
- **`.releaserc.json`** - Semantic Release configuration
  - Defines release rules and changelog generation
  - Used by: `modules-semantic-release.yml`

### PR Labeling & Triage
- **`pr-labeler-paths.yml`** - File path-based labeling rules
  - Maps file patterns to labels
  - Used by: `modules-pr-labeler.yml`, `pr-labeler.yml`
  
- **`pr-labeler-triage-rules.yml`** - Advanced triage rules
  - Custom rules for auto-assignment, priority, and automation
  - Used by: `modules-pr-labeler.yml`, `pr-labeler.yml`

## 📝 Naming Convention

All configuration files follow this naming pattern:
```
{module-name}-{config-type}.{extension}
```

Examples:
- `pr-labeler-paths.yml` - Path rules for PR labeler module
- `pr-labeler-triage-rules.yml` - Triage rules for PR labeler module
- `security-scan-patterns.toml` - (future) Patterns for security scanning

## 🚀 Usage in External Repositories

To use these configurations in your repository:

1. Copy the required config files to `.github/config/`
2. Reference them in your workflow:

```yaml
jobs:
  labeler:
    uses: bauer-group/automation-templates/.github/workflows/modules-pr-labeler.yml@main
    with:
      config-path: '.github/config/pr-labeler-paths.yml'
      custom-rules: '.github/config/pr-labeler-triage-rules.yml'
```

## 🎨 Customization

All configuration files can be customized for your specific needs:

### PR Labeler Paths
```yaml
# .github/config/pr-labeler-paths.yml
documentation:
  - changed-files:
    - any-glob-to-any-file:
      - 'docs/**'
      - '*.md'

frontend:
  - changed-files:
    - any-glob-to-any-file:
      - 'src/frontend/**'
      - '*.jsx'
      - '*.tsx'
```

### PR Triage Rules
```yaml
# .github/config/pr-labeler-triage-rules.yml
priority_rules:
  critical:
    conditions:
      - has_any_labels: ['security', 'hotfix']
    actions:
      - add_labels: ['priority/critical']
      - request_reviewers: ['security-team']
```

## 📊 Module Configuration Matrix

| Module | Config File | Required | Purpose |
|--------|------------|----------|---------|
| `modules-pr-labeler` | `pr-labeler-paths.yml` | Yes | File-based labeling |
| `modules-pr-labeler` | `pr-labeler-triage-rules.yml` | No | Advanced triage |
| `modules-semantic-release` | `.releaserc.json` | Yes | Release configuration |

## 🔒 Security Notes

- Never commit sensitive data in configuration files
- Use repository secrets for API keys and tokens
- Review custom rules for security implications

## 📚 Documentation

For detailed documentation on each configuration format, see:
- [PR Labeler Documentation](../actions/labeler-triage/README.md)
- [Semantic Release Documentation](../actions/semantic-release/README.md)

---

*Configuration files are essential for workflow customization and should be version controlled.*