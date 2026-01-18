# 🐘 PHP Build Workflow Documentation

## Overview

The PHP Build workflow provides a comprehensive, reusable CI/CD pipeline for PHP applications using Composer. It supports multiple PHP versions, frameworks (Laravel, Symfony, Laminas), testing frameworks, code quality tools, and deployment options.

## Features

### Core Capabilities
- ✅ **Multi-version PHP support** (8.0 - 8.3)
- ✅ **Composer dependency management**
- ✅ **Framework support** (Laravel, Symfony, Laminas)
- ✅ **Comprehensive testing** (PHPUnit with coverage)
- ✅ **Code quality tools** (PHPStan, Psalm, PHPCS, PHPMD)
- ✅ **Security vulnerability scanning**
- ✅ **Docker containerization**
- ✅ **Multiple deployment targets**
- ✅ **Matrix builds** for testing across versions

### Supported Tools
- **Testing**: PHPUnit 9.x/10.x
- **Static Analysis**: PHPStan, Psalm
- **Code Style**: PHP CodeSniffer, PHP CS Fixer
- **Security**: Local PHP Security Checker
- **Coverage**: Xdebug, PCOV
- **Frameworks**: Laravel, Symfony, Laminas

## Quick Start

### Basic Usage

```yaml
name: PHP CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
    with:
      php-version: '8.2'
      run-tests: true
      run-phpcs: true
      run-phpstan: true
```

### Laravel Application

```yaml
jobs:
  laravel:
    uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
    with:
      php-version: '8.2'
      framework: 'laravel'
      run-migrations: true
      run-tests: true
      coverage: 'pcov'
      test-coverage-threshold: 80
```

## Configuration

### Input Parameters

#### PHP Configuration

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `php-version` | PHP version(s) to use | `'8.2'` | `'8.0'`, `'8.1'`, `'8.2'`, `'8.3'` |
| `extensions` | PHP extensions to install | `'mbstring, xml, curl, zip, intl, gd, mysql, redis'` | Any valid PHP extension |
| `ini-values` | PHP ini values | `'error_reporting=E_ALL, display_errors=On, memory_limit=256M'` | Key=value pairs |
| `coverage` | Code coverage driver | `'none'` | `'none'`, `'xdebug'`, `'pcov'` |

#### Composer Configuration

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `composer-version` | Composer version | `'latest'` | `'latest'`, `'preview'`, `'snapshot'`, `'1'`, `'2'` |
| `dependency-versions` | Dependency versions to use | `'locked'` | `'lowest'`, `'locked'`, `'highest'` |
| `composer-options` | Additional composer options | `'--prefer-dist --no-progress --no-interaction'` | Any composer flags |
| `validate-strict` | Use strict validation | `true` | `true`, `false` |

#### Testing Configuration

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `run-tests` | Run PHPUnit tests | `true` | `true`, `false` |
| `test-suite` | PHPUnit test suite to run | `''` | Suite name from phpunit.xml |
| `test-coverage-threshold` | Minimum coverage percentage | `0` | `0-100` |

#### Code Quality

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `run-phpcs` | Run PHP CodeSniffer | `true` | `true`, `false` |
| `phpcs-standard` | Coding standard | `'PSR12'` | `'PSR12'`, `'PSR2'`, `'PSR1'`, custom |
| `run-phpstan` | Run PHPStan | `true` | `true`, `false` |
| `phpstan-level` | PHPStan level | `'5'` | `'0-9'`, `'max'` |
| `run-psalm` | Run Psalm | `false` | `true`, `false` |
| `psalm-level` | Psalm error level | `'3'` | `'1-8'` |
| `run-phpmd` | Run PHP Mess Detector | `false` | `true`, `false` |
| `phpmd-ruleset` | PHPMD rules | `'cleancode,codesize,controversial,design,naming,unusedcode'` | Ruleset names |

#### Security

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `run-security-check` | Run security check | `true` | `true`, `false` |
| `fail-on-security-issues` | Fail on vulnerabilities | `true` | `true`, `false` |

