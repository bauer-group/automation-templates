# Auto Maintenance — Examples

Callers of [`modules-auto-maintenance.yml`](../../../../.github/workflows/modules-auto-maintenance.yml): base image digests and dependency updates (npm, pip, .NET, Go) in one scheduled run, validated by the repository's own build and tests and rolled back when they fail.

Full reference (German): [`docs/workflows/modules-auto-maintenance.md`](../../../../docs/workflows/modules-auto-maintenance.md) — every config block, more configurations and [what gets committed](../../../../docs/workflows/modules-auto-maintenance.md#was-committet-wird).

## What gets committed

Only dependency manifests and lock files that the run changed, wherever they are in the repository (a `working-directory` below the root included). Each file is matched by its name and staged on its own:

| Ecosystem | Committed when changed |
|-----------|------------------------|
| Node.js (npm, yarn, pnpm) | `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `requirements*.txt`, the configured `requirements-file` under any name, `Pipfile.lock`, `poetry.lock` |
| .NET | `*.csproj`, `*.fsproj`, `*.vbproj`, `Directory.Build.props`, `Directory.Packages.props`, `packages.lock.json` |
| Go | `go.mod`, `go.sum` |
| Base images | No file - the digest lives in a repository variable; an empty release commit when nothing else changed |

Ignored files and anything under `node_modules/` are never committed. Source edits and build output stay in the runner's checkout and are listed in the log under `Not committed - not a dependency manifest or lock file`.

> Before this was fixed, the module staged each ecosystem with one `git add` of fixed root paths, e.g. `package.json package-lock.json yarn.lock pnpm-lock.yaml`. Git stages nothing when one of them is missing, so npm, pip and .NET updates were validated and then dropped while the run stayed green. Repositories that kept `ecosystems` out of their config for that reason can enable it now.

## Examples

| Example | Use case |
|---------|----------|
| [weekly-maintenance.yml](weekly-maintenance.yml) | Weekly run with a manual dry run, serialized by `concurrency` |
| [maintenance-config.json](maintenance-config.json) | Config for it: three floating base images and a release dispatch of `docker-release.yml` with `force-release` — valid against the [schema](../../../../.github/config/maintenance/auto-maintenance.schema.json) |
| [maintenance-config-npm.json](maintenance-config-npm.json) | Config for an npm project: `npm update` + `npm audit fix`, committed only after `npm run build` and `npm test` passed. No `trigger-workflow`: the `fix(deps)` commit is released by the repository's push-triggered release workflow (needs the PAT - a push made with `GITHUB_TOKEN` starts no workflows) |

## Setup

1. **Create the token secret** `MAINTENANCE_TOKEN` (or reuse `PAT_READWRITE_ORGANISATION`): Contents, Variables and Actions read/write; classic `repo`, plus `read:packages` for internal or private GHCR base images — the registry login uses this PAT. Base images need it: the job's `GITHUB_TOKEN`, the fallback without a PAT, cannot write the digest variables.
2. **Copy a config** to `.github/config/maintenance/config.json`: list the base images the Dockerfiles are built `FROM`, and/or the ecosystems to update. Set `validation` whenever `ecosystems` is used - without it, updates are committed unbuilt and untested.
3. **Copy the caller** to `.github/workflows/maintenance.yml` and run it once by hand with `dry-run: true`.

## When to use which

| Need | Use |
|------|-----|
| Floating base image tags, one empty release commit per run - the digest counts once the release was dispatched | This module |
| Floating base image tags behind a release gate - the digest counts only once the release succeeded, failed releases are retried | [Docker Base Image Monitor](../docker-base-image-monitor/README.md) |
| Dependency updates (npm, pip, .NET, Go) committed straight to the branch once the repository's own build and tests passed | This module (`ecosystems` + `validation`) |
| Pinned base image tags and other ecosystems (npm, pip, .NET) as reviewable PRs, merged after their CI passed | Dependabot + [Docker Maintenance (Dependabot)](../docker-maintenance-dependabot/README.md) |
