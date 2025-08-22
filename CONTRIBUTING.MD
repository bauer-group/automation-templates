# 🤝 Contributing to Automation Templates

## Welcome

Thank you for your interest in contributing to the BAUER GROUP Automation Templates repository! This project provides enterprise-grade GitHub Actions workflows and reusable components for modern software development.

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [Getting Started](#-getting-started)
- [Development Workflow](#-development-workflow)
- [Contributing Guidelines](#-contributing-guidelines)
- [Architecture Standards](#-architecture-standards)
- [Testing Requirements](#-testing-requirements)
- [Documentation Standards](#-documentation-standards)
- [Review Process](#-review-process)

## 📜 Code of Conduct

This project follows the [BAUER GROUP Code of Conduct](https://github.com/bauer-group/.github/blob/main/CODE_OF_CONDUCT.md). By participating, you agree to uphold this code.

## 🚀 Getting Started

### Prerequisites

- **Git**: Version 2.30+
- **GitHub Account**: With access to BAUER GROUP repositories
- **Development Environment**: VS Code recommended with YAML extension
- **Knowledge**: Basic understanding of GitHub Actions, YAML, and CI/CD concepts

### Repository Structure

```
automation-templates/
├── .github/
│   ├── workflows/          # Reusable workflows
│   ├── actions/           # Composite actions
│   └── config/            # Configuration templates
├── github/
│   ├── workflows/examples/  # Usage examples
│   └── cleanup/            # Repository maintenance tools
├── docs/                  # Documentation
└── README.MD             # Project overview
```

### Initial Setup

1. **Fork the repository** to your personal GitHub account
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/automation-templates.git
   cd automation-templates
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/bauer-group/automation-templates.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 🔄 Development Workflow

### Branching Strategy

- **Main Branch**: `main` - Production-ready code
- **Feature Branches**: `feature/description` - New features
- **Bug Fixes**: `fix/description` - Bug fixes
- **Documentation**: `docs/description` - Documentation updates

### Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/) for clear commit messages:

```
type(scope): description

feat(docker): add multi-platform build support
fix(nodejs): resolve dependency security vulnerabilities
docs(readme): update installation instructions
chore(deps): bump actions/checkout to v4
```

**Types:**
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

## 📝 Contributing Guidelines

### 1. Issues and Feature Requests

Before contributing, please:

1. **Search existing issues** to avoid duplicates
2. **Create an issue** for discussion before major changes
3. **Use issue templates** when available
4. **Provide detailed descriptions** with context and examples

### 2. Pull Request Process

1. **Update documentation** for any new features
2. **Add or update tests** as appropriate
3. **Follow coding standards** outlined below
4. **Ensure CI passes** all checks
5. **Request reviews** from maintainers
6. **Address feedback** promptly

### 3. Code Standards

#### YAML Formatting
- Use 2 spaces for indentation
- No trailing whitespace
- Consistent naming conventions (kebab-case for files)
- Descriptive comments for complex logic

#### Action Development
- Follow the [GitHub Actions best practices](https://docs.github.com/en/actions/creating-actions/about-custom-actions)
- Use semantic versioning for releases
- Include comprehensive `action.yml` metadata
- Provide clear input/output descriptions

#### Workflow Design
- Modular and reusable components
- Error handling and graceful failures
- Secure secret management
- Performance optimization (caching, parallelization)

## 🏗️ Architecture Standards

### Modular Design Principles

1. **Separation of Concerns**: Each action/workflow has a single responsibility
2. **Reusability**: Components work across different project types
3. **Configuration-Driven**: Behavior controlled via inputs and config files
4. **Security-First**: No hardcoded secrets, proper permission scoping

### Naming Conventions

#### Files and Directories
- **Workflows**: `kebab-case.yml` (e.g., `nodejs-build.yml`)
- **Actions**: `kebab-case` directories (e.g., `security-scan/`)
- **Configs**: `kebab-case.yml` in appropriate config subdirectories

#### Secrets
Follow our [Secrets Naming Convention](github/workflows/SECRETS-NAMING-CONVENTION.MD):
```
<SCOPE>_<SERVICE>_<PURPOSE>_<FORMAT>
```

Examples:
- `DOTNET_NUGET_PUBLISH_API_KEY`
- `DOCKER_REGISTRY_PASSWORD`
- `NODEJS_NPM_TOKEN`

### Configuration Management

Use the `/.github/config/` structure:
```
.github/config/
├── nodejs-build/
│   ├── default.yml
│   ├── package.yml
│   └── microservice.yml
├── docker-build/
│   └── default.yml
└── security/
    └── scan-rules.yml
```

## 🧪 Testing Requirements

### Workflow Testing

1. **Local Testing**: Use [act](https://github.com/nektos/act) for local workflow testing
2. **Integration Tests**: Test with real repositories when possible
3. **Edge Cases**: Handle error conditions gracefully
4. **Performance**: Monitor resource usage and execution time

### Test Examples

Create test workflows in `github/workflows/examples/` directories:

```yaml
name: Test Example - Node.js Build
on:
  workflow_dispatch:
    inputs:
      test-scenario:
        description: 'Test scenario to run'
        type: choice
        options: ['basic', 'with-cache', 'multi-version']

jobs:
  test-nodejs-build:
    uses: ./.github/workflows/nodejs-build.yml
    with:
      node-versions: '["16", "18", "20"]'
      package-manager: 'npm'
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

## 📚 Documentation Standards

### Required Documentation

1. **README.MD**: Overview, quick start, examples
2. **Action README.MD**: Detailed usage, inputs, outputs
3. **Examples**: Working examples in `github/workflows/examples/`
4. **CHANGELOG.MD**: Version history and breaking changes

### Documentation Format

#### Action Documentation Template
```markdown
# Action Name

Brief description of what this action does.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `input-name` | Description | Yes | `default` |

## Outputs

| Output | Description |
|--------|-------------|
| `output-name` | Description |

## Example Usage

\```yaml
- name: Step Name
  uses: bauer-group/automation-templates/.github/actions/action-name@main
  with:
    input-name: value
\```
```

#### Workflow Documentation
- Clear purpose and use cases
- Configuration options
- Secret requirements
- Integration examples
- Troubleshooting guide

### Examples and Templates

Provide comprehensive examples:

1. **Basic Usage**: Minimal configuration
2. **Advanced Usage**: Full feature demonstration  
3. **Integration**: Real-world scenarios
4. **Troubleshooting**: Common issues and solutions

## 🔍 Review Process

### Pull Request Reviews

1. **Automated Checks**: CI must pass
2. **Code Review**: At least one maintainer approval
3. **Security Review**: For security-related changes
4. **Documentation Review**: Ensure completeness

### Review Criteria

#### Functionality
- ✅ Feature works as expected
- ✅ Error handling implemented
- ✅ Performance considerations addressed
- ✅ Security best practices followed

#### Code Quality
- ✅ Follows project conventions
- ✅ Clear, readable code
- ✅ Appropriate comments
- ✅ No hardcoded values

#### Documentation
- ✅ Updated README files
- ✅ Added usage examples
- ✅ Updated CHANGELOG
- ✅ Clear commit messages

### Feedback Process

1. **Be Constructive**: Provide specific, actionable feedback
2. **Be Responsive**: Address review comments promptly
3. **Be Collaborative**: Work together to improve the solution
4. **Be Patient**: Reviews take time for quality assurance

## 🏷️ Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Workflow

1. **Prepare Release**: Update CHANGELOG.MD and documentation
2. **Create PR**: Target `main` branch
3. **Review**: Maintainer approval required
4. **Tag Release**: Automatic via [automatic-release.yml](.github/workflows/automatic-release.yml)
5. **Documentation**: Auto-updated via [documentation.yml](.github/workflows/documentation.yml)

## 🆘 Getting Help

### Communication Channels

- **Issues**: For bug reports and feature requests
- **Discussions**: For questions and general discussion
- **Email**: support@bauer-group.com for sensitive issues

### Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [YAML Specification](https://yaml.org/spec/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)

## 📄 License

By contributing to this repository, you agree that your contributions will be licensed under the same license as the project.

---

**Thank you for contributing to making our automation infrastructure better! 🚀**

For questions or clarification on these guidelines, please create an issue or reach out to the maintainers.