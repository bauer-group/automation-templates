# Docker Build Workflow

This document describes the comprehensive Docker build system provided by the automation-templates repository. The system includes reusable workflows, actions, and configurations for building, testing, and deploying Docker images with enterprise-grade security and best practices.

## Overview

The Docker build system provides:

- **Reusable Workflows**: Pre-configured workflows for different application types
- **Composite Actions**: Modular Docker build components
- **Multi-Registry Support**: Push to GHCR, Docker Hub, or both with a single build
- **Security Integration**: Comprehensive vulnerability scanning and image signing
- **Multi-Platform Support**: Cross-architecture builds for cloud and edge deployment
- **Enterprise Features**: Compliance, governance, and comprehensive monitoring

## Quick Start

### Basic Usage (GitHub Container Registry)

```yaml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      ghcr-image-name: 'my-app'
      auto-tags: true
    secrets: inherit
```

### Push to Docker Hub Only

```yaml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'dockerhub'
      docker-image-name: 'myuser/my-app'
      auto-tags: true
    secrets: inherit
```

### Push to Both Registries

```yaml
name: Docker Build
on:
  push:
    branches: [main]
    tags: ['v*.*.*']

jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'both'
      ghcr-image-name: 'my-org/my-app'
      docker-image-name: 'myuser/my-app'
      auto-tags: true
      sync-dockerhub-readme: true
    secrets: inherit
```

## Registry Configuration

### The `publish-to` Input

The `publish-to` input controls where Docker images are published:

| Value | Primary Registry | Secondary Registry | Authentication |
|-------|------------------|-------------------|----------------|
| `ghcr` (default) | ghcr.io | - | `github.actor` + `GITHUB_TOKEN` (automatic) |
| `dockerhub` | docker.io | - | `DOCKER_USERNAME` + `DOCKER_PASSWORD` |
| `both` | ghcr.io | docker.io | GHCR automatic, Docker Hub via secrets |

### Required Secrets

| Secret | Required When | Description |
|--------|---------------|-------------|
| `DOCKER_USERNAME` | `publish-to: 'dockerhub'` or `'both'` | Docker Hub username |
| `DOCKER_PASSWORD` | `publish-to: 'dockerhub'` or `'both'` | Docker Hub password or access token |
| `COSIGN_PRIVATE_KEY` | `sign-image: true` | Cosign private key for image signing |
| `COSIGN_PASSWORD` | `sign-image: true` | Cosign key password |

**Note:** For GHCR, `GITHUB_TOKEN` is automatically available and used for authentication.

## Components

### 1. Reusable Workflow

**File**: `.github/workflows/docker-build.yml`

The main workflow orchestrates the entire Docker build process including:

- **Build Job**: Docker image building with BuildKit
- **Test Job**: Container testing and validation
- **Security Job**: Vulnerability scanning and SBOM generation
- **README Sync Job**: Synchronize README to Docker Hub
- **Deploy Job**: Conditional deployment to target environments

### 2. Composite Action

**File**: `.github/actions/docker-build/action.yml`

The Docker build action provides:

- Multi-platform build support
- Advanced caching strategies
- Multi-registry authentication
- Security scanning integration
- Image signing with Cosign
- SBOM generation
- Performance optimization

## Input Parameters

### Registry & Publishing

| Parameter | Description | Default |
|-----------|-------------|---------|
| `publish-to` | Where to publish: `'ghcr'`, `'dockerhub'`, or `'both'` | `'ghcr'` |
| `ghcr-image-name` | GitHub Container Registry image name (e.g., `org/app-name`) | Repository name |
| `docker-image-name` | Docker Hub image name (e.g., `username/app-name`) | `''` |
| `registry` | Custom registry URL (when `publish-to: 'ghcr'`) | `'ghcr.io'` |
| `secondary-registry` | Secondary registry URL (for custom multi-registry setups) | `''` |

### Version & Tagging

