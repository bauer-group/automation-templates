# 🔐 Secrets Naming Convention

## Overview

This document defines the naming convention for GitHub Secrets used in our workflows. Clear, descriptive secret names help developers understand their purpose and scope immediately.

## Naming Pattern

```
<SCOPE>_<SERVICE>_<PURPOSE>_<FORMAT>
```

### Components:

- **SCOPE**: Technology or platform (e.g., `DOTNET`, `NODEJS`, `DOCKER`)
- **SERVICE**: External service or tool (e.g., `NUGET`, `NPM`, `GITHUB`)
- **PURPOSE**: What the secret does (e.g., `PUBLISH`, `SIGNING`, `ANALYSIS`)
- **FORMAT** (optional): Format indicator (e.g., `BASE64`, `TOKEN`, `KEY`)

## Secret Categories

### 🔷 .NET Secrets

| Secret Name | Description | Scope | Used In |
|------------|-------------|-------|---------|
| `DOTNET_SIGNING_CERTIFICATE_BASE64` | Base64 encoded PFX certificate for .NET desktop app code signing | Project | dotnet-desktop-build.yml |
| `DOTNET_SIGNING_CERTIFICATE_PASSWORD` | Password for .NET desktop app signing certificate | Project | dotnet-desktop-build.yml |
| `DOTNET_NUGET_API_KEY` | NuGet API key for private feed restoration | Global | dotnet-desktop-build.yml |
| `DOTNET_NUGET_PUBLISH_API_KEY` | NuGet API key for publishing packages | Global | dotnet-build.yml |

### 📦 Node.js Secrets

| Secret Name | Description | Scope | Used In |
|------------|-------------|-------|---------|
| `NPM_REGISTRY_PUBLISH_TOKEN` | NPM token for publishing packages to npm registry | Global | nodejs-build.yml |
| `GITHUB_PACKAGES_TOKEN` | GitHub token for publishing to GitHub Packages | Global | nodejs-build.yml |

### 🐳 Docker Secrets

| Secret Name | Description | Scope | Used In |
|------------|-------------|-------|---------|
| `DOCKER_REGISTRY_USERNAME` | Username for Docker registry authentication | Global | All build workflows |
| `DOCKER_REGISTRY_PASSWORD` | Password for Docker registry authentication | Global | All build workflows |

### 📊 Code Quality & Analysis

| Secret Name | Description | Scope | Used In |
|------------|-------------|-------|---------|
| `CODECOV_UPLOAD_TOKEN` | Token for uploading coverage reports to Codecov | Project | All build workflows |
| `SONARCLOUD_ANALYSIS_TOKEN` | Token for SonarCloud code quality analysis | Project | All build workflows |

### 🔒 Security Scanning

| Secret Name | Description | Scope | Used In |
|------------|-------------|-------|---------|
| `GITGUARDIAN_API_KEY` | GitGuardian API key for secret scanning | Global | modules-security-scan.yml |
| `GITLEAKS_LICENSE_KEY` | Gitleaks license for advanced features | Global | modules-security-scan.yml |
| `FOSSA_LICENSE_API_KEY` | FOSSA API key for license compliance | Global | modules-license-compliance.yml |

### 🤖 AI & Automation

| Secret Name | Description | Scope | Used In |
|------------|-------------|-------|---------|
| `OPENAI_API_KEY` | OpenAI API key for AI-powered features | Global | modules-ai-issue-summary.yml |

## Scope Definitions

### Global Secrets (Organization/Repository level)
- Used across multiple projects
- Service credentials
- API keys for external services
- Example: `NPM_REGISTRY_PUBLISH_TOKEN`

### Project Secrets (Environment level)
- Specific to a single project or application
- Signing certificates
- Project-specific API keys
- Example: `DOTNET_SIGNING_CERTIFICATE_BASE64`

## Migration Guide

### Old Secret Names → New Names

