# 🖥️ .NET Desktop Build Workflow

## Overview

The **`.NET Desktop Build`** workflow provides a comprehensive, reusable GitHub Actions workflow for building, testing, signing, and packaging .NET desktop applications. It supports WPF, Windows Forms, MAUI, and console applications with extensive configuration options.

## Features

### Core Capabilities
- ✅ **Multi-Framework Support**: WPF, Windows Forms, MAUI, Console Apps
- ✅ **.NET 8+ LTS**: Optimized for .NET 8 (LTS) and newer versions
- ✅ **Multiple Configurations**: Debug, Release, and custom configurations
- ✅ **Multi-Platform**: x64, x86, ARM64 support
- ✅ **Publishing Options**: Single-file, self-contained, framework-dependent, MSIX
- ✅ **Code Signing**: Certificate-based signing with timestamping
- ✅ **Automated Testing**: Unit tests with coverage reporting
- ✅ **Artifact Management**: Automatic artifact creation and retention

### Advanced Features
- 🔒 **Secure Certificate Handling**: Base64 encoded certificates in secrets
- 📊 **Code Coverage**: Configurable coverage thresholds
- 📦 **MSIX Packaging**: Windows Store-ready packages
- 🎯 **Trimming & AOT**: Size and performance optimizations
- 🔄 **Matrix Builds**: Parallel builds for multiple configurations
- 📝 **Detailed Logging**: Configurable verbosity levels

## Quick Start

### Basic Usage

```yaml
name: Build My App

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-desktop-build.yml@main
    with:
      dotnet-version: '8.0.x'
      solution-path: 'src/MyApp.sln'
      configurations: '["Release"]'
      platforms: '["x64"]'
```

### Advanced Configuration

```yaml
jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-desktop-build.yml@main
    with:
      # .NET Configuration
      dotnet-version: '8.0.x'
      configurations: '["Debug", "Release"]'
      platforms: '["x64", "x86"]'
      
      # Project Settings
      solution-path: 'src/MyApp.sln'
      test-project-pattern: '**/*Tests.csproj'
      
      # Publishing
      publish-type: 'single-file'
      include-native-libs: true
      enable-compression: true
      trimming: true
      ready-to-run: true
      
      # Code Signing
      sign-output: true
      timestamp-server: 'http://timestamp.digicert.com'
      
      # Testing
      run-tests: true
      collect-coverage: true
      coverage-threshold: 80
      
      # Build Options
      verbosity: 'detailed'
      treat-warnings-as-errors: true
      
      # Artifacts
      upload-artifacts: true
      artifact-name: 'my-app'
      artifact-retention-days: 30
      
    secrets:
      SIGNING_CERTIFICATE: ${{ secrets.CODE_SIGNING_CERT }}
      CERTIFICATE_PASSWORD: ${{ secrets.CERT_PASSWORD }}
```

## Configuration Options

### Required Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `solution-path` or `project-path` | Path to solution or project file | `**/*.sln` |

### Build Configuration

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `dotnet-version` | .NET SDK version | `8.0.x` | `6.0.x`, `7.0.x`, `8.0.x`, `9.0.x` |
| `configurations` | Build configurations (JSON array) | `["Release"]` | `Debug`, `Release`, custom |
| `platforms` | Target platforms (JSON array) | `["x64"]` | `x64`, `x86`, `arm64` |
| `verbosity` | MSBuild verbosity | `normal` | `quiet`, `minimal`, `normal`, `detailed`, `diagnostic` |
| `treat-warnings-as-errors` | Treat warnings as errors | `false` | `true`, `false` |

### Publishing Options

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `publish-type` | Publishing type | `self-contained` | `single-file`, `framework-dependent`, `self-contained`, `msix` |
| `include-native-libs` | Include native libraries | `true` | `true`, `false` |
| `enable-compression` | Enable single-file compression | `true` | `true`, `false` |
| `trimming` | Enable assembly trimming | `false` | `true`, `false` |
| `ready-to-run` | Enable R2R compilation | `true` | `true`, `false` |

