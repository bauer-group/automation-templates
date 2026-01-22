# ESP32 Build Workflow Examples

This directory contains example workflows for building ESP32 firmware using the `esp32-build` reusable workflow.

## Available Examples

| Example | Description | Use Case |
|---------|-------------|----------|
| [basic-build.yml](basic-build.yml) | Simple single-target build | Getting started, simple projects |
| [multi-target-matrix.yml](multi-target-matrix.yml) | Matrix build for multiple ESP32 variants | IoT products supporting multiple chips |
| [vscode-espidf-project.yml](vscode-espidf-project.yml) | VS Code ESP-IDF Extension projects | VS Code development workflow |
| [iot-device-ci.yml](iot-device-ci.yml) | Complete IoT CI/CD pipeline | Production IoT devices with OTA |
| [industrial-release.yml](industrial-release.yml) | Secure build with compliance | Industrial/automotive applications |

## Quick Start

### 1. Basic Build

For simple projects, copy `basic-build.yml` to your repository:

```yaml
name: ESP32 Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      target: esp32
      idf-version: v5.2
```

### 2. Multi-Target Build

For products supporting multiple ESP32 variants:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      targets: '["esp32", "esp32s3", "esp32c3"]'
      config-file: iot-device
```

### 3. Production Release

For tagged releases with firmware signing:

```yaml
jobs:
  release:
    if: startsWith(github.ref, 'refs/tags/v')
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: industrial
      create-release: true
      secure-boot: true
    secrets: inherit
```

## Configuration Templates

The workflow supports pre-defined configuration templates in `.github/config/esp32-build/`:

| Template | Description |
|----------|-------------|
| `default` | Standard projects, basic settings |
| `iot-device` | IoT devices with OTA, multiple targets |
| `industrial` | Safety-critical with secure boot |
| `prototype` | Fast iteration, debug builds |

## Supported Targets

| Target | Chip | Architecture | Features |
|--------|------|--------------|----------|
| `esp32` | ESP32 | Xtensa LX6 | WiFi, BT Classic, BLE |
| `esp32s2` | ESP32-S2 | Xtensa LX7 | WiFi, USB OTG |
| `esp32s3` | ESP32-S3 | Xtensa LX7 | WiFi, BLE, AI Acceleration |
| `esp32c3` | ESP32-C3 | RISC-V | WiFi, BLE 5.0 |
| `esp32c6` | ESP32-C6 | RISC-V | WiFi 6, BLE 5.0, Thread |
| `esp32h2` | ESP32-H2 | RISC-V | BLE 5.0, Thread, Zigbee |

## ESP-IDF Versions

Available versions can be found at [Docker Hub](https://hub.docker.com/r/espressif/idf/tags).

**Recommended versions:**
- `v5.2` - Latest stable (recommended)
- `v5.1.2` - Previous stable
- `v5.0.4` - LTS
- `latest` - Bleeding edge (not for production)

## Secrets Configuration

For production releases, configure these secrets in your repository:

| Secret | Description | Required For |
|--------|-------------|--------------|
| `SECURE_BOOT_SIGNING_KEY` | RSA-3072 or ECDSA signing key (PEM) | Secure Boot |
| `OTA_SERVER_URL` | OTA server endpoint | OTA deployment |
| `OTA_API_KEY` | OTA server authentication | OTA deployment |

## Project Structure

Recommended ESP-IDF project structure:

```
my-esp32-project/
├── .github/
│   └── workflows/
│       └── build.yml          # Your workflow file
├── main/
│   ├── CMakeLists.txt
│   └── main.c
├── components/                 # Custom components
│   └── my_component/
├── test/                       # Test applications
├── CMakeLists.txt
├── sdkconfig.defaults         # Default configuration
├── sdkconfig.defaults.iot     # IoT-specific config
├── partitions.csv             # Custom partition table
└── partitions_ota.csv         # OTA partition table
```

## Troubleshooting

### Build fails with "target not supported"

Ensure your `sdkconfig.defaults` doesn't have conflicting target settings. Let the workflow set the target.

### ccache not improving build times

First build always runs full. Subsequent builds should be faster. Check cache hit rate in logs.

### Tests not running

Ensure you have `pytest.ini` or `conftest.py` in your project root, and pytest-embedded is configured.

### Secure boot key format error

Keys must be in PEM format. Generate with:
```bash
espsecure.py generate_signing_key --version 2 secure_boot_signing_key.pem
```

## Resources

- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/)
- [esp-idf-ci-action](https://github.com/espressif/esp-idf-ci-action)
- [ESP-IDF Docker Image](https://hub.docker.com/r/espressif/idf)
