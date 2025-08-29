# GitHub Actions Workflow Examples

This directory contains example workflows demonstrating how to use the reusable workflows from this repository.

## Directory Structure

```
github/workflows/examples/
├── ci-cd/                   # CI/CD pipeline examples
│   ├── comprehensive-ci-cd.yml
│   └── security-focused.yml
├── documentation/           # Documentation & automation examples
│   ├── ai-issue-summary.yml
│   ├── documentation.yml
│   ├── issue-automation.yml
│   ├── pr-labeler.yml
│   └── readme.yml
├── dotnet-desktop-build/    # .NET Desktop application examples
│   ├── basic-wpf-build.yml
│   ├── advanced-signed-build.yml
│   ├── msix-package-build.yml
│   ├── multi-project-build.yml
│   └── matrix-build-test.yml
├── dotnet-build/            # .NET Core/5+ application examples
│   ├── simple-library.yml
│   ├── web-api-docker.yml
│   ├── nuget-package-publish.yml
│   ├── blazor-wasm-deploy.yml
│   ├── matrix-cross-platform.yml
│   └── microservice-k8s.yml
├── nodejs-build/            # Node.js application examples
│   ├── simple-npm-package.yml
│   ├── npm-publish-release.yml
│   ├── matrix-multi-version.yml
│   ├── react-app-deploy.yml
│   ├── nextjs-docker-deploy.yml
│   └── monorepo-turborepo.yml
├── python-release/           # Python package release examples
│   ├── nocodb-simpleclient-example.yml
│   └── README.MD
├── release/                 # Release automation examples
│   ├── semantic-release.yml
│   └── simple-release.yml
├── security/               # Security workflow examples
│   ├── automatic-release.yml
│   └── manual-release.yml
├── project-templates/      # Complete project workflow templates
│   └── nodejs-project.yml
└── docker/                 # Docker-specific examples (future)
```

## Using These Examples

1. **Copy the example** that matches your use case
2. **Place it in your repository's** `.github/workflows/` directory
3. **Modify the configuration** to match your project structure
4. **Update the `uses:` statement** to reference this repository:
   ```yaml
   uses: your-org/automation-templates/.github/workflows/[workflow-name].yml@main
   ```

## Available Reusable Workflows

### .NET Desktop Build (`dotnet-desktop-build.yml`)
For building Windows desktop applications (WPF, WinForms, MAUI)

**Examples:**
- `dotnet-desktop-build/basic-wpf-build.yml` - Simple WPF application
- `dotnet-desktop-build/advanced-signed-build.yml` - With code signing
- `dotnet-desktop-build/msix-package-build.yml` - MSIX packaging
- `dotnet-desktop-build/multi-project-build.yml` - Multiple projects
- `dotnet-desktop-build/matrix-build-test.yml` - Matrix configurations

### .NET Build (`dotnet-build.yml`)
For building .NET Core/5+ applications, libraries, and services

**Examples:**
- `dotnet-build/simple-library.yml` - Class library
- `dotnet-build/web-api-docker.yml` - Web API with Docker
- `dotnet-build/nuget-package-publish.yml` - NuGet publishing
- `dotnet-build/blazor-wasm-deploy.yml` - Blazor WebAssembly
- `dotnet-build/matrix-cross-platform.yml` - Cross-platform builds
- `dotnet-build/microservice-k8s.yml` - Microservice with Kubernetes

### Node.js Build (`nodejs-build.yml`)
For building Node.js applications and packages

**Examples:**
- `nodejs-build/simple-npm-package.yml` - NPM package
- `nodejs-build/npm-publish-release.yml` - NPM publishing
- `nodejs-build/matrix-multi-version.yml` - Multi-version testing
- `nodejs-build/react-app-deploy.yml` - React deployment
- `nodejs-build/nextjs-docker-deploy.yml` - Next.js with Docker
- `nodejs-build/monorepo-turborepo.yml` - Monorepo management

### Python Release (`python-automatic-release.yml`)
For building and releasing Python packages with comprehensive CI/CD

**Examples:**
- `python-release/nocodb-simpleclient-example.yml` - Complete Python package release
- `python-release/README.MD` - Detailed documentation and GitHub Packages installation guide

### CI/CD Pipelines
Complete CI/CD pipeline configurations

**Examples:**
- `ci-cd/comprehensive-ci-cd.yml` - Full CI/CD pipeline with all checks
- `ci-cd/security-focused.yml` - Security-first CI/CD pipeline

### Documentation & Automation
Various automation and documentation workflows

**Examples:**
- `documentation/ai-issue-summary.yml` - AI-powered issue summaries
- `documentation/documentation.yml` - Auto-generate documentation
- `documentation/issue-automation.yml` - Issue management automation
- `documentation/pr-labeler.yml` - Automatic PR labeling
- `documentation/readme.yml` - README generation

### Release Management
Release and versioning workflows

**Examples:**
- `release/semantic-release.yml` - Semantic versioning automation
- `release/simple-release.yml` - Basic release workflow

### Security Workflows
Security scanning and compliance workflows

**Examples:**
- `security/automatic-release.yml` - Secure automated releases
- `security/manual-release.yml` - Manual release with security checks

### Project Templates
Complete workflow templates for specific project types

**Examples:**
- `project-templates/nodejs-project.yml` - Complete Node.js project setup

## Configuration

Most workflows support configuration through:

1. **Workflow inputs** - Direct parameters in the workflow file
2. **Configuration files** - YAML files in `.github/config/`
3. **Secrets** - Sensitive data like tokens and credentials
4. **Environment variables** - Runtime configuration

## Best Practices

1. **Start simple** - Use basic examples and add complexity as needed
2. **Use matrix builds** - Test across multiple versions/platforms
3. **Cache dependencies** - Improve build performance
4. **Pin versions** - Use specific versions for reproducibility
5. **Secure secrets** - Never commit sensitive data

## Support

### Build Workflow Documentation
- [Docker Build Documentation](../../../docs/workflows/docker-build.md)
- [Python Build Documentation](../../../docs/workflows/python-build.md)
- [.NET Desktop Build Documentation](../../../docs/workflows/dotnet-desktop-build.md)
- [.NET Build Documentation](../../../docs/workflows/dotnet-build.md)
- [Node.js Build Documentation](../../../docs/workflows/nodejs-build.md)

### Management & Notification Workflows
- [Teams Notifications Documentation](../../../docs/workflows/teams-notifications.md)
- [Documentation Management Workflow](../../../.github/workflows/documentation.yml)
- [Security Policy Management Workflow](../../../.github/workflows/security-management.yml)

### Project Resources
- [Contributing Guidelines](../../../CONTRIBUTING.MD) - Learn how to contribute
- [Security Policy](../../../SECURITY.MD) - Security and vulnerability reporting
- [Code of Conduct](../../../CODE_OF_CONDUCT.MD) - Community standards

## Contributing

When adding new examples:
1. Place them in the appropriate category directory
2. Use descriptive names
3. Include comments explaining key configurations
4. Update this README with the new example