# ESP32 Build Workflow

## Overview

The ESP32 Build workflow provides a comprehensive CI/CD solution for ESP32 microcontroller projects using the official [Espressif IDF Docker images](https://hub.docker.com/r/espressif/idf) and [esp-idf-ci-action](https://github.com/espressif/esp-idf-ci-action).

## Features

- **Official Espressif Support**: Uses official Docker images and GitHub Action
- **Multi-Target Builds**: Support for ESP32, ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C6, ESP32-H2
- **Firmware Versioning**: Semantic versioning with automatic version embedding
- **Release Management**: Automated firmware releases with checksums and changelogs
- **Build Caching**: ccache support for faster rebuilds
- **Quality Gates**: Static analysis, unit tests, and compliance checks
- **Artifact Management**: Binary artifacts with metadata for deployment

## Supported Targets

| Target | Description | Status |
|--------|-------------|--------|
| `esp32` | Original ESP32 (Xtensa LX6) | Stable |
| `esp32s2` | ESP32-S2 (Xtensa LX7, USB) | Stable |
| `esp32s3` | ESP32-S3 (Xtensa LX7, AI) | Stable |
| `esp32c3` | ESP32-C3 (RISC-V) | Stable |
| `esp32c6` | ESP32-C6 (RISC-V, WiFi 6) | Stable |
| `esp32h2` | ESP32-H2 (RISC-V, Thread/Zigbee) | Stable |

## Quick Start

### Basic Usage

```yaml
name: ESP32 Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      target: esp32
      idf-version: v5.2
```

### Multi-Target Build

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: iot-device
      targets: esp32,esp32s3,esp32c3
      build-types: release,debug
```

## Configuration

### Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `config-file` | string | `default` | Configuration template to use |
| `target` | string | `esp32` | Single target chip |
| `targets` | string | - | Comma-separated list for matrix builds |
| `idf-version` | string | `v5.2` | ESP-IDF version tag |
| `build-types` | string | `release` | Build types: `release`, `debug`, or both |
| `project-path` | string | `.` | Path to the ESP-IDF project |
| `run-tests` | boolean | `true` | Run unit tests |
| `enable-ccache` | boolean | `true` | Enable build caching |
| `enable-analysis` | boolean | `false` | Run static analysis |
| `create-release` | boolean | `false` | Create GitHub release |
| `artifact-retention` | number | `30` | Days to retain artifacts |

### Configuration Templates

#### `default.yml` - Standard Projects

General-purpose configuration for most ESP32 projects.

```yaml
idf-version: v5.2
target: esp32
build-type: release
ccache: true
tests: true
analysis: false
```

#### `iot-device.yml` - Connected Devices

Optimized for WiFi/Bluetooth IoT devices with OTA support.

```yaml
idf-version: v5.2
targets:
  - esp32
  - esp32s3
  - esp32c3
build-type: release
ccache: true
tests: true
analysis: true
ota-support: true
secure-boot: false
```

#### `industrial.yml` - Industrial Applications

Safety-critical configurations with secure boot and compliance checks.

```yaml
idf-version: v5.2
target: esp32s3
build-types:
  - release
  - debug
ccache: true
tests: true
analysis: true
secure-boot: true
flash-encryption: true
compliance-checks: true
```

## Firmware Release Process

### Version Management

Firmware versions follow semantic versioning and are embedded into the binary:

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

**Examples:**
- `1.0.0` - Production release
- `1.1.0-beta.1` - Beta release
- `1.0.1+build.123` - Patch with build metadata

### Release Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ESP32 Release Pipeline                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────────┐  │
│  │  Build  │───►│  Test   │───►│  Sign   │───►│   Release   │  │
│  │         │    │         │    │         │    │             │  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────────┘  │
│       │              │              │               │           │
│       ▼              ▼              ▼               ▼           │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────────┐  │
│  │ .bin    │    │ Unit    │    │ Secure  │    │ GitHub      │  │
│  │ .elf    │    │ Tests   │    │ Boot    │    │ Release     │  │
│  │ .map    │    │ Pytest  │    │ Signing │    │ Changelog   │  │
│  └─────────┘    └─────────┘    └─────────┘    └─────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Release Artifacts

Each release includes:

| Artifact | Description |
|----------|-------------|
| `firmware-{target}-{version}.bin` | Main application binary |
| `bootloader-{target}-{version}.bin` | Bootloader binary |
| `partition-table-{target}.bin` | Partition table |
| `ota-{target}-{version}.bin` | OTA update package |
| `checksums.sha256` | SHA256 checksums |
| `build-info.json` | Build metadata |

### Build Info Metadata

```json
{
  "version": "1.2.3",
  "target": "esp32s3",
  "idf_version": "v5.2",
  "build_type": "release",
  "build_date": "2026-01-22T10:30:00Z",
  "git_commit": "a1b2c3d4",
  "git_branch": "main",
  "secure_boot": false,
  "flash_encryption": false,
  "checksums": {
    "firmware": "sha256:...",
    "bootloader": "sha256:..."
  }
}
```

## Deployment Strategies

### OTA (Over-The-Air) Updates

```yaml
# Enable OTA support in configuration
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: iot-device
      create-release: true
    secrets:
      OTA_SERVER_URL: ${{ secrets.OTA_SERVER_URL }}
      OTA_API_KEY: ${{ secrets.OTA_API_KEY }}
```

**OTA Update Flow:**

```
┌──────────────────────────────────────────────────────────────┐
│                      OTA Update Flow                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  GitHub Release          OTA Server            ESP32 Device   │
│       │                      │                      │         │
│       │  1. Upload binary    │                      │         │
│       │─────────────────────►│                      │         │
│       │                      │                      │         │
│       │                      │  2. Check version    │         │
│       │                      │◄─────────────────────│         │
│       │                      │                      │         │
│       │                      │  3. Download OTA     │         │
│       │                      │─────────────────────►│         │
│       │                      │                      │         │
│       │                      │  4. Verify & Apply   │         │
│       │                      │                      ├──┐      │
│       │                      │                      │  │      │
│       │                      │                      │◄─┘      │
│       │                      │                      │         │
│       │                      │  5. Report success   │         │
│       │                      │◄─────────────────────│         │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### Factory Provisioning

For mass production, use factory images:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: industrial
      create-factory-image: true
      flash-encryption: true
      secure-boot: true
```

## Security Features

### Secure Boot

Enable secure boot to ensure only signed firmware runs:

```yaml
secure-boot:
  enabled: true
  version: v2  # Recommended for ESP32-S2/S3/C3
  signing-key: ${{ secrets.SECURE_BOOT_SIGNING_KEY }}
```

### Flash Encryption

Protect firmware from readout:

```yaml
flash-encryption:
  enabled: true
  mode: release  # development or release
```

### Signing Keys Management

**Required Secrets:**

| Secret | Description | Required For |
|--------|-------------|--------------|
| `SECURE_BOOT_SIGNING_KEY` | RSA-3072 or ECDSA key | Secure Boot |
| `FLASH_ENCRYPTION_KEY` | AES-256 key | Flash Encryption |
| `OTA_SIGNING_KEY` | Firmware signing key | OTA Updates |

## Quality Gates

### Build Validation

- Compilation without warnings (`-Werror`)
- Size optimization checks
- Memory usage analysis

### Static Analysis

```yaml
analysis:
  enabled: true
  tools:
    - cppcheck
    - clang-tidy
  fail-on-warning: true
```

### Unit Testing

```yaml
tests:
  enabled: true
  framework: unity  # or pytest
  coverage: true
  minimum-coverage: 80
```

## Examples

### Complete IoT Device Pipeline

```yaml
name: IoT Device CI/CD

on:
  push:
    branches: [main, develop]
    tags: ['v*']
  pull_request:
    branches: [main]

jobs:
  # Quick validation for PRs
  validate:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      target: esp32
      build-types: debug
      run-tests: true

  # Full build for main branch
  build:
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: iot-device
      targets: esp32,esp32s3,esp32c3
      build-types: release
      run-tests: true
      enable-analysis: true

  # Release on tag
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: iot-device
      targets: esp32,esp32s3,esp32c3
      create-release: true
    secrets: inherit
```

### Industrial Application with Secure Boot

```yaml
name: Industrial Firmware

on:
  push:
    tags: ['v*']

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: industrial
      target: esp32s3
      secure-boot: true
      flash-encryption: true
      create-release: true
    secrets:
      SECURE_BOOT_SIGNING_KEY: ${{ secrets.SECURE_BOOT_SIGNING_KEY }}
```

## Troubleshooting

### Common Issues

**Build fails with "IDF version not found"**
```
Ensure the idf-version matches a tag on Docker Hub:
https://hub.docker.com/r/espressif/idf/tags
```

**ccache not working**
```yaml
# Ensure ccache volume is mounted
enable-ccache: true
```

**Secure boot key format error**
```
Keys must be in PEM format. Generate with:
espsecure.py generate_signing_key --version 2 secure_boot_signing_key.pem
```

## Resources

- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/)
- [ESP-IDF Docker Image Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/tools/idf-docker-image.html)
- [esp-idf-ci-action GitHub](https://github.com/espressif/esp-idf-ci-action)
- [ESP-IDF Security Features](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/)

## Support

For issues specific to this workflow, please open an issue in the automation-templates repository.

For ESP-IDF related questions, refer to the [ESP32 Forum](https://www.esp32.com/).
