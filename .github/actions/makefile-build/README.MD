# 🔨 Makefile Build Action

Professional Makefile-based build automation with configuration, dependencies, checks, and distribution validation for C/C++, autotools, CMake, and kernel module projects.

## ✨ Features

- **🔧 Multi-Build System Support**: Autotools, CMake Makefiles, basic Makefiles, kernel modules
- **⚙️ Flexible Configuration**: YAML-based configuration system
- **🚀 Performance Optimization**: Automatic parallel builds and intelligent caching
- **🧪 Comprehensive Testing**: Multiple test targets and reporting
- **📦 Distribution Validation**: Built-in distcheck support
- **🔍 Quality Assurance**: Warning handling and static analysis integration
- **📊 Detailed Reporting**: Build artifacts and comprehensive logs
- **🌐 Cross-Platform**: Linux, macOS support with matrix builds

## 🎯 Quick Start

### Basic Usage

```yaml
- name: 🔨 Build with Makefile
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'default'
    make-targets: 'all'
    check-targets: 'check'
```

### Autotools Project

```yaml
- name: 🔨 Autotools Build
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'autotools'
    configure-args: '--enable-shared --enable-static'
    make-targets: 'all'
    check-targets: 'check installcheck'
    distcheck-enabled: true
```

### CMake with Makefiles

```yaml
- name: 🔨 CMake Build
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'cmake-makefile'
    configure-script: 'cmake'
    configure-args: '-S . -B build -DCMAKE_BUILD_TYPE=Release'
    working-directory: 'build'
    make-targets: 'all'
    check-targets: 'test'
```

## 📋 Inputs

### Core Configuration

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `config-file` | Configuration file from `.github/config/makefile-build/` | `default` | No |
| `working-directory` | Working directory for operations | `.` | No |
| `configure-script` | Configuration script to run | `./configure` | No |
| `configure-args` | Additional configure arguments | `` | No |

### Build Configuration

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `make-targets` | Space-separated make targets | `all` | No |
| `check-targets` | Space-separated test targets | `check` | No |
| `parallel-jobs` | Number of parallel jobs (`auto` or number) | `auto` | No |
| `fail-on-warnings` | Treat warnings as errors | `false` | No |

### Advanced Options

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `distcheck-enabled` | Enable distribution check | `true` | No |
| `install-dependencies` | Install system dependencies | `true` | No |
| `cache-enabled` | Enable build caching | `true` | No |
| `generate-reports` | Generate build reports | `true` | No |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `build-status` | Build status (success/failure) |
| `test-status` | Test status (success/failure) |
| `distcheck-status` | Distribution check status |
| `build-time` | Total build time in seconds |
| `artifacts-path` | Path to generated artifacts |

## ⚙️ Configuration Files

The action uses YAML configuration files stored in `.github/config/makefile-build/`:

### Available Configurations

| Config | Description | Use Case |
|--------|-------------|----------|
| `default` | Basic autotools/make setup | Standard C/C++ projects |
| `autotools` | Full GNU autotools support | Complex autotools projects |
| `cmake-makefile` | CMake Makefile generator | CMake-based projects |
| `kernel-module` | Linux kernel development | Kernel modules |
| `matrix` | Multi-platform testing | Cross-platform projects |

### Custom Configuration

Create a custom configuration file in `.github/config/makefile-build/my-project.yml`:

```yaml
name: "My Project Build"
description: "Custom configuration for my project"

# Configure stage
configure:
  script: "./configure"
  args: ["--enable-feature", "--with-library"]
  cache_enabled: true

# Build stage
build:
  targets: ["all", "docs"]
  parallel_jobs: 4
  fail_on_warnings: false
  
  env:
    CFLAGS: "-O2 -g -Wall"
    CXXFLAGS: "-O2 -g -Wall"

# Test stage
test:
  enabled: true
  targets: ["check", "integration-test"]
  parallel: true
  
  env:
    VERBOSE: "1"

# Artifacts
artifacts:
  enabled: true
  paths:
    - "config.log"
    - "**/*.log"
    - "*.tar.gz"
```

## 🔧 Build Systems Support

### GNU Autotools

```yaml
- uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'autotools'
    configure-args: '--enable-shared --disable-static'
    make-targets: 'all'
    check-targets: 'check installcheck'
    distcheck-enabled: true
```

**Features:**
- Automatic `autoreconf` if configure is missing
- Configure script caching
- Full distcheck support
- Installation testing

### CMake Makefiles

```yaml
- uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'cmake-makefile'
    configure-script: 'cmake'
    configure-args: '-S . -B build -DCMAKE_BUILD_TYPE=Release'
    working-directory: 'build'
    make-targets: 'all'
    check-targets: 'test'
```

**Features:**
- CMake configuration
- Out-of-source builds
- CTest integration
- Package generation

### Linux Kernel Modules

```yaml
- uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'kernel-module'
    make-targets: 'modules'
    check-targets: 'modules_check'
    distcheck-enabled: false
```

