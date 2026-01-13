# Zephyr RTOS Build System

Comprehensive automation system for Zephyr Real-Time Operating System projects with support for multi-platform builds, hardware testing, and embedded system compliance.

## Overview

The Zephyr Build System provides enterprise-grade CI/CD automation for Zephyr RTOS applications, supporting embedded systems, IoT devices, and real-time applications with comprehensive testing, compliance checks, and hardware validation.

### Key Features

- **Multi-Platform Support**: Linux, macOS, and Windows runners
- **Hardware Testing**: Real hardware-in-the-loop testing with supported boards
- **Compliance Checks**: Code style, commit format, and embedded standards
- **Security Scanning**: Secret detection and dependency scanning
- **Coverage Analysis**: Code coverage with multiple output formats
- **Static Analysis**: Advanced code quality and safety analysis
- **Artifact Management**: Binary generation and automated uploads

## Quick Start

### Basic Zephyr Application

```yaml
name: ⚡ Zephyr Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  zephyr:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["qemu_x86", "nucleo_f429zi"]'
      build-types: '["debug", "release"]'
      run-tests: true
      enable-coverage: true
```

### IoT Device Project

```yaml
name: ⚡ IoT Device Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  iot-build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'iot-device'
      boards: '["esp32", "esp32s3", "nrf52840dk_nrf52840"]'
      build-types: '["release"]'
      run-tests: true
      enable-coverage: true
      static-analysis: true
      upload-artifacts: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### Embedded System (Production)

```yaml
name: ⚡ Embedded System Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  embedded:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'embedded-system'
      boards: '["nucleo_f429zi", "frdm_k64f", "mimxrt1064_evk"]'
      build-types: '["release"]'
      run-tests: true
      enable-coverage: true
      run-compliance: true
      static-analysis: true
      timeout-minutes: 120
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
      TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
```

## Configuration System

### Available Configurations

| Configuration | Use Case | Key Features |
|---------------|----------|---------------|
| **default** | General Zephyr applications | Standard build, basic testing |
| **iot-device** | IoT and connected devices | WiFi/Bluetooth, network testing, power optimization |
| **embedded-system** | Industrial/automotive systems | Safety compliance, real-time testing, extended validation |
| **sample-application** | Demos and learning projects | Interactive features, educational documentation |

### Custom Configuration

Create `.github/config/zephyr-build/my-config.yml`:

```yaml
zephyr:
  sdk_version: "0.17.4"
  default_board: "my_custom_board"
  build_type: "release"

build:
  cmake_args:
    - "-DCONFIG_MY_FEATURE=y"
    - "-DCONFIG_CUSTOM_DRIVER=y"
  extra_flags:
    - "-Os"
  treat_warnings_as_errors: true

testing:
  enabled: true
  test_pattern: "tests/my_tests/*"
  platforms: ["my_board", "qemu_x86"]

coverage:
  enabled: true
  target_coverage: 80

quality:
  compliance_checks: true
  static_analysis: true
  misra_compliance: true

hardware:
  enabled: true
  boards: ["my_custom_board"]
  runners: ["my-hardware-runner"]
```

## Component Architecture

### Zephyr Build Action

Core composite action for building Zephyr applications:

```yaml
- name: ⚡ Zephyr Build
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    zephyr-version: '0.17.4'
    board: 'esp32'
    build-type: 'release'
    run-tests: true
    enable-coverage: true
    static-analysis: true
```

#### Key Features

- **Automated SDK Setup**: Downloads and configures Zephyr SDK
- **West Integration**: Manages Zephyr workspace and dependencies
- **Multi-OS Support**: Linux, macOS, and Windows compatibility
- **Caching**: Intelligent caching of SDK and build artifacts
- **Testing**: Twister test runner integration
- **Coverage**: Code coverage with multiple formats
- **Hardware Support**: Real hardware flashing and testing

### Workflow Inputs

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `config-file` | Configuration template name | `default` | No |
| `zephyr-version` | Zephyr SDK version | `latest` | No |
| `boards` | Target boards JSON array | `["qemu_x86"]` | No |
| `build-types` | Build types JSON array | `["debug"]` | No |
| `run-tests` | Enable Twister testing | `true` | No |
| `enable-coverage` | Enable code coverage | `false` | No |
| `static-analysis` | Enable static analysis | `false` | No |
| `upload-artifacts` | Upload build artifacts | `true` | No |
| `runs-on` | Runner to use | `ubuntu-latest` | No |

#### Self-Hosted Runner Support

The `runs-on` parameter supports both GitHub-hosted and self-hosted runners:

```yaml
# GitHub-hosted (string)
runs-on: 'ubuntu-latest'

