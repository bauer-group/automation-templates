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
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
    with:
      dotnet-version: '8.0.x'
      project-path: 'src/MyProject.csproj'
      run-tests: true
      upload-artifacts: true
```

### Advanced Configuration

```yaml
jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
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
| `dotnet-version` | .NET SDK version(s) | `8.0.x` | `6.0.x`, `7.0.x`, `8.0.x`, `9.0.x` |
| `dotnet-version-file` | Path to global.json | `''` | File path |
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
| `runs-on` | Runner OS | `ubuntu-latest` | `ubuntu-latest`, `windows-latest`, `macos-latest` |
| `timeout-minutes` | Job timeout | `30` | Minutes |

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
| `SONAR_TOKEN` | SonarCloud token | For code analysis |

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
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
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
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
    with:
      project-path: 'src/MyLibrary.csproj'
      create-package: true
      include-symbols: true
      push-to-nuget: true
    secrets:
      NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

### Blazor WebAssembly

```yaml
jobs:
  build-blazor:
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
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
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
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
    
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-build.yml@main
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