### MSIX Packaging

| Input | Description | Default |
|-------|-------------|---------|
| `create-msix` | Create MSIX package | `false` |
| `wap-project-path` | Windows Application Packaging project | `""` |
| `app-version` | Application version | `1.0.0` |

### Code Signing

| Input | Description | Default |
|-------|-------------|---------|
| `sign-output` | Enable code signing | `false` |
| `certificate-subject` | Certificate subject (Windows store) | `""` |
| `timestamp-server` | Timestamp server URL | `http://timestamp.digicert.com` |

### Testing Options

| Input | Description | Default |
|-------|-------------|---------|
| `run-tests` | Run unit tests | `true` |
| `test-filter` | Test filter expression | `""` |
| `collect-coverage` | Collect code coverage | `false` |
| `coverage-threshold` | Minimum coverage percentage | `0` |

### Artifact Management

| Input | Description | Default |
|-------|-------------|---------|
| `upload-artifacts` | Upload build artifacts | `true` |
| `artifact-name` | Artifact name | `dotnet-desktop-build` |
| `artifact-retention-days` | Retention period (days) | `30` |

### Runner Configuration

| Input | Description | Default |
|-------|-------------|---------|
| `runs-on` | Runner OS | `windows-latest` |
| `timeout-minutes` | Job timeout | `60` |

## Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `SIGNING_CERTIFICATE` | Base64 encoded PFX certificate | When `sign-output: true` |
| `CERTIFICATE_PASSWORD` | Certificate password | When using certificate |
| `NUGET_API_KEY` | NuGet API key for private feeds | Optional |

## Publishing Types

### Single File
Creates a single executable containing all dependencies:

```yaml
publish-type: 'single-file'
include-native-libs: true
enable-compression: true
```

### Self-Contained
Includes .NET runtime with the application:

```yaml
publish-type: 'self-contained'
trimming: true  # Optional: reduce size
```

### Framework-Dependent
Requires .NET runtime on target machine:

```yaml
publish-type: 'framework-dependent'
```

### MSIX Package
Creates Windows Store-ready package:

```yaml
create-msix: true
wap-project-path: 'Package/MyApp.Package.wapproj'
publish-type: 'msix'
```

## Code Signing

### Prepare Certificate

1. **Export certificate as PFX**:
   ```powershell
   Export-PfxCertificate -Cert $cert -FilePath "cert.pfx" -Password $password
   ```

2. **Convert to Base64**:
   ```powershell
   $pfx_cert = Get-Content 'cert.pfx' -Encoding Byte
   [System.Convert]::ToBase64String($pfx_cert) | Out-File 'cert_base64.txt'
   ```

3. **Add to GitHub Secrets**:
   - `SIGNING_CERTIFICATE`: Contents of `cert_base64.txt`
   - `CERTIFICATE_PASSWORD`: Certificate password

### Usage in Workflow

```yaml
with:
  sign-output: true
  timestamp-server: 'http://timestamp.digicert.com'
secrets:
  SIGNING_CERTIFICATE: ${{ secrets.CODE_SIGNING_CERT }}
  CERTIFICATE_PASSWORD: ${{ secrets.CERT_PASSWORD }}
```

## Configuration Files

### Default Configuration
Location: `.github/config/dotnet-desktop-build/default.yml`

```yaml
build:
  dotnet_version: '8.0.x'
  configurations:
    - Release
  platforms:
    - x64
  verbosity: normal

publish:
  type: self-contained
  include_native_libs: true
  enable_compression: true

testing:
  enabled: true
  collect_coverage: false

artifacts:
  upload: true
  retention_days: 30
```

### Application-Specific Configurations

#### WPF Application
`.github/config/dotnet-desktop-build/wpf-app.yml`

#### Windows Forms
`.github/config/dotnet-desktop-build/winforms-app.yml`

