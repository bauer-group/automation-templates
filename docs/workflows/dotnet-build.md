# 🚀 .NET Build & Test Workflow

## Overview

The **`.NET Build & Test`** workflow is a comprehensive, reusable GitHub Actions workflow for building, testing, and deploying .NET applications. It supports web APIs, libraries, Blazor WebAssembly, microservices, and console applications with extensive configuration options.

## Features

### Core Capabilities
- ✅ **Multi-Platform Support**: Linux, Windows, macOS
- ✅ **.NET 8+ LTS**: Optimized for .NET 8 (LTS) with support for 6.0+
- ✅ **Project Types**: Web APIs, Class Libraries, Blazor, Microservices, Console Apps
- ✅ **Matrix Builds**: Parallel builds across OS, .NET versions, configurations
- ✅ **Docker Support**: Build and push container images
- ✅ **NuGet Packages**: Create and publish NuGet packages
- ✅ **Code Coverage**: Multiple coverage formats with thresholds
- ✅ **Code Analysis**: Static analysis and quality checks

### Advanced Features
- 🐳 **Container Optimization**: Multi-stage builds, Alpine support
- 📦 **Package Management**: Symbol packages, source linking
- 🔍 **Testing**: Unit, integration, E2E test support
- 📊 **Reporting**: Test results, coverage reports, code metrics
- 🚀 **CI/CD Ready**: Artifact management, deployment outputs
- ⚡ **Performance**: Dependency caching, parallel execution

## Quick Start

### Basic Usage

```yaml
name: Build My Project

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      dotnet-version: '8.0.x'
      project-path: 'src/MyProject.csproj'
      run-tests: true
      upload-artifacts: true
```

### Required Caller Permissions

This workflow calls `modules-code-quality.yml`, which declares `pull-requests: write`. A called workflow can only **restrict** the caller's permissions, never extend them, so the scope has to come from your calling job:

```yaml
jobs:
  build:
    permissions:
      contents: read
      pull-requests: write    # required by modules-code-quality.yml
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      dotnet-version: '8.0.x'
    secrets: inherit
```

This applies **even with `enable-sonar` left at its default `false`**. GitHub validates the permissions of every called workflow when the run is created, before any job `if:` is evaluated — the opt-in gate does not spare you the scope.

Without it the run never starts. There is no job and no log, only `startup_failure`:

```text
The workflow is requesting 'pull-requests: write', but is only allowed 'pull-requests: none'.
```

Declare the scope explicitly instead of relying on the default. A **partial** `permissions:` block sets every scope it does not name to `none`, and the `Read repository contents and package permissions` repository default is already `pull-requests: none`. Only the `Read and write permissions` default covers it implicitly.

See [GHCR internal visibility](../ghcr-internal-visibility.md) for the full ceiling rule and the same trap applied to `packages: read`.

### Advanced Configuration

```yaml
jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      # .NET Configuration
      dotnet-version: '8.0.x'
      configuration: 'Release'
      
      # Project Settings
      project-path: 'src/MyApi.csproj'
      working-directory: '.'
      
      # Build Options
      treat-warnings-as-errors: true
      verbosity: 'minimal'
      
      # Testing
      run-tests: true
      collect-coverage: true
      coverage-threshold: 80
      
      # Code Analysis
      run-code-analysis: true
      analysis-level: 'recommended'
      
      # Publishing
      publish: true
      self-contained: false
      
      # Docker
      build-docker: true
      dockerfile-path: './Dockerfile'
      
      # NuGet Package
      create-package: true
      push-to-nuget: true
      
    secrets:
      NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
      DOCKER_USERNAME: ${{ secrets.DOCKER_USER }}
      DOCKER_PASSWORD: ${{ secrets.DOCKER_PASS }}
```

## Configuration Options

### .NET Configuration

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `dotnet-version` | .NET SDK version(s) | `10.0.x` | `8.0.x`, `9.0.x`, `10.0.x` |
| `global-json-file` | Path to global.json | `''` | File path |
| `dotnet-quality` | SDK quality level | `''` | `daily`, `signed`, `validated`, `preview`, `ga` |

### Project Configuration

| Input | Description | Default |
|-------|-------------|---------|
| `project-path` | Path to project/solution | `.` |
| `working-directory` | Working directory | `.` |
| `configuration` | Build configuration | `Release` |

