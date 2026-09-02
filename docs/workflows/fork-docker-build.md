# 🐳 Fork Docker Build

## Overview

`fork-docker-build.yml` is a lean, reusable image builder for **forked repositories**. It builds one or more service images (a matrix over an `images` list) from the fork's integration branch — typically `workspace` — scans each with Trivy, and publishes them to a container registry (GHCR by default).

It is purpose-built for continuous fork CI: rebuild on every `workspace` push, tag for the branch, and keep `latest` pointing at the integration branch. It is intentionally separate from [`docker-build.yml`](docker-build.md) (see [Why not docker-build.yml](#why-not-docker-buildyml)).

## Key Features

- ✅ **Multi-image matrix** — build `relay`, `ui`, `nginx`, … from one call
- ✅ **Secure by default** — Trivy scans the built image **before** push; a `CRITICAL` finding blocks the publish
- ✅ **Workspace-oriented tags** — branch, short SHA, timestamp, and `latest` on the default branch
- ✅ **Per-image build cache** — GitHub Actions cache scoped per image (no cross-image collisions)
- ✅ **GHCR out of the box** — authenticates with the automatic `GITHUB_TOKEN`; no secret required
- ✅ **SARIF to Security tab** — scan results uploaded via CodeQL SARIF upload
- ✅ **Runner-flex** — GitHub-hosted or self-hosted via the `runs-on` input

## Quick Start

Add this caller to the fork (on the `workspace` branch):

```yaml
name: 🐳 Fork Docker Build

on:
  push:
    branches: [workspace, "workspace/**"]
    paths-ignore: [".github/**", "**/*.md"]
  workflow_dispatch:

concurrency:
  group: fork-docker-build-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  packages: write
  security-events: write

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/fork-docker-build.yml@main
    with:
      images: |
        [
          {"name": "relay", "dockerfile": "relay/Dockerfile"},
          {"name": "ui",    "dockerfile": "ui/Dockerfile"},
          {"name": "nginx", "dockerfile": "nginx/Dockerfile"}
        ]
    secrets: inherit
```

This publishes to `ghcr.io/<owner>/<repo>/relay`, `…/ui`, `…/nginx` with tags `workspace`, `<sha>`, `<YYYYMMDD-HHmmss>`, and `latest`.

## The `images` input

A JSON array. Each entry supports:

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | ✅ | — | Matrix label and cache scope (also the last path segment of the default image ref) |
| `dockerfile` | ✅ | — | Path to the Dockerfile |
| `context` | | `.` | Build context |
| `target` | | (final) | Dockerfile build stage to target |
| `platforms` | | `inputs.platforms` | Comma-separated platforms for this image |
| `build-args` | | — | Newline-separated `KEY=VALUE` build args |
| `image` | | `<repo>/<name>` | Full image name **after** the registry. Overrides the default (`<namespace>/<name>`) — use it for single-image forks that publish to `<registry>/<owner>/<repo>` without a `/<name>` suffix |

### Single-image forks

By default each image is published to `<registry>/<owner>/<repo>/<name>`. A fork that builds one image and wants the bare `<registry>/<owner>/<repo>` (no name suffix) sets `image` to the repository:

```yaml
with:
  images: |
    [{"name": "app", "dockerfile": "Dockerfile", "image": "${{ github.repository }}"}]
```

→ publishes to `ghcr.io/<owner>/<repo>` with tags `workspace`, `<sha>`, `<timestamp>`, `latest`.

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `images` | string (JSON) | — (required) | Array of images to build (see above) |
| `registry` | string | `ghcr.io` | Target registry |
| `image-namespace` | string | `''` → repo | Base path; final ref `<registry>/<namespace>/<name>` |
| `platforms` | string | `linux/amd64` | Default platform(s); overridable per image |
| `push` | boolean | `true` | Push to the registry (auto-disabled on `pull_request`) |
| `cache` | boolean | `true` | GitHub Actions build cache, scoped per image |
| `latest-on-default` | boolean | `true` | Tag `latest` on the repository's default branch |
| `extra-tags` | string | `''` | Additional `docker/metadata-action` tag lines |
| `security-scan` | boolean | `true` | Scan with Trivy before pushing |
| `security-fail-on` | string | `CRITICAL` | Severity that blocks the push: `CRITICAL`, `HIGH`, `MEDIUM`, or `NONE` (scan + report only) |
| `cache-mode` | string | `max` | Cache export mode: `max` (every intermediate layer of every stage) or `min` (final stage only) |
| `free-disk-space` | boolean | `false` | Remove unused runner toolchains before building (Linux only) |
| `runs-on` | string | `ubuntu-latest` | Runner (string or JSON array for self-hosted) |
| `build-timeout` | number | `30` | Per-image job timeout (minutes) |

## Running out of disk space

A GitHub-hosted runner has roughly 4 GB free once its preinstalled toolchains are
accounted for, and this workflow needs that several times over: BuildKit's layers,
the `load: true` copy kept in the daemon so the image can be scanned, the cache
export, and the tarball Trivy has Docker export before it analyses anything.

The scan checks first and says so plainly:

```
💽 Image ~1967 MB, free ~3142 MB
::warning::Disk space is tight for this scan … Trivy wants roughly 3934 MB
```

Below the image size the job stops there with an error rather than letting Trivy
die mid-export — which used to surface as `Trivy produced no readable report`,
naming the guard instead of the cause.

Two settings answer it:

```yaml
free-disk-space: true    # reclaims 10+ GB: CodeQL bundle, Android SDK, .NET, GHC, Swift, PowerShell
cache-mode: 'min'        # exports only the final stage instead of every layer of every stage
```

`free-disk-space` runs after checkout and before the build — the only place it can,
since a caller cannot inject a step into this job. It skips itself on non-Linux
runners, logs `df -h /` before and after, and deliberately leaves the rest of
`/opt/hostedtoolcache` and all of `/usr/local/lib/node_modules` alone (npm lives
in the latter).

## Secrets

None required. GHCR uses `github.actor` + the automatic `GITHUB_TOKEN`. Callers pass `secrets: inherit` for consistency with the rest of the toolkit.

## Security model

Each image is built locally first (`load: true`, amd64), scanned with Trivy, and only then built-and-pushed (a near-instant cache hit). If the scan finds vulnerabilities at or above `security-fail-on`, the job **fails and the push is skipped** — a vulnerable image never reaches the registry. Scan results are uploaded to the repository's **Security → Code scanning** tab as SARIF (one category per image). `fail-fast: false` means one image's finding does not cancel the others.

## Why not `docker-build.yml`

[`docker-build.yml`](docker-build.md) is release-oriented: it only tags `latest` on Git **tags** (`refs/tags/`), not on branch pushes, and carries Cosign signing, SBOM generation and Dockerfile version write-back. A fork's `workspace` build is a different concern — continuous, branch-tagged, rebuilt on every push — so `fork-docker-build.yml` keeps that path lean. Forks that need release semantics (semver tags, signing) can still call `docker-build.yml` directly.

## Components

- **Reusable workflow:** `.github/workflows/fork-docker-build.yml`
- **Examples:** `github/workflows/examples/fork-docker-build/`
- **Related:** [`sync-upstream.yml`](sync-upstream.md) — pushes the `workspace` branch that triggers this build
