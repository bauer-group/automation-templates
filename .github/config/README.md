# 📁 Workflow Configuration Directory

Organized configuration files for GitHub Actions workflows and modules.

## 📂 Directory Structure

```
.github/config/
├── 📁 release/          # Release & versioning configurations
│   └── semantic-release.json
├── 📁 pr-labeler/       # Pull request labeling configurations  
│   ├── path-labels.yml
│   └── triage-rules.yml
├── 📁 issues/           # Issue automation configurations
│   ├── label-actions.yml
│   └── ai-prompts.yml
├── 📁 security/         # Security scanning configurations (future)
│   ├── gitleaks.toml
│   └── gitguardian.yml
├── 📁 license/          # License compliance configurations (future)
│   └── allowed-licenses.yml
├── 📁 claude-code/      # Claude Code Assistant configurations
│   ├── default.yml
│   ├── code-review.yml
│   ├── issue-helper.yml
│   ├── security-review.yml
│   └── minimal.yml
└── commitlint.config.js # Commit message linting configuration
```

## 🔧 Configuration Files by Module

### 📦 Release Management (`release/`)
**Modules:** `modules-semantic-release.yml`, `documentation.yml`

- **`semantic-release.json`** - Semantic versioning and release configuration
  - Defines version bump rules (major/minor/patch)
  - Configures changelog generation
  - Sets up release notes formatting
  - Triggers automatic README updates on releases

### 🏷️ PR Labeler (`pr-labeler/`)
**Module:** `modules-pr-labeler.yml`

- **`path-labels.yml`** - File path-based labeling rules
  - Maps file patterns to labels
  - Supports glob patterns
  
- **`triage-rules.yml`** - Advanced triage and automation rules
  - Auto-assignment based on labels/paths
  - Priority classification
  - Custom automation rules

### 🤖 Issue Automation (`issues/`)
**Modules:** `modules-issue-automation.yml`, `modules-ai-issue-summary.yml`

- **`label-actions.yml`** - Automated actions based on issue/PR labels
  - Close issues with specific messages (support, feature, duplicate)
  - Add comments and additional labels
  - Remove labels based on conditions
  - Handle stale issues and security reports

- **`ai-prompts.yml`** - AI prompt templates for issue analysis
  - Brief, detailed, technical, and user-friendly summaries
  - Bug analysis and feature evaluation templates
  - Security issue handling (sanitized)
  - Multi-language support templates

### 🔒 Security (future) (`security/`)
**Modules:** `modules-security-scan.yml`

- **`gitleaks.toml`** - Gitleaks secret detection patterns
- **`gitguardian.yml`** - GitGuardian scanning rules

### 📋 License (future) (`license/`)
**Module:** `modules-license-compliance.yml`

- **`allowed-licenses.yml`** - License whitelist/blacklist configuration

### 🤖 Claude Code Assistant (`claude-code/`)

**Module:** `claude-code.yml`

- **`default.yml`** - Standard configuration for general assistance
  - Claude Opus model with balanced settings
  - All users allowed, standard rate limits

- **`code-review.yml`** - Optimized for thorough code reviews
  - Extended tokens and timeout for detailed analysis
  - Structured review format with severity levels

- **`issue-helper.yml`** - Helping with issues and feature requests
  - Quick responses for issue triage
  - Bug analysis and feature evaluation

- **`security-review.yml`** - Security-focused code analysis
  - OWASP-based vulnerability scanning
  - Restricted to security team (configurable)

- **`minimal.yml`** - Quick, concise responses
  - Uses Sonnet for faster responses
  - Minimal context for brief answers

## 📝 Naming Convention

Files follow a clear naming pattern:
```
{category}/{function}.{extension}
```

Examples:
- `release/semantic-release.json` - Release configuration
- `pr-labeler/path-labels.yml` - Path-based label mapping
- `pr-labeler/triage-rules.yml` - Triage automation rules

## 🚀 Usage in Workflows

### Internal Repository
```yaml
jobs:
  labeler:
    uses: ./.github/workflows/modules-pr-labeler.yml
    with:
      config-path: '.github/config/pr-labeler/path-labels.yml'
      custom-rules: '.github/config/pr-labeler/triage-rules.yml'
```

### External Repository
```yaml
jobs:
  labeler:
    uses: bauer-group/automation-templates/.github/workflows/modules-pr-labeler.yml@main
    with:
      config-path: '.github/config/pr-labeler/path-labels.yml'
      custom-rules: '.github/config/pr-labeler/triage-rules.yml'
```

## 🎨 Customization Guide

### Creating Your Own Configuration

1. **Create the directory structure:**
```bash
mkdir -p .github/config/{release,pr-labeler,security,license}
```

2. **Copy and customize configurations:**
```bash
# Copy from templates repository
cp -r bauer-group/automation-templates/.github/config/* .github/config/

# Edit as needed
vim .github/config/pr-labeler/path-labels.yml
```