### Build Options

| Input | Description | Default |
|-------|-------------|---------|
| `build-args` | Additional build arguments | `''` |
| `restore-args` | Additional restore arguments | `''` |
| `verbosity` | Logging verbosity | `normal` |
| `treat-warnings-as-errors` | Treat warnings as errors | `false` |

### Assembly Signing (SNK)

| Input           | Description                                                          | Default |
|-----------------|----------------------------------------------------------------------|---------|
| `snk-file-path` | Path where SNK key should be created (relative to working-directory) | `''`    |

The `snk-file-path` must match the `AssemblyOriginatorKeyFile` setting in your `.csproj` or `Directory.Build.props`. The workflow decodes `DOTNET_SIGNKEY_BASE64` secret and writes it to this path before building.

> **PR Builds:** When `snk-file-path` is configured but the `DOTNET_SIGNKEY_BASE64` secret is not available (e.g. pull requests from forks), the workflow automatically disables assembly signing via MSBuild overrides (`-p:SignAssembly=false`). A warning annotation is emitted so reviewers can see that signing was skipped. The build will succeed but assemblies will not be strong-name signed.
>
> To suppress the warning entirely, only pass `snk-file-path` on non-PR events:
>
> ```yaml
> snk-file-path: ${{ github.event_name != 'pull_request' && 'build/MyLibrary.snk' || '' }}
> ```

### Runtime Configuration

| Input | Description | Default | Examples |
|-------|-------------|---------|----------|
| `runtime` | Target runtime | `''` | `linux-x64`, `win-x64`, `osx-x64` |
| `self-contained` | Self-contained deployment | `false` | `true`, `false` |

### Testing Configuration

| Input | Description | Default |
|-------|-------------|---------|
| `run-tests` | Run unit tests | `true` |
| `test-filter` | Test filter expression | `''` |
| `test-args` | Additional test arguments | `''` |
| `test-logger` | Test logger format | `trx;LogFileName=test-results.trx` |

### Code Coverage

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `collect-coverage` | Collect coverage | `false` | `true`, `false` |
| `coverage-type` | Coverage format | `cobertura` | `cobertura`, `opencover`, `coverlet` |
| `coverage-threshold` | Minimum coverage % | `0` | `0-100` |
| `coverage-exclude` | Exclusions | `''` | Comma-separated |

### Code Analysis

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `run-code-analysis` | Run analysis | `false` | `true`, `false` |
| `analysis-level` | Analysis level | `recommended` | `none`, `default`, `minimum`, `recommended`, `all` |

### Publishing Options

| Input | Description | Default |
|-------|-------------|---------|
| `publish` | Publish application | `false` |
| `publish-args` | Additional publish arguments | `''` |
| `output-directory` | Output directory | `./publish` |

### Package Management

| Input | Description | Default |
|-------|-------------|---------|
| `create-package` | Create NuGet package | `false` |
| `package-version` | Package version | `''` |
| `include-symbols` | Include symbols | `true` |
| `include-source` | Include source | `false` |
| `push-to-nuget` | Push to NuGet | `false` |
| `nuget-source` | NuGet source URL | `https://api.nuget.org/v3/index.json` |

### Docker Support

| Input | Description | Default |
|-------|-------------|---------|
| `build-docker` | Build Docker image | `false` |
| `dockerfile-path` | Dockerfile path | `./Dockerfile` |
| `docker-image-name` | Image name | `''` |
| `docker-registry` | Registry URL | `''` |

### Artifact Management

| Input | Description | Default |
|-------|-------------|---------|
| `upload-artifacts` | Upload artifacts | `true` |
| `artifact-name` | Artifact name | `dotnet-build` |
| `artifact-path` | Artifact path pattern | `''` |
| `artifact-retention-days` | Retention days | `30` |

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
runs-on: 'windows-latest'