#### Framework Specific

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `framework` | PHP framework | `'none'` | `'none'`, `'laravel'`, `'symfony'`, `'laminas'` |
| `run-migrations` | Run database migrations | `false` | `true`, `false` |

### Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `COMPOSER_AUTH_JSON` | Composer auth.json for private packages | No |
| `PHP_DEPLOY_KEY` | SSH key for deployment | No |
| `PHP_FTP_PASSWORD` | FTP password for deployment | No |
| `DOCKER_REGISTRY_USERNAME` | Docker registry username | No |
| `DOCKER_REGISTRY_PASSWORD` | Docker registry password | No |
| `CODECOV_TOKEN` | Codecov token | No |
| `SONARCLOUD_TOKEN` | SonarCloud token | No |

### Platform Configuration

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `runs-on` | Runner to use | `ubuntu-latest` | String or JSON array (see below) |
| `timeout-minutes` | Job timeout | `30` | Minutes |

#### Self-Hosted Runner Support

The `runs-on` parameter supports both GitHub-hosted and self-hosted runners:

```yaml
# GitHub-hosted (string)
runs-on: 'ubuntu-latest'

# Self-hosted (JSON array)
runs-on: '["self-hosted", "linux"]'
runs-on: '["self-hosted", "linux", "docker"]'
```

See [Self-Hosted Runner Documentation](../self-hosted-runners.md) for details.

### Outputs

| Output | Description |
|--------|-------------|
| `build-status` | Overall build status (`success` or `failure`) |
| `test-results` | Test results summary |
| `coverage-percentage` | Code coverage percentage |
| `quality-score` | Code quality score (0-100) |
| `docker-image` | Docker image tag if built |

## Advanced Examples

### Matrix Testing

Test across multiple PHP versions and dependency sets:

```yaml
jobs:
  test-matrix:
    strategy:
      matrix:
        php: ['8.0', '8.1', '8.2', '8.3']
        dependencies: ['lowest', 'locked', 'highest']
    uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
    with:
      php-version: ${{ matrix.php }}
      dependency-versions: ${{ matrix.dependencies }}
      run-tests: true
      coverage: ${{ matrix.php == '8.2' && 'pcov' || 'none' }}
```

### Docker Build and Push

```yaml
jobs:
  docker:
    uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
    with:
      php-version: '8.2'
      build-docker: true
      docker-image-name: 'my-php-app'
      docker-registry: 'ghcr.io/${{ github.repository_owner }}'
    secrets:
      DOCKER_REGISTRY_USERNAME: ${{ github.actor }}
      DOCKER_REGISTRY_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
```

### Full CI/CD Pipeline

```yaml
name: Complete PHP CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  release:
    types: [published]

jobs:
  test:
    uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
    with:
      php-version: '8.2'
      framework: 'laravel'
      run-tests: true
      coverage: 'pcov'
      test-coverage-threshold: 80
      run-phpcs: true
      run-phpstan: true
      phpstan-level: 'max'
      run-security-check: true
      upload-artifacts: true

  deploy:
    if: github.ref == 'refs/heads/main'
    needs: test
    uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
    with:
      php-version: '8.2'
      framework: 'laravel'
      run-tests: false
      deploy-to: 'aws'
      deploy-path: '/var/www/production'
    secrets:
      PHP_DEPLOY_KEY: ${{ secrets.PRODUCTION_DEPLOY_KEY }}
```

## Configuration Files

### Composer Configuration

Place in `.github/config/php-build/composer-config.json`:

```json
{
  "require-dev": {
    "phpunit/phpunit": "^10.0",
    "squizlabs/php_codesniffer": "^3.7",
    "phpstan/phpstan": "^1.10"
  },
  "scripts": {
    "test": "phpunit",
    "cs": "phpcs --standard=PSR12 src/",
    "stan": "phpstan analyse --level=5 src/"
  }
}
```

### PHPUnit Configuration

Place in `.github/config/php-build/phpunit.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit bootstrap="vendor/autoload.php" colors="true">
    <testsuites>
        <testsuite name="Unit">
            <directory>tests/Unit</directory>
        </testsuite>
    </testsuites>
    <coverage>
        <include>
            <directory suffix=".php">src</directory>
        </include>
    </coverage>
</phpunit>
```