3. **Override default paths in workflow:**
```yaml
with:
  config-path: '.github/config/pr-labeler/my-custom-labels.yml'
```

## 📊 Configuration Matrix

| Module | Config Directory | File | Required | Purpose |
|--------|-----------------|------|----------|---------|
| `modules-semantic-release` | `release/` | `semantic-release.json` | Yes | Version & changelog rules |
| `documentation` | - | - | No | Auto-updates on releases |
| `modules-pr-labeler` | `pr-labeler/` | `path-labels.yml` | Yes | File-based labeling |
| `modules-pr-labeler` | `pr-labeler/` | `triage-rules.yml` | No | Advanced automation |
| `modules-issue-automation` | `issues/` | `label-actions.yml` | No | Issue/PR automation |
| `modules-ai-issue-summary` | `issues/` | `ai-prompts.yml` | No | AI-powered summaries |
| `modules-security-scan` | `security/` | `gitleaks.toml` | No | Secret patterns |
| `modules-license-compliance` | `license/` | `allowed-licenses.yml` | No | License rules |

## 🔍 Configuration Examples

### PR Labeler Path Configuration
```yaml
# .github/config/pr-labeler/path-labels.yml
documentation:
  - changed-files:
    - any-glob-to-any-file:
      - 'docs/**'
      - '**/*.md'

frontend:
  - changed-files:
    - any-glob-to-any-file:
      - 'src/frontend/**'
```

### Semantic Release Configuration

**Standard-Konfiguration:**

```json
// .github/config/release/semantic-release.json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.MD"
    }],
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.MD"],
      "message": "chore(release): ${nextRelease.version}\n\n${nextRelease.notes}"
    }],
    "@semantic-release/github"
  ]
}
```

**Mit @semantic-release/npm (package.json Version aktualisieren ohne npm publish):**

```json
// .github/config/release/semantic-release.json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.MD"
    }],
    ["@semantic-release/npm", {
      "npmPublish": false
    }],
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.MD", "package.json", "package-lock.json"],
      "message": "chore(release): ${nextRelease.version}\n\n${nextRelease.notes}"
    }],
    "@semantic-release/github"
  ]
}
```

**Workflow-Aufruf mit extra-plugins:**

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
      extra-plugins: '@semantic-release/npm'
    secrets: inherit
```

### Documentation Auto-Update on Release
```yaml
# .github/workflows/documentation.yml
on:
  # Automatic trigger on new releases
  release:
    types: [published, created]
  
  # Manual trigger with version override
  workflow_dispatch:
    inputs:
      custom-version:
        description: 'Custom version for README'
        type: string

jobs:
  generate-documentation:
    uses: ./.github/actions/readme-generate
    with:
      # Auto-extract version from release
      custom-version: ${{ github.event.release.tag_name }}
      # Force update on releases
      force-update: ${{ github.event_name == 'release' }}
```

### Triage Rules Configuration
```yaml
# .github/config/pr-labeler/triage-rules.yml
priority_rules:
  critical:
    conditions:
      - has_any_labels: ['security', 'hotfix']
    actions:
      - add_labels: ['priority/critical']
```

### Issue Automation Configuration
```yaml
# .github/config/issues/label-actions.yml
support:
  action: close
  comment: |
    Thank you for reaching out! This is a support request.
    Please use our forums or discussions instead.
  close_reason: not_planned

bug-confirmed:
  action: comment
  comment: |
    Bug confirmed! We'll prioritize this for fixing.
  add_labels: ["confirmed", "priority-high"]
  remove_labels: ["needs-triage"]
```

## 🔒 Security Notes

- Never commit sensitive data or secrets
- Use repository secrets for API keys
- Review configurations for security implications
- Keep configurations version controlled

## 🎉 Release Integration Features

### Automatic Documentation Updates
The `documentation.yml` workflow automatically updates README when a new release is created:

- **Automatic Version Detection**: Extracts version from release tag
- **Force Update**: README is always updated on releases
- **Special Commit Messages**: `docs: update README.MD for release v1.2.3 [automated]`
- **Release Details in Summary**: Shows release name, version, and timestamp

### Configuration
No additional configuration needed! The workflow automatically:
1. Detects new releases (`release` event)
2. Extracts version from `github.event.release.tag_name`
3. Updates README with new version
4. Commits changes with release-specific message

## 🛠️ Maintenance

### Adding New Modules
1. Create new subdirectory under `.github/config/`
2. Use clear, descriptive names
3. Document in this README
4. Update workflow defaults

### Deprecating Configurations
1. Move to `deprecated/` subdirectory
2. Update workflows to new paths
3. Document migration path

## 📚 Related Documentation

- [Secrets Reference](../../docs/secrets-reference.md) - All required secrets and tokens
- [Workflow Modules](../workflows/MODULES-README.MD)
- [GitHub Actions](../actions/README.MD)
- [Examples](../../github/workflows/examples/)

---

*Organized configuration structure for better maintainability and clarity.*