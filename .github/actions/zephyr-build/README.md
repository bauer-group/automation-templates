# Zephyr RTOS Build Action

Professional GitHub Action for building, testing, and validating Zephyr Real-Time Operating System applications with comprehensive CI/CD automation.

## Features

- ⚡ **Automated SDK Setup** - Downloads and configures Zephyr SDK automatically
- 🌊 **West Integration** - Full west workspace management and dependency handling
- 🔨 **Multi-Platform Builds** - Linux, macOS, and Windows support
- 🧪 **Comprehensive Testing** - Twister test runner with coverage analysis
- 🛡️ **Quality Assurance** - Compliance checks, static analysis, and code quality
- 🔌 **Hardware Support** - Real hardware flashing and testing capabilities
- 📊 **Rich Reporting** - Detailed build reports, coverage, and artifacts
- 📂 **Intelligent Caching** - Smart caching of SDK and build artifacts

## Quick Start

### Basic Usage

```yaml
- name: ⚡ Build Zephyr Application
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    board: 'qemu_x86'
    build-type: 'debug'
    run-tests: true
```

### IoT Device Build

```yaml
- name: ⚡ Build IoT Device Firmware
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    config-file: 'iot-device'
    zephyr-version: '0.17.4'
    board: 'esp32'
    build-type: 'release'
    run-tests: true
    enable-coverage: true
    static-analysis: true
```

### Production Embedded System

```yaml
- name: ⚡ Build Production Firmware
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    config-file: 'embedded-system'
    board: 'nucleo_f429zi'
    build-type: 'release'
    run-tests: true
    enable-coverage: true
    run-compliance: true
    static-analysis: true
    generate-artifacts: true
```

## Inputs

### Core Configuration

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `config-file` | Configuration template name (without .yml) | `default` | No |
| `zephyr-version` | Zephyr SDK version (e.g., 0.17.4, latest) | `latest` | No |
| `board` | Target board for building | `qemu_x86` | No |
| `application-path` | Path to Zephyr application directory | `.` | No |
| `build-type` | Build configuration (debug, release, size_optimized) | `debug` | No |

### Build Configuration

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `extra-cmake-args` | Additional CMake arguments | `""` | No |
| `west-config-path` | Path to west.yml manifest file | `""` | No |
| `parallel-jobs` | Number of parallel build jobs | `auto` | No |
| `cache-enabled` | Enable caching of SDK and build artifacts | `true` | No |

