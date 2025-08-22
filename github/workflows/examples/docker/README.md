# Docker Build Examples

This directory contains comprehensive examples demonstrating how to use the automation-templates Docker build system in various scenarios.

## Available Examples

### 1. Simple Docker Build (`simple-docker-build.yml`)
Basic Docker build workflow with minimal configuration.

**Features:**
- Simple build process
- Basic security scanning
- GHCR.io registry
- No deployment

**Use Case:** Small applications, proof of concepts, development builds

### 2. Web Application Build (`web-application-build.yml`)
Complete web application Docker build with testing and deployment.

**Features:**
- Web-specific optimizations
- Multi-platform builds (AMD64, ARM64)
- Enhanced security scanning (HIGH severity)
- Health checks
- Conditional deployment to staging
- SBOM generation and image signing

**Use Case:** Production web applications, Node.js apps, React/Vue/Angular frontends

### 3. Microservice Build (`microservice-build.yml`)
Microservice Docker build with service mesh and comprehensive testing.

**Features:**
- Microservice-specific patterns
- Helm deployment to Kubernetes
- Service mesh integration (Istio)
- Contract and integration testing
- Monitoring and observability
- Performance optimization

**Use Case:** Microservice architectures, API services, cloud-native applications

### 4. Enterprise Build (`enterprise-build.yml`)
Enterprise-grade Docker build with maximum security and compliance.

**Features:**
- Compliance validation workflow
- Maximum security (MEDIUM severity threshold)
- Enterprise registry support
- Comprehensive testing suite
- Governance and policy enforcement
- Full observability and monitoring
- Backup and disaster recovery
- Audit logging and compliance reports

**Use Case:** Enterprise applications, regulated industries, critical systems

### 5. Multi-Platform Build (`multi-platform-build.yml`)
Cross-platform Docker build for ARM64, AMD64, and ARM/v7 architectures.

**Features:**
- Multi-architecture support
- Cross-compilation build arguments
- Platform-specific testing
- Manifest creation
- Optimized caching

**Use Case:** IoT applications, edge computing, multi-cloud deployment

### 6. Security-Focused Build (`security-focused-build.yml`)
Security-first Docker build with comprehensive vulnerability scanning.

**Features:**
- Pre-build security analysis
- Dockerfile security scanning
- Source code security scanning (SAST)
- Very strict security thresholds (LOW severity)
- Security-hardened Docker images
- Comprehensive security reporting
- Automated security issue creation

**Use Case:** Security-critical applications, financial services, healthcare

## Configuration Files

Each example uses one of the predefined configuration files:

- `default.yml` - Basic configuration for standard applications
- `web-application.yml` - Optimized for web applications
- `microservice.yml` - Microservice-specific configuration
- `enterprise.yml` - Maximum security and compliance

## Getting Started

1. **Choose the appropriate example** based on your use case
2. **Copy the example file** to your repository's `.github/workflows/` directory
3. **Customize the configuration** by modifying:
   - `image-name`: Your application name
   - `registry`: Your container registry
   - `build-args`: Application-specific build arguments
   - `platforms`: Target platforms for your application
   - Deployment settings and secrets

4. **Configure secrets** in your repository:
   - `GITHUB_TOKEN` (automatically available)
   - `REGISTRY_TOKEN` (for custom registries)
   - `COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD` (for image signing)
   - `KUBECONFIG` (for Kubernetes deployment)

## Common Patterns

### Image Naming
```yaml
image-name: 'my-app'
image-tag: ${{ github.ref_name }}-${{ github.sha }}
```

### Conditional Deployment
```yaml
deploy: ${{ github.ref == 'refs/heads/main' }}
deployment-environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}
```

### Multi-Platform Builds
```yaml
platforms: 'linux/amd64,linux/arm64'
multi-platform: true
```

### Security Scanning
```yaml
security-scan: true
fail-on-severity: 'HIGH'
generate-sbom: true
sign-image: true
```

## Best Practices

1. **Start Simple**: Begin with `simple-docker-build.yml` and add features as needed
2. **Security First**: Always enable security scanning for production builds
3. **Image Signing**: Use Cosign for production image signing
4. **SBOM Generation**: Generate Software Bill of Materials for compliance
5. **Multi-Platform**: Consider ARM64 support for cloud and edge deployment
6. **Testing**: Include comprehensive testing in your Docker workflows
7. **Monitoring**: Set up proper observability for production deployments

## Customization

You can customize any example by:

1. **Modifying the configuration file** used (`config-file` parameter)
2. **Creating custom build arguments** in the `build-args` section
3. **Adjusting security settings** based on your requirements
4. **Adding custom deployment commands** for your infrastructure
5. **Implementing custom testing strategies**

## Support

For questions or issues with these examples:

1. Check the main workflow file: `.github/workflows/docker-build.yml`
2. Review the action documentation: `.github/actions/docker-build/action.yml`
3. Examine the configuration files in `.github/config/docker-build/`
4. Create an issue in the automation-templates repository