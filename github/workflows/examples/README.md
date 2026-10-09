# GitHub Actions Workflow Examples

This directory contains example workflows demonstrating how to use the reusable workflows from this repository.

## Directory Structure

```
github/workflows/examples/
├── auto-maintenance/        # Base images + dependency updates in one run
│   ├── README.md
│   ├── weekly-maintenance.yml
│   └── maintenance-config.json
├── backup-roundtrip/        # Backup round trip of a compose stack before release
│   ├── README.md
│   ├── minimal-postgres-filesystem.yml
│   ├── gated-release-pipeline.yml
│   ├── plugin-and-external-sources.yml
│   ├── upgrade-from-previous-release.yml
│   ├── offsite-s3-new-host.yml
│   └── compose-variants-matrix.yml
├── ci-cd/                   # CI/CD pipeline examples
│   ├── comprehensive-ci-cd.yml
│   └── security-focused.yml
├── documentation/           # Documentation & automation examples
│   ├── ai-issue-summary.yml
│   ├── documentation.yml
│   ├── issue-automation.yml
│   ├── pr-labeler.yml
│   └── readme.yml
├── dotnet-desktop-build/    # .NET Desktop application examples
│   ├── basic-wpf-build.yml
│   ├── advanced-signed-build.yml
│   ├── msix-package-build.yml
│   ├── multi-project-build.yml
│   └── matrix-build-test.yml
├── dotnet-build/            # .NET Core/5+ application examples
│   ├── simple-library.yml
│   ├── web-api-docker.yml
│   ├── nuget-package-publish.yml
│   ├── blazor-wasm-deploy.yml
│   ├── matrix-cross-platform.yml
│   └── microservice-k8s.yml
├── nodejs-build/            # Node.js application examples
│   ├── simple-npm-package.yml
│   ├── npm-publish-release.yml
│   ├── matrix-multi-version.yml
│   ├── react-app-deploy.yml
│   ├── nextjs-docker-deploy.yml
│   └── monorepo-turborepo.yml
├── python-release/           # Python package release examples
│   ├── nocodb-simpleclient-example.yml
│   └── README.MD
├── release/                 # Release automation examples
│   ├── semantic-release.yml
│   └── simple-release.yml
├── security/               # Security workflow examples
│   ├── automatic-release.yml
│   └── manual-release.yml
├── project-templates/      # Complete project workflow templates
│   └── nodejs-project.yml
├── docker/                 # Docker build examples
│   ├── simple-docker-build.yml
│   ├── dockerhub-with-readme-sync.yml
│   └── ...
├── fork-docker-build/       # Image build for forked repositories
│   ├── README.md
│   └── fork-docker-build.yml
├── docker-base-image-monitor/      # Rebuild when a floating base image tag moves
│   ├── README.md
│   ├── daily-release-dispatch.yml
│   ├── multi-image-config.yml
│   ├── multi-image-base-images.json
│   └── dry-run.yml
├── docker-maintenance-dependabot/  # Merge Dependabot PRs after their PR CI passed
│   ├── README.md
│   ├── simple-dependabot-maintenance.yml
│   ├── with-backup-roundtrip-gate.yml
│   ├── own-build-and-test-workflow.yml
│   ├── multiple-required-workflows.yml
│   └── no-pr-ci-manual-merge.yml
└── claude-code/            # Claude Code Assistant examples
    ├── basic-claude-assistant.yml
    ├── code-review-assistant.yml
    ├── security-review-assistant.yml
    ├── restricted-claude-assistant.yml
    └── multi-trigger-assistant.yml
```

## Using These Examples

1. **Copy the example** that matches your use case
2. **Place it in your repository's** `.github/workflows/` directory
3. **Modify the configuration** to match your project structure
4. **Update the `uses:` statement** to reference this repository:
   ```yaml
   uses: your-org/automation-templates/.github/workflows/[workflow-name].yml@main
   ```

## Available Reusable Workflows

### .NET Desktop Build (`dotnet-desktop-build.yml`)
For building Windows desktop applications (WPF, WinForms, MAUI)

**Examples:**
- `dotnet-desktop-build/basic-wpf-build.yml` - Simple WPF application
- `dotnet-desktop-build/advanced-signed-build.yml` - With code signing
- `dotnet-desktop-build/msix-package-build.yml` - MSIX packaging
- `dotnet-desktop-build/multi-project-build.yml` - Multiple projects
- `dotnet-desktop-build/matrix-build-test.yml` - Matrix configurations

### .NET Build (`dotnet-build.yml`)
For building .NET Core/5+ applications, libraries, and services

**Examples:**
- `dotnet-build/simple-library.yml` - Class library
- `dotnet-build/web-api-docker.yml` - Web API with Docker
- `dotnet-build/nuget-package-publish.yml` - NuGet publishing
- `dotnet-build/blazor-wasm-deploy.yml` - Blazor WebAssembly
- `dotnet-build/matrix-cross-platform.yml` - Cross-platform builds
- `dotnet-build/microservice-k8s.yml` - Microservice with Kubernetes