```yaml
# ❌ Old (unclear)
SIGNING_CERTIFICATE: ${{ secrets.SIGNING_CERTIFICATE }}
CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}

# ✅ New (descriptive)
DOTNET_SIGNING_CERTIFICATE_BASE64: ${{ secrets.DOTNET_SIGNING_CERTIFICATE_BASE64 }}
DOTNET_SIGNING_CERTIFICATE_PASSWORD: ${{ secrets.DOTNET_SIGNING_CERTIFICATE_PASSWORD }}
NPM_REGISTRY_PUBLISH_TOKEN: ${{ secrets.NPM_REGISTRY_PUBLISH_TOKEN }}
DOCKER_REGISTRY_USERNAME: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
```

## Best Practices

### 1. Be Specific
- ❌ `API_KEY` - Too generic
- ✅ `DOTNET_NUGET_PUBLISH_API_KEY` - Clear purpose

### 2. Include Technology Scope
- ❌ `SIGNING_CERTIFICATE` - Which technology?
- ✅ `DOTNET_SIGNING_CERTIFICATE_BASE64` - Clearly for .NET

### 3. Indicate Format When Relevant
- ❌ `CERTIFICATE` - What format?
- ✅ `CERTIFICATE_BASE64` - Base64 encoded

### 4. Separate Read/Write Permissions
- `NUGET_API_KEY` - For package restoration (read)
- `NUGET_PUBLISH_API_KEY` - For publishing (write)

### 5. Use Consistent Prefixes
- All Docker secrets start with `DOCKER_`
- All .NET secrets start with `DOTNET_`
- All Node.js/NPM secrets start with `NPM_` or `NODEJS_`

## Security Guidelines

1. **Never commit secrets** to the repository
2. **Use least privilege** - separate read and write tokens
3. **Rotate regularly** - especially after team changes
4. **Document expiration** - track when secrets need renewal
5. **Use environments** - separate secrets for dev/staging/prod

## Setting Up Secrets

### GitHub UI
1. Go to Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Use the naming convention
4. Add clear description in the UI

### GitHub CLI
```bash
# Repository secret
gh secret set DOTNET_NUGET_PUBLISH_API_KEY

# Organization secret
gh secret set DOCKER_REGISTRY_USERNAME --org your-org

# Environment secret
gh secret set DOTNET_SIGNING_CERTIFICATE_BASE64 --env production
```

## Workflow Usage Examples

### .NET Desktop Build
```yaml
jobs:
  build:
    uses: ./.github/workflows/dotnet-desktop-build.yml
    secrets:
      DOTNET_SIGNING_CERTIFICATE_BASE64: ${{ secrets.DOTNET_SIGNING_CERTIFICATE_BASE64 }}
      DOTNET_SIGNING_CERTIFICATE_PASSWORD: ${{ secrets.DOTNET_SIGNING_CERTIFICATE_PASSWORD }}
      DOTNET_NUGET_API_KEY: ${{ secrets.DOTNET_NUGET_API_KEY }}
```

### Node.js Package Publish
```yaml
jobs:
  publish:
    uses: ./.github/workflows/nodejs-build.yml
    secrets:
      NPM_REGISTRY_PUBLISH_TOKEN: ${{ secrets.NPM_REGISTRY_PUBLISH_TOKEN }}
      GITHUB_PACKAGES_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Docker Build & Push
```yaml
jobs:
  docker:
    uses: ./.github/workflows/dotnet-build.yml
    secrets:
      DOCKER_REGISTRY_USERNAME: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
      DOCKER_REGISTRY_PASSWORD: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
```

## Troubleshooting

### Secret Not Found
- Check the exact name (case-sensitive)
- Verify scope (repository/organization/environment)
- Ensure proper permissions

### Authentication Failed
- Verify secret value is correct
- Check if token/key has expired
- Confirm correct permissions/scopes

### Wrong Secret Used
- Review the naming convention
- Check for typos in workflow files
- Verify you're using the right secret for the purpose

## Maintenance

### Regular Reviews
- Quarterly: Review all secrets for usage
- Annually: Rotate all long-lived secrets
- On-demand: Update after security incidents

### Documentation
- Keep this document updated with new secrets
- Document expiration dates
- Note any special configuration requirements

## Contact

For questions about secrets management:
- Security Team: security@your-org.com
- DevOps Team: devops@your-org.com
- Create an issue with the `secrets-management` label