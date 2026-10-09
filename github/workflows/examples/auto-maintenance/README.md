# Auto Maintenance — Examples

Callers of [`modules-auto-maintenance.yml`](../../../../.github/workflows/modules-auto-maintenance.yml): base image digests and dependency updates (npm, pip, .NET, Go) in one scheduled run, validated by the repository's own build and tests and rolled back when they fail.

Full reference (German): [`docs/workflows/modules-auto-maintenance.md`](../../../../docs/workflows/modules-auto-maintenance.md) — more configurations for Node.js, Python, Go and base-image-only repositories.

## Examples

| Example | Use case |
|---------|----------|
| [weekly-maintenance.yml](weekly-maintenance.yml) | Weekly run with a manual dry run, serialized by `concurrency` |
| [maintenance-config.json](maintenance-config.json) | Config for it: two floating base images, npm and pip updates, build/test/typecheck validation, release dispatch with `force-release` — valid against the [schema](../../../../.github/config/maintenance/auto-maintenance.schema.json) |

## Setup

1. **Create the token secret** `MAINTENANCE_TOKEN` (or reuse `PAT_READWRITE_ORGANISATION`): Contents, Variables and Actions read/write; classic `repo`, plus `read:packages` for internal or private GHCR base images. Without a PAT the run falls back to `GITHUB_TOKEN`: enough for dependency updates, but it cannot write the digest variables, so base images need the PAT.
2. **Copy the config** to `.github/config/maintenance/config.json` and keep only the blocks the repository needs.
3. **Copy the caller** to `.github/workflows/maintenance.yml` and run it once by hand with `dry-run: true`.

## When to use which

| Need | Use |
|------|-----|
| Floating base image tags **and** dependency updates, one commit per run | This module |
| Floating base image tags behind a release gate - the digest counts only once the release succeeded, failed releases are retried | [Docker Base Image Monitor](../docker-base-image-monitor/README.md) |
| Pinned base image tags and other ecosystems as reviewable PRs | Dependabot + [Docker Maintenance (Dependabot)](../docker-maintenance-dependabot/README.md) |