#### MAUI Windows
`.github/config/dotnet-desktop-build/maui-windows.yml`

## Examples

### WPF Application with Signing

```yaml
name: Build WPF App

on:
  push:
    tags: [ 'v*' ]

jobs:
  build:
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-desktop-build.yml@main
    with:
      solution-path: 'src/WpfApp.sln'
      publish-type: 'single-file'
      sign-output: true
      configurations: '["Release"]'
      platforms: '["x64", "x86"]'
    secrets:
      SIGNING_CERTIFICATE: ${{ secrets.CERT }}
      CERTIFICATE_PASSWORD: ${{ secrets.CERT_PWD }}
```

### Multi-Project Solution

```yaml
jobs:
  build-all:
    strategy:
      matrix:
        project:
          - path: 'src/App1/App1.csproj'
            type: 'single-file'
          - path: 'src/App2/App2.csproj'
            type: 'self-contained'
    
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-desktop-build.yml@main
    with:
      project-path: ${{ matrix.project.path }}
      publish-type: ${{ matrix.project.type }}
```

### MSIX Package for Store

```yaml
jobs:
  create-msix:
    uses: your-org/automation-templates/.github/workflows/reusable-dotnet-desktop-build.yml@main
    with:
      solution-path: 'src/StoreApp.sln'
      create-msix: true
      wap-project-path: 'Package/StoreApp.Package.wapproj'
      publish-type: 'msix'
      sign-output: true
      app-version: ${{ github.ref_name }}
```

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `version` | Built application version | `1.2.3` |
| `artifacts-path` | Path to build artifacts | `artifacts/Release/x64` |

## Best Practices

### 1. Version Management
```yaml
app-version: ${{ github.ref_name }}  # Use git tag as version
```

### 2. Matrix Builds
```yaml
strategy:
  matrix:
    config: [Debug, Release]
    platform: [x64, x86]
```

### 3. Conditional Signing
```yaml
sign-output: ${{ github.event_name == 'release' }}
```

### 4. Optimized Builds
```yaml
# For production
trimming: true
ready-to-run: true
enable-compression: true

# For development
trimming: false
ready-to-run: false
```

### 5. Test Filtering
```yaml
test-filter: 'Category!=LongRunning'
```

## Troubleshooting

### Common Issues

1. **Certificate not found**
   - Ensure certificate is properly Base64 encoded
   - Check secret name matches

2. **Build fails on specific platform**
   - Verify project targets the platform
   - Check runtime identifier support

3. **MSIX packaging fails**
   - Ensure Package.appxmanifest is configured
   - Verify certificate matches publisher

4. **Tests not running**
   - Check test project pattern
   - Verify test discovery

### Debug Mode

Enable detailed logging:
```yaml
with:
  verbosity: 'diagnostic'
```

## Performance Tips

1. **Use caching** for NuGet packages
2. **Parallelize** matrix builds
3. **Filter tests** to reduce runtime
4. **Enable incremental** builds
5. **Use artifact retention** wisely

## Security Considerations

1. **Never commit** certificates or passwords
2. **Use GitHub Secrets** for sensitive data
3. **Enable signing** for production builds
4. **Validate** dependencies regularly
5. **Review** third-party actions

## Migration Guide

### From Template Workflow

1. Replace hardcoded values with inputs
2. Move secrets to GitHub Secrets
3. Update paths to match your structure
4. Configure publishing type
5. Add signing if needed

### From Azure DevOps

1. Convert pipeline YAML to GitHub Actions
2. Map build tasks to workflow inputs
3. Update artifact handling
4. Configure runners

## Support

- 📚 [Documentation](https://github.com/your-org/automation-templates)
- 🐛 [Issues](https://github.com/your-org/automation-templates/issues)
- 💬 [Discussions](https://github.com/your-org/automation-templates/discussions)
- 📧 [Contact](mailto:devops@your-org.com)

## License

This workflow is part of the Automation Templates repository and follows the same license terms.