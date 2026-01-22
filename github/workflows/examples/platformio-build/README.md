# PlatformIO Build Workflow Examples

This directory contains example workflows for building embedded firmware using the `platformio-build` reusable workflow.

## Available Examples

| Example | Description | Use Case |
|---------|-------------|----------|
| [basic-build.yml](basic-build.yml) | Simple single-environment build | Getting started |
| [multi-environment.yml](multi-environment.yml) | Matrix build for multiple envs | Cross-platform projects |
| [esp32-iot.yml](esp32-iot.yml) | ESP32 IoT device pipeline | WiFi/BLE connected devices |
| [stm32-industrial.yml](stm32-industrial.yml) | STM32 industrial release | Safety-critical applications |
| [library-ci.yml](library-ci.yml) | Library development CI | PlatformIO libraries |

## Quick Start

### 1. Basic Build

```yaml
name: PlatformIO Build

on:
  push:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      environments: '["esp32dev"]'
```

### 2. All Environments

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      build-all-environments: true
```

### 3. With Testing

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      environments: '["esp32dev", "native"]'
      run-tests: true
      test-environments: '["native"]'
```

## Configuration Templates

| Template | Description |
|----------|-------------|
| `default` | Standard projects |
| `multi-platform` | Cross-platform libraries |
| `production` | Release builds with full validation |
| `esp32-iot` | ESP32 IoT devices |
| `stm32-industrial` | Industrial STM32 applications |

## Supported Platforms

### Espressif

| Board | Environment |
|-------|-------------|
| ESP32 DevKit | `esp32dev` |
| ESP32-S2 | `esp32-s2-saola-1` |
| ESP32-S3 | `esp32-s3-devkitc-1` |
| ESP32-C3 | `esp32-c3-devkitm-1` |
| ESP8266 NodeMCU | `nodemcuv2` |

### STMicroelectronics

| Board | Environment |
|-------|-------------|
| Nucleo F103RB | `nucleo_f103rb` |
| Nucleo F401RE | `nucleo_f401re` |
| Nucleo F446RE | `nucleo_f446re` |
| Nucleo H743ZI | `nucleo_h743zi` |
| Blue Pill | `bluepill_f103c8` |

### Other

| Board | Environment |
|-------|-------------|
| Arduino Uno | `uno` |
| Arduino Mega | `megaatmega2560` |
| Teensy 4.0 | `teensy40` |
| Raspberry Pi Pico | `pico` |
| Native (Host) | `native` |

## platformio.ini Template

```ini
[platformio]
default_envs = esp32dev

[env]
framework = arduino
monitor_speed = 115200
test_framework = unity

[env:esp32dev]
platform = espressif32
board = esp32dev

[env:nucleo_f446re]
platform = ststm32
board = nucleo_f446re

[env:native]
platform = native
test_build_src = yes
```

## Project Structure

```
my-platformio-project/
├── .github/
│   └── workflows/
│       └── build.yml
├── src/
│   └── main.cpp
├── lib/
│   └── MyLib/
│       ├── MyLib.h
│       └── MyLib.cpp
├── include/
│   └── config.h
├── test/
│   ├── test_native/
│   │   └── test_main.cpp
│   └── test_embedded/
│       └── test_main.cpp
└── platformio.ini
```

## Resources

- [PlatformIO Documentation](https://docs.platformio.org/)
- [PlatformIO Registry](https://registry.platformio.org/)
- [PlatformIO Boards](https://registry.platformio.org/boards)
