# Python Release Workflow Examples

This directory contains examples for using the Python automatic release workflow.

## Overview

The Python automatic release workflow (`python-automatic-release.yml`) provides:
- 🐍 Full Python CI/CD pipeline with integrated testing
- 🛡️ Security scanning (Gitleaks, GitGuardian, Bandit, Safety)
- 🧪 Comprehensive test suite with pytest, coverage, and quality checks
- 📦 PyPI and GitHub Packages publishing
- 🚀 Semantic versioning with automatic releases

## Quick Start

### 1. Basic Usage

Copy the example workflow to your repository's `.github/workflows/` directory:

```yaml
# .github/workflows/python-release.yml
name: 🚀 Python Release

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  release:
    name: 📦 Python Package Pipeline
    uses: bauer-group/automation-templates/.github/workflows/python-automatic-release.yml@main
    with:
      python-version: '3.12'
      version-file: 'src/your_package/__init__.py'
    secrets: inherit
```

### 2. Required Secrets

Configure these secrets in your repository settings:

```yaml
# Required
PYPI_API_TOKEN       # Your PyPI API token
GITHUB_TOKEN         # Automatically provided by GitHub

# Optional
GITGUARDIAN_API_KEY  # GitGuardian API key for enhanced security
GITLEAKS_LICENSE     # Gitleaks Pro license key
```

### 3. Project Structure

The workflow auto-discovers your project structure, but works best with:

```
your-python-project/
├── src/
│   └── your_package/
│       ├── __init__.py          # Contains __version__ = "1.0.0"
│       └── module.py
├── tests/                       # Automatically discovered
│   ├── test_module.py
│   └── conftest.py
├── scripts/                     # Optional test scripts
│   └── test-integration.py
├── pyproject.toml              # Preferred configuration
├── requirements.txt            # Dependencies
├── requirements-dev.txt        # Development dependencies
└── README.md
```

## Configuration Options

### Workflow Inputs

| Input | Description | Default | Required |
|-------|-------------|---------|----------|
| `python-version` | Python version to use | `'3.12'` | No |
| `security-engine` | Security scan engine (`gitleaks`, `gitguardian`, `both`) | `'both'` | No |
| `force-release` | Force create release even without changes | `false` | No |
| `skip-pypi` | Skip PyPI publishing | `false` | No |
| `package-source-path` | Path to package source | `'src'` | No |
| `version-file` | File containing `__version__` variable | Auto-discovered | No |

### Example with All Options

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/python-automatic-release.yml@main
    with:
      python-version: '3.11'
      security-engine: 'both'
      force-release: false
      skip-pypi: false
      package-source-path: 'src'
      version-file: 'src/my_package/__init__.py'
    secrets: inherit
```

## Direct GitHub Installation

The workflow configures your repository for direct installation using pip and git. Users can install your package directly from GitHub without needing package registries.

### Method 1: Install Latest Release (Recommended)

```bash
# Install the latest released version
pip install git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient

# Install a specific release tag
pip install git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient@v1.2.3
```

### Method 2: Install from Specific Branch

```bash
# Install from main branch (development version)
pip install git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient@main

# Install from feature branch
pip install git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient@feature-branch
```

### Method 3: Install with Extra Dependencies

```bash
# Install with development dependencies
pip install "git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient[dev]"

# Install with specific extras (if configured in pyproject.toml)
pip install "git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient[test,docs]"
```

### Method 4: Development Installation (Editable)

```bash
# Clone and install in editable mode
git clone https://github.com/bauer-group/LIB-NocoDB_SimpleClient.git
cd LIB-NocoDB_SimpleClient
pip install -e .

# Or with development dependencies
pip install -e ".[dev]"
```

### Method 5: Using requirements.txt

Add to your `requirements.txt`:

```txt
# Latest release
git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient

# Specific version
git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient@v1.2.3

# From branch
git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient@main

# With extras
git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient[dev]
```

### Method 6: Private Repository Authentication

For private repositories, authenticate using:

```bash
# Using personal access token
pip install git+https://username:token@github.com/bauer-group/LIB-NocoDB_SimpleClient

