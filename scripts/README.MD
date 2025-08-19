# Automation Scripts Collection

**Utility scripts for repository automation and documentation management**

## 📄 Overview

This directory contains essential utility scripts that support repository automation, documentation generation, and release management workflows. These scripts provide the foundation for maintaining consistent and professional repository standards.

## 🛠️ Available Scripts

### Documentation Generation

#### `generate_readme.py`

Professional README generation tool that creates comprehensive documentation from templates and repository metadata.

**Features:**

- Template-based README generation
- Automatic project structure analysis
- Metadata extraction from repository files
- Multi-language support for documentation
- Customizable templates for different project types

**Usage:**

```bash
# Generate README from template
python generate_readme.py --template docs/README.template.MD --output README.MD

# Generate with project analysis
python generate_readme.py --analyze-project --auto-detect

# Custom template with variables
python generate_readme.py --template custom.template --variables config.json
```

**Configuration:**

```json
{
  "template_variables": {
    "project_name": "Automation Templates",
    "description": "Professional automation templates for GitHub workflows",
    "author": "Bauer Group Development Team",
    "license": "MIT",
    "version": "1.0.0"
  },
  "analysis_settings": {
    "scan_dependencies": true,
    "extract_features": true,
    "generate_toc": true,
    "include_badges": true
  }
}
```

### Release Management

#### `universal-release.ps1`

PowerShell-based universal release automation script for Windows environments.

**Features:**

- Cross-platform release management
- Automated version bumping
- Changelog generation
- Asset compilation and packaging
- Multi-format release notes

**Usage:**

```powershell
# Basic release
.\universal-release.ps1 -Version "1.2.3" -Type "minor"

# Full release with assets
.\universal-release.ps1 -Version "2.0.0" -Type "major" -IncludeAssets -GenerateChangelog

# Pre-release
.\universal-release.ps1 -Version "1.2.3-beta.1" -PreRelease -DryRun
```

#### `universal-release.sh`

Cross-platform shell script for Unix/Linux release automation.

**Features:**

- POSIX-compliant shell scripting
- Docker integration for consistent environments
- CI/CD pipeline integration
- Automated testing before release

**Usage:**

```bash
# Standard release
./universal-release.sh --version "1.2.3" --type minor

# Release with testing
./universal-release.sh --version "1.2.3" --test --build-assets

# Docker-based release
./universal-release.sh --version "1.2.3" --docker --push-images
```

## 🔧 Configuration

### Environment Variables

```bash
# General Settings
AUTOMATION_ENV=production                # Environment mode
DEBUG_MODE=false                        # Enable debug output
LOG_LEVEL=INFO                          # Logging level

# GitHub Integration
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxx  # GitHub Personal Access Token
GITHUB_REPOSITORY=owner/repo            # Target repository
GITHUB_API_URL=https://api.github.com   # GitHub API endpoint

# Release Settings
DEFAULT_BRANCH=main                     # Default branch for releases
RELEASE_NOTES_TEMPLATE=.github/release-template.md
VERSION_FILE=package.json               # File containing version information
CHANGELOG_FILE=CHANGELOG.md             # Changelog file location

# Documentation Settings
README_TEMPLATE=docs/README.template.MD # README template file
DOCS_OUTPUT_DIR=docs/generated          # Generated documentation directory
AUTO_UPDATE_TOC=true                    # Automatically update table of contents
```

### Script Configuration Files

#### `readme-config.json`

```json
{
  "template_settings": {
    "source_template": "docs/README.template.MD",
    "output_file": "README.MD",
    "encoding": "utf-8",
    "preserve_custom_sections": true
  },
  "project_analysis": {
    "scan_patterns": ["**/*.md", "**/*.json", "**/*.yml"],
    "exclude_patterns": ["node_modules/**", ".git/**", "vendor/**"],
    "extract_metadata": true,
    "generate_badges": true
  },
  "content_generation": {
    "auto_toc": true,
    "include_installation": true,
    "include_usage": true,
    "include_contributing": true,
    "include_license": true
  }
}
```

#### `release-config.json`

```json
{
  "release_settings": {
    "auto_increment": true,
    "create_tags": true,
    "generate_notes": true,
    "upload_assets": true
  },
  "version_management": {
    "version_files": ["package.json", "setup.py", "Cargo.toml"],
    "version_pattern": "\\d+\\.\\d+\\.\\d+",
    "update_strategy": "semver"
  },
  "asset_management": {
    "build_command": "npm run build",
    "asset_patterns": ["dist/**", "build/**", "*.zip"],
    "compress_assets": true,
    "checksum_files": true
  }
}
```

## 🚀 Quick Start

### Setting Up Documentation Generation