| Parameter | Description | Default |
|-----------|-------------|---------|
| `auto-tags` | Generate automatic tags based on Git refs | `true` |
| `latest-tag` | Tag image as `latest` on tag push | `true` |
| `image-tags` | Additional custom image tags | `''` |
| `version-from-dockerfile` | Extract version from Dockerfile LABEL | `false` |
| `semver-from-dockerfile` | Generate additional semver tags (major.minor, major) from Dockerfile version on branch commits | `true` |
| `update-dockerfile-version` | Update Dockerfile LABEL from Git tag | `false` |

### Build Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `dockerfile-path` | Path to Dockerfile | `'./Dockerfile'` |
| `docker-context` | Docker build context | `'.'` |
| `build-target` | Docker build target stage | `''` |
| `build-args` | Build arguments as JSON object | `'{}'` |
| `platforms` | Target platforms to build and push (comma-separated). Listing more than one produces a multi-arch manifest list | `'linux/amd64'` |
| `multi-platform` | **Deprecated** - ignored. `platforms` alone decides what is built | `false` |
| `checkout-fetch-depth` | Git history depth for the build checkout. `0` = full history (required for Dockerfile-version write-back and semver derivation); set `1` for a faster shallow checkout when neither is used | `0` |
| `checkout-lfs` | Fetch Git LFS objects on the build checkout; set `false` to skip LFS blobs for a faster checkout | `true` |

### Push Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `push` | Push image to registry | `true` |
| `push-on-pr` | Push images on pull requests | `false` |

### Security Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `security-scan` | Run security vulnerability scan | `true` |
| `security-scanner` | Scanner: `'trivy'`, `'grype'`, `'snyk'` | `'trivy'` |
| `security-fail-on` | Fail on: `'CRITICAL'`, `'HIGH'`, `'MEDIUM'`, `'LOW'` | `'CRITICAL'` |
| `security-ignore-unfixed` | Ignore unfixed vulnerabilities | `false` |
| `sign-image` | Sign image with Cosign | `false` |
| `generate-sbom` | Generate Software Bill of Materials | `false` |
| `sbom-format` | SBOM format: `'cyclonedx'`, `'spdx'` | `'cyclonedx'` |
| `attest-sbom` | Create a GitHub (Sigstore) attestation for the SBOM. Requires `generate-sbom: true` | `false` |
| `provenance` | SLSA build provenance for the pushed image: `'false'`, `'true'`, or `'mode=max'`. Enabling it attaches an attestation manifest | `'false'` |
| `generate-vex` | Generate an OpenVEX document from the Trivy scan report (requires `security-scan: true` with the `trivy` scanner) | `false` |

### Docker Hub README Sync

| Parameter | Description | Default |
|-----------|-------------|---------|
| `sync-dockerhub-readme` | Sync README to Docker Hub | `false` |
| `readme-file` | Custom README path (auto-detects if empty) | `''` |