# Self-hosted (JSON array)
runs-on: '["self-hosted", "linux"]'
runs-on: '["self-hosted", "linux", "docker"]'
runs-on: '["self-hosted", "Windows", "vs2022"]'
```

See [Self-Hosted Runner Documentation](../self-hosted-runners.md) for details.

### Matrix Support

| Input | Description | Default |
|-------|-------------|---------|
| `enable-matrix` | Enable matrix builds | `false` |
| `matrix-os` | OS matrix (JSON) | `["ubuntu-latest"]` |
| `matrix-dotnet` | .NET matrix (JSON) | `["8.0.x"]` |

## Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `NUGET_API_KEY` | NuGet API key | When pushing packages |
| `DOCKER_USERNAME` | Docker username | When pushing images |
| `DOCKER_PASSWORD` | Docker password | When pushing images |
| `CODECOV_TOKEN` | Codecov token | For coverage upload |
| `SONARQUBE_TOKEN` | Self-hosted SonarQube Server token | When `enable-sonar: true` |
| `SONARQUBE_HOST_URL` | Self-hosted SonarQube Server URL | When `enable-sonar: true` |
| `DOTNET_SIGNKEY_BASE64` | Base64-encoded SNK key for assembly signing | When `snk-file-path` is set |
| `DOTNET_NUGET_RESTORE_CREDENTIALS` | PAT (`read:packages`) for restoring from the private feed named by `nuget-source-name`. Not the same thing as the publish API key - see [Private NuGet Feeds](#private-nuget-feeds). | When `nuget-source-name` is set |

## Private NuGet Feeds

Restore from an authenticated feed - GitHub Packages, Azure Artifacts, an internal
mirror - without the credential ever reaching a file, and without the repository's
`nuget.config` being modified.

### How it works

The workflow composes `Username=<user>;Password=<token>` and exports it as
`NuGetPackageSourceCredentials_<sourceName>`. NuGet reads that variable **before** it
reads any `nuget.config`, so:

- no credential is written to disk at any point;
- the repository's committed `nuget.config` survives the run untouched, including
  `packageSourceMapping` - which is what stops a public package of the same name being
  resolved instead of yours;
- `nuget.exe`, the `dotnet` CLI and MSBuild all honour it, because the lookup lives in
  the `NuGet.Configuration` assembly they share.

### Setup

**1. Declare the source in the repository's `nuget.config`:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="GITHUB" value="https://nuget.pkg.github.com/bauer-group/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    <packageSource key="GITHUB">
      <package pattern="BAUERGROUP.Shared.Industrial.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
```

A source NuGet does not know about cannot have a credential attached to it. If the
repository ships no `nuget.config`, set `nuget-source-url` instead and the workflow
registers the source in the runner's **user-level** config - never in the repository's.

**2. Store the token** as `DOTNET_NUGET_RESTORE_CREDENTIALS` - the PAT alone, with the
`read:packages` scope. The workflow composes the rest.

**3. Name the source:**

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.sln'
      nuget-source-name: 'GITHUB'
    secrets: inherit
```

### Inputs

| Input | Description |
|-------|-------------|
| `nuget-source-name` | Package source key in `nuget.config`, spelled exactly. Empty disables authenticated restore entirely. |

Leaving `nuget-source-name` empty is the normal case, and it stays a no-op even when
`DOTNET_NUGET_RESTORE_CREDENTIALS` exists as an organisation secret and arrives via
`secrets: inherit`. NuGet only ever reads `NuGetPackageSourceCredentials_<name>`, so a
credential with no source is never composed into a variable and never leaves the runner.
The run logs a notice saying the credential was inherited but unused, in case the input
was meant to be set.

| Input | Description |
|-------|-------------|
| `nuget-source-url` | Feed URL. Only used when the key is not configured anywhere; registered at user level. |
| `nuget-username` | HTTP Basic username. Defaults to the workflow actor. GitHub Packages ignores it; Azure Artifacts does not. |

### Two traps this closes

**The source key is case-sensitive - on Linux only.** NuGet resolves the variable with
`Environment.GetEnvironmentVariable`, which is case-insensitive on Windows and
case-**sensitive** on Linux. `github` instead of `GITHUB` therefore builds green on
`windows-latest` and fails the day the job moves to `ubuntu-latest`. The workflow
compares the spelling up front and fails with both spellings named.

**A malformed credential is discarded in silence.** If the composed value is not
exactly `Username=...;Password=...`, NuGet drops it with no log line at all and the
symptom is a bare HTTP 401 that appears to blame the token. A trailing newline on a
pasted secret and a semicolon inside it both do this. Both are detected and rejected
before restore runs.

### Restore is not publish

`DOTNET_NUGET_RESTORE_CREDENTIALS` is deliberately separate from the publish key. A
NuGet.org **API key** is a publish credential and GitHub Packages does not accept one
for restore at all - restore authenticates with HTTP Basic and needs a PAT carrying
`read:packages`. They are not interchangeable.

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `version` | Application/package version | `1.2.3` |
| `test-results` | Path to test results | `/tmp/test-results` |
| `coverage-report` | Path to coverage report | `/tmp/coverage.xml` |
| `package-path` | Path to NuGet package | `/tmp/packages/lib.1.2.3.nupkg` |
| `docker-image` | Docker image tag | `myapp:1.2.3` |

## Project Type Examples

### Web API with Docker

```yaml
jobs:
  build-api:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/WebApi.csproj'
      build-docker: true
      dockerfile-path: './Dockerfile'
      docker-registry: 'ghcr.io'
      docker-image-name: '${{ github.repository }}'
    secrets:
      DOCKER_USERNAME: ${{ github.actor }}
      DOCKER_PASSWORD: ${{ secrets.GITHUB_TOKEN }}
