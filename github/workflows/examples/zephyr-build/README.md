# Zephyr RTOS Build Examples

This directory contains comprehensive examples demonstrating how to use the Zephyr RTOS build automation system for different types of projects and use cases.

## Available Examples

### 1. Basic Zephyr Application
**File**: `basic-zephyr-app.yml`

Simple example for getting started with Zephyr builds:
- Single board build (qemu_x86)
- Basic testing enabled
- Minimal configuration
- Perfect for learning and small projects

```yaml
uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
with:
  board: 'qemu_x86'
  build-type: 'debug'
  run-tests: true
```

### 2. Multi-Board Matrix Build
**File**: `multi-board-matrix.yml`

Advanced matrix build strategy for multiple boards and configurations:
- Multiple target boards (qemu_x86, nucleo_f429zi, esp32, etc.)
- Multiple build types (debug, release)
- Matrix exclusions for optimization
- Artifact upload for release builds
- Coverage collection for specific boards

```yaml
strategy:
  matrix:
    board: [qemu_x86, nucleo_f429zi, esp32]
    build-type: [debug, release]
```

### 3. IoT Device CI/CD Pipeline
**File**: `iot-device-ci.yml`

Complete CI/CD pipeline for IoT device development:
- **Quick Validation**: Fast PR validation with security scanning
- **IoT Builds**: Multiple IoT boards (ESP32, nRF52840)
- **Connectivity Testing**: Network protocol validation
- **Hardware-in-the-Loop**: Real hardware testing (optional)
- **Performance Testing**: Memory analysis and stress testing
- **Security Analysis**: Comprehensive security validation
- **Release Preparation**: Automated release packaging
- **Notifications**: Teams integration for build status

Features:
- Conditional execution based on triggers
- Hardware testing with self-hosted runners
- Comprehensive test coverage
- Security and compliance validation
- Automated release management

## Usage Patterns

### For Rapid Prototyping
Use `basic-zephyr-app.yml` as a starting point:

```yaml
name: 🚀 My Zephyr Project

on: [push, pull_request]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["qemu_x86"]'
      run-tests: true
```

### For Multi-Platform Projects
Adapt `multi-board-matrix.yml` for your boards:

```yaml
jobs:
  matrix-build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["your_board1", "your_board2"]'
      build-types: '["debug", "release"]'
      enable-coverage: true
```

### For Production IoT Devices
Use `iot-device-ci.yml` as a comprehensive template:

```yaml
jobs:
  production-build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'iot-device'
      boards: '["esp32", "nrf52840dk_nrf52840"]'
      build-types: '["release"]'
      run-tests: true
      enable-coverage: true
      static-analysis: true
      upload-artifacts: true
```

## Configuration Options

### Board Selection
Choose appropriate boards for your project:

```yaml
# Emulation (fast, always available)
boards: '["qemu_x86", "qemu_cortex_m3", "native_posix"]'

# ARM Development Boards
boards: '["nucleo_f429zi", "nucleo_f767zi", "frdm_k64f"]'

# IoT Platforms
boards: '["esp32", "esp32s3", "nrf52840dk_nrf52840"]'
```

### Build Types
Select appropriate build configurations:

```yaml
# Development
build-types: '["debug"]'

# Testing
build-types: '["debug", "release"]'

# Production
build-types: '["release"]'

# Optimization Analysis  
build-types: '["debug", "release", "size_optimized"]'
```

### Feature Flags

```yaml
# Basic features
run-tests: true
enable-coverage: false
static-analysis: false

# Quality assurance
run-compliance: true
static-analysis: true
enable-coverage: true

# Production ready
upload-artifacts: true
timeout-minutes: 120
fail-fast: false
```

## Customization Guide

### 1. Modify for Your Project Structure

If your Zephyr application is not in the repository root:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      application-path: 'firmware/my-app'
      west-config-path: 'firmware/west.yml'
```

### 2. Add Custom CMake Arguments

For project-specific build configurations:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      extra-cmake-args: |
        -DCONFIG_MY_FEATURE=y
        -DCONFIG_LOG_DEFAULT_LEVEL=2
        -DOVERLAY_CONFIG=boards/my_board.conf
```

### 3. Configure Hardware Testing

For projects with hardware-in-the-loop testing:

```yaml
jobs:
  hardware-test:
    runs-on: [self-hosted, zephyr-hardware, my-board]
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["my_custom_board"]'
      # Hardware testing is automatically enabled on self-hosted runners
```

### 4. Add Custom Configuration

Create `.github/config/zephyr-build/my-config.yml` and reference it:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'my-config'
```

## Advanced Scenarios

### Conditional Hardware Testing

```yaml
jobs:
  hardware-test:
    if: |
      contains(github.event.pull_request.labels.*.name, 'hardware-test') ||
      github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["nucleo_f429zi"]'
```

### Environment-Specific Builds

```yaml
jobs:
  development:
    if: github.ref != 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'development'
      
  production:
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'production'
```

### Multi-Repository Builds

```yaml
jobs:
  build-app1:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      application-path: 'applications/app1'
      
  build-app2:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      application-path: 'applications/app2'
```

## Best Practices

### 1. Start Simple
Begin with `basic-zephyr-app.yml` and gradually add features:

1. Basic build and test
2. Add coverage collection
3. Enable static analysis
4. Add multiple boards
5. Implement hardware testing
6. Add release automation

### 2. Use Matrix Builds Efficiently

```yaml
# Good: Efficient matrix with strategic exclusions
strategy:
  matrix:
    board: [qemu_x86, esp32, nrf52840dk_nrf52840]
    build-type: [debug, release]
  exclude:
    - board: esp32
      build-type: debug  # Skip debug builds for ESP32
```

### 3. Implement Progressive Testing

```yaml
# Quick validation for PRs
quick-test:
  if: github.event_name == 'pull_request'
  with:
    boards: '["qemu_x86"]'
    
# Full testing for main branch
full-test:
  if: github.ref == 'refs/heads/main'
  with:
    boards: '["qemu_x86", "esp32", "nucleo_f429zi"]'
```

### 4. Optimize CI Performance

- Use caching: `cache-enabled: true`
- Parallel jobs: `parallel-jobs: 'auto'`
- Smart artifact uploads
- Conditional hardware testing

## Troubleshooting

### Common Issues

1. **Build Failures**: Check board support and Zephyr version compatibility
2. **Test Timeouts**: Increase timeout for complex tests
3. **Artifact Size**: Use compression and selective inclusion
4. **Hardware Connectivity**: Verify self-hosted runner configuration

### Debug Tips

```yaml
# Enable debug logging
env:
  RUNNER_DEBUG: 1
  ACTIONS_STEP_DEBUG: true

# Use specific Zephyr version for reproducibility
with:
  zephyr-version: '0.17.4'  # Instead of 'latest'
```

## Contributing

To contribute new examples:

1. Create a new `.yml` file in this directory
2. Follow the naming convention: `purpose-description.yml`
3. Add comprehensive comments explaining the configuration
4. Update this README with the new example
5. Test the workflow thoroughly

## Support

- **Issues**: [Report problems](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [Ask questions](https://github.com/bauer-group/automation-templates/discussions)
- **Documentation**: [Full documentation](https://github.com/bauer-group/automation-templates/wiki)

---

For more information about the Zephyr build system, see the [complete documentation](../../docs/workflows/zephyr-build.md).