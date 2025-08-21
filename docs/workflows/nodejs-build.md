# 📦 Node.js Build & Publish Workflow

## Overview

The **`Node.js Build & Publish`** workflow is a comprehensive, reusable GitHub Actions workflow for building, testing, and publishing Node.js applications and packages. It supports multiple package managers, various project types, and includes extensive configuration options for modern JavaScript/TypeScript development.

## Features

### Core Capabilities
- ✅ **Node.js 20 LTS**: Optimized for Node.js 20 with support for 18.x, 20.x, 22.x
- ✅ **Multiple Package Managers**: npm, yarn, pnpm, bun (auto-detection)
- ✅ **Project Types**: Libraries, React, Next.js, Express, Monorepos
- ✅ **Matrix Builds**: Parallel builds across OS and Node.js versions
- ✅ **Publishing**: NPM, GitHub Packages, Docker registries
- ✅ **Testing**: Unit, integration, E2E, coverage reporting
- ✅ **Code Quality**: Linting, formatting, type checking, security audits

### Advanced Features
- 🚀 **Monorepo Support**: Lerna, Nx, Rush, Turborepo, pnpm workspaces
- 📊 **Bundle Analysis**: Size limits, performance budgets
- 🔒 **Security Scanning**: Dependency audits, vulnerability checks
- 🐳 **Docker Support**: Multi-stage builds, registry publishing
- 📈 **Coverage Reports**: Multiple formats, threshold enforcement
- ⚡ **Caching**: Dependencies, build outputs, custom paths

## Quick Start

### Basic Usage

```yaml
name: Build Node.js Project

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      node-version: '20.x'
      package-manager: 'npm'
      run-tests: true
      run-lint: true
      upload-artifacts: true
```

### Advanced Configuration

```yaml
jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      # Node.js Configuration
      node-version: '20.x'
      package-manager: 'pnpm'
      
      # Build Settings
      build-command: 'npm run build'
      build-env: 'production'
      
      # Testing
      run-tests: true
      test-coverage: true
      coverage-threshold: 80
      
      # Code Quality
      run-lint: true
      run-typecheck: true
      run-format-check: true
      
      # Security
      run-audit: true
      audit-level: 'moderate'
      
      # Bundle Analysis
      analyze-bundle: true
      max-bundle-size: 500
      
      # Publishing
      publish-package: true
      publish-registry: 'npm'
      
      # Docker
      build-docker: true
      
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      DOCKER_USERNAME: ${{ secrets.DOCKER_USER }}
      DOCKER_PASSWORD: ${{ secrets.DOCKER_PASS }}
```

## Configuration Options

### Node.js Configuration

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `node-version` | Node.js version(s) | `20.x` | `18.x`, `20.x`, `22.x` |
| `node-version-file` | Path to .nvmrc/.node-version | `''` | File path |

### Package Manager

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `package-manager` | Package manager | Auto-detect | `npm`, `yarn`, `pnpm`, `bun` |
| `package-manager-version` | PM version | Latest | Version string |
| `frozen-lockfile` | Use frozen lockfile | `true` | `true`, `false` |

### Build Configuration

| Input | Description | Default |
|-------|-------------|---------|
| `working-directory` | Working directory | `.` |
| `build-command` | Build command | `''` |
| `build-env` | Build environment | `production` |
| `install-command` | Custom install command | Auto-detect |

### Testing

| Input | Description | Default |
|-------|-------------|---------|
| `run-tests` | Run tests | `true` |
| `test-command` | Test command | Auto-detect |
| `test-coverage` | Collect coverage | `false` |
| `coverage-command` | Coverage command | Auto-detect |
| `coverage-threshold` | Min coverage % | `0` |

### Code Quality

| Input | Description | Default |
|-------|-------------|---------|
| `run-lint` | Run linting | `false` |
| `lint-command` | Lint command | Auto-detect |
| `run-format-check` | Check formatting | `false` |
| `format-command` | Format command | Auto-detect |
| `run-typecheck` | TypeScript check | `false` |
| `typecheck-command` | Type check command | Auto-detect |

### Security

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `run-audit` | Security audit | `true` | `true`, `false` |
| `audit-level` | Audit level | `moderate` | `low`, `moderate`, `high`, `critical` |

### Bundle Analysis

| Input | Description | Default |
|-------|-------------|---------|
| `analyze-bundle` | Analyze bundle | `false` |
| `bundle-command` | Analysis command | Auto-detect |
| `max-bundle-size` | Max size (KB) | `0` |