### PHPStan Configuration

Place in `.github/config/php-build/phpstan.neon`:

```neon
parameters:
    level: 5
    paths:
        - src
        - app
    excludePaths:
        - vendor
```

## Framework-Specific Setup

### Laravel

```yaml
with:
  framework: 'laravel'
  extensions: 'mbstring, xml, curl, zip, intl, gd, mysql, redis, bcmath'
  run-migrations: true
  # Laravel will automatically:
  # - Copy .env.example to .env
  # - Generate application key
  # - Clear and cache config
  # - Run migrations if enabled
```

### Symfony

```yaml
with:
  framework: 'symfony'
  extensions: 'mbstring, xml, curl, zip, intl, gd, mysql, redis, apcu, opcache'
  run-migrations: true
  # Symfony will automatically:
  # - Clear cache
  # - Run Doctrine migrations if enabled
```

## Best Practices

### 1. Use Matrix Builds for Libraries

```yaml
strategy:
  matrix:
    php: ['8.0', '8.1', '8.2', '8.3']
    dependencies: ['lowest', 'highest']
```

### 2. Enable Coverage for Main Branch

```yaml
coverage: ${{ github.ref == 'refs/heads/main' && 'pcov' || 'none' }}
test-coverage-threshold: 80
```

### 3. Separate CI and CD Jobs

```yaml
jobs:
  ci:
    uses: ./.github/workflows/php-build.yml@main
    with:
      run-tests: true
      run-phpcs: true
      run-phpstan: true
      
  cd:
    needs: ci
    if: github.ref == 'refs/heads/main'
    uses: ./.github/workflows/php-build.yml@main
    with:
      run-tests: false
      deploy-to: 'production'
```

### 4. Cache Dependencies

```yaml
with:
  cache-dependencies: true  # Enabled by default
```

### 5. Security Scanning

Always enable security scanning for production deployments:

```yaml
with:
  run-security-check: true
  fail-on-security-issues: true
```

## Troubleshooting

### Common Issues

#### 1. Composer Memory Limit

```yaml
with:
  ini-values: 'memory_limit=512M'
```

#### 2. Missing PHP Extensions

```yaml
with:
  extensions: 'mbstring, xml, curl, zip, intl, gd, mysql, redis, bcmath, soap'
```

#### 3. Private Packages

```yaml
secrets:
  COMPOSER_AUTH_JSON: |
    {
      "github-oauth": {
        "github.com": "${{ secrets.GITHUB_TOKEN }}"
      }
    }
```

#### 4. Timeout Issues

```yaml
with:
  timeout-minutes: 45  # Increase for large test suites
```

## Performance Optimization

### 1. Use PCOV for Coverage

PCOV is faster than Xdebug for code coverage:

```yaml
with:
  coverage: 'pcov'  # Instead of 'xdebug'
```

### 2. Parallel Testing

For large test suites, consider splitting tests:

```yaml
strategy:
  matrix:
    test-suite: ['Unit', 'Feature', 'Integration']
with:
  test-suite: ${{ matrix.test-suite }}
```

### 3. Optimize Composer

```yaml
with:
  composer-options: '--prefer-dist --no-progress --no-interaction --optimize-autoloader'
```

## Migration Guide

### From Basic GitHub Actions

Before:
```yaml
- uses: shivammathur/setup-php@v2
  with:
    php-version: '8.2'
- run: composer install
- run: vendor/bin/phpunit
```

After:
```yaml
uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
with:
  php-version: '8.2'
  run-tests: true
```

### From Travis CI

Replace `.travis.yml`:
```yaml
language: php
php:
  - 8.1
  - 8.2
script:
  - composer install
  - vendor/bin/phpunit
```

With workflow:
```yaml
uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main
with:
  enable-matrix: true
  php-version: '8.1,8.2'
  run-tests: true
```

## Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Examples**: [PHP Build Examples](https://github.com/bauer-group/automation-templates/tree/main/github/workflows/examples/php-build)
- **Config Templates**: [PHP Build Config](https://github.com/bauer-group/automation-templates/tree/main/.github/config/php-build)