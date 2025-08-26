# 🔨 Makefile Build Examples

This directory contains comprehensive examples for using the Makefile build system with various project types and configurations.

## 📂 Available Examples

| Example | Description | Use Case |
|---------|-------------|----------|
| **🔧 [Basic Makefile](basic-makefile.yml)** | Simple Makefile-based project | Standard C/C++ projects with basic Makefile |
| **⚙️ [Autotools Project](autotools-project.yml)** | GNU autotools-based build | Projects using autoconf/automake |
| **📦 [CMake Makefile](cmake-makefile.yml)** | CMake with Makefile generator | CMake projects generating Makefiles |
| **🐧 [Kernel Module](kernel-module.yml)** | Linux kernel module build | Kernel module development |
| **🌐 [Multi-Platform](multi-platform.yml)** | Cross-platform matrix build | Testing across multiple OS/compilers |
| **🔒 [Security-Focused](security-focused.yml)** | Security-enhanced build | Security scanning and compliance |
| **📊 [Comprehensive](comprehensive.yml)** | Full-featured build pipeline | Enterprise-grade CI/CD |

## 🚀 Quick Start

### 1. Choose Your Example

Copy the appropriate example to your repository:

```bash
# For basic Makefile projects
cp examples/makefile-build/basic-makefile.yml .github/workflows/build.yml

# For autotools projects
cp examples/makefile-build/autotools-project.yml .github/workflows/build.yml

# For CMake projects
cp examples/makefile-build/cmake-makefile.yml .github/workflows/build.yml
```

### 2. Configure Your Build

Edit the configuration in `.github/config/makefile-build/`:

```bash
# Choose or customize a configuration
cp .github/config/makefile-build/default.yml .github/config/makefile-build/my-config.yml
vim .github/config/makefile-build/my-config.yml
```

### 3. Update Your Workflow

Update the `config-file` parameter in your workflow:

```yaml
with:
  config-file: 'my-config'  # References my-config.yml
```

## 📋 Configuration Files

### Available Configurations

| Config | Description | Best For |
|--------|-------------|----------|
| `default` | Basic autotools/make setup | Standard projects |
| `autotools` | Full GNU autotools support | Complex autotools projects |
| `cmake-makefile` | CMake Makefile generator | CMake-based projects |
| `kernel-module` | Linux kernel development | Kernel modules |
| `matrix` | Multi-platform testing | Cross-platform projects |

### Customization

Create custom configurations in `.github/config/makefile-build/`:

```yaml
# .github/config/makefile-build/my-project.yml
name: "My Project Build"
description: "Custom configuration for my project"

configure:
  script: "./configure"
  args: ["--enable-feature", "--with-library"]

build:
  targets: ["all", "docs"]
  parallel_jobs: 4

test:
  targets: ["check", "integration-test"]
```

## 🔧 Common Patterns

### Standard Autotools Project

```yaml
name: 🔨 Build & Test

on: [push, pull_request]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/makefile-build.yml@main
    with:
      config-file: 'autotools'
      make-targets: 'all'
      check-targets: 'check installcheck'
      distcheck-enabled: true
```

### CMake with Makefile Generator

```yaml
name: 🔨 CMake Build

on: [push, pull_request]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/makefile-build.yml@main
    with:
      config-file: 'cmake-makefile'
      configure-script: 'cmake'
      configure-args: '-S . -B build -DCMAKE_BUILD_TYPE=Release'
      make-targets: 'all'
      working-directory: 'build'
```

### Cross-Platform Testing

```yaml
name: 🌐 Multi-Platform Build

on: [push, pull_request]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/makefile-build.yml@main
    with:
      config-file: 'matrix'
      make-targets: 'all'
      check-targets: 'check'
      upload-artifacts: true
```

## 🛡️ Security Features

### Security Scanning

Enable security scanning in your workflow:

```yaml
with:
  config-file: 'default'
  security-scan: true
  fail-on-warnings: true
```

### Secret Detection

Automatically scan for secrets before building:

```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/makefile-build.yml@main
    with:
      security-scan: true
      # Build will only run if security scan passes
```

## 📊 Advanced Features

### Artifact Management

Upload build artifacts and test results:

```yaml
with:
  generate-reports: true
  upload-artifacts: true
```

### Caching

Enable build caching for faster builds:

```yaml
with:
  cache-enabled: true
  config-file: 'autotools'  # Includes cache configuration
```

### Parallel Builds

Configure parallel compilation:

```yaml
with:
  parallel-jobs: 'auto'  # Use all available cores
  # or specify a number:
  # parallel-jobs: '4'
```

## 🔍 Troubleshooting

### Common Issues

1. **Configure script not found**
   ```yaml
   # Generate configure script from configure.ac
   configure-script: 'autoreconf -fiv && ./configure'
   ```

2. **Missing dependencies**
   ```yaml
   # Enable dependency installation
   install-dependencies: true
   ```

3. **Test failures**
   ```yaml
   # Continue on test errors for debugging
   check-targets: 'check || true'
   generate-reports: true
   ```

### Debug Mode

Enable verbose output for debugging:

```yaml
with:
  fail-on-warnings: false
  generate-reports: true
  # Check uploaded artifacts for detailed logs
```

## 📚 Additional Resources

- [Makefile Build Action Documentation](../../../actions/makefile-build/README.md)
- [Configuration Reference](../../../config/makefile-build/README.md)
- [GNU Autotools Manual](https://www.gnu.org/software/automake/manual/)
- [CMake Documentation](https://cmake.org/documentation/)
- [Make Manual](https://www.gnu.org/software/make/manual/)

## 🤝 Contributing

Have a useful Makefile build example? Please contribute:

1. Create your example workflow
2. Add appropriate documentation
3. Test with real projects
4. Submit a pull request

Follow the existing naming convention: `{category}-{type}.yml`