**Features:**
- Kernel header dependencies
- Module information extraction
- Static analysis integration
- Security compliance

### Basic Makefiles

```yaml
- uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'default'
    configure-script: ''  # No configure step
    make-targets: 'all install'
    check-targets: 'test'
```

**Features:**
- Direct make execution
- Flexible target specification
- Dependency management
- Parallel compilation

## 🚀 Performance Features

### Parallel Compilation

```yaml
with:
  parallel-jobs: 'auto'  # Use all available cores
  # or specify exact number:
  # parallel-jobs: '4'
```

### Build Caching

```yaml
with:
  cache-enabled: true
  config-file: 'autotools'  # Includes cache configuration
```

**Cached Items:**
- Configure cache files
- Dependency metadata
- Autotools cache
- Build intermediates

### Optimized Builds

```yaml
with:
  configure-args: '--enable-optimization --disable-debug'
env:
  CFLAGS: '-O3 -march=native'
  CXXFLAGS: '-O3 -march=native'
```

## 🔍 Quality Assurance

### Warning Handling

```yaml
with:
  fail-on-warnings: true  # Treat warnings as errors
```

### Static Analysis Integration

The action integrates with common static analysis tools:

```bash
# Tools supported in configurations
- cppcheck
- clang-tidy
- sparse (kernel modules)
- checkpatch (kernel modules)
```

### Test Reporting

```yaml
with:
  generate-reports: true
  check-targets: 'check installcheck unit-test'
```

Generated reports include:
- Build logs
- Test results
- Configuration status
- Error summaries

## 🌐 Multi-Platform Usage

### Cross-Platform Build

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
    compiler: [gcc, clang]

steps:
  - uses: bauer-group/automation-templates/.github/actions/makefile-build@main
    with:
      config-file: 'matrix'
      parallel-jobs: 'auto'
```

### Platform-Specific Configuration

```yaml
- name: 🔨 Linux Build
  if: runner.os == 'Linux'
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'autotools'
    configure-args: '--enable-linux-features'

- name: 🔨 macOS Build
  if: runner.os == 'macOS'
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    config-file: 'autotools'
    configure-args: '--enable-macos-features'
```

## 📊 Reporting and Artifacts

### Build Artifacts

The action generates comprehensive artifacts:

```
build-artifacts/
├── build-summary.txt
├── config.log
├── config.status
├── Makefile.generated
├── test-*.log
└── *.xml (test results)
```

### Custom Artifact Collection

```yaml
with:
  generate-reports: true

# Access artifacts in subsequent steps
- name: 📤 Upload Custom Artifacts
  uses: actions/upload-artifact@v7
  with:
    name: my-build-artifacts
    path: ${{ steps.build.outputs.artifacts-path }}
```

## 🐞 Troubleshooting

### Common Issues

**Configure script not found:**
```yaml
with:
  configure-script: 'autoreconf -fiv && ./configure'
```

**Missing dependencies:**
```yaml
with:
  install-dependencies: true
```

**Build failures:**
```yaml
with:
  fail-on-warnings: false
  generate-reports: true  # Enable detailed logs
```

**Test failures:**
```yaml
with:
  check-targets: 'check || true'  # Continue on test failure
  generate-reports: true
```

### Debug Mode

Enable verbose output for debugging:

```yaml
with:
  generate-reports: true
env:
  VERBOSE: '1'
  MAKEFLAGS: '-d'  # Make debug mode
```

### Log Analysis

Check the generated artifacts for detailed logs:
- `config.log` - Configure stage issues
- `build.log` - Compilation problems
- `test-*.log` - Test execution details

## 🔗 Integration Examples

### With Security Scanning

```yaml
- name: 🛡️ Security Scan
  uses: bauer-group/automation-templates/.github/actions/gitleaks-scan@main

- name: 🔨 Secure Build
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    fail-on-warnings: true
    config-file: 'autotools'
```

### With Documentation Generation

```yaml
- name: 🔨 Build Project
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    make-targets: 'all doc'
    config-file: 'autotools'

- name: 📚 Deploy Documentation
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: ./doc
```

### With Package Publishing

```yaml
- name: 🔨 Create Release Build
  uses: bauer-group/automation-templates/.github/actions/makefile-build@main
  with:
    make-targets: 'dist'
    distcheck-enabled: true
    config-file: 'autotools'

- name: 🚀 Create Release
  uses: softprops/action-gh-release@v3
  with:
    files: '*.tar.gz'
```

## 📚 Related Actions

- [🛡️ Security Scan](../security-scan/README.md) - Multi-engine security scanning
- [📋 License Compliance](../license-compliance/README.md) - License compliance checking
- [🐳 Docker Build](../docker-build/README.md) - Docker containerization
- [📄 README Generate](../readme-generate/README.md) - Documentation automation

## 🤝 Contributing

Contributions are welcome! Please:

1. Follow the existing code style
2. Add tests for new features
3. Update documentation
4. Ensure cross-platform compatibility

## 📄 License

This action is part of the BAUER GROUP Automation Templates and is licensed under the MIT License.