# Self-hosted (JSON array)
runs-on: '["self-hosted", "linux"]'
runs-on: '["self-hosted", "linux", "docker"]'
```

See [Self-Hosted Runner Documentation](../self-hosted-runners.md) for details.

### Workflow Outputs

| Output | Description |
|--------|-------------|
| `build-status` | Overall build status |
| `test-results` | Test results summary |
| `artifact-url` | URL to build artifacts |

## Board Support

### Officially Tested Boards

| Board | Architecture | Use Case | Hardware Testing |
|-------|--------------|----------|------------------|
| `qemu_x86` | x86 | Emulation, CI testing | ❌ |
| `qemu_cortex_m3` | ARM Cortex-M3 | Emulation, testing | ❌ |
| `native_posix` | POSIX | Native testing | ❌ |
| `nucleo_f429zi` | ARM Cortex-M4 | STM32 development | ✅ |
| `nucleo_f767zi` | ARM Cortex-M7 | STM32 high-performance | ✅ |
| `esp32` | Xtensa LX6 | WiFi/Bluetooth IoT | ✅ |
| `esp32s3` | Xtensa LX7 | Advanced IoT | ✅ |
| `nrf52840dk_nrf52840` | ARM Cortex-M4 | Bluetooth/Thread | ✅ |
| `frdm_k64f` | ARM Cortex-M4 | NXP development | ✅ |

### Adding Custom Boards

1. **Board Definition**: Ensure board is supported by Zephyr
2. **Configuration**: Add board-specific settings in config files
3. **Testing**: Configure hardware runners if available
4. **Documentation**: Update board support documentation

## Testing Strategy

### Test Categories

#### Unit Tests
- Individual function testing
- Mock-based testing
- Component isolation

#### Integration Tests
- Module interaction testing
- System integration
- Cross-platform compatibility

#### Hardware Tests
- Real hardware validation
- GPIO functionality
- Communication protocols
- Power management

#### Compliance Tests
- Code style validation
- Commit message format
- Documentation standards
- Security compliance

### Test Configuration

```yaml
testing:
  enabled: true
  twister_enabled: true
  test_pattern: "tests/kernel/* tests/drivers/*"
  timeout: 600
  platforms: ["native_posix", "qemu_x86", "nucleo_f429zi"]
  
  # Test categories
  unit_tests: true
  integration_tests: true
  benchmark_tests: true
  stress_tests: true
  real_time_tests: true
```

## Coverage Analysis

### Coverage Configuration

```yaml
coverage:
  enabled: true
  format: ["html", "xml", "json"]
  target_coverage: 85
  exclude_patterns:
    - "tests/*"
    - "samples/*"
    - "build/*"
```

### Coverage Reports

The system generates comprehensive coverage reports:

- **HTML Report**: Interactive web-based coverage visualization
- **XML Report**: Machine-readable format for CI integration
- **JSON Report**: Programmatic access to coverage data
- **Codecov Integration**: Automatic upload to Codecov service

## Hardware Testing

### Hardware-in-the-Loop (HIL)

```yaml
hardware:
  enabled: true
  runners: ["nucleo-runner", "esp32-runner"]
  boards: ["nucleo_f429zi", "esp32"]
  flash_timeout: 60
  test_timeout: 300
  
  # Hardware-specific tests
  gpio_tests: true
  communication_tests: true
  power_tests: true
```

### Supported Hardware

| Hardware | Runner Label | Capabilities |
|----------|--------------|--------------|
| STM32 Nucleo | `nucleo-runner` | GPIO, UART, SPI, I2C |
| ESP32 DevKit | `esp32-runner` | WiFi, Bluetooth, GPIO |
| Nordic nRF52 | `nrf-runner` | Bluetooth, Thread, GPIO |
| Custom Boards | `custom-hw-runner` | User-defined |

### Setting Up Hardware Runners

1. **Runner Registration**: Register self-hosted runners with hardware labels
2. **Hardware Connection**: Connect boards via USB/JTAG
3. **Tool Installation**: Install flashing and debugging tools
4. **Permission Setup**: Configure device access permissions
5. **Test Validation**: Verify hardware connectivity

## Security and Compliance

### Security Features

- **Secret Scanning**: Automated detection of exposed secrets
- **Dependency Scanning**: Vulnerability analysis of dependencies
- **Code Analysis**: Static analysis for security issues
- **Firmware Signing**: Support for signed firmware images

### Compliance Standards

| Standard | Description | Configuration |
|----------|-------------|---------------|
| **MISRA C** | Automotive software guidelines | `misra_compliance: true` |
| **ISO 26262** | Automotive functional safety | `iso26262_compliance: true` |
| **IEC 61508** | Industrial safety standard | `iec61508_compliance: true` |

### Compliance Configuration

```yaml
safety:
  iso26262_compliance: true
  iec61508_compliance: true
  misra_c_compliance: true
  
  # Safety analysis
  hazard_analysis: true
  fmea_analysis: true
  fault_injection: true
```

## Performance Analysis

### Performance Metrics

- **Memory Usage**: Flash and RAM consumption analysis
- **Execution Time**: Performance profiling and benchmarks
- **Code Size**: Binary size tracking and optimization
- **Boot Time**: System startup performance
- **Real-Time**: Interrupt latency and timing analysis

### Performance Configuration

```yaml
performance:
  memory_analysis: true
  code_size_tracking: true
  execution_profiling: true
  interrupt_latency: true
  
  # Thresholds
  max_flash_size: "512KB"
  max_ram_size: "192KB"
  max_boot_time: "2s"
  max_interrupt_latency: "10us"
```

## Artifacts and Reports

### Generated Artifacts

| Artifact Type | Description | Location |
|---------------|-------------|----------|
| **Binaries** | Compiled firmware files (.bin, .hex, .elf) | `build/zephyr/` |
| **Maps** | Memory layout and symbol information | `build/zephyr/zephyr.map` |
| **Device Tree** | Hardware configuration | `build/zephyr/zephyr.dts` |
| **Test Reports** | XML test results | `twister-out/` |
| **Coverage** | Code coverage reports | `coverage-report/` |
| **Logs** | Build and test logs | `**/*.log` |

### Artifact Configuration

```yaml
artifacts:
  enabled: true
  retention_days: 30
  compression: true
  
  include:
    - "build/zephyr/*.bin"
    - "build/zephyr/*.hex"
    - "build/zephyr/*.elf"
    - "build/zephyr/zephyr.map"
    - "coverage-report/**"
    - "**/*.log"
```

## Advanced Features

### Multi-Board Matrix Builds

```yaml
jobs:
  matrix-build:
    strategy:
      matrix:
        board: ["esp32", "nucleo_f429zi", "nrf52840dk_nrf52840"]
        build_type: ["debug", "release"]
        
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["${{ matrix.board }}"]'
      build-types: '["${{ matrix.build_type }}"]'
```

### Conditional Hardware Testing

```yaml
jobs:
  hardware-test:
    if: |
      contains(github.event.pull_request.labels.*.name, 'hardware-test') ||
      github.ref == 'refs/heads/main'
    
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'embedded-system'
      boards: '["nucleo_f429zi"]'
      # Hardware testing enabled automatically
```

### Custom West Manifests

```yaml
jobs:
  custom-manifest:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      west-config-path: 'manifest/west.yml'
      boards: '["my_custom_board"]'
```

## Troubleshooting

### Common Issues

#### SDK Download Failures
```bash
# Check network connectivity
curl -I https://github.com/zephyrproject-rtos/sdk-ng/releases/

# Verify SDK version exists
west sdk list
```

#### Build Failures
```bash
# Clean build directory
rm -rf build/
west build -b <board> -p

# Check board support
west boards | grep <board>
```

#### Test Failures
```bash
# Run tests locally
python3 scripts/twister --platform <board> --testsuite-root .

# Check test configuration
cat testcase.yaml
```

#### Hardware Testing Issues
```bash
# Check device connectivity
lsusb
dmesg | tail

