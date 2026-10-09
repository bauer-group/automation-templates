# Fork Docker Build — Example

Drop-in caller for building a **fork's** service images and publishing them to GHCR.

Full reference: [`docs/workflows/fork-docker-build.md`](../../../../docs/workflows/fork-docker-build.md).

## What it does

On every push to the `workspace` branch, it builds each image in the `images` list, scans it with Trivy, and — if the scan passes — pushes it to `ghcr.io/<owner>/<repo>/<name>` with tags `workspace`, `<sha>`, `<timestamp>`, and `latest`.

## Setup

1. Copy [`fork-docker-build.yml`](fork-docker-build.yml) to `.github/workflows/fork-docker-build.yml` on the fork's `workspace` branch.
2. Edit the `images` list to match your Dockerfiles:

   ```yaml
   images: |
     [
       {"name": "app", "dockerfile": "Dockerfile"},
       {"name": "worker", "dockerfile": "worker/Dockerfile", "context": "worker"}
     ]
   ```
3. That's it — GHCR authentication uses the automatic `GITHUB_TOKEN`.

## Per-image options

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Image name / cache scope |
| `dockerfile` | ✅ | Path to the Dockerfile |
| `context` | | Build context (default `.`) |
| `target` | | Build stage to target |
| `platforms` | | e.g. `linux/amd64,linux/arm64` |
| `build-args` | | Newline-separated `KEY=VALUE` |

## Disk space

A GitHub-hosted runner has about 4 GB free. If a large image fails with `no space left on device`, uncomment `free-disk-space: true` (reclaims 10+ GB of unused toolchains) and `cache-mode: 'min'` in the example. `free-disk-space` is skipped on self-hosted runners, whose disk outlives the job — free space on that host instead. Details: [Running out of disk space](../../../../docs/workflows/fork-docker-build.md#running-out-of-disk-space).

## Security

Images are scanned **before** they are pushed. A `CRITICAL` finding (configurable via `security-fail-on`) fails the job and blocks the push; results appear under **Security → Code scanning**.

## Part of the self-maintaining fork

This build is the last link in the chain driven by [`sync-upstream`](../sync-upstream/README.md): a `workspace` push (made by the sync workflow with a PAT) triggers this build automatically.
