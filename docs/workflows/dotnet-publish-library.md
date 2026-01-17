# .NET Library Publishing Workflow

This document describes the .NET library publishing system provided by the automation-templates repository. The system provides comprehensive support for building, testing, signing, and publishing .NET libraries to NuGet.org and GitHub Packages.

## Overview

The .NET library publishing system provides:

- **Reusable Workflows**: Pre-configured workflows for library publishing
- **Composite Actions**: Modular .NET build and pack components
- **Multi-Target Support**: Build for multiple .NET versions (net8.0, net9.0, net10.0)
- **Assembly Signing**: Strong name key (SNK) signing support
- **NuGet Publishing**: Publish to NuGet.org with Trusted Publishing (OIDC) or API key
- **GitHub Packages**: Publish to GitHub Packages with automatic authentication
- **Semantic Versioning**: Integration with semantic-release for automatic versioning
- **Graceful Test Handling**: Tests are optional - skip if none exist, don't fail

## Quick Start

### Basic Usage (Build Only)

```yaml
name: .NET Build
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary/MyLibrary.csproj'
      run-tests: true
    secrets: inherit
```

### Publish to NuGet.org

```yaml
name: .NET Publish
on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: write
  packages: write
  id-token: write  # Required for Trusted Publishing

jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary/MyLibrary.csproj'
      push-to-nuget: true
      push-to-github: true
    secrets: inherit
```

### With Semantic Release Integration

```yaml
name: Release & Publish

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      force-release:
        description: 'Force create release'
        type: boolean
        default: false

permissions:
  contents: write
  packages: write
  id-token: write

jobs:
  # Validation
  validate:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyLibrary.sln'
      run-tests: true

  # Semantic Release
  release:
    needs: validate
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
      force-release: ${{ inputs.force-release || false }}
    secrets: inherit

  # NuGet Publish
  publish:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary/MyLibrary.csproj'
      release-version: ${{ needs.release.outputs.version }}
      sign-assembly: true
      push-to-nuget: true
      push-to-github: true
    secrets: inherit
```

## Publishing Configuration

### Publishing Options

| Option | Description | When to Use |
|--------|-------------|-------------|
| Build Only | `push-to-nuget: false`, `push-to-github: false` | PR validation, local testing |
| GitHub Packages Only | `push-to-github: true` | Internal libraries, pre-release testing |
| NuGet.org Only | `push-to-nuget: true` | Public open-source libraries |
| Both | `push-to-nuget: true`, `push-to-github: true` | Enterprise libraries with public distribution |

### NuGet Authentication Methods

The workflow supports two authentication methods for NuGet.org:

#### 1. Trusted Publishing (OIDC) - Recommended

Trusted Publishing uses OpenID Connect (OIDC) for secure, keyless authentication:

```yaml
permissions:
  id-token: write  # Required for OIDC

jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      push-to-nuget: true
      nuget-auth-method: 'trusted-publishing'  # Default
```

**Setup on NuGet.org:**
1. Go to NuGet.org > Manage Packages > Your Package > Trusted Publishers
2. Add GitHub Actions as trusted publisher:
   - Repository: `your-org/your-repo`
   - Workflow: `dotnet-publish-library.yml` (or your calling workflow)
   - Environment: `production` (optional)

#### 2. API Key (Fallback)

For repositories without Trusted Publishing configured:

```yaml
jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      push-to-nuget: true
      nuget-auth-method: 'api-key'
    secrets:
      NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

## Components

### 1. Reusable Workflow

**File**: `.github/workflows/dotnet-publish-library.yml`

The main workflow orchestrates the entire publishing process:

- **Build Job**: .NET SDK setup, restore, build, and test
- **Pack Job**: NuGet package creation with versioning
- **Publish NuGet Job**: Push to NuGet.org (conditional)
- **Publish GitHub Job**: Push to GitHub Packages (conditional)
- **Version Commit Job**: Commit version updates (conditional)
- **Summary Job**: Pipeline summary generation

### 2. Composite Action

**File**: `.github/actions/dotnet-nuget/action.yml`

The .NET NuGet action provides:

- Multi-SDK version support
- NuGet package caching
- Automatic test discovery
- Code coverage collection
- Assembly signing with SNK
- Symbol package generation
- Deterministic builds

## Input Parameters

### Build Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `project-path` | Path to .csproj or .sln file | **Required** |
| `working-directory` | Working directory for commands | `.` |
| `configuration` | Build configuration | `'Release'` |
| `dotnet-version` | .NET SDK version(s) | `'10.0.x'` |

### Testing

| Parameter | Description | Default |
|-----------|-------------|---------|
| `run-tests` | Run tests if projects exist | `true` |
| `test-project-path` | Path to test project (auto-detected) | `''` |
| `test-filter` | Test filter expression | `''` |
| `collect-coverage` | Enable code coverage | `true` |
| `coverage-threshold` | Minimum coverage % (0 to disable) | `0` |

### Versioning

| Parameter | Description | Default |
|-----------|-------------|---------|
| `package-version` | Explicit version (overrides all) | `''` |
| `release-version` | Version from release workflow | `''` |
| `version-suffix` | Pre-release suffix (e.g., preview) | `''` |
| `update-project-version` | Update version in project files | `false` |

### Assembly Signing

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sign-assembly` | Enable SNK signing | `false` |
| `delay-sign` | Use delay signing | `false` |

### Packaging

| Parameter | Description | Default |
|-----------|-------------|---------|
| `create-package` | Create NuGet package | `true` |
| `include-symbols` | Include .snupkg | `true` |
| `include-source` | Include source in symbols | `true` |
| `deterministic-build` | Enable deterministic builds | `true` |

### Publishing

| Parameter | Description | Default |
|-----------|-------------|---------|
| `push-to-nuget` | Publish to NuGet.org | `false` |
| `push-to-github` | Publish to GitHub Packages | `false` |
| `skip-duplicate` | Skip if version exists | `true` |
| `nuget-auth-method` | `'trusted-publishing'` or `'api-key'` | `'trusted-publishing'` |

### Runner Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `runs-on` | Runner for Linux/cross-platform builds | `'ubuntu-latest'` |
| `runs-on-windows` | Runner for Windows-specific builds | `'windows-latest'` |
| `enable-platform-matrix` | Enable parallel Linux + Windows builds | `false` |
| `timeout-minutes` | Job timeout | `30` |
| `cache-enabled` | Enable NuGet caching | `true` |

## Secrets

| Secret | Required When | Description |
|--------|---------------|-------------|
| `NUGET_API_KEY` | `nuget-auth-method: 'api-key'` | NuGet.org API key |
| `DOTNET_SIGNKEY_BASE64` | `sign-assembly: true` | Base64-encoded .snk file |
| `CODECOV_TOKEN` | Coverage upload | Codecov token (optional) |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | Package version |
| `package-path` | Path to .nupkg file (first package) |
| `symbols-path` | Path to .snupkg file (first package) |
| `package-name` | Full package name with version (first package) |
| `package-count` | Number of packages created |
| `package-names` | JSON array of all package names |
| `build-succeeded` | Build success status |
| `test-passed` | Test success status |
| `test-skipped` | Tests skipped (no projects) |
| `coverage-percentage` | Code coverage % |
| `pushed-to-nuget` | NuGet.org publish status |
| `pushed-to-github` | GitHub Packages publish status |
| `has-windows-tfms` | Windows TFMs detected (platform matrix) |
| `has-crossplatform-tfms` | Cross-platform TFMs detected (platform matrix) |

### Multi-Package Solutions

When building a solution with multiple projects, all packages are built and published:

```yaml
# Access outputs
jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary.sln'  # Solution with multiple projects
      push-to-github: true

  post-publish:
    needs: publish
    runs-on: ubuntu-latest
    steps:
      - name: Show package info
        run: |
          echo "Published ${{ needs.publish.outputs.package-count }} packages"
          echo "Packages: ${{ needs.publish.outputs.package-names }}"
```

## Assembly Signing (SNK)

### Why Sign Assemblies?