### Node.js Build (`nodejs-build.yml`)
For building Node.js applications and packages

**Examples:**
- `nodejs-build/simple-npm-package.yml` - NPM package
- `nodejs-build/npm-publish-release.yml` - NPM publishing
- `nodejs-build/matrix-multi-version.yml` - Multi-version testing
- `nodejs-build/react-app-deploy.yml` - React deployment
- `nodejs-build/nextjs-docker-deploy.yml` - Next.js with Docker
- `nodejs-build/monorepo-turborepo.yml` - Monorepo management

### Python Release (`python-automatic-release.yml`)
For building and releasing Python packages with comprehensive CI/CD

**Examples:**
- `python-release/nocodb-simpleclient-example.yml` - Complete Python package release
- `python-release/README.MD` - Detailed documentation and GitHub Packages installation guide

### Backup Round-Trip Test (`modules-backup-roundtrip-test.yml`)
Starts a compose stack with its BackupHelper sidecar, seeds data, backs it up, deletes it, restores it and proves it is back — before an image is released

**Examples:**
- `backup-roundtrip/minimal-postgres-filesystem.yml` - PostgreSQL + file volume, on pull requests
- `backup-roundtrip/gated-release-pipeline.yml` - Complete `docker-release.yml` gated on the round trip
- `backup-roundtrip/plugin-and-external-sources.yml` - In-stack plugin source tested, external SaaS source switched off
- `backup-roundtrip/upgrade-from-previous-release.yml` - Upgrade from the latest release: old sidecar backs up, new sidecar restores
- `backup-roundtrip/offsite-s3-new-host.yml` - Off-site copy in a throwaway S3 bucket, restored on a "new host" with a wiped data dir
- `backup-roundtrip/compose-variants-matrix.yml` - One round trip per compose variant (local, Traefik, Coolify), external proxy networks created
- `backup-roundtrip/README.md` - Setup and what a run proves

### Docker Build (`docker-build.yml`)
Multi-platform image build with a security scan gate before the push, SBOM, signing and Dockerfile version write-back

**Examples:** see [`docker/README.md`](docker/README.md) for all of them, e.g.
- `docker/simple-docker-build.yml` - Basic GHCR build
- `docker/large-image-build.yml` - Images that outgrow a GitHub-hosted runner's free disk (`free-disk-space`, `cache-mode: 'min'`)
- `docker/self-hosted-build.yml` - Self-hosted runners (`free-disk-space` is skipped there - free space on the host)

### Fork Docker Build (`fork-docker-build.yml`)
Lean multi-image builder for forks: Trivy scan before the push, workspace tags, GHCR

**Examples:**
- `fork-docker-build/fork-docker-build.yml` - Drop-in caller for the fork's `workspace` branch
- `fork-docker-build/README.md` - Setup, per-image options, disk space

### Docker Maintenance with Dependabot (`docker-maintenance-dependabot.yml`)
Merges a Dependabot PR only after every workflow in `required-workflows` has run on its head commit and passed. The caller's `on.pull_request.paths` decide which Dependabot PRs reach it at all

**Examples:**
- `docker-maintenance-dependabot/simple-dependabot-maintenance.yml` - Smallest caller: Dockerfile updates, one PR CI workflow
- `docker-maintenance-dependabot/with-backup-roundtrip-gate.yml` - Container stack: merged after the PR run of `docker-release.yml`, backup round trip included; private-repository permissions
- `docker-maintenance-dependabot/own-build-and-test-workflow.yml` - Image without backup: the repository's own `ci.yml` vouches; Docker and npm updates
- `docker-maintenance-dependabot/multiple-required-workflows.yml` - Image build and a separate test suite, both required
- `docker-maintenance-dependabot/no-pr-ci-manual-merge.yml` - No PR CI: `required-workflows` deliberately unset, nothing is merged
- `docker-maintenance-dependabot/README.md` - Setup, trigger scope and what decides a merge

### Docker Base Image Monitor (`modules-docker-base-image-monitor.yml`)
Reads the digest behind floating tags (`stable`, `latest`) and releases a rebuild when it moves; the digest is stored once the dispatched release succeeded, failed releases are retried

**Examples:**
- `docker-base-image-monitor/daily-release-dispatch.yml` - Daily check that dispatches `docker-release.yml` with `force-release`
- `docker-base-image-monitor/multi-image-config.yml` + `multi-image-base-images.json` - Several images (Docker Hub and internal GHCR) in one config
- `docker-base-image-monitor/dry-run.yml` - Config changes checked on their PR; preview before recovery
- `docker-base-image-monitor/README.md` - Setup, what a check does and what to do when a release keeps failing

