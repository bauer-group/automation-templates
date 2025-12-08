# Docker Build Workflow

This document describes the comprehensive Docker build system provided by the automation-templates repository. The system includes reusable workflows, actions, and configurations for building, testing, and deploying Docker images with enterprise-grade security and best practices.

## Overview

The Docker build system provides:

- **Reusable Workflows**: Pre-configured workflows for different application types
- **Composite Actions**: Modular Docker build components
- **Multi-Registry Support**: Push to GHCR, Docker Hub, or both with a single build
- **Security Integration**: Comprehensive vulnerability scanning and image signing
- **Multi-Platform Support**: Cross-architecture builds for cloud and edge deployment
- **Enterprise Features**: Compliance, governance, and comprehensive monitoring

## Quick Start

### Basic Usage (GitHub Container Registry)

```yaml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      image-name: 'my-app'
      auto-tags: true
    secrets: inherit
```

### Push to Docker Hub Only

```yaml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'dockerhub'
      image-name: 'myuser/my-app'
      auto-tags: true
    secrets: inherit
```

### Push to Both Registries

```yaml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'both'
      image-name: 'my-org/my-app'              # GHCR image name
      secondary-image-name: 'myuser/my-app'    # Docker Hub image name
      auto-tags: true
      sync-dockerhub-readme: true
    secrets: inherit
```

## Registry Configuration

### The `publish-to` Input

The `publish-to` input controls where Docker images are published:

| Value | Primary Registry | Secondary Registry | Authentication |
|-------|------------------|-------------------|----------------|
| `ghcr` (default) | ghcr.io | - | `github.actor` + `GITHUB_TOKEN` (automatic) |
| `dockerhub` | docker.io | - | `DOCKER_USERNAME` + `DOCKER_PASSWORD` |
| `both` | ghcr.io | docker.io | GHCR automatic, Docker Hub via secrets |

### Required Secrets

| Secret | Required When | Description |
|--------|---------------|-------------|
| `DOCKER_USERNAME` | `publish-to: 'dockerhub'` or `'both'` | Docker Hub username |
| `DOCKER_PASSWORD` | `publish-to: 'dockerhub'` or `'both'` | Docker Hub password or access token |
| `COSIGN_PRIVATE_KEY` | `sign-image: true` | Cosign private key for image signing |
| `COSIGN_PASSWORD` | `sign-image: true` | Cosign key password |

**Note:** For GHCR, `GITHUB_TOKEN` is automatically available and used for authentication.

## Components

### 1. Reusable Workflow

**File**: `.github/workflows/docker-build.yml`

The main workflow orchestrates the entire Docker build process including:

- **Build Job**: Docker image building with BuildKit
- **Test Job**: Container testing and validation
- **Security Job**: Vulnerability scanning and SBOM generation
- **README Sync Job**: Synchronize README to Docker Hub
- **Deploy Job**: Conditional deployment to target environments

### 2. Composite Action

**File**: `.github/actions/docker-build/action.yml`

The Docker build action provides:

- Multi-platform build support
- Advanced caching strategies
- Multi-registry authentication
- Security scanning integration
- Image signing with Cosign
- SBOM generation
- Performance optimization

## Input Parameters

### Registry & Publishing

| Parameter | Description | Default |
|-----------|-------------|---------|
| `publish-to` | Where to publish: `'ghcr'`, `'dockerhub'`, or `'both'` | `'ghcr'` |
| `registry` | Custom registry URL (when `publish-to: 'ghcr'`) | `'ghcr.io'` |
| `secondary-registry` | Secondary registry URL (for custom multi-registry setups) | `''` |
| `image-name` | Docker image name (without registry) | Repository name |
| `secondary-image-name` | Image name for secondary registry | Same as `image-name` |

### Version & Tagging

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auto-tags` | Generate automatic tags based on Git refs | `true` |
| `latest-tag` | Tag image as `latest` on tag push | `true` |
| `image-tags` | Additional custom image tags | `''` |
| `version-from-dockerfile` | Extract version from Dockerfile LABEL | `false` |
| `update-dockerfile-version` | Update Dockerfile LABEL from Git tag | `false` |

### Build Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dockerfile-path` | Path to Dockerfile | `'./Dockerfile'` |
| `docker-context` | Docker build context | `'.'` |
| `build-target` | Docker build target stage | `''` |
| `build-args` | Build arguments as JSON object | `'{}'` |
| `platforms` | Target platforms (comma-separated) | `'linux/amd64'` |
| `multi-platform` | Enable multi-platform builds | `false` |

### Push Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `push` | Push image to registry | `true` |
| `push-on-pr` | Push images on pull requests | `false` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `security-scan` | Run security vulnerability scan | `true` |
| `security-scanner` | Scanner: `'trivy'`, `'grype'`, `'snyk'` | `'trivy'` |
| `security-fail-on` | Fail on: `'CRITICAL'`, `'HIGH'`, `'MEDIUM'`, `'LOW'` | `'CRITICAL'` |
| `security-ignore-unfixed` | Ignore unfixed vulnerabilities | `false` |
| `sign-image` | Sign image with Cosign | `false` |
| `generate-sbom` | Generate Software Bill of Materials | `false` |
| `sbom-format` | SBOM format: `'cyclonedx'`, `'spdx'` | `'cyclonedx'` |

