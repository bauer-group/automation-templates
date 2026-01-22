# PlatformIO Build Workflow

## Overview

The PlatformIO Build workflow provides a comprehensive CI/CD solution for embedded projects using the [PlatformIO](https://platformio.org/) ecosystem. It supports multiple hardware platforms, frameworks, and provides integrated library management.

## Features

- **Multi-Platform Support**: ESP32, ESP8266, STM32, AVR, ARM, RISC-V, and more
- **Framework Agnostic**: Arduino, ESP-IDF, STM32Cube, Zephyr, mbed, and others
- **Environment Matrix**: Build multiple environments in parallel
- **Library Management**: Automatic dependency resolution
- **Unit Testing**: Native and embedded test support
- **Static Analysis**: PIO Check integration (cppcheck, clangtidy, pvs-studio)
- **Remote Testing**: Support for remote device testing
- **Release Management**: Automated firmware releases

## Supported Platforms

| Platform | Boards | Frameworks |
|----------|--------|------------|
| `espressif32` | ESP32, ESP32-S2/S3/C3/C6 | Arduino, ESP-IDF |
| `espressif8266` | ESP8266, NodeMCU | Arduino |
| `ststm32` | STM32F0/F1/F2/F3/F4/F7, STM32G0/G4, STM32H7, STM32L0/L1/L4/L5 | Arduino, STM32Cube, Zephyr, mbed |
| `atmelsam` | SAMD21, SAMD51, SAM3X | Arduino |
| `atmelavr` | ATmega328P, ATmega2560, ATtiny | Arduino |
| `teensy` | Teensy 3.x, 4.x | Arduino |
| `nordicnrf52` | nRF52832, nRF52840 | Arduino, Zephyr |
| `raspberrypi` | RP2040, Pico | Arduino |
| `native` | Host machine | Native (for testing) |

## Quick Start

### Basic Build

```yaml
name: PlatformIO Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      environments: '["esp32dev"]'
```

### Multi-Environment Build

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      environments: '["esp32dev", "esp32-s3-devkitc-1", "nucleo_f446re"]'
      run-tests: true
```

### All Environments from platformio.ini

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      build-all-environments: true
```

## Configuration

### Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `config-file` | string | `default` | Configuration template |
| `environments` | string | - | JSON array of PIO environments |
| `build-all-environments` | boolean | `false` | Build all envs from platformio.ini |
| `project-path` | string | `.` | Path to PlatformIO project |
| `pio-version` | string | `latest` | PlatformIO Core version |
| `run-tests` | boolean | `true` | Run unit tests |
| `test-environments` | string | - | Environments for testing |
| `enable-check` | boolean | `false` | Run PIO Check (static analysis) |
| `check-tools` | string | `cppcheck` | Analysis tools |
| `upload-artifacts` | boolean | `true` | Upload firmware artifacts |
| `create-release` | boolean | `false` | Create GitHub release |

### platformio.ini Example

```ini
[platformio]
default_envs = esp32dev, nucleo_f446re

[env]
framework = arduino
monitor_speed = 115200
lib_deps =
    bblanchon/ArduinoJson@^7.0.0

[env:esp32dev]
platform = espressif32
board = esp32dev

[env:esp32-s3-devkitc-1]
platform = espressif32
board = esp32-s3-devkitc-1

[env:nucleo_f446re]
platform = ststm32
board = nucleo_f446re

[env:native]
platform = native
test_build_src = yes
```

### Configuration Templates

#### `default.yml` - Standard Projects

```yaml
pio-version: latest
build-all-environments: false
tests:
  enabled: true
  filter: '*'
check:
  enabled: false
```

#### `multi-platform.yml` - Cross-Platform

```yaml
pio-version: latest
build-all-environments: true
tests:
  enabled: true
  environments:
    - native
check:
  enabled: true
  tools:
    - cppcheck
```

#### `production.yml` - Release Builds

```yaml
pio-version: '6.1.13'  # Pinned version
build-all-environments: true
tests:
  enabled: true
  fail-on-error: true
check:
  enabled: true
  tools:
    - cppcheck
    - clangtidy
  severity: medium
release:
  enabled: true
  include-elf: true
  include-map: false
```

## Unit Testing

### Native Tests

```ini
[env:native]
platform = native
test_build_src = yes
test_framework = unity
```

```yaml
with:
  run-tests: true
  test-environments: '["native"]'
```

### Embedded Tests

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
test_framework = unity
test_port = /dev/ttyUSB0
```

### Test Directory Structure

```
project/
├── src/
│   └── main.cpp
├── lib/
│   └── MyLib/
│       ├── MyLib.h
│       └── MyLib.cpp
├── include/
├── test/
│   ├── test_native/
│   │   └── test_main.cpp
│   └── test_embedded/
│       └── test_main.cpp
└── platformio.ini
```

## Static Analysis

### PIO Check

```yaml
with:
  enable-check: true
  check-tools: 'cppcheck,clangtidy'
  check-severity: 'medium'
```

### Available Tools

| Tool | Description |
|------|-------------|
| `cppcheck` | Static analysis for C/C++ |
| `clangtidy` | Clang-based linter |
| `pvs-studio` | Professional analyzer (license required) |

## Release Artifacts

Each release includes:

| Artifact | Description |
|----------|-------------|
| `firmware-{env}.bin` | Binary firmware |
| `firmware-{env}.hex` | Intel HEX format |
| `firmware-{env}.elf` | ELF with debug symbols |
| `checksums.sha256` | File checksums |
| `build-info.json` | Build metadata |

### Build Metadata

```json
{
  "version": "1.2.3",
  "environments": ["esp32dev", "nucleo_f446re"],
  "platformio_version": "6.1.13",
  "build_date": "2026-01-22T10:30:00Z",
  "git_commit": "a1b2c3d4",
  "git_branch": "main"
}
```

## Examples

### ESP32 IoT Project

```yaml
name: ESP32 IoT Build

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      environments: '["esp32dev", "esp32-s3-devkitc-1", "esp32-c3-devkitm-1"]'
      run-tests: true
      test-environments: '["native"]'
      enable-check: true
      create-release: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

### Multi-Platform Library

```yaml
name: Library CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      build-all-environments: true
      run-tests: true
      enable-check: true
      check-tools: 'cppcheck,clangtidy'
```

### STM32 Industrial

```yaml
name: STM32 Industrial

on:
  push:
    tags: ['v*']

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      config-file: production
      environments: '["nucleo_f446re", "nucleo_h743zi"]'
      pio-version: '6.1.13'
      run-tests: true
      enable-check: true
      create-release: true
```

## Library Development

### Library CI Workflow

```yaml
name: Library CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      project-path: 'examples/basic'
      build-all-environments: true

  test:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      run-tests: true
      test-environments: '["native"]'
```

### library.json Example

```json
{
  "name": "MyAwesomeLib",
  "version": "1.0.0",
  "description": "An awesome PlatformIO library",
  "keywords": ["iot", "sensor"],
  "repository": {
    "type": "git",
    "url": "https://github.com/user/mylib.git"
  },
  "frameworks": ["arduino", "espidf"],
  "platforms": ["espressif32", "ststm32"]
}
```

## Troubleshooting

### Common Issues

**"Environment not found"**
```
Ensure the environment is defined in platformio.ini
Check for typos in the environment name
```

**"Library not found"**
```
Add the library to lib_deps in platformio.ini
Or install globally: pio pkg install -g -l "library"
```

**"Board not found"**
```
Install the platform first: pio pkg install -g -p "platform"
Or add platform_packages to platformio.ini
```

**"Test failed to compile"**
```
Ensure test_build_src = yes for native tests
Check test directory structure (test/test_*/test_*.cpp)
```

## Resources

- [PlatformIO Documentation](https://docs.platformio.org/)
- [PlatformIO Registry](https://registry.platformio.org/)
- [PlatformIO Boards](https://registry.platformio.org/boards)
- [PlatformIO Unit Testing](https://docs.platformio.org/en/latest/advanced/unit-testing/)
- [PlatformIO Check](https://docs.platformio.org/en/latest/plus/pio-check.html)
