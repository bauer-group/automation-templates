# Docker Build Workflow

This document describes the comprehensive Docker build system provided by the automation-templates repository. The system includes reusable workflows, actions, and configurations for building, testing, and deploying Docker images with enterprise-grade security and best practices.

## Overview

The Docker build system provides:

- **Reusable Workflows**: Pre-configured workflows for different application types
- **Composite Actions**: Modular Docker build components
- **Configuration Templates**: Pre-defined configurations for various use cases
- **Security Integration**: Comprehensive vulnerability scanning and image signing
- **Multi-Platform Support**: Cross-architecture builds for cloud and edge deployment
- **Enterprise Features**: Compliance, governance, and comprehensive monitoring

## Quick Start

### Basic Usage

```yaml
name: Docker Build
on:
  push:
    branches: [ main ]

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      config-file: 'default'
      image-name: 'my-app'
      image-tag: ${{ github.sha }}
    secrets:
      REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Advanced Usage

```yaml
name: Enterprise Docker Build
on:
  push:
    branches: [ main ]

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      config-file: 'enterprise'
      image-name: 'enterprise-app'
      image-tag: ${{ github.ref_name }}-${{ github.sha }}
      registry: 'enterprise-registry.company.com'
      platforms: 'linux/amd64,linux/arm64'
      security-scan: true
      fail-on-severity: 'MEDIUM'
      generate-sbom: true
      sign-image: true
      deploy: true
      deployment-environment: 'production'
    secrets:
      REGISTRY_TOKEN: ${{ secrets.ENTERPRISE_REGISTRY_TOKEN }}
      COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
      COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
```

## Components

### 1. Reusable Workflow

**File**: `.github/workflows/docker-build.yml`

The main workflow orchestrates the entire Docker build process including:

- **Build Job**: Docker image building with BuildKit
- **Test Job**: Container testing and validation
- **Security Job**: Vulnerability scanning and SBOM generation
- **Deploy Job**: Conditional deployment to target environments

### 2. Composite Action

**File**: `.github/actions/docker-build/action.yml`

The Docker build action provides:

- Multi-platform build support
- Advanced caching strategies
- Registry authentication
- Security scanning integration
- Image signing with Cosign
- SBOM generation
- Performance optimization

### 3. Configuration Files

Located in `.github/config/docker-build/`:

#### `default.yml`
Basic configuration for standard applications:
- Single platform (linux/amd64)
- Basic security scanning
- Standard caching
- No image signing

#### `web-application.yml`
Optimized for web applications:
- Multi-platform builds
- Enhanced security (HIGH severity threshold)
- Health check support
- Web-specific labels and testing

#### `microservice.yml`
Designed for microservice architectures:
- Service mesh integration
- Kubernetes deployment
- Contract testing
- Monitoring and observability

#### `enterprise.yml`
Maximum security and compliance:
- Strict security scanning (MEDIUM threshold)
- Comprehensive testing suite
- Compliance validation
- Audit logging
- Governance policies

## Input Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `config-file` | Configuration template to use | `'default'`, `'web-application'`, `'microservice'`, `'enterprise'` |
| `image-name` | Docker image name | `'my-app'` |

### Optional Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image-tag` | Docker image tag | `'latest'` |
| `registry` | Container registry | `'ghcr.io'` |
| `dockerfile` | Dockerfile path | `'./Dockerfile'` |
| `context` | Build context | `'.'` |
| `target` | Build target stage | `''` |
| `platforms` | Target platforms | `'linux/amd64'` |
| `build-args` | Build arguments | `''` |
| `security-scan` | Enable security scanning | `true` |
| `fail-on-severity` | Security failure threshold | `'CRITICAL'` |
| `generate-sbom` | Generate SBOM | `false` |
| `sign-image` | Sign image with Cosign | `false` |
| `deploy` | Enable deployment | `false` |
| `deployment-environment` | Target environment | `'staging'` |

## Security Features

### Vulnerability Scanning

The system supports multiple security scanners:

- **Trivy** (default): Comprehensive vulnerability scanning
- **Grype**: Alternative vulnerability scanner
- **Snyk**: Commercial security scanning

Configuration example:
```yaml
security-scan: true
scanner: 'trivy'
fail-on-severity: 'HIGH'
ignore-unfixed: false
```

### Image Signing

Uses Cosign for image signing and verification:

```yaml
sign-image: true
# Requires secrets:
# COSIGN_PRIVATE_KEY
# COSIGN_PASSWORD
```

### SBOM Generation

Generates Software Bill of Materials:

```yaml
generate-sbom: true
sbom-format: 'cyclonedx'  # or 'spdx'
```

### Additional Security Features

- Secret scanning in Docker images
- License compliance scanning
- Malware detection
- Policy enforcement with OPA

## Multi-Platform Builds

Enable cross-architecture builds:

```yaml
platforms: 'linux/amd64,linux/arm64,linux/arm/v7'
multi-platform: true
```

Build arguments automatically available:
- `TARGETPLATFORM`
- `TARGETOS`
- `TARGETARCH`
- `TARGETVARIANT`
- `BUILDPLATFORM`

## Testing Integration

### Pre-Build Testing
```yaml
testing:
  pre_build: true
```

### Post-Build Testing
```yaml
testing:
  post_build: true
  test_command: "docker run --rm $IMAGE_TAG test"
```

### Advanced Testing
```yaml
testing:
  integration_tests: true
  contract_tests: true
  security_tests: true
  performance_tests: true
```

## Deployment

### Basic Deployment
```yaml
deploy: true
deployment-environment: 'staging'
deployment-command: 'kubectl set image deployment/app container=$IMAGE_URL'
```

### Advanced Deployment
```yaml
deployment:
  enabled: true
  environment: 'production'
  command: 'helm upgrade --install app ./helm --set image.tag=$IMAGE_TAG'
  approval_required: true
```

## Performance Optimization

### Caching
```yaml
cache:
  enabled: true
  mode: 'max'
  registry: 'ghcr.io/cache'
```

### Build Performance
```yaml
performance:
  builder_driver: 'kubernetes'
  build_timeout: 60
  parallel_builds: true
  resource_limits:
    memory: '512Mi'
    cpu: '250m'
```

## Monitoring and Observability

### Metrics and Monitoring
```yaml
monitoring:
  metrics_port: 9090
  health_port: 8080
  tracing_enabled: true
  logging_format: 'json'
```

### Enterprise Monitoring
```yaml
monitoring:
  full_observability: true
  apm_enabled: true
  log_aggregation: 'splunk'
  metrics_system: 'prometheus'
  alerting: 'pagerduty'
```

## Required Secrets

### Basic Secrets
- `REGISTRY_TOKEN`: Container registry authentication
- `GITHUB_TOKEN`: Automatically available for GHCR

### Security Secrets
- `COSIGN_PRIVATE_KEY`: For image signing
- `COSIGN_PASSWORD`: Cosign key password

### Deployment Secrets
- `KUBECONFIG`: Kubernetes cluster access
- `HELM_VALUES`: Helm deployment values

### Enterprise Secrets
- `ENTERPRISE_REGISTRY_TOKEN`: Enterprise registry access
- `ENTERPRISE_LICENSE`: Enterprise feature licensing
- `COMPLIANCE_TOKEN`: Compliance scanning access

## Examples

The repository includes comprehensive examples in `github/workflows/examples/docker/`:

1. **Simple Build**: Basic Docker build workflow
2. **Web Application**: Complete web app build with deployment
3. **Microservice**: Microservice with service mesh integration
4. **Enterprise**: Maximum security and compliance
5. **Multi-Platform**: Cross-architecture builds
6. **Security-Focused**: Security-first approach with comprehensive scanning

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

### 3. Testing
- Include comprehensive testing in Docker workflows
- Test containers in isolation with read-only filesystems
- Validate health checks and monitoring endpoints
- Perform contract testing for API services

### 4. Deployment
- Use conditional deployment based on branch/environment
- Implement approval workflows for production deployments
- Use rolling deployments with health checks
- Maintain deployment rollback capabilities

### 5. Compliance
- Generate and store SBOM for all production images
- Implement policy enforcement with admission controllers
- Maintain audit logs for all build and deployment activities
- Regular security scanning and vulnerability management

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check Dockerfile syntax and instructions
   - Verify build context and file paths
   - Review build arguments and environment variables

2. **Security Scan Failures**
   - Review vulnerability reports and SARIF output
   - Update base images and dependencies
   - Consider vulnerability exceptions for false positives

3. **Multi-Platform Issues**
   - Ensure cross-compilation support in application
   - Verify platform-specific dependencies
   - Check Dockerfile compatibility across architectures

4. **Registry Authentication**
   - Verify registry credentials and permissions
   - Check registry URL and namespace configuration
   - Ensure token has appropriate scopes

### Debug Mode

Enable debug logging:
```yaml
with:
  debug: true
```

This provides detailed logging for troubleshooting build and deployment issues.

## Migration Guide

### From Docker/build-push-action

Replace:
```yaml
- uses: docker/build-push-action@v5
```

With:
```yaml
uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
```

### From Custom Docker Workflows

1. Identify your current Docker workflow patterns
2. Choose the appropriate configuration template
3. Map your existing parameters to the new system
4. Test with a simple configuration first
5. Gradually add advanced features

## Support and Contributing

- **Documentation**: Complete examples and configuration references
- **Issues**: Report issues in the automation-templates repository
- **Contributing**: Follow the repository contribution guidelines
- **Security**: Report security issues through responsible disclosure

For advanced customization and enterprise support, contact the automation-templates maintainers.