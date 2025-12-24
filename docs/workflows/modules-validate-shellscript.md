# Shell Script Validation Module

Validates shell scripts using ShellCheck for syntax errors, best practices, and potential bugs.

## Overview

This reusable workflow module provides:

- **Static Analysis**: Comprehensive shell script linting with ShellCheck
- **Automatic Detection**: Finds shell scripts by extension and shebang
- **Configurable Severity**: Filter by error, warning, info, or style issues
- **Multiple Dialect Support**: Validate sh, bash, dash, or ksh scripts
- **Flexible Exclusions**: Ignore specific codes, patterns, or directories

## Quick Start

### Basic Usage

```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:

jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
```

### With Custom Configuration

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      scan-directory: 'scripts/'
      severity: 'warning'
      shell-dialect: 'bash'
```

## Input Parameters

### Scan Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scan-directory` | Directory to scan for shell scripts | `'.'` |
| `scan-paths` | Specific paths as JSON array | `''` |
| `additional-files` | Extra file patterns as JSON array | `''` |

### Severity & Filtering

| Parameter | Description | Default |
|-----------|-------------|---------|
| `severity` | Minimum level: `error`, `warning`, `info`, `style` | `'warning'` |
| `exclude-patterns` | Patterns to exclude as JSON array | `''` |
| `exclude-codes` | ShellCheck codes to ignore as JSON array | `''` |

### Shell Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `shell-dialect` | Shell to check: `sh`, `bash`, `dash`, `ksh`, `auto` | `'auto'` |
| `external-sources` | Follow source statements | `true` |
| `enable-optional` | Optional checks as JSON array | `''` |

### Output & Behavior

| Parameter | Description | Default |
|-----------|-------------|---------|
| `format` | Output format: `tty`, `checkstyle`, `json`, `gcc`, `quiet` | `'tty'` |
| `fail-on-findings` | Fail workflow if issues found | `true` |
| `runs-on` | Runner OS | `'ubuntu-latest'` |

## Outputs

| Output | Description |
|--------|-------------|
| `passed` | Whether all scripts passed (`'true'`/`'false'`) |
| `files-checked` | Number of files analyzed |
| `issues-found` | Total number of issues |
| `error-count` | Number of errors found |
| `warning-count` | Number of warnings found |

## Examples

### Example 1: Simple Validation

Scan entire repository for shell scripts:

```yaml
name: CI

on: [push, pull_request]

jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
```

### Example 2: Specific Directories

Scan only certain directories:

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      scan-paths: '["scripts/", "bin/", "tools/"]'
```

### Example 3: Exclude Vendor Files

Skip third-party or generated scripts:

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      exclude-patterns: '["vendor/*", "node_modules/*", "*.generated.sh"]'
```

### Example 4: Ignore Specific Codes

Suppress known acceptable warnings:

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      exclude-codes: '["SC1091", "SC2034", "SC2155"]'
```

Common codes to exclude:
- `SC1091` - Not following sourced files
- `SC2034` - Variable appears unused
- `SC2155` - Declare and assign separately

### Example 5: Strict Mode

Enable maximum strictness with optional checks:

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      severity: 'style'
      enable-optional: '["require-variable-braces", "check-unassigned-uppercase"]'
      fail-on-findings: true
```

Optional checks include:
- `require-variable-braces` - Require `${var}` instead of `$var`
- `check-unassigned-uppercase` - Warn on unassigned uppercase variables
- `avoid-nullary-conditions` - Suggest explicit comparisons

### Example 6: Check Additional File Types

Include template or config files with shell syntax:

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      additional-files: '["*.sh.tpl", "*.sh.j2", "Makefile.include"]'
```

### Example 7: Warnings Only (Non-Blocking)

Report issues without failing the build:

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      severity: 'info'
      fail-on-findings: false
```

### Example 8: Integration with Docker Compose Validation

Complete validation workflow for Docker Compose projects:

```yaml
name: Release

on:
  push:
    branches: [main]
    paths-ignore:
      - '*.md'
      - 'docs/**'

jobs:
  validate-compose:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker-compose.yml'
      env-template: '{"DB_PASSWORD": "test", "API_KEY": "test"}'

  validate-scripts:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      scan-directory: '.'
      severity: 'warning'
      exclude-patterns: '["vendor/*"]'

  release:
    needs: [validate-compose, validate-scripts]
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
    secrets: inherit
```

### Example 9: Using Outputs

```yaml
jobs:
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main

  report:
    needs: shellcheck
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Report Results
        run: |
          echo "Validation passed: ${{ needs.shellcheck.outputs.passed }}"
          echo "Files checked: ${{ needs.shellcheck.outputs.files-checked }}"
          echo "Issues found: ${{ needs.shellcheck.outputs.issues-found }}"
          echo "  Errors: ${{ needs.shellcheck.outputs.error-count }}"
          echo "  Warnings: ${{ needs.shellcheck.outputs.warning-count }}"

      - name: Fail on Errors Only
        if: needs.shellcheck.outputs.error-count != '0'
        run: exit 1
```

## Severity Levels

| Level | Description | Example |
|-------|-------------|---------|
| `error` | Definite bugs or syntax errors | Missing quotes around variables with spaces |
| `warning` | Likely issues or bad practices | Using deprecated syntax |
| `info` | Suggestions for improvement | Consider using `[[ ]]` instead of `[ ]` |
| `style` | Pure style suggestions | Prefer `$(cmd)` over backticks |

## Common ShellCheck Codes

### Frequently Excluded

| Code | Description | Why Exclude |
|------|-------------|-------------|
| `SC1091` | Not following sourced files | CI can't access all includes |
| `SC2034` | Variable appears unused | May be used by sourced scripts |
| `SC2086` | Quote to prevent splitting | Sometimes intentional |
| `SC2155` | Declare and assign separately | Style preference |

### Important to Keep

| Code | Description | Impact |
|------|-------------|--------|
| `SC2006` | Use `$()` instead of backticks | Deprecation |
| `SC2046` | Quote to prevent word splitting | Security |
| `SC2068` | Double quote array expansions | Correctness |
| `SC2129` | Group commands for efficiency | Performance |

## Best Practices

### 1. Start with Warnings

Begin with `severity: warning` and tighten over time:

```yaml
severity: 'warning'
```

### 2. Document Exclusions

When excluding codes, document why:

```yaml
# SC1091: External config sourced at runtime
# SC2034: Variables used by deployment scripts
exclude-codes: '["SC1091", "SC2034"]'
```

### 3. Use Shebang

Always include a shebang for proper dialect detection:

```bash
#!/usr/bin/env bash
# or
#!/bin/bash
```

### 4. Enable External Sources

Allow ShellCheck to follow sourced files when possible:

```yaml
external-sources: true
```

### 5. Progressive Strictness

For new projects, enable strict mode:

```yaml
severity: 'style'
enable-optional: '["require-variable-braces"]'
```

## Troubleshooting

### No Shell Scripts Found

If validation reports 0 files:

1. Check `scan-directory` or `scan-paths` are correct
2. Ensure scripts have `.sh` extension or proper shebang
3. Verify `exclude-patterns` isn't too broad

### False Positives on Sourced Files

If SC1091 errors on legitimate includes:

```yaml
exclude-codes: '["SC1091"]'
```

Or ensure sourced files are in the repository.

### Different Results Locally

Ensure local ShellCheck version matches CI. The module uses the latest available version.

## Related Modules

- [modules-validate-compose.yml](./modules-validate-compose.md) - Validate Docker Compose files
- [modules-semantic-release.yml](./modules-semantic-release.md) - Create semantic releases
- [modules-pr-validation.yml](./modules-pr-validation.md) - Validate pull requests

## References

- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [ShellCheck Error Codes](https://www.shellcheck.net/wiki/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

## Support

- **Issues**: Report problems in the automation-templates repository
- **Documentation**: See examples in this document
- **Contributing**: Follow repository contribution guidelines