### Caching & Performance

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cache-enabled` | Enable build caching | `true` |
| `cache-mode` | Cache mode: `'min'`, `'max'`, `'inline'` | `'max'` |
| `free-disk-space` | Remove unused runner toolchains before building (Linux only) | `false` |
| `builder-driver` | Builder driver: `'docker'`, `'docker-container'`, `'kubernetes'` | `'docker-container'` |
| `build-timeout` | Build timeout in minutes | `30` |

#### Running out of disk space

A GitHub-hosted runner has roughly 4 GB free once the toolchains it ships with
are accounted for. That is enough for most images and not enough for large ones,
because a build needs the space several times over: BuildKit's layers, the
`load: true` copy this workflow keeps in the daemon so the image can be scanned,
the cache export, and - when `security-scan` is on - the tarball Trivy has Docker
export before it analyses anything.

When it runs out, it does not say so plainly. The scan fails with
`unable to export the image: no space left on device`, minutes and one step away
from the cause, which reads like a scanner fault; disabling the scanner does not
help, because the expensive step is the unconditional local build. Run out
earlier and the runner process itself dies without writing a log.

```yaml
free-disk-space: true
```

removes toolchains no Docker build uses - the CodeQL bundle, Android SDK, .NET,
GHC, Swift, PowerShell - and logs `df -h /` before and after, so the number is in
the log whether or not it turned out to matter. Over 10 GB on a current
`ubuntu-24.04` runner, most of it the Android SDK and the CodeQL bundle.

Deliberately not the whole of `/opt/hostedtoolcache`: only its CodeQL bundle,
which is the bulk of it and is never used inside a build job. The rest holds the
Python, Node and Go versions a `setup-*` step later in the same job may expect.

Deliberately not `/usr/local/lib/node_modules` either, which several published
cleanup snippets do remove: npm lives in it, so deleting it leaves
`/usr/local/bin/npm` dangling and breaks `run-tests` for any repository with a
`package.json` - the pre-build test step runs `npm test`.

`cache-mode: 'min'` is the other lever worth reaching for: the default `'max'`
exports every intermediate layer of every build stage, into two separate scopes.
On a multi-stage build that export is regularly larger than the image itself.

Both settings together, with the reasoning inline, are in
**[large-image-build.yml](../../github/workflows/examples/docker/large-image-build.yml)**.

The scan says so before it dies, too. It measures the image against the free space
on `/var/lib/docker` and reports one of three things:

| Free space | Behaviour |
|---|---|
| below the image size | error, job stops before Trivy runs |
| between 1x and 2x the image size | warning naming the real requirement |
| 2x or more | silent |

Trivy needs closer to twice the image size - the export tarball, plus room to
analyse the layers - but a build in the middle band can still finish, so that one
warns rather than blocks. A real failure showed `Image ~1967 MB, free ~3142 MB`,
passed the gate and died in the scan three minutes later; that run now carries the
warning in its log.

### Platform Configuration

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `runs-on` | Runner to use | `ubuntu-latest` | String or JSON array (see below) |

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

### Deployment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `deploy-enabled` | Enable deployment after build | `false` |
| `deploy-environment` | Deployment environment | `'staging'` |
| `deploy-command` | Custom deployment command | `''` |

## Automatic Tag Generation

When `auto-tags: true`, the workflow generates tags based on Git context and registry:

### GHCR (Primary Registry)

**On Tag Push (e.g., `v1.2.3`):**

- `1.2.3` - Full semantic version
- `1.2` - Major.minor version
- `1` - Major version (disabled for v0.x.x)
- `latest` - If `latest-tag: true`

**On Branch Push:**

- `main` or `develop` - Branch name
- `main-a1b2c3d` - Branch + commit SHA prefix

**On Pull Request:**

- `pr-123` - Pull request number

### Docker Hub (Secondary Registry)

Docker Hub only receives **release tags** (no branch/SHA tags):

**On Tag Push (e.g., `v1.2.3`):**

- `1.2.3` - Full semantic version
- `1.2` - Major.minor version
- `1` - Major version (disabled for v0.x.x)
- `latest` - If `latest-tag: true`

**On Branch Push:** No tags (image not pushed to Docker Hub)

This ensures Docker Hub only contains stable, versioned releases.

## Version Management

### Extract Version from Dockerfile

When `version-from-dockerfile: true`, the workflow extracts the version from Dockerfile LABEL:

```dockerfile
LABEL org.opencontainers.image.version="1.2.3"
```

This version is used as an additional image tag.

### Semver Tags from Dockerfile Version

When `semver-from-dockerfile: true` (default) and `version-from-dockerfile: true`, the workflow generates additional semantic version tags from the extracted Dockerfile version on **branch commits**:

**Example:** Dockerfile contains `org.opencontainers.image.version="0.2.1"`

On branch push (e.g., `main`):

- `0.2.1` - Full version
- `0.2` - Major.minor version
- `0` - Major version (only if major > 0, following semver convention)

This is useful when you want consistent semver tagging without requiring Git tag pushes.

**Note:** On Git tag pushes, the standard `type=semver` patterns are used instead, as they work natively with the metadata-action.

### Update Dockerfile Version from Git Tag

When `update-dockerfile-version: true` and a Git tag is pushed (e.g., `v1.2.3`):

1. The workflow extracts the version from the tag (stripping `v` prefix)
2. Updates the Dockerfile LABEL `org.opencontainers.image.version`
3. Uses the updated version for tagging
4. **Commits the updated Dockerfile back to the default branch**

This ensures the Dockerfile version stays in sync with release tags.

**Note:** The workflow requires `contents: write` permission to commit the Dockerfile update:

```yaml
permissions:
  contents: write
  packages: write