```

### Class Library with NuGet

```yaml
jobs:
  build-library:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      create-package: true
      include-symbols: true
      push-to-nuget: true
    secrets:
      NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

### Signed Assembly Build

For projects with `SignAssembly=true` in `.csproj` or `Directory.Build.props`:

```yaml
jobs:
  build-signed:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'MyLibrary.sln'
      # Path must match AssemblyOriginatorKeyFile in your project
      snk-file-path: 'build/MyLibrary.snk'
      run-tests: true
    secrets: inherit
```

The workflow decodes `DOTNET_SIGNKEY_BASE64` and creates the SNK file at the specified path before building. If the secret is not available (e.g. in PR builds), signing is automatically skipped with a warning annotation. Your project configuration should look like:

```xml
<!-- Directory.Build.props -->
<PropertyGroup>
  <SignAssembly>true</SignAssembly>
  <AssemblyOriginatorKeyFile>$(MSBuildThisFileDirectory)build\MyLibrary.snk</AssemblyOriginatorKeyFile>
</PropertyGroup>
```

### Blazor WebAssembly

```yaml
jobs:
  build-blazor:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/BlazorApp.csproj'
      publish: true
      output-directory: './dist'
      build-args: '-p:BlazorEnableCompression=true'
      publish-args: '-p:BlazorWebAssemblyEnableLinking=true'
```

### Microservice

```yaml
jobs:
  build-microservice:
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/Microservice.csproj'
      runtime: 'linux-musl-x64'
      self-contained: true
      build-docker: true
      run-code-analysis: true
```

## Matrix Build Example

```yaml
jobs:
  matrix-build:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        dotnet: ['6.0.x', '8.0.x']
        configuration: [Debug, Release]
    
    uses: your-org/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      dotnet-version: ${{ matrix.dotnet }}
      configuration: ${{ matrix.configuration }}
      runs-on: ${{ matrix.os }}
      project-path: 'src/MyProject.csproj'
```

## Configuration Files

### Default Configuration
Location: `.github/config/dotnet-build/default.yml`

```yaml
dotnet:
  version: '8.0.x'
build:
  configuration: Release
  verbosity: normal
testing:
  enabled: true
coverage:
  enabled: false
  threshold: 0
```

### Project-Specific Configurations

- **Web API**: `.github/config/dotnet-build/web-api.yml`
- **Class Library**: `.github/config/dotnet-build/class-library.yml`
- **Blazor WebAssembly**: `.github/config/dotnet-build/blazor-wasm.yml`
- **Microservice**: `.github/config/dotnet-build/microservice.yml`

### Example Workflows

All example workflows are located in `github/workflows/examples/dotnet-build/`:
- `simple-library.yml` - Simple class library build
- `web-api-docker.yml` - Web API with Docker deployment
- `nuget-package-publish.yml` - NuGet package publishing
- `blazor-wasm-deploy.yml` - Blazor WebAssembly deployment
- `matrix-cross-platform.yml` - Cross-platform matrix builds
- `microservice-k8s.yml` - Microservice with Kubernetes

## Best Practices