### Publishing

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `publish-package` | Publish package | `false` | `true`, `false` |
| `publish-registry` | Registry | `npm` | `npm`, `github`, `custom` |
| `registry-url` | Custom registry URL | `''` | URL |
| `publish-tag` | NPM dist-tag | `latest` | `latest`, `beta`, `next` |
| `publish-access` | Access level | `public` | `public`, `restricted` |
| `dry-run` | Dry run | `false` | `true`, `false` |

### Version Management

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `version-strategy` | Version strategy | `manual` | `manual`, `auto`, `semantic` |
| `version` | Explicit version | `''` | Version string |
| `prerelease` | Prerelease | `false` | `true`, `false` |
| `prerelease-identifier` | Prerelease ID | `beta` | `alpha`, `beta`, `rc` |

### Monorepo Support

| Input | Description | Default |
|-------|-------------|---------|
| `is-monorepo` | Is monorepo | `false` |
| `packages-path` | Packages path | `packages/*` |
| `affected-only` | Build affected only | `false` |

### Docker

| Input | Description | Default |
|-------|-------------|---------|
| `build-docker` | Build Docker image | `false` |
| `dockerfile-path` | Dockerfile path | `./Dockerfile` |
| `docker-image-name` | Image name | `''` |
| `docker-registry` | Registry URL | `''` |

### Artifacts

| Input | Description | Default |
|-------|-------------|---------|
| `upload-artifacts` | Upload artifacts | `true` |
| `artifact-name` | Artifact name | `nodejs-build` |
| `artifact-path` | Paths to include | Auto-detect |
| `artifact-retention-days` | Retention days | `30` |

### Platform

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `runs-on` | Runner OS | `ubuntu-latest` | `ubuntu-latest`, `windows-latest`, `macos-latest` |
| `timeout-minutes` | Timeout | `30` | Minutes |

### Matrix Builds

| Input | Description | Default |
|-------|-------------|---------|
| `enable-matrix` | Enable matrix | `false` |
| `matrix-os` | OS matrix (JSON) | `["ubuntu-latest"]` |
| `matrix-node` | Node matrix (JSON) | `["20.x"]` |

## Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `NPM_TOKEN` | NPM auth token | For NPM publishing |
| `GITHUB_TOKEN` | GitHub token | For GitHub Packages |
| `DOCKER_USERNAME` | Docker username | For Docker push |
| `DOCKER_PASSWORD` | Docker password | For Docker push |
| `CODECOV_TOKEN` | Codecov token | For coverage upload |
| `SONAR_TOKEN` | SonarCloud token | For code analysis |

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `version` | Package version | `1.2.3` |
| `published` | Was published | `true` |
| `artifact-path` | Artifact path | `/tmp/artifacts` |
| `docker-image` | Docker image tag | `myapp:1.2.3` |

## Package Manager Support

### NPM
```yaml
package-manager: 'npm'
install-command: 'npm ci'
build-command: 'npm run build'
test-command: 'npm test'
```

### Yarn
```yaml
package-manager: 'yarn'
install-command: 'yarn install --frozen-lockfile'
build-command: 'yarn build'
test-command: 'yarn test'
```

### PNPM
```yaml
package-manager: 'pnpm'
package-manager-version: '8'
install-command: 'pnpm install --frozen-lockfile'
build-command: 'pnpm build'
test-command: 'pnpm test'
```

### Bun
```yaml
package-manager: 'bun'
install-command: 'bun install'
build-command: 'bun run build'
test-command: 'bun test'
```

## Project Type Examples

### NPM Package

```yaml
jobs:
  publish:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      node-version: '20.x'
      build-command: 'npm run build'
      run-tests: true
      test-coverage: true
      publish-package: true
      publish-registry: 'npm'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### React Application

```yaml
jobs:
  build-react:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      node-version: '20.x'
      build-command: 'npm run build'
      build-env: 'production'
      test-command: 'npm test -- --coverage --watchAll=false'
      analyze-bundle: true
      max-bundle-size: 500
```

### Next.js Application

```yaml
jobs:
  build-nextjs:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      node-version: '20.x'
      build-command: 'npm run build'
      run-typecheck: true
      build-docker: true
      dockerfile-path: './Dockerfile'
```

### Monorepo (Turborepo)

```yaml
jobs:
  build-monorepo:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      package-manager: 'pnpm'
      is-monorepo: true
      packages-path: 'packages/*'
      build-command: 'pnpm turbo build'
      test-command: 'pnpm turbo test'
      affected-only: true
