# 🛒 Shopware 5 Plugin Build System

Complete automation for Shopware 5 plugin development with support for both legacy (v5.0-5.1) and modern (v5.2+) plugin systems.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Plugin System Support](#plugin-system-support)
- [Configuration](#configuration)
- [Workflow Inputs](#workflow-inputs)
- [Secrets](#secrets)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The Shopware 5 Plugin Build System provides comprehensive CI/CD automation for Shopware 5 plugins, including:

- **Automatic plugin system detection** (legacy vs. modern)
- **Build automation** with shopware-cli integration
- **Code quality checks** (PHPUnit, PHPStan, PHP CodeSniffer)
- **Shopware Store integration** (validation, upload, page updates)
- **GitHub release management** with automatic versioning
- **Frontend asset building** with Node.js support
- **Security scanning** and vulnerability checks

## Features

### ✅ Plugin System Support

| Feature | Legacy (v5.0-5.1) | Modern (v5.2+) |
|---------|-------------------|----------------|
| **Structure** | plugin.xml, Bootstrap.php | composer.json, PSR-4 |
| **Directory** | src/Backend/PluginName | src/PluginName |
| **Auto-detection** | ✅ | ✅ |
| **Composer** | ⚠️ Optional | ✅ Required |
| **Store Upload** | ✅ | ✅ |

### 🔧 Build Features

- ✅ **Shopware CLI integration** for plugin building and validation
- ✅ **Composer dependency management** (for modern plugins)
- ✅ **Frontend asset compilation** with Node.js/npm/webpack
- ✅ **Automatic zip generation** for manual installation
- ✅ **Version extraction** from plugin.json/plugin.xml/composer.json
- ✅ **Legacy OpenSSL support** for older build tools

### 🧪 Quality Assurance

- ✅ **PHPUnit tests** with coverage reporting
- ✅ **PHP CodeSniffer** for coding standards
- ✅ **PHPStan** for static analysis
- ✅ **Security vulnerability scanning**
- ✅ **Plugin structure validation**

### 🏪 Shopware Store Integration

- ✅ **Automatic store upload** on new versions
- ✅ **Store page updates** via commit message triggers
- ✅ **Plugin validation** with shopware-cli
- ✅ **Changelog generation** from plugin metadata

### 🚀 Release Management

- ✅ **Automatic GitHub releases**
- ✅ **Git tagging** from plugin version
- ✅ **Changelog generation**
- ✅ **Release asset uploads**

## Quick Start

### 1. Basic Setup

Create `.github/workflows/build.yml` in your plugin repository:

```yaml
name: 🛒 Build Plugin

on:
  push:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    with:
      plugin-system: 'auto'  # Auto-detect legacy or modern
      php-version: '7.4'

      # Testing
      run-tests: true

      # Store integration
      upload-to-store: true

      # GitHub releases
      create-github-release: true

    secrets:
      SHOPWARE_ACCOUNT_EMAIL: ${{ secrets.SHOPWARE_ACCOUNT_EMAIL }}
      SHOPWARE_ACCOUNT_PASSWORD: ${{ secrets.SHOPWARE_ACCOUNT_PASSWORD }}
```

### 2. Configure Secrets

Add these secrets to your GitHub repository:

```bash
gh secret set SHOPWARE_ACCOUNT_EMAIL --body "your-email@example.com"
gh secret set SHOPWARE_ACCOUNT_PASSWORD --body "your-password"
```

### 3. Plugin Structure

#### Legacy Plugin (v5.0-5.1)

```
YourPlugin/
├── src/
│   └── Backend/              # or Frontend/
│       └── YourPluginName/
│           ├── Bootstrap.php
│           ├── Controllers/
│           ├── Models/
│           └── Views/
├── plugin.xml
└── .github/
    └── workflows/
        └── build.yml
```

#### Modern Plugin (v5.2+)

```
YourPlugin/
├── src/
│   └── YourPluginName/
│       ├── YourPluginName.php  # Main plugin class
│       ├── Resources/
│       │   ├── config/
│       │   ├── views/
│       │   └── public/
│       └── Services/
├── composer.json
├── plugin.json (optional)
└── .github/
    └── workflows/
        └── build.yml
```

## Plugin System Support

### Automatic Detection

The workflow automatically detects the plugin system:

```yaml
with:
  plugin-system: 'auto'  # Detects based on file structure
```

Detection logic:
1. If `plugin.xml` exists → **Legacy system**
2. If `composer.json` or `plugin.json` exists → **Modern system**
3. Default → **Modern system**

### Manual Override

Force a specific plugin system:

```yaml
with:
  plugin-system: 'legacy'  # or 'modern'
```

### Directory Structure Conventions

#### Legacy Plugin Paths

```
src/Backend/PluginName/     # Backend plugin
src/Frontend/PluginName/    # Frontend plugin
```

#### Modern Plugin Paths

```
src/PluginName/             # PSR-4 autoloaded plugin
```

## Configuration

### Configuration Templates

Pre-configured templates are available in [`.github/config/shopware5-build/`](../../.github/config/shopware5-build/):

| Template | Description | Best For |
|----------|-------------|----------|
| **default.yml** | Basic configuration with auto-detection | Most plugins |
| **legacy-plugin.yml** | Optimized for v5.0-5.1 plugins | Legacy plugins |
| **modern-plugin.yml** | Optimized for v5.2+ plugins | Modern plugins |
| **store-plugin.yml** | Production-ready store plugins | Store releases |

### Using Configuration Templates

While configuration templates exist for reference, the workflow uses direct input parameters:

```yaml
with:
  # Reference the template configurations in your inputs
  plugin-system: 'auto'
  php-version: '7.4'
  run-tests: true
  # ... more parameters
```

## Workflow Inputs

### Plugin Configuration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `plugin-name` | string | auto | Plugin name (auto-detected) |
| `plugin-system` | string | `auto` | Plugin system: `auto`, `legacy`, `modern` |

### PHP Configuration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `php-version` | string | `7.4` | PHP version to use |

### Shopware CLI

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `shopware-cli-version` | string | `latest` | Shopware CLI version |

### Build Configuration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `build-command` | string | - | Custom build command |
| `node-build` | boolean | `false` | Enable Node.js frontend build |
| `node-version` | string | `18.x` | Node.js version |

### Testing Configuration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `run-tests` | boolean | `true` | Run PHPUnit tests |
| `test-command` | string | - | Custom test command |

### Code Quality

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `run-phpcs` | boolean | `true` | Run PHP CodeSniffer |
| `phpcs-standard` | string | `PSR12` | Coding standard |
| `run-phpstan` | boolean | `true` | Run PHPStan analysis |
| `phpstan-level` | string | `5` | PHPStan level (0-9) |

### Store Integration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `validate-plugin` | boolean | `true` | Validate with shopware-cli |
| `update-store-page` | boolean | `true` | Update on `[store update]` commit |
| `upload-to-store` | boolean | `true` | Upload on new version tags |

### Release Configuration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `create-github-release` | boolean | `true` | Create GitHub releases |
| `auto-tag-version` | boolean | `true` | Auto-create git tags |
| `generate-changelog` | boolean | `true` | Generate changelog |

### Security

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `run-security-check` | boolean | `true` | Run security scan |

### Deployment

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `deploy-to-shop` | boolean | `false` | Deploy to test shop |
| `shop-url` | string | - | Shop URL for deployment |

### Runner Configuration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `runs-on` | string | `ubuntu-latest` | Runner OS |
| `timeout-minutes` | number | `30` | Job timeout |
| `artifact-retention-days` | number | `90` | Artifact retention |

## Secrets

### Required Secrets (for Store Integration)

| Secret | Required | Description |
|--------|----------|-------------|
| `SHOPWARE_ACCOUNT_EMAIL` | For store upload | Shopware account email |
| `SHOPWARE_ACCOUNT_PASSWORD` | For store upload | Shopware account password |

### Optional Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `COMPOSER_AUTH_JSON` | Optional | Composer auth for private packages |
| `SHOP_DEPLOY_TOKEN` | For deployment | Token for shop deployment |

### Setting Up Secrets

```bash
# Required for store upload
gh secret set SHOPWARE_ACCOUNT_EMAIL --body "your-email@example.com"
gh secret set SHOPWARE_ACCOUNT_PASSWORD --body "your-password"

# Optional
gh secret set COMPOSER_AUTH_JSON --body '{"github-oauth": {"github.com": "token"}}'
gh secret set SHOP_DEPLOY_TOKEN --body "your-deploy-token"
```

## Examples

### Simple Legacy Plugin

[See: github/workflows/examples/shopware5-build/simple-legacy-plugin.yml](../../github/workflows/examples/shopware5-build/simple-legacy-plugin.yml)

```yaml
name: Build Legacy Plugin
on:
  push:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    with:
      plugin-system: 'legacy'
      php-version: '7.2'
      run-tests: false
      upload-to-store: true
    secrets:
      SHOPWARE_ACCOUNT_EMAIL: ${{ secrets.SHOPWARE_ACCOUNT_EMAIL }}
      SHOPWARE_ACCOUNT_PASSWORD: ${{ secrets.SHOPWARE_ACCOUNT_PASSWORD }}
```

### Modern Plugin with Frontend Build

[See: github/workflows/examples/shopware5-build/simple-modern-plugin.yml](../../github/workflows/examples/shopware5-build/simple-modern-plugin.yml)

```yaml
name: Build Modern Plugin
on:
  push:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    with:
      plugin-system: 'modern'
      php-version: '7.4'
      node-build: true
      run-tests: true
      run-phpstan: true
      upload-to-store: true
    secrets:
      SHOPWARE_ACCOUNT_EMAIL: ${{ secrets.SHOPWARE_ACCOUNT_EMAIL }}
      SHOPWARE_ACCOUNT_PASSWORD: ${{ secrets.SHOPWARE_ACCOUNT_PASSWORD }}
```

### Store-Ready Plugin

[See: github/workflows/examples/shopware5-build/store-ready-plugin.yml](../../github/workflows/examples/shopware5-build/store-ready-plugin.yml)

```yaml
name: Store Plugin Build
on:
  push:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    with:
      plugin-system: 'auto'
      php-version: '7.4'
      node-build: true

      # Comprehensive testing
      run-tests: true
      run-phpcs: true
      run-phpstan: true
      phpstan-level: '8'

      # Store integration
      validate-plugin: true
      upload-to-store: true
      update-store-page: true

      # Release management
      create-github-release: true
      auto-tag-version: true
      generate-changelog: true

      artifact-retention-days: 365
    secrets:
      SHOPWARE_ACCOUNT_EMAIL: ${{ secrets.SHOPWARE_ACCOUNT_EMAIL }}
      SHOPWARE_ACCOUNT_PASSWORD: ${{ secrets.SHOPWARE_ACCOUNT_PASSWORD }}
```

### Multi-Environment Setup

[See: github/workflows/examples/shopware5-build/multi-environment.yml](../../github/workflows/examples/shopware5-build/multi-environment.yml)

Different configurations for different branches:
- **develop**: Build and test only
- **staging**: Build, test, deploy to staging
- **main**: Full pipeline with store upload

## Best Practices

### 1. Version Management

**Always maintain version in plugin metadata:**

Legacy plugin (`plugin.xml`):
```xml
<?xml version="1.0" encoding="utf-8"?>
<plugin xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <label>Your Plugin Name</label>
    <version>1.2.3</version>
    <!-- ... -->
</plugin>
```

Modern plugin (`plugin.json`):
```json
{
  "name": "YourPluginName",
  "version": "1.2.3",
  "label": {
    "de": "Dein Plugin Name",
    "en": "Your Plugin Name"
  }
}
```

Or in `composer.json`:
```json
{
  "name": "your-vendor/your-plugin",
  "version": "1.2.3",
  "type": "shopware-plugin"
}
```

### 2. Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.0.1): Bug fixes

### 3. Store Page Updates

Trigger store page updates with commit message:
```bash
git commit -m "docs: update store description [store update]"
```

### 4. Testing

Always include PHPUnit tests:

```php
<?php
// tests/PluginTest.php
namespace YourPlugin\Tests;

use PHPUnit\Framework\TestCase;

class PluginTest extends TestCase
{
    public function testPluginIsAvailable()
    {
        $this->assertTrue(true);
    }
}
```

### 5. Code Quality

Use PHPStan configuration (`phpstan.neon`):
```yaml
parameters:
  level: 7
  paths:
    - src
  excludePaths:
    - vendor
```

### 6. Security

- Never commit credentials
- Use GitHub secrets for sensitive data
- Enable security scanning
- Keep dependencies updated

### 7. Frontend Assets

For modern plugins with frontend builds:

`package.json`:
```json
{
  "scripts": {
    "build": "webpack --mode production",
    "build:staging": "webpack --mode development",
    "watch": "webpack --mode development --watch"
  }
}
```

Workflow configuration:
```yaml
with:
  node-build: true
  build-command: 'npm run build'
```

## Troubleshooting

### Common Issues

#### 1. Plugin Not Detected

**Problem**: Workflow can't detect plugin name or version

**Solutions**:
- Ensure `plugin.json`, `plugin.xml`, or `composer.json` exists
- Verify version field is present
- Manually specify plugin name:
  ```yaml
  with:
    plugin-name: 'YourPluginName'
  ```

#### 2. Store Upload Fails

**Problem**: Upload to Shopware store fails

**Solutions**:
- Verify account credentials are correct
- Check plugin passes validation: `shopware-cli extension validate plugin.zip`
- Ensure version doesn't already exist in store
- Review store account permissions

#### 3. Build Fails with "GLIBC not found"

**Problem**: Node.js build fails with GLIBC errors

**Solution**: Use legacy OpenSSL provider:
```yaml
with:
  node-build: true
  build-command: 'NODE_OPTIONS=--openssl-legacy-provider npm run build'
```

#### 4. Composer Authentication Failed

**Problem**: Can't install private Composer packages

**Solution**: Add Composer auth secret:
```bash
gh secret set COMPOSER_AUTH_JSON --body '{
  "github-oauth": {
    "github.com": "your-token"
  }
}'
```

#### 5. PHPUnit Not Found

**Problem**: Tests fail because PHPUnit is not installed

**Solutions**:
- Add PHPUnit to `composer.json`:
  ```json
  {
    "require-dev": {
      "phpunit/phpunit": "^9.5"
    }
  }
  ```
- Or disable tests:
  ```yaml
  with:
    run-tests: false
  ```

#### 6. Version Tag Already Exists

**Problem**: GitHub release fails because tag exists

**Solution**: This is expected behavior - the workflow won't create duplicate releases. Update version number in plugin metadata.

### Debug Mode

Enable debug output:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    with:
      # ... your configuration

env:
  ACTIONS_RUNNER_DEBUG: true
  ACTIONS_STEP_DEBUG: true
```

### Getting Help

1. **Check workflow logs** in GitHub Actions
2. **Review examples** in [github/workflows/examples/shopware5-build/](../../github/workflows/examples/shopware5-build/)
3. **Open an issue** with:
   - Workflow configuration
   - Error messages
   - Plugin structure
   - Expected vs actual behavior

## Workflow Outputs

The workflow provides these outputs:

```yaml
outputs:
  plugin-version: ${{ jobs.build.outputs.plugin-version }}
  zip-filename: ${{ jobs.build.outputs.zip-filename }}
  release-created: ${{ jobs.build.outputs.release-created }}
  store-uploaded: ${{ jobs.build.outputs.store-uploaded }}
```

Use outputs in subsequent jobs:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    # ... configuration

  notify:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Notify
        run: |
          echo "Version: ${{ needs.build.outputs.plugin-version }}"
          echo "Zip: ${{ needs.build.outputs.zip-filename }}"
```

## Related Documentation

- [PHP Build System](php-build.md)
- [Node.js Build System](nodejs-build.md)
- [Security Scanning](../actions/security-scan/README.md)
- [Secrets Naming Convention](../SECRETS-NAMING-CONVENTION.md)

## References

- [Shopware 5 Plugin Guide](https://developers.shopware.com/developers-guide/plugin-guide/)
- [Shopware CLI Documentation](https://sw-cli.fos.gg/)
- [FriendsOfShopware Actions](https://github.com/FriendsOfShopware/actions)
- [Shopware Store](https://store.shopware.com/)

---

**Need help?** [Open an issue](https://github.com/bauer-group/automation-templates/issues/new?template=WORKFLOW_SUPPORT.MD) with the `shopware5-build` label.
