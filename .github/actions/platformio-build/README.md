# PlatformIO Build Action

A composite GitHub Action for building embedded firmware using the PlatformIO ecosystem.

## Features

- Multi-platform support (ESP32, STM32, AVR, ARM, etc.)
- Framework agnostic (Arduino, ESP-IDF, STM32Cube, Zephyr)
- Automatic caching
- Unit test support
- Static analysis integration
- Artifact preparation

## Usage

### Basic Usage

```yaml
- uses: bauer-group/automation-templates/.github/actions/platformio-build@main
  with:
    environment: esp32dev
```

### Full Configuration

```yaml
- uses: bauer-group/automation-templates/.github/actions/platformio-build@main
  with:
    pio-version: '6.1.13'
    environment: esp32dev
    project-path: ./firmware
    run-tests: true
    enable-check: true
    cache-enabled: true
    generate-artifacts: true
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `config-file` | Configuration template | `default` |
| `pio-version` | PlatformIO version | `latest` |
| `environment` | PIO environment | - |
| `project-path` | Project directory | `.` |
| `extra-build-flags` | Additional flags | - |
| `run-tests` | Run unit tests | `false` |
| `test-filter` | Test filter | `*` |
| `enable-check` | Run PIO Check | `false` |
| `check-tools` | Analysis tools | `cppcheck` |
| `cache-enabled` | Enable caching | `true` |
| `generate-artifacts` | Prepare artifacts | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `build-status` | Build status |
| `binary-path` | Path to binaries |
| `firmware-size` | Size in bytes |
| `version` | Firmware version |

## Example Workflow

```yaml
name: PlatformIO Build

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [esp32dev, nucleo_f446re]

    steps:
      - uses: actions/checkout@v6

      - name: Build Firmware
        id: build
        uses: bauer-group/automation-templates/.github/actions/platformio-build@main
        with:
          environment: ${{ matrix.environment }}
          run-tests: true

      - name: Upload Artifacts
        uses: actions/upload-artifact@v6
        with:
          name: firmware-${{ matrix.environment }}
          path: ${{ steps.build.outputs.binary-path }}
```

## Resources

- [PlatformIO Documentation](https://docs.platformio.org/)
- [PlatformIO Registry](https://registry.platformio.org/)