### Docker Hub README Sync

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sync-dockerhub-readme` | Sync README to Docker Hub | `false` |
| `readme-file` | Custom README path (auto-detects if empty) | `''` |

### Caching & Performance

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cache-enabled` | Enable build caching | `true` |
| `cache-mode` | Cache mode: `'min'`, `'max'`, `'inline'` | `'max'` |
| `builder-driver` | Builder driver: `'docker'`, `'docker-container'`, `'kubernetes'` | `'docker-container'` |
| `build-timeout` | Build timeout in minutes | `30` |

### Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deploy-enabled` | Enable deployment after build | `false` |
| `deploy-environment` | Deployment environment | `'staging'` |
| `deploy-command` | Custom deployment command | `''` |

## Automatic Tag Generation

When `auto-tags: true`, the workflow generates tags based on Git context:

### On Tag Push (e.g., `v1.2.3`)

- `1.2.3` - Full semantic version
- `1.2` - Major.minor version
- `1` - Major version
- `latest` - If `latest-tag: true`

### On Branch Push

- `main` or `develop` - Branch name
- `main-a1b2c3d` - Branch + commit SHA prefix

### On Pull Request

- `pr-123` - Pull request number

## Version Management

### Extract Version from Dockerfile

When `version-from-dockerfile: true`, the workflow extracts the version from Dockerfile LABEL:

```dockerfile
LABEL org.opencontainers.image.version="1.2.3"
```

This version is used as an additional image tag.

### Update Dockerfile Version from Git Tag

When `update-dockerfile-version: true` and a Git tag is pushed (e.g., `v1.2.3`):

1. The workflow extracts the version from the tag (stripping `v` prefix)
2. Updates the Dockerfile LABEL `org.opencontainers.image.version`
3. Uses the updated version for tagging

This is useful for keeping Dockerfile metadata in sync with release tags.

## Security Features

### Vulnerability Scanning

```yaml
security-scan: true
security-scanner: 'trivy'
security-fail-on: 'HIGH'
security-ignore-unfixed: false
```

### Image Signing with Cosign

```yaml
sign-image: true
# Requires secrets:
# COSIGN_PRIVATE_KEY
# COSIGN_PASSWORD
```

### SBOM Generation

```yaml
generate-sbom: true
sbom-format: 'cyclonedx'  # or 'spdx'
```

## Multi-Platform Builds

Enable cross-architecture builds:

```yaml
platforms: 'linux/amd64,linux/arm64,linux/arm/v7'
multi-platform: true
```

## README Sync to Docker Hub

Automatically sync your README to Docker Hub:

```yaml
publish-to: 'both'  # or 'dockerhub'
sync-dockerhub-readme: true
readme-file: ''  # Auto-detects: DOCKER_README.MD -> README.MD -> README.md
```

## Examples

The repository includes comprehensive examples in `github/workflows/examples/docker/`:

1. **[simple-docker-build.yml](../../github/workflows/examples/docker/simple-docker-build.yml)**: Basic GHCR build
2. **[ghost-bunnycdn-connector.yml](../../github/workflows/examples/docker/ghost-bunnycdn-connector.yml)**: Multi-registry with version sync
3. **[dockerhub-with-readme-sync.yml](../../github/workflows/examples/docker/dockerhub-with-readme-sync.yml)**: Docker Hub with README sync
4. **[multi-platform-build.yml](../../github/workflows/examples/docker/multi-platform-build.yml)**: Cross-architecture builds
5. **[security-focused-build.yml](../../github/workflows/examples/docker/security-focused-build.yml)**: Security-first approach
6. **[enterprise-build.yml](../../github/workflows/examples/docker/enterprise-build.yml)**: Maximum security and compliance

## Best Practices

### 1. Security
- Always enable security scanning for production builds
- Use image signing for production images
- Generate SBOM for compliance and security tracking
- Implement least-privilege container configurations

### 2. Performance
- Use multi-stage Dockerfiles with specific targets
- Enable BuildKit caching for faster builds
- Optimize layer caching with proper ordering
- Use parallel builds for multi-platform images

### 3. Multi-Registry

- Use `publish-to: 'both'` for maximum image availability
- Keep image names consistent across registries
- Sync README to Docker Hub for discoverability

### 4. Version Management
- Use `update-dockerfile-version: true` for consistent versioning
- Follow semantic versioning with Git tags
- Use `auto-tags: true` for automatic tag generation

## Troubleshooting

### Common Issues

1. **Docker Hub Authentication Failed**
   - Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets are set
   - Ensure Docker Hub access token has read/write permissions
   - Check username matches Docker Hub account (not email)

2. **GHCR Authentication Failed**
   - `GITHUB_TOKEN` is automatically provided
   - Ensure repository has package write permissions

3. **Invalid Image Tag**
   - Check for empty branch names on tag pushes
   - Verify tag format matches expected patterns

4. **README Sync Failed**
   - Ensure `publish-to` is `'dockerhub'` or `'both'`
   - Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` are set
   - Check README file exists and is readable

### Debug Mode

Enable debug logging:

```yaml
with:
  debug: true
```

## Migration Guide

### From Separate Registry Workflows

If you previously had separate workflows for GHCR and Docker Hub:

**Before:**
```yaml
# Two separate jobs building the same image twice
jobs:
  ghcr:
    # ... build and push to GHCR
  dockerhub:
    # ... build and push to Docker Hub
```

**After:**
```yaml
# Single job, single build, push to both
jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'both'
      image-name: 'my-org/my-app'
      secondary-image-name: 'myuser/my-app'
    secrets: inherit
```

## Support

- **Documentation**: See examples in `github/workflows/examples/docker/`
- **Issues**: Report issues in the automation-templates repository
- **Contributing**: Follow the repository contribution guidelines
