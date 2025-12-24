# Docker Compose Validation Module

Validates Docker Compose configuration files for syntax errors, service definitions, and optional image reference checks.

## Overview

This reusable workflow module provides:

- **Syntax Validation**: Ensures `docker-compose.yml` is valid YAML and Docker Compose syntax
- **Service Discovery**: Extracts and reports all defined services
- **Environment Handling**: Auto-generates dummy `.env` files for validation when originals contain secrets
- **Multiple File Support**: Validates single or multiple compose files
- **Image Reference Checking**: Optional verification that referenced images exist

## Quick Start

### Basic Usage

```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:

jobs:
  validate-compose:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
```

### With Custom Compose File

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker/docker-compose.prod.yml'
```

### With Environment Template

For projects that require environment variables but shouldn't expose real values in CI:

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker-compose.yml'
      env-template: |
        {
          "DB_PASSWORD": "test",
          "API_KEY": "test-key",
          "SECRET_TOKEN": "dummy-token"
        }
```

## Input Parameters

### File Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `compose-file` | Path to Docker Compose file | `'docker-compose.yml'` |
| `compose-files` | Multiple compose files as JSON array | `''` |
| `working-directory` | Working directory for validation | `'.'` |

### Environment Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env-file` | Path to existing `.env` file | `''` |
| `env-template` | Environment variables as JSON object for dummy generation | `''` |
| `create-dummy-env` | Auto-create dummy `.env` with placeholder values | `true` |

### Validation Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `fail-on-warning` | Fail validation on warnings (not just errors) | `false` |
| `validate-services` | Required services as JSON array | `''` |
| `check-image-references` | Verify referenced images exist in registries | `false` |

### Runner Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `runs-on` | Runner OS | `'ubuntu-latest'` |

## Outputs

| Output | Description |
|--------|-------------|
| `valid` | Whether the compose file(s) are valid (`'true'`/`'false'`) |
| `services` | Comma-separated list of services found |
| `service-count` | Number of services defined |
| `warnings` | Validation warnings (if any) |

## Examples

### Example 1: Simple Validation

Validate a standard `docker-compose.yml` in the repository root:

```yaml
name: CI

on: [push, pull_request]

jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
```

### Example 2: Multiple Compose Files

Validate a base file with environment-specific overrides:

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-files: '["docker-compose.yml", "docker-compose.override.yml"]'
```

### Example 3: With Required Services Check

Ensure specific services are defined:

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker-compose.yml'
      validate-services: '["app", "db", "redis"]'
```

### Example 4: Full Validation with Image Check

Complete validation including image reference verification:

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker-compose.yml'
      env-template: |
        {
          "MYSQL_ROOT_PASSWORD": "test",
          "MYSQL_DATABASE": "testdb",
          "APP_SECRET": "test-secret"
        }
      validate-services: '["app", "mysql", "nginx"]'
      check-image-references: true
      fail-on-warning: true
```

### Example 5: Integration with Semantic Release

Use with other modules for a complete release workflow:

```yaml
name: Release

on:
  push:
    branches: [main]

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

  release:
    needs: [validate-compose, validate-scripts]
    if: needs.validate-compose.outputs.valid == 'true' && needs.validate-scripts.outputs.passed == 'true'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
    secrets: inherit
```

### Example 6: Using Outputs for Conditional Logic

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker-compose.yml'

  report:
    needs: validate
    runs-on: ubuntu-latest
    steps:
      - name: Report Results
        run: |
          echo "Validation passed: ${{ needs.validate.outputs.valid }}"
          echo "Services found: ${{ needs.validate.outputs.services }}"
          echo "Service count: ${{ needs.validate.outputs.service-count }}"

      - name: Check for Database
        if: contains(needs.validate.outputs.services, 'db')
        run: echo "Database service is configured"
```

## Environment Variable Handling

The module intelligently handles environment variables required by your compose files:

### Automatic Detection

When `create-dummy-env: true` (default), the module:

1. Scans your compose file for `${VARIABLE}` patterns
2. Detects `${VARIABLE:-default}` with default values
3. Creates placeholder values for validation

### Manual Template

Provide explicit values with `env-template`:

```yaml
env-template: |
  {
    "DATABASE_URL": "postgres://user:pass@db:5432/app",
    "REDIS_URL": "redis://redis:6379",
    "SECRET_KEY": "dummy-secret-for-validation"
  }
```

### Using Existing File

Reference an existing (non-secret) env file:

```yaml
env-file: '.env.example'
```

## Best Practices

### 1. Always Validate in CI

Add compose validation to your CI pipeline to catch issues early:

```yaml
on:
  pull_request:
    paths:
      - 'docker-compose*.yml'
      - 'Dockerfile*'
```

### 2. Use Environment Templates

Never commit real secrets. Use `env-template` for validation:

```yaml
env-template: '{"API_KEY": "test", "DB_PASSWORD": "test"}'
```

### 3. Validate Required Services

Ensure critical services are always defined:

```yaml
validate-services: '["app", "db"]'
```

### 4. Check Image References for Production

Enable image checking before releases:

```yaml
check-image-references: true
```

## Troubleshooting

### "Variable not set" Errors

If validation fails with undefined variable errors:

1. Enable `create-dummy-env: true` (default)
2. Or provide explicit values via `env-template`
3. Or reference an example env file via `env-file`

### Multiple Compose Files Not Merging

Ensure files are specified in the correct order (base first):

```yaml
compose-files: '["docker-compose.yml", "docker-compose.prod.yml"]'
```

### Image Reference Check Failures

Private registry images may fail verification. This is expected:

- Public images on Docker Hub should pass
- Private/build-time images will show warnings
- The workflow continues unless critical errors occur

## Related Modules

- [modules-validate-shellscript.yml](./modules-validate-shellscript.md) - Validate shell scripts with ShellCheck
- [modules-semantic-release.yml](./modules-semantic-release.md) - Create semantic releases
- [docker-build.yml](./docker-build.md) - Build and push Docker images

## Support

- **Issues**: Report problems in the automation-templates repository
- **Documentation**: See examples in this document
- **Contributing**: Follow repository contribution guidelines
