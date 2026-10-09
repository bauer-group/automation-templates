# Auto Maintenance — Examples

Callers of [`modules-auto-maintenance.yml`](../../../../.github/workflows/modules-auto-maintenance.yml): base image digests and dependency updates (npm, pip, .NET, Go) in one scheduled run, validated by the repository's own build and tests and rolled back when they fail.

> **Known limitation — npm, pip and .NET updates are not committed.** The module stages each ecosystem with a single `git add` of fixed paths at the repository root, e.g. `package.json package-lock.json yarn.lock pnpm-lock.yaml`. Git stages nothing when one of those paths does not exist, and npm, pip and Go files under a `working-directory` other than the root are not listed. A repository with one package manager therefore never gets its npm, pip or .NET update committed: the run updates and validates the files, logs `No dependency files to commit` and drops them, while the job summary still says "Dependency file changes detected". Base image updates (an empty commit) and a Go module at the root (`go.mod` and `go.sum`) are not affected. Until the module stages only the files that exist, take dependency updates from Dependabot with [Docker Maintenance (Dependabot)](../docker-maintenance-dependabot/README.md) — the example config below is therefore the base image setup the container stacks run.

Full reference (German): [`docs/workflows/modules-auto-maintenance.md`](../../../../docs/workflows/modules-auto-maintenance.md) — every config block, more configurations and the [limitation in detail](../../../../docs/workflows/modules-auto-maintenance.md#bekannte-einschraenkung-dependency-updates-werden-nicht-committet).

## Examples

| Example | Use case |
|---------|----------|
| [weekly-maintenance.yml](weekly-maintenance.yml) | Weekly run with a manual dry run, serialized by `concurrency` |
| [maintenance-config.json](maintenance-config.json) | Config for it: three floating base images and a release dispatch of `docker-release.yml` with `force-release` — valid against the [schema](../../../../.github/config/maintenance/auto-maintenance.schema.json) |

## Setup

1. **Create the token secret** `MAINTENANCE_TOKEN` (or reuse `PAT_READWRITE_ORGANISATION`): Contents, Variables and Actions read/write; classic `repo`, plus `read:packages` for internal or private GHCR base images — the registry login uses this PAT. Base images need it: the job's `GITHUB_TOKEN`, the fallback without a PAT, cannot write the digest variables.
2. **Copy the config** to `.github/config/maintenance/config.json` and list the base images the Dockerfiles are built `FROM`. The `ecosystems` and `validation` blocks are described in the module doc; read the known limitation above before relying on them.
3. **Copy the caller** to `.github/workflows/maintenance.yml` and run it once by hand with `dry-run: true`.

## When to use which

| Need | Use |
|------|-----|
| Floating base image tags, one empty release commit per run - the digest counts once the release was dispatched | This module |
| Floating base image tags behind a release gate - the digest counts only once the release succeeded, failed releases are retried | [Docker Base Image Monitor](../docker-base-image-monitor/README.md) |
| Pinned base image tags and other ecosystems (npm, pip, .NET) as reviewable PRs, merged after their CI passed | Dependabot + [Docker Maintenance (Dependabot)](../docker-maintenance-dependabot/README.md) |