# Using SSH (with SSH key configured)
pip install git+ssh://git@github.com/bauer-group/LIB-NocoDB_SimpleClient.git
```

### Method 7: Installation with Subdirectories

If your Python package is in a subdirectory:

```bash
pip install git+https://github.com/bauer-group/LIB-NocoDB_SimpleClient#subdirectory=python-package
```

## Package Publishing Details

### PyPI Publishing (Recommended)

The workflow automatically publishes to PyPI when:
- A release is created by semantic-release
- `skip-pypi` is not set to `true`
- `PYPI_API_TOKEN` secret is configured

### Direct GitHub Installation Setup

**✅ Automatic Configuration**: The workflow automatically configures your repository for direct git installation.

The workflow:
- Verifies repository structure for pip compatibility
- Creates/updates setup.py if needed
- Generates INSTALLATION.md with usage instructions
- Tests installation compatibility
- Provides installation commands in pipeline summary

**Installation Requirements:**
- Repository must have `pyproject.toml` or `setup.py`
- Package structure should follow Python standards
- Version information in `__init__.py` or configuration files

## Examples

### Example 1: NocoDB SimpleClient

See [nocodb-simpleclient-example.yml](./nocodb-simpleclient-example.yml) for a complete example with:
- Python 3.12
- Custom version file location
- Security scanning with both engines
- Conditional PyPI publishing

### Example 2: Basic Library

```yaml
name: 🚀 Release My Python Library

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/python-automatic-release.yml@main
    with:
      python-version: '3.11'
    secrets: inherit
```

### Example 3: Advanced Configuration

```yaml
name: 🚀 Advanced Python Release

on:
  push:
    branches: [ main ]
    paths-ignore:
      - 'docs/**'
      - '*.md'
  pull_request:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      force-release:
        description: 'Force create release'
        type: boolean
        default: false

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/python-automatic-release.yml@main
    with:
      python-version: '3.12'
      security-engine: 'both'
      force-release: ${{ inputs.force-release || false }}
      version-file: 'src/my_package/__init__.py'
    secrets: inherit
```

## Workflow Features

### ✅ What's Included

- **Automated Testing**: pytest, coverage reporting, test discovery
- **Code Quality**: flake8, mypy, black, isort checks
- **Security Scanning**: Bandit, Safety, Gitleaks, GitGuardian
- **Package Building**: Wheel and source distributions  
- **Version Management**: Automatic version detection and updating
- **Release Creation**: Semantic release with changelog
- **Publishing**: PyPI publishing and direct GitHub installation setup
- **Artifacts**: Test reports, coverage, security scans

### 🔄 Workflow Steps

1. **PR Validation** (for pull requests)
2. **Security Analysis** (Python security tools + configurable engines)
3. **Build & Test** (comprehensive testing with auto-discovery)
4. **License Compliance** (SBOM generation)
5. **Release Management** (semantic versioning)
6. **Package Building** (with correct release version)
7. **Publishing** (PyPI and direct GitHub installation setup)
8. **Documentation Updates** (automatic updates after release)

### 📊 Generated Artifacts

- **Test Results**: HTML and JSON reports with coverage
- **Security Reports**: Bandit and Safety scan results
- **Package Artifacts**: Built wheels and source distributions
- **Pipeline Summary**: Detailed status and installation instructions

## Troubleshooting

### Common Issues

1. **Version Detection**: Ensure your `__init__.py` contains `__version__ = "x.y.z"`
2. **Test Failures**: Check test discovery - use `tests/` or `test/` directory
3. **PyPI Upload**: Verify `PYPI_API_TOKEN` is correctly configured
4. **Security Scans**: Install missing tools in development environment

### Support

For issues and questions:
- [Repository Issues](https://github.com/bauer-group/automation-templates/issues)
- [Contributing Guidelines](../../../../CONTRIBUTING.MD)
- [Security Policy](../../../../SECURITY.MD)

## Migration Guide

### From Other Workflows

If you're migrating from another Python CI/CD workflow:

1. **Copy your secrets** to the required format
2. **Update version files** to use `__version__` format
3. **Move tests** to `tests/` directory if needed
4. **Update dependencies** in requirements files
5. **Test the workflow** with a pull request first

### Upgrading

When upgrading to newer versions:
- Review the [CHANGELOG](../../../../CHANGELOG.md)
- Check for breaking changes in inputs
- Update your workflow file references

---

*Powered by **BAUER GROUP** automation templates* 🐍