```

## Matrix Build Example

```yaml
jobs:
  matrix-build:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: ['18.x', '20.x', '22.x']
        pm: [npm, yarn, pnpm]
    
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      node-version: ${{ matrix.node }}
      package-manager: ${{ matrix.pm }}
      runs-on: ${{ matrix.os }}
```

## Configuration Files

### Default Configuration
Location: `.github/config/nodejs-build/default.yml`

```yaml
node:
  version: '20.x'
package_manager:
  type: 'npm'
  frozen_lockfile: true
build:
  command: 'npm run build'
  environment: 'production'
testing:
  enabled: true
  coverage:
    enabled: false
    threshold: 80
```

### Project-Specific Configurations

- **NPM Package**: `.github/config/nodejs-build/npm-package.yml`
- **React App**: `.github/config/nodejs-build/react-app.yml`
- **Next.js App**: `.github/config/nodejs-build/nextjs-app.yml`
- **Monorepo**: `.github/config/nodejs-build/monorepo.yml`

## Publishing Workflow

### NPM Publishing

```yaml
on:
  release:
    types: [published]

jobs:
  publish:
    uses: your-org/automation-templates/.github/workflows/reusable-nodejs-build.yml@main
    with:
      publish-package: true
      publish-registry: 'npm'
      version: ${{ github.ref_name }}
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### GitHub Packages

```yaml
with:
  publish-registry: 'github'
  registry-url: 'https://npm.pkg.github.com'
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Docker Support

### Dockerfile Example

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

### Container Publishing

```yaml
with:
  build-docker: true
  docker-registry: 'ghcr.io'
  docker-image-name: '${{ github.repository }}'
secrets:
  DOCKER_USERNAME: ${{ github.actor }}
  DOCKER_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
```

## Best Practices

### 1. Version Management
```yaml
version: ${{ startsWith(github.ref, 'refs/tags/v') && github.ref_name || format('0.0.0-dev.{0}', github.run_number) }}
```

### 2. Conditional Publishing
```yaml
publish-package: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

### 3. Environment-Specific Builds
```yaml
build-env: ${{ github.ref == 'refs/heads/main' && 'production' || 'development' }}
```

### 4. Coverage Enforcement
```yaml
coverage-threshold: ${{ github.event_name == 'pull_request' && 80 || 0 }}
```

### 5. Security Auditing
```yaml
audit-level: ${{ github.ref == 'refs/heads/main' && 'moderate' || 'high' }}
```

## Troubleshooting

### Common Issues

1. **Package manager not detected**
   - Explicitly set `package-manager`
   - Ensure lockfile exists

2. **Build fails**
   - Check Node.js version compatibility
   - Verify build command
   - Review environment variables

3. **Tests not running**
   - Verify test command
   - Check test file patterns
   - Review test configuration

4. **Publishing fails**
   - Verify registry credentials
   - Check package.json configuration
   - Review publish access settings

### Debug Mode

Enable verbose output:
```yaml
with:
  build-command: 'npm run build --verbose'
  test-command: 'npm test -- --verbose'
```

## Performance Optimization

1. **Cache dependencies**: Enabled by default
2. **Cache build outputs**: Set `cache-build: true`
3. **Use frozen lockfile**: Set `frozen-lockfile: true`
4. **Matrix builds**: Parallelize across versions
5. **Monorepo optimization**: Use `affected-only: true`

## Security Considerations

1. **Audit dependencies**: Always enabled by default
2. **Use secrets**: Never hardcode credentials
3. **Pin versions**: Use exact versions in production
4. **Check licenses**: Enable license checking
5. **Scan images**: Use container scanning tools

## Migration Guide

### From Jenkins

1. Convert Jenkinsfile to workflow YAML
2. Map npm scripts to workflow inputs
3. Configure credentials as secrets
4. Set up webhooks

### From CircleCI

1. Convert config.yml to GitHub Actions
2. Map orbs to actions
3. Update environment variables
4. Configure contexts as environments

## Support

- 📚 [Documentation](https://github.com/your-org/automation-templates)
- 🐛 [Issues](https://github.com/your-org/automation-templates/issues)
- 💬 [Discussions](https://github.com/your-org/automation-templates/discussions)
- 📧 [Contact](mailto:devops@your-org.com)

## License

This workflow is part of the Automation Templates repository and follows the same license terms.