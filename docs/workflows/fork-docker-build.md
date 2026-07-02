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
| `name` | ✅ | — | Image name (last path segment of the image ref, also the cache scope) |
| `dockerfile` | ✅ | — | Path to the Dockerfile |
| `context` | | `.` | Build context |
| `target` | | (final) | Dockerfile build stage to target |
| `platforms` | | `inputs.platforms` | Comma-separated platforms for this image |
| `build-args` | | — | Newline-separated `KEY=VALUE` build args |

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
| `security-fail-on` | string | `CRITICAL` | Severity that blocks the push: `CRITICAL`, `HIGH`, `MEDIUM` |
| `runs-on` | string | `ubuntu-latest` | Runner (string or JSON array for self-hosted) |
| `build-timeout` | number | `30` | Per-image job timeout (minutes) |

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