```

## Security Features

### Vulnerability Scanning

```yaml
security-scan: true
security-scanner: 'trivy'
security-fail-on: 'HIGH'
security-ignore-unfixed: false
```

### Image Signing with Cosign

```yaml
sign-image: true
# Requires secrets:
# COSIGN_PRIVATE_KEY
# COSIGN_PASSWORD
```

### SBOM Generation

```yaml
generate-sbom: true
sbom-format: 'cyclonedx'  # or 'spdx'
```

### SBOM Attestation & Build Provenance (opt-in)

Create a cryptographic, verifiable trail for the published image. Both default to
today's behaviour (off) and require no changes for existing callers:

```yaml
generate-sbom: true
attest-sbom: true      # Sigstore attestation for the SBOM (verifiable provenance)
provenance: 'mode=max' # SLSA build provenance attached to the pushed image
```

The workflow already requests `attestations: write` and `id-token: write`; a caller
using `secrets: inherit` and the default `GITHUB_TOKEN` needs no extra setup. Verify with:

```bash
gh attestation verify <sbom-file> --repo <owner>/<repo>
```

> **Note:** `provenance` attaches an attestation manifest, which changes the pushed
> image from a single manifest to an image index. Leave it `'false'` (default) if you
> depend on the exact single-manifest form.

### OpenVEX Document (opt-in)

Emit an [OpenVEX](https://github.com/openvex/spec) document from the Trivy scan report,
marking every discovered CVE `under_investigation` and merging manual triage from
`security/vex-overrides.json` when present:

```yaml
security-scan: true       # trivy scanner (default)
generate-vex: true
```

The document is written into the security-reports artifact and exposed via the
`vex-path` output.

### Advanced Security Analysis

When `security-scan: true` and the image is pushed, a separate advisory job runs the
shared `modules-vulnerability-scan` workflow against the image, producing unified SARIF
categories and a security score in the **Security** tab. It is advisory only
(`fail-on-findings: false`) and never blocks the build or deploy.

> **Note:** the container scan pulls the image without a registry login, so for **private
> GHCR** images this advisory job may report a pull failure. The build, tags, digests,
> outputs and deploy gate are unaffected.

## Outputs

| Output | Description |
|--------|-------------|
| `image-digest` | Built image digest |
| `image-tags` | Generated image tags |
| `image-url` | Full image URL with tag |
| `image-size` / `image-size-display` | Image size (bytes / human-readable) |
| `image-pushed` | Whether the image was pushed (`false` if the scan blocked it) |
| `security-scan-passed` | Whether the in-build security scan passed |
| `security-report` | Path to the security scan report |
| `sbom-path` | Path to the generated SBOM (empty when `generate-sbom: false`) |
| `sbom-attested` | Whether the SBOM was cryptographically attested |
| `vex-path` | Path to the generated OpenVEX document (empty when `generate-vex: false`) |
| `build-duration` | Build duration in seconds |
| `platforms` | Platforms actually built and pushed (comma-separated) |

## Multi-Platform Builds

List every architecture in `platforms`. More than one entry produces a multi-arch
manifest list, and QEMU is registered automatically for the non-native ones:

```yaml
platforms: 'linux/amd64,linux/arm64,linux/arm/v7'
```

Verify the result:

```console
$ docker buildx imagetools inspect ghcr.io/<owner>/<image>:<tag>
MediaType: application/vnd.oci.image.index.v1+json   # manifest list
  Platform: linux/amd64
  Platform: linux/arm64