### 1. Version Management
```yaml
package-version: ${{ startsWith(github.ref, 'refs/tags/v') && github.ref_name || format('1.0.0-preview.{0}', github.run_number) }}
```

### 2. Conditional Publishing
```yaml
publish: ${{ github.ref == 'refs/heads/main' }}
push-to-nuget: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

### 3. Environment-Specific Builds
```yaml
configuration: ${{ github.ref == 'refs/heads/main' && 'Release' || 'Debug' }}
```

### 4. Coverage Thresholds
```yaml
coverage-threshold: ${{ github.event_name == 'pull_request' && 80 || 0 }}
```

### 5. Docker Tagging
```yaml
docker-image-name: '${{ github.repository }}:${{ github.sha }}'
```

## Docker Support

### Multi-Stage Dockerfile Example

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

### Container Registry Options

- **GitHub Container Registry**: `ghcr.io`
- **Docker Hub**: `docker.io`
- **Azure Container Registry**: `*.azurecr.io`
- **AWS ECR**: `*.dkr.ecr.*.amazonaws.com`

## Testing Strategies

### Test Categories

```yaml
test-filter: 'Category!=LongRunning & Category!=Integration'
```

### Parallel Testing

```yaml
test-args: '--parallel --max-parallel-threads 4'
```

### Test Result Formats

- **TRX**: Visual Studio test results
- **HTML**: Human-readable reports
- **JUnit**: CI/CD integration

## Troubleshooting

### Common Issues

1. **Package restore fails**
   - Check network connectivity
   - Verify NuGet sources
   - Clear NuGet cache

2. **Tests not discovered**
   - Verify test project references
   - Check test framework packages
   - Review filter expressions

3. **Docker build fails**
   - Verify Dockerfile path
   - Check base image availability
   - Review build context

4. **Coverage below threshold**
   - Exclude generated code
   - Add more test cases
   - Review threshold settings

5. **"No test report files were found"**
   - This warning appears when no `.trx` files are generated
   - **Cause**: No test projects exist or `run-tests: true` is set but the solution has no tests
   - **Solution A**: Set `run-tests: false` if your project has no tests:

     ```yaml
     uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
     with:
       run-tests: false
     ```

   - **Solution B**: Add a test project with `Microsoft.NET.Test.Sdk` package reference
   - The workflow now gracefully skips test reporting when no test projects are found

6. **"Input required and not supplied: path" (Upload artifact)**
   - This error occurs when test results path is empty
   - **Cause**: Tests didn't run or no test projects were found
   - **Solution**: Same as issue #5 above - set `run-tests: false` or add test projects
   - The workflow now includes `if-no-files-found: ignore` to prevent this error

### For Developers Using This Workflow

If your repository uses this reusable workflow and you see test-related warnings:

```yaml
# Option 1: Disable tests if your project has none
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      run-tests: false  # No test projects in this repo

# Option 2: Ensure test projects are properly configured
# Your test project .csproj must include:
#   <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
#   <PackageReference Include="xunit" Version="2.*" /> (or NUnit/MSTest)
#   <PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
```

### Debug Mode

Enable verbose logging:
```yaml
verbosity: 'diagnostic'
```

## Performance Optimization

1. **Cache dependencies**: Enabled by default
2. **Parallel builds**: Use matrix strategy
3. **Selective testing**: Use test filters
4. **Incremental builds**: Leverage build cache
5. **Container optimization**: Multi-stage builds

## Security Considerations

1. **Use secrets** for sensitive data
2. **Enable code analysis** for security checks
3. **Scan Docker images** for vulnerabilities
4. **Sign NuGet packages** when publishing
5. **Use dependabot** for dependency updates

## Migration Guide

### From Azure DevOps

1. Convert pipeline YAML syntax
2. Map tasks to workflow inputs
3. Update variable references
4. Configure service connections as secrets

### From Jenkins

1. Convert pipeline script to YAML
2. Map plugins to actions
3. Update credential management
4. Configure webhooks

## Support

- 📚 [Documentation](https://github.com/your-org/automation-templates)
- 🐛 [Issues](https://github.com/your-org/automation-templates/issues)
- 💬 [Discussions](https://github.com/your-org/automation-templates/discussions)
- 📧 [Contact](mailto:devops@your-org.com)

## License

This workflow is part of the Automation Templates repository and follows the same license terms.