# Verify permissions
ls -l /dev/ttyUSB* /dev/ttyACM*
```

### Debug Configuration

```yaml
# Enable verbose logging
jobs:
  debug:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'debug'  # Create debug-specific config
      extra-cmake-args: '-DCONFIG_LOG_DEFAULT_LEVEL=4'
```

## Integration Examples

### Complete IoT Project

```yaml
name: 🌐 IoT Device CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * 1'  # Weekly full test

jobs:
  # Quick validation on PR
  quick-check:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["qemu_x86"]'
      build-types: '["debug"]'
      run-tests: true
      
  # Full testing on main branch
  full-test:
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'iot-device'
      boards: '["esp32", "esp32s3", "nrf52840dk_nrf52840"]'
      build-types: '["debug", "release"]'
      run-tests: true
      enable-coverage: true
      static-analysis: true
      upload-artifacts: true
      runner-os: '["ubuntu-latest", "macos-latest"]'
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
      
  # Weekly comprehensive test
  weekly-full:
    if: github.event_name == 'schedule'
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'embedded-system'
      boards: '["esp32", "nucleo_f429zi", "nrf52840dk_nrf52840", "frdm_k64f"]'
      build-types: '["debug", "release", "size_optimized"]'
      run-tests: true
      enable-coverage: true
      run-compliance: true
      static-analysis: true
      timeout-minutes: 180
```

## Best Practices

### Repository Structure

```
my-zephyr-project/
├── .github/
│   ├── workflows/
│   │   └── zephyr-ci.yml
│   └── config/
│       └── zephyr-build/
│           └── my-config.yml
├── src/                    # Application source
├── include/               # Header files
├── tests/                 # Test files
├── boards/               # Custom board definitions
├── dts/                  # Device tree overlays
├── west.yml              # West manifest
├── CMakeLists.txt        # Build configuration
├── prj.conf             # Project configuration
└── README.md            # Documentation
```

### Configuration Management

1. **Environment-Specific Configs**: Create separate configs for development, testing, and production
2. **Board-Specific Settings**: Customize settings per target board
3. **Feature Flags**: Use CMake options for conditional features
4. **Version Pinning**: Pin Zephyr SDK versions for reproducible builds

### Testing Strategy

1. **Pyramid Testing**: More unit tests, fewer integration tests, minimal hardware tests
2. **Continuous Testing**: Run basic tests on every commit
3. **Comprehensive Testing**: Full test suite on main branch
4. **Hardware Validation**: Critical path testing on real hardware

### Security Practices

1. **Secret Management**: Use GitHub Secrets for sensitive data
2. **Dependency Scanning**: Regular vulnerability scanning
3. **Code Signing**: Sign firmware for production deployment
4. **Access Control**: Limit hardware runner access

## Migration Guide

### From Manual Builds

1. **Assessment**: Analyze current build process
2. **Configuration**: Create appropriate config file
3. **Testing**: Start with basic workflow
4. **Enhancement**: Add advanced features gradually
5. **Hardware**: Integrate hardware testing last

### From Other CI Systems

1. **Workflow Translation**: Convert existing workflows
2. **Secret Migration**: Move secrets to GitHub
3. **Hardware Setup**: Configure new hardware runners
4. **Testing**: Validate equivalent functionality
5. **Optimization**: Leverage new features

## Support and Resources

### Getting Help

- **GitHub Issues**: [Report bugs and request features](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [Ask questions and share ideas](https://github.com/bauer-group/automation-templates/discussions)
- **Documentation**: [Complete documentation](https://github.com/bauer-group/automation-templates/wiki)

### External Resources

- **Zephyr Project**: [Official Zephyr RTOS documentation](https://docs.zephyrproject.org/)
- **West Tool**: [West meta-tool documentation](https://docs.zephyrproject.org/latest/develop/west/index.html)
- **Twister**: [Zephyr testing framework](https://docs.zephyrproject.org/latest/develop/test/twister.html)

### Community

- **Zephyr Discord**: [Join the community](https://chat.zephyrproject.org/)
- **Mailing Lists**: [Development discussions](https://lists.zephyrproject.org/)
- **GitHub**: [Contribute to Zephyr](https://github.com/zephyrproject-rtos/zephyr)

---

*This documentation is part of the BAUER GROUP Automation Templates. For the latest version, visit the [GitHub repository](https://github.com/bauer-group/automation-templates).*