### Testing and Quality

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `run-tests` | Run Twister tests after building | `true` | No |
| `test-pattern` | Test pattern for Twister (e.g., tests/*, kernel.*) | `tests/*` | No |
| `enable-coverage` | Enable code coverage collection | `false` | No |
| `run-compliance` | Run compliance checks (style, commit format) | `true` | No |
| `static-analysis` | Run static analysis tools (sparse, checkpatch) | `false` | No |
| `generate-artifacts` | Generate build artifacts (binaries, maps, reports) | `true` | No |

## Outputs

| Output | Description |
|--------|-------------|
| `build-status` | Build status (success/failure) |
| `test-status` | Test status (success/failure/skipped) |
| `compliance-status` | Compliance check status (success/failure/skipped) |
| `coverage-report` | Path to coverage report |
| `binary-path` | Path to generated binary files |
| `build-time` | Total build time in seconds |

## Supported Boards

### Emulation Platforms
- `qemu_x86` - x86 emulation (default)
- `qemu_cortex_m3` - ARM Cortex-M3 emulation
- `native_posix` - Native POSIX execution

### ARM Development Boards
- `nucleo_f429zi` - STM32 Nucleo F429ZI
- `nucleo_f767zi` - STM32 Nucleo F767ZI
- `frdm_k64f` - NXP Freedom K64F
- `mimxrt1064_evk` - NXP i.MX RT1064

### IoT Platforms
- `esp32` - ESP32 WiFi/Bluetooth
- `esp32s2` - ESP32-S2 WiFi
- `esp32s3` - ESP32-S3 WiFi/Bluetooth
- `esp32c3` - ESP32-C3 RISC-V WiFi/Bluetooth

### Nordic Semiconductor
- `nrf52840dk_nrf52840` - nRF52840 Development Kit
- `nrf9160dk_nrf9160` - nRF9160 Cellular IoT

## Configuration Templates

### Available Templates

| Template | Use Case | Key Features |
|----------|----------|--------------|
| `default` | General applications | Standard build, basic testing |
| `iot-device` | IoT and connected devices | WiFi/Bluetooth, network testing, power optimization |
| `embedded-system` | Industrial/automotive | Safety compliance, real-time testing, MISRA |
| `sample-application` | Demos and learning | Interactive features, educational docs |

### Custom Configuration

Create `.github/config/zephyr-build/my-config.yml`:

```yaml
zephyr:
  sdk_version: "0.17.4"
  default_board: "my_board"
  build_type: "release"

build:
  cmake_args:
    - "-DCONFIG_MY_FEATURE=y"
  extra_flags:
    - "-Os"
  treat_warnings_as_errors: true

testing:
  enabled: true
  twister_enabled: true
  test_pattern: "tests/my_tests/*"
  platforms: ["my_board", "qemu_x86"]

coverage:
  enabled: true
  target_coverage: 85

quality:
  compliance_checks: true
  static_analysis: true
```

## Advanced Usage

### Multi-Board Testing

```yaml
strategy:
  matrix:
    board: [qemu_x86, nucleo_f429zi, esp32]

steps:
  - uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
    with:
      board: ${{ matrix.board }}
      run-tests: true
      enable-coverage: true
```

### Custom West Manifest

```yaml
- uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    west-config-path: 'manifest/west.yml'
    board: 'my_custom_board'
    application-path: 'applications/my-app'
```

### Production Build with Full Validation

```yaml
- name: Production Build
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    config-file: 'embedded-system'
    zephyr-version: '0.17.4'
    board: 'nucleo_f429zi'
    build-type: 'release'
    run-tests: true
    enable-coverage: true
    run-compliance: true
    static-analysis: true
    extra-cmake-args: |
      -DCONFIG_STACK_CANARIES=y
      -DCONFIG_THREAD_STACK_INFO=y
      -DCONFIG_ASSERT=y
```

### Coverage Analysis with Upload

```yaml
- name: Build with Coverage
  id: build
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    enable-coverage: true
    test-pattern: 'tests/unit/*'

- name: Upload Coverage
  uses: codecov/codecov-action@v4
  with:
    files: ${{ steps.build.outputs.coverage-report }}/coverage.xml
    flags: zephyr-${{ matrix.board }}
```

## Build Process Overview

### 1. Environment Setup
- Detects OS and architecture
- Installs system dependencies
- Sets up Python environment
- Configures caching

### 2. Zephyr SDK Installation
- Downloads specified SDK version
- Extracts and installs SDK
- Configures environment variables
- Sets up toolchain paths

### 3. West Workspace
- Initializes west workspace
- Updates dependencies
- Exports Zephyr environment
- Configures build system

### 4. Quality Checks (if enabled)
- Runs compliance checks
- Validates commit format
- Checks coding style
- Performs security scans

### 5. Application Build
- Configures CMake build
- Compiles application
- Links binary files
- Generates artifacts

### 6. Testing (if enabled)
- Runs Twister test suite
- Collects test results
- Generates coverage reports
- Uploads test artifacts

### 7. Static Analysis (if enabled)
- Runs sparse analysis
- Executes checkpatch
- Performs security analysis
- Generates quality reports

### 8. Artifact Generation
- Copies binary files
- Generates build reports
- Creates documentation
- Prepares upload artifacts

## Caching Strategy

The action implements intelligent caching for:

- **Zephyr SDK**: Platform-specific SDK installations
- **West Modules**: Downloaded Zephyr modules and dependencies
- **Build Artifacts**: Compiled objects and intermediate files
- **Python Packages**: pip cache for faster dependency installation

Cache keys include:
- Platform (Linux/macOS/Windows)
- Zephyr version
- Target board
- Configuration file hashes

## Error Handling

### Common Issues and Solutions

#### SDK Download Failures
```yaml
# Specify exact version instead of 'latest'
- uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    zephyr-version: '0.17.4'
```

#### Build Failures
```yaml
# Enable verbose logging
- uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    extra-cmake-args: '-DCMAKE_VERBOSE_MAKEFILE=ON'
```

#### Test Failures
```yaml
# Run specific test patterns
- uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    test-pattern: 'tests/unit/kernel/*'
```

### Debug Mode

Enable debug output by setting environment variable:

```yaml
env:
  RUNNER_DEBUG: 1
```

## Hardware Testing

For hardware-in-the-loop testing, configure self-hosted runners with hardware labels:

```yaml
runs-on: [self-hosted, zephyr-hardware, nucleo]

steps:
  - uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
    with:
      board: 'nucleo_f429zi'
      # Action will automatically detect hardware runner
      # and enable hardware flashing/testing
```

## Security Considerations

### Secrets Management
- SDK downloads use HTTPS verification
- No sensitive data is logged
- Build artifacts exclude debug information in release builds

### Dependency Security
- SDK checksums are verified
- Python packages use pip's security features
- Optional dependency scanning available

### Code Security
- Optional secret scanning with gitleaks
- Static analysis for security vulnerabilities
- Compliance checking for secure coding standards

## Performance Optimization

### Build Speed
- Parallel compilation using all available cores
- Intelligent caching reduces setup time
- Optimized Docker layer caching

### Resource Usage
- Memory-optimized build configurations
- Efficient artifact compression
- Smart cleanup of temporary files

### Network Optimization
- CDN-cached SDK downloads
- Parallel dependency installation
- Connection reuse for multiple downloads

## Troubleshooting

### Enable Debug Logging

```yaml
- uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    board: 'qemu_x86'
  env:
    RUNNER_DEBUG: 1
    ACTIONS_STEP_DEBUG: true
```

### Check Build Environment

```yaml
- name: Debug Environment
  run: |
    echo "OS: ${{ runner.os }}"
    echo "Architecture: ${{ runner.arch }}"
    which python3
    python3 --version
    cmake --version
```

### Validate Board Support

```yaml
- name: List Available Boards
  run: |
    west boards | grep ${{ inputs.board }}
```

## Contributing

To contribute to this action:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Update documentation
5. Submit a pull request

### Development Setup

```bash
git clone https://github.com/bauer-group/automation-templates.git
cd automation-templates/.github/actions/zephyr-build
```

### Testing

```bash
# Test basic functionality
act -j test-basic

# Test with hardware simulation
act -j test-hardware --platform ubuntu-latest=nektos/act-environments-ubuntu:18.04
```

## License

This action is licensed under the MIT License. See [LICENSE](../../../LICENSE) for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
- **Documentation**: [Wiki](https://github.com/bauer-group/automation-templates/wiki)

---

For more information about Zephyr RTOS, visit the [official Zephyr Project documentation](https://docs.zephyrproject.org/).