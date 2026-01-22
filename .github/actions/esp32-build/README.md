# ESP32 Build Action

A composite GitHub Action for building ESP32 firmware using the official [Espressif IDF Docker images](https://hub.docker.com/r/espressif/idf).

## Features

- Official ESP-IDF Docker image support
- Multi-target builds (ESP32, ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C6, ESP32-H2)
- Build caching with ccache
- Automatic version embedding
- Size analysis
- Static analysis support
- Unit test integration
- Artifact preparation

## Usage

### Basic Usage

```yaml
- uses: bauer-group/automation-templates/.github/actions/esp32-build@main
  with:
    target: esp32
    idf-version: v5.2
```

### Full Configuration

```yaml
- uses: bauer-group/automation-templates/.github/actions/esp32-build@main
  with:
    config-file: iot-device
    idf-version: v5.2
    target: esp32s3
    project-path: ./firmware
    build-type: release
    sdkconfig-defaults: sdkconfig.defaults.production
    enable-ccache: true
    run-tests: true
    enable-analysis: true
    generate-artifacts: true
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `config-file` | Configuration template name | `default` |
| `idf-version` | ESP-IDF version | `v5.2` |
| `target` | Target chip | `esp32` |
| `project-path` | Project directory | `.` |
| `build-type` | Build type (release/debug) | `release` |
| `sdkconfig-defaults` | Custom sdkconfig file | - |
| `extra-cmake-args` | Additional CMake args | - |
| `enable-ccache` | Enable build caching | `true` |
| `run-tests` | Run unit tests | `false` |
| `enable-analysis` | Run static analysis | `false` |
| `generate-artifacts` | Prepare artifacts | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `build-status` | Build status (success/failure) |
| `binary-path` | Path to built binaries |
| `firmware-size` | Firmware size in bytes |
| `build-time` | Build duration in seconds |
| `version` | Firmware version string |

## Supported Targets

| Target | Chip | Architecture |
|--------|------|--------------|
| `esp32` | ESP32 | Xtensa LX6 |
| `esp32s2` | ESP32-S2 | Xtensa LX7 |
| `esp32s3` | ESP32-S3 | Xtensa LX7 |
| `esp32c3` | ESP32-C3 | RISC-V |
| `esp32c6` | ESP32-C6 | RISC-V |
| `esp32h2` | ESP32-H2 | RISC-V |

## ESP-IDF Versions

Available at [Docker Hub](https://hub.docker.com/r/espressif/idf/tags):
- `v5.2` - Latest stable (recommended)
- `v5.1.2` - Previous stable
- `v5.0.4` - LTS
- `latest` - Bleeding edge

## Build Artifacts

When `generate-artifacts: true`, the following files are prepared:

```
build/artifacts/
├── *.bin              # Application binary
├── bootloader.bin     # Bootloader
├── partition-table.bin# Partition table
├── *.elf              # ELF file (for debugging)
├── size-report.txt    # Size analysis
├── version.json       # Build metadata
└── checksums.sha256   # File checksums
```

## Example Workflow

```yaml
name: ESP32 Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        target: [esp32, esp32s3, esp32c3]

    steps:
      - uses: actions/checkout@v6

      - name: Build Firmware
        id: build
        uses: bauer-group/automation-templates/.github/actions/esp32-build@main
        with:
          target: ${{ matrix.target }}
          idf-version: v5.2
          run-tests: true

      - name: Upload Artifacts
        uses: actions/upload-artifact@v6
        with:
          name: firmware-${{ matrix.target }}
          path: ${{ steps.build.outputs.binary-path }}
```

## Resources

- [ESP-IDF Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/)
- [esp-idf-ci-action](https://github.com/espressif/esp-idf-ci-action)
- [ESP-IDF Docker Image](https://hub.docker.com/r/espressif/idf)