Strong name signing provides:
- **Assembly Identity**: Unique identity based on name, version, culture, and public key
- **Tamper Detection**: Verification that assemblies haven't been modified
- **GAC Compatibility**: Required for Global Assembly Cache installation
- **InternalsVisibleTo**: Secure internal visibility between signed assemblies

### Setting Up SNK Signing

#### 1. Generate SNK File

Use the provided scripts (see SNK Generation Scripts section) or:

```bash
# Using .NET SDK (cross-platform)
sn -k MyProject.snk

# Or using OpenSSL
openssl genrsa -out key.pem 2048
```

#### 2. Convert to Base64

```bash
# Linux/macOS
base64 -w 0 MyProject.snk > MyProject.snk.base64

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("MyProject.snk"))
```

#### 3. Add to GitHub Secrets

Add the base64 content as `DOTNET_SIGNKEY_BASE64` secret in your repository.

#### 4. Enable in Workflow

```yaml
jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      sign-assembly: true
    secrets:
      DOTNET_SIGNKEY_BASE64: ${{ secrets.DOTNET_SIGNKEY_BASE64 }}
```

### Project Configuration

Your .csproj or Directory.Build.props should include:

```xml
<PropertyGroup>
  <SignAssembly>true</SignAssembly>
  <AssemblyOriginatorKeyFile>$(MSBuildThisFileDirectory)build\MyProject.snk</AssemblyOriginatorKeyFile>
</PropertyGroup>
```

The workflow will override these settings with the decoded SNK file during build.

## Version Detection

The workflow determines package version in this priority order:

1. **`package-version` input**: Explicit version override
2. **`release-version` input**: Version from semantic-release workflow
3. **Git tag**: `refs/tags/v1.2.3` -> `1.2.3`
4. **Directory.Build.props**: `<VersionPrefix>` or `<Version>`
5. **Project file**: `<VersionPrefix>` or `<Version>` in .csproj
6. **Default**: `1.0.0-preview.{run_number}`

### Version Suffix

Add pre-release suffixes:

```yaml
with:
  version-suffix: 'preview'  # Results in: 1.0.0-preview.123
```

## Project Structure Support

The workflow supports various project structures:

### Single Project

```
MyLibrary/
├── src/
│   └── MyLibrary.csproj
└── tests/
    └── MyLibrary.Tests.csproj
```

### Multi-Project Solution

```
MyLibrary/
├── src/
│   ├── MyLibrary.Core/
│   │   └── MyLibrary.Core.csproj
│   └── MyLibrary.Data/
│       └── MyLibrary.Data.csproj
├── tests/
│   └── MyLibrary.Tests/
├── Directory.Build.props
├── Directory.Packages.props
└── MyLibrary.sln
```

### With Signing Key

```
MyLibrary/
├── build/
│   └── MyLibrary.snk
├── src/
│   └── MyLibrary/
│       └── MyLibrary.csproj
├── Directory.Build.props
└── MyLibrary.sln
```

## Windows Desktop / Platform Matrix

For libraries that target Windows-specific TFMs (like `net8.0-windows` for WPF/WinForms), use the platform matrix feature to build on appropriate runners.

### Why Platform Matrix?

- **Windows TFMs require Windows**: `net8.0-windows`, `net9.0-windows` cannot be built on Linux
- **Cross-platform TFMs are flexible**: `net8.0`, `net9.0` can build on any runner
- **Parallel builds**: Build both in parallel for faster CI/CD
- **Auto-detection**: Workflow automatically detects which TFMs require which runner

### Enable Platform Matrix

```yaml
jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyDesktopLib/MyDesktopLib.csproj'
      dotnet-version: '8.0.x,9.0.x'

      # Enable parallel platform builds
      enable-platform-matrix: true

      # Configure runners (optional - these are defaults)
      runs-on: 'ubuntu-latest'
      runs-on-windows: 'windows-latest'

      push-to-nuget: true
    secrets: inherit
```

### How It Works

When `enable-platform-matrix: true`:

1. **Detect Platforms**: Workflow scans `.csproj` and `Directory.Build.props` for TFMs
2. **Split Build**: Creates separate jobs for:
   - Cross-platform TFMs (net8.0, net9.0) → Linux runner
   - Windows TFMs (net8.0-windows, net9.0-windows) → Windows runner
3. **Merge Artifacts**: Combines packages from both builds
4. **Single Release**: Publishes a unified package to NuGet

### Detected Framework Categories

| Category                 | Examples                                 | Runner                       |
|--------------------------|------------------------------------------|------------------------------|
| Cross-Platform           | net6.0, net7.0, net8.0, net9.0, net10.0  | Linux (`runs-on`)            |
| Windows-Specific         | net8.0-windows, net9.0-windows10.0.17763 | Windows (`runs-on-windows`)  |
| Other Platform-Specific  | net8.0-android, net8.0-ios               | Skipped (not supported)      |

### Self-Hosted Windows Runners

For self-hosted runners with Windows:

```yaml
with:
  enable-platform-matrix: true
  runs-on: '["self-hosted", "linux"]'
  runs-on-windows: '["self-hosted", "windows"]'
  cache-enabled: false  # GitHub Actions cache not available on self-hosted
```

### Example .csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <!-- Multi-target: cross-platform + Windows-specific -->
    <TargetFrameworks>net8.0;net8.0-windows;net9.0;net9.0-windows</TargetFrameworks>

    <!-- Windows-specific settings -->
    <UseWPF Condition="$(TargetFramework.Contains('windows'))">true</UseWPF>
  </PropertyGroup>
</Project>
```

## Self-Hosted Runners

Use self-hosted runners with the `runs-on` parameter:

```yaml
jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      runs-on: '["self-hosted", "linux", "docker"]'
      cache-enabled: false  # GitHub Actions cache not available
```

## Best Practices

### 1. Use Trusted Publishing

Prefer OIDC-based Trusted Publishing over API keys for NuGet.org:
- No long-lived secrets to manage
- Automatic token exchange
- Better audit trail

### 2. Enable Deterministic Builds

Keep `deterministic-build: true` (default) for:
- Reproducible builds
- Better debugging experience
- SourceLink support

### 3. Include Symbols

Keep `include-symbols: true` (default) for:
- Better debugging in consuming applications
- Source-stepped debugging
- NuGet.org symbol server integration

### 4. Use Directory.Build.props

Centralize version and build settings:

```xml
<Project>
  <PropertyGroup>
    <VersionPrefix>1.0.0</VersionPrefix>
    <Authors>Your Team</Authors>
    <Company>Your Company</Company>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
  </PropertyGroup>
</Project>
```

### 5. Semantic Versioning

Integrate with semantic-release for automatic versioning based on conventional commits.

## Troubleshooting

### Package Already Exists

If you see "package already exists" errors:

1. Ensure `skip-duplicate: true` (default) to skip silently
2. Check if version was correctly incremented
3. Verify no manual packages were pushed with the same version

### Trusted Publishing Fails

If OIDC authentication fails:

1. Verify `id-token: write` permission is set
2. Check NuGet.org Trusted Publishers configuration
3. Ensure repository and workflow match the configuration
4. Try API key fallback: set `NUGET_API_KEY` secret

### Tests Not Found

If tests are skipped unexpectedly:

1. Check test project naming (should contain `Tests` or `Test`)
2. Verify test project path if specified
3. Check if tests directory exists (`tests/` or `test/`)

### SNK Signing Fails

If assembly signing fails:

1. Verify `DOTNET_SIGNKEY_BASE64` secret is correctly encoded
2. Check that the base64 content doesn't have line breaks
3. Ensure project files don't have conflicting signing settings

### GitHub Packages Authentication

If GitHub Packages push fails:

1. Verify `packages: write` permission
2. Check if package namespace matches repository owner
3. Ensure GITHUB_TOKEN is passed (automatic with `secrets: inherit`)

## SNK Generation Scripts

Helper scripts for generating strong name keys are available:

- **Bash**: `github/dotnet/scripts/create-snk.sh`
- **PowerShell**: `github/dotnet/scripts/create-snk.ps1`

See the scripts documentation for usage details.

## Related Workflows

- **dotnet-build.yml**: Basic .NET build and test workflow
- **modules-semantic-release.yml**: Semantic versioning and release automation
- **docker-build.yml**: For containerized .NET applications

## Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