```

A `vnd.oci.image.manifest.v1+json` media type with no `Platform:` lines means a
single-platform image was published.

> **Deprecated:** `multi-platform` is no longer required and is ignored. Before
> this was fixed, omitting it silently narrowed `platforms` to `linux/amd64`, so
> callers requesting arm64 published amd64-only images with a green pipeline.
> Remove the input; `platforms` alone controls what is built.

Non-native architectures build under QEMU emulation and are noticeably slower.
Build cache is exported per architecture, so only the first run pays full price.

## README Sync to Docker Hub

Automatically sync your README to Docker Hub:

```yaml
publish-to: 'both'  # or 'dockerhub'
sync-dockerhub-readme: true
readme-file: ''  # Auto-detects: DOCKER_README.MD -> README.MD -> README.md
```

## Examples

The repository includes comprehensive examples in `github/workflows/examples/docker/`:

1. **[simple-docker-build.yml](../../github/workflows/examples/docker/simple-docker-build.yml)**: Basic GHCR build
2. **[dockerhub-with-readme-sync.yml](../../github/workflows/examples/docker/dockerhub-with-readme-sync.yml)**: Docker Hub with README sync
3. **[multi-platform-build.yml](../../github/workflows/examples/docker/multi-platform-build.yml)**: Cross-architecture builds
4. **[security-focused-build.yml](../../github/workflows/examples/docker/security-focused-build.yml)**: Security-first approach
5. **[enterprise-build.yml](../../github/workflows/examples/docker/enterprise-build.yml)**: Maximum security and compliance
6. **[large-image-build.yml](../../github/workflows/examples/docker/large-image-build.yml)**: Images that outgrow a runner's free disk
7. **[web-application-build.yml](../../github/workflows/examples/docker/web-application-build.yml)**: Web app build with staging deploy
8. **[microservice-build.yml](../../github/workflows/examples/docker/microservice-build.yml)**: Microservice with Helm deployment
9. **[self-hosted-build.yml](../../github/workflows/examples/docker/self-hosted-build.yml)**: Building on a self-hosted runner

## Best Practices

### 1. Security
- Always enable security scanning for production builds
- Use image signing for production images
- Generate SBOM for compliance and security tracking
- Implement least-privilege container configurations

### 2. Performance
- Use multi-stage Dockerfiles with specific targets
- Enable BuildKit caching for faster builds
- Optimize layer caching with proper ordering
- Use parallel builds for multi-platform images

### 3. Multi-Registry

- Use `publish-to: 'both'` for maximum image availability
- Keep image names consistent across registries
- Sync README to Docker Hub for discoverability

### 4. Version Management
- Use `update-dockerfile-version: true` for consistent versioning
- Follow semantic versioning with Git tags
- Use `auto-tags: true` for automatic tag generation

## Troubleshooting

### Common Issues

1. **Docker Hub Authentication Failed**
   - Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets are set
   - Ensure Docker Hub access token has read/write permissions
   - Check username matches Docker Hub account (not email)

2. **GHCR Authentication Failed**
   - `GITHUB_TOKEN` is automatically provided
   - Ensure repository has package write permissions

3. **Invalid Image Tag**
   - Check for empty branch names on tag pushes
   - Verify tag format matches expected patterns

4. **README Sync Failed**
   - Ensure `publish-to` is `'dockerhub'` or `'both'`
   - Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` are set
   - Check README file exists and is readable

### Debug Mode

Enable debug logging:

```yaml
with:
  debug: true
```

## Migration Guide

### From Separate Registry Workflows

If you previously had separate workflows for GHCR and Docker Hub:

**Before:**
```yaml
# Two separate jobs building the same image twice
jobs:
  ghcr:
    # ... build and push to GHCR
  dockerhub:
    # ... build and push to Docker Hub
```

**After:**
```yaml
# Single job, single build, push to both
jobs:
  docker-build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'both'
      ghcr-image-name: 'my-org/my-app'
      docker-image-name: 'myuser/my-app'
    secrets: inherit
```

## Support

- **Documentation**: See examples in `github/workflows/examples/docker/`
- **Issues**: Report issues in the automation-templates repository
- **Contributing**: Follow the repository contribution guidelines