```bash
# Install dependencies
pip install jinja2 pyyaml markdown

# Create template variables
cat > template-vars.json << EOF
{
  "project_name": "My Project",
  "description": "A professional project template",
  "author": "Development Team"
}
EOF

# Generate README
python generate_readme.py --template docs/README.template.MD \
  --variables template-vars.json --output README.MD
```

### Setting Up Release Automation

```bash
# Configure Git
git config user.name "Release Bot"
git config user.email "releases@company.com"

# Set up GitHub token
export GITHUB_TOKEN=ghp_your_token_here

# Run release
./universal-release.sh --version "1.0.0" --type major --dry-run
```

## 🔄 Integration Examples

### GitHub Actions Integration

```yaml
name: Documentation Update

on:
  push:
    branches: [main]
    paths: ['docs/**', 'scripts/**']

jobs:
  update-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: |
          pip install jinja2 pyyaml markdown
          
      - name: Generate README
        run: |
          cd scripts
          python generate_readme.py \
            --template ../docs/README.template.MD \
            --output ../README.MD \
            --auto-analyze
            
      - name: Commit changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add README.MD
          git diff --staged --quiet || git commit -m "docs: update generated README"
          git push
```

### Automated Release Pipeline

```yaml
name: Release Automation

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version'
        required: true
      release_type:
        description: 'Release type'
        type: choice
        options: [patch, minor, major]
        default: 'patch'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Run release script
        run: |
          chmod +x scripts/universal-release.sh
          ./scripts/universal-release.sh \
            --version "${{ github.event.inputs.version }}" \
            --type "${{ github.event.inputs.release_type }}" \
            --github-token "${{ secrets.GITHUB_TOKEN }}"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📊 Advanced Features

### Template Engine

The documentation generator supports advanced templating with:

- **Variable substitution**: Replace placeholders with dynamic content
- **Conditional sections**: Include/exclude content based on conditions
- **Loop constructs**: Generate repetitive content from data
- **Include directives**: Compose documentation from multiple files

### Release Automation

The release scripts provide:

- **Semantic versioning**: Automatic version calculation based on changes
- **Multi-format releases**: Support for different package formats
- **Asset management**: Automated building and uploading of release assets
- **Rollback capabilities**: Safe rollback of failed releases

### CI/CD Integration

Scripts are designed for:

- **Pipeline integration**: Easy integration with CI/CD systems
- **Parallel execution**: Support for parallel processing
- **Error handling**: Robust error handling and recovery
- **Logging and monitoring**: Comprehensive logging for debugging

## 🛡️ Best Practices

### Security

```bash
# Use secure token handling
export GITHUB_TOKEN=$(cat ~/.github-token)

# Validate inputs
./universal-release.sh --validate-only --version "1.2.3"

# Dry-run before actual execution
python generate_readme.py --dry-run --template docs/template.md
```

### Error Handling

```bash
# Enable strict error handling
set -euo pipefail

# Validate prerequisites
./universal-release.sh --check-prerequisites

# Use transaction-like operations
python generate_readme.py --backup-original --rollback-on-error
```

### Performance

```bash
# Use caching for repeated operations
python generate_readme.py --cache-metadata

# Parallel processing for multiple files
./universal-release.sh --parallel --max-workers 4

# Optimize for large repositories
python generate_readme.py --optimize-large-repos
```

## 📈 Monitoring and Logging

### Log Configuration

```bash
# Enable detailed logging
export LOG_LEVEL=DEBUG
export LOG_FILE=/var/log/automation-scripts.log

# Structured logging
export LOG_FORMAT=json
export LOG_INCLUDE_STACKTRACE=true
```

### Metrics Collection

```bash
# Generate metrics report
python generate_readme.py --metrics --output metrics.json

# Performance profiling
./universal-release.sh --profile --output performance-report.html

# Usage analytics
python scripts/analyze-usage.py --period 30d --format dashboard
```

## 🔧 Troubleshooting

### Common Issues

1. **Template not found**: Verify template path and permissions
2. **Version conflicts**: Check version format and existing tags
3. **Permission errors**: Ensure proper GitHub token scopes
4. **Encoding issues**: Verify file encoding matches configuration

### Debug Commands

```bash
# Test template rendering
python generate_readme.py --test-template docs/README.template.MD

# Validate release configuration
./universal-release.sh --validate-config

# Debug mode with verbose output
python generate_readme.py --debug --verbose --template template.md
```

## 📚 Documentation

- [Template Syntax Guide](../docs/template-syntax.md)
- [Release Management Guide](../docs/release-management.md)
- [API Reference](../docs/api-reference.md)
- [Contributing Guidelines](../CONTRIBUTING.md)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation**: [Project Wiki](https://github.com/bauer-group/automation-templates/wiki)
- **Community**: [Discussions](https://github.com/bauer-group/automation-templates/discussions)

---

*These scripts provide the foundation for professional repository automation and documentation management.*