### Auto Maintenance (`modules-auto-maintenance.yml`)
Base image digests and dependency updates (npm, pip, .NET, Go) in one scheduled run, validated by the repository's build and tests and rolled back on failure

**Examples:**
- `auto-maintenance/weekly-maintenance.yml` - Weekly run with a manual dry run
- `auto-maintenance/maintenance-config.json` - Three floating base images and a release dispatch, as the container stacks run it
- `auto-maintenance/README.md` - Setup, the known limitation (npm, pip and .NET updates are not committed yet), and when to use the base image monitor or Dependabot instead

### CI/CD Pipelines
Complete CI/CD pipeline configurations

**Examples:**
- `ci-cd/comprehensive-ci-cd.yml` - Full CI/CD pipeline with all checks
- `ci-cd/security-focused.yml` - Security-first CI/CD pipeline

### Documentation & Automation
Various automation and documentation workflows

**Examples:**
- `documentation/ai-issue-summary.yml` - AI-powered issue summaries (**paused**, being reworked in [#105](https://github.com/bauer-group/automation-templates/issues/105))
- `documentation/documentation.yml` - Auto-generate documentation
- `documentation/issue-automation.yml` - Issue management automation
- `documentation/pr-labeler.yml` - Automatic PR labeling
- `documentation/readme.yml` - README generation

### Release Management
Release and versioning workflows

**Examples:**
- `release/semantic-release.yml` - Semantic versioning automation
- `release/simple-release.yml` - Basic release workflow

### Security Workflows
Security scanning and compliance workflows

**Examples:**
- `security/automatic-release.yml` - Secure automated releases
- `security/manual-release.yml` - Manual release with security checks

### Project Templates
Complete workflow templates for specific project types

**Examples:**
- `project-templates/nodejs-project.yml` - Complete Node.js project setup

### Claude Code Assistant (`claude-code.yml`)

AI-powered code assistant that responds to @claude mentions

**Examples:**

- `claude-code/basic-claude-assistant.yml` - Simple setup responding to @claude
- `claude-code/code-review-assistant.yml` - Thorough code reviews on PRs
- `claude-code/security-review-assistant.yml` - Security-focused code analysis
- `claude-code/restricted-claude-assistant.yml` - Limited to specific users/teams
- `claude-code/multi-trigger-assistant.yml` - Different behaviors per trigger phrase

## Configuration

Most workflows support configuration through:

1. **Workflow inputs** - Direct parameters in the workflow file
2. **Configuration files** - YAML files in `.github/config/`
3. **Secrets** - Sensitive data like tokens and credentials
4. **Environment variables** - Runtime configuration

## Best Practices

1. **Start simple** - Use basic examples and add complexity as needed
2. **Use matrix builds** - Test across multiple versions/platforms
3. **Cache dependencies** - Improve build performance
4. **Pin versions** - Use specific versions for reproducibility
5. **Secure secrets** - Never commit sensitive data

## Support

### Setup & Configuration

- [Secrets Reference](../../../docs/secrets-reference.md) - All required secrets and tokens
- [Self-Hosted Runners](../../../docs/self-hosted-runners.md) - Runner configuration

### Build Workflow Documentation
- [Docker Build Documentation](../../../docs/workflows/docker-build.md)
- [Fork Docker Build Documentation](../../../docs/workflows/fork-docker-build.md)
- [Backup Round-Trip Test Documentation](../../../docs/workflows/modules-backup-roundtrip-test.md)
- [Docker Maintenance Documentation](../../../docs/workflows/docker-maintenance.md)
- [Auto Maintenance Documentation](../../../docs/workflows/modules-auto-maintenance.md)
- [Docker Base Image Monitor Documentation](../../../docs/workflows/modules-docker-base-image-monitor.md)
- [Python Build Documentation](../../../docs/workflows/python-build.md)
- [.NET Desktop Build Documentation](../../../docs/workflows/dotnet-desktop-build.md)
- [.NET Build Documentation](../../../docs/workflows/dotnet-build.md)
- [Node.js Build Documentation](../../../docs/workflows/nodejs-build.md)

### Management & Notification Workflows
- [Teams Notifications Documentation](../../../docs/workflows/teams-notifications.md)
- [Documentation Management Workflow](../../../.github/workflows/documentation.yml)
- [Security Policy Management Workflow](../../../.github/workflows/security-management.yml)

### Project Resources
- [Contributing Guidelines](../../../CONTRIBUTING.MD) - Learn how to contribute
- [Security Policy](../../../SECURITY.MD) - Security and vulnerability reporting
- [Code of Conduct](../../../CODE_OF_CONDUCT.md) - Community standards

## Contributing

When adding new examples:
1. Place them in the appropriate category directory
2. Use descriptive names
3. Include comments explaining key configurations
4. Update this README with the new example