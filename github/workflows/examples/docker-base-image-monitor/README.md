# Docker Base Image Monitor — Examples

Callers of [`modules-docker-base-image-monitor.yml`](../../../../.github/workflows/modules-docker-base-image-monitor.yml): read the digest behind floating tags (`stable`, `latest`, `7`) that Dependabot cannot track, and release a rebuild when it moves — counted as done only once the release has succeeded.

Full reference: [`docs/workflows/modules-docker-base-image-monitor.md`](../../../../docs/workflows/modules-docker-base-image-monitor.md).

## Examples

| Example | Use case |
|---------|----------|
| [daily-release-dispatch.yml](daily-release-dispatch.yml) | The Container-Solution default: a daily check that pushes a release commit and dispatches `docker-release.yml` with `force-release`; a failed release is dispatched again until `max-release-attempts` runs have failed |
| [multi-image-config.yml](multi-image-config.yml) | Several images — Docker Hub and an internal GHCR package — in one config file; images that moved together share one release |
| [multi-image-base-images.json](multi-image-base-images.json) | The config file for it, valid against the [schema](../../../../.github/config/docker-base-image-monitor/docker-base-images.schema.json) |
| [dry-run.yml](dry-run.yml) | Checks a config change on its pull request, or previews the next check during recovery — stores, commits and dispatches nothing |

## Setup

1. **Create the PAT secret** `PAT_READWRITE_ORGANISATION` (organisation or repository): classic `repo`, or fine-grained **Contents**, **Variables** and **Actions** read/write. It writes the digest variables, pushes the release commit, dispatches the release and reads its result — see [Secrets](../../../../docs/workflows/modules-docker-base-image-monitor.md#secrets). It is not used for the registry login.
2. **List the images** in `.github/config/docker-base-image-monitor/base-images.json` — `name`, `image` (without tag), `tag` and `variable` (`^[A-Z][A-Z0-9_]*$`) per image. The variables are created on the first run.
3. **Make the release dispatchable.** `docker-release.yml` needs `workflow_dispatch` with a `force-release` input, and must build the images itself: the monitor confirms only the run it dispatched. A complete pipeline with a release gate is [`gated-release-pipeline.yml`](../backup-roundtrip/gated-release-pipeline.yml).
4. **Grant `packages: read`** in the caller when an image is an internal or private GHCR package. A partial `permissions:` block without it sets it to `none`.
5. **Copy an example** to `.github/workflows/check-base-images.yml` and run it once by hand with `dry-run: true`. An image without a stored digest counts as moved, so the first real check releases once; to avoid that, store the digests from the dry run's **New digests** block first (`gh variable set <VAR> --body sha256:...`).

## What a check does

| State of an image | The check | Summary |
|-------------------|-----------|---------|
| Digest unchanged | Nothing | ℹ️ No updates found |
| Digest moved, no release recorded | Release commit and dispatch; run recorded in `<VAR>_PENDING` | ✅ Updates found, 🚀 Workflow dispatched |
| Release still running | Nothing; reads it again next time | ⏳ Release still running |
| Release succeeded | Stores the digest in `<VAR>`, removes `<VAR>_PENDING` | ✅ Release confirmed |
| Release failed | Dispatches it again with the next attempt number | ❌ Release failed |
| Release failed `max-release-attempts` times | Nothing dispatched; the job fails until the record is deleted | 🛑 Release retries exhausted |
| Image could not be read | Nothing stored, committed or dispatched; the job fails (default `fail-on-unreachable-image: true`) | ⚠️ Incomplete check |

The full lifecycle is in [State variables and lifecycle](../../../../docs/workflows/modules-docker-base-image-monitor.md#state-variables-and-lifecycle).

## When a release keeps failing

Fix the cause in the release run the summary links. The monitor retries on its own until `max-release-attempts` runs have failed. After that it stops and its job stays red: delete the image's `<VAR>_PENDING` repository variable and run the check again. All recovery steps, with `gh` commands: [Operator recovery](../../../../docs/workflows/modules-docker-base-image-monitor.md#operator-recovery).

## Related

- [Backup Round-Trip Test examples](../backup-roundtrip/README.md) — the release gate whose failures the monitor retries
- [Docker Maintenance (Dependabot) examples](../docker-maintenance-dependabot/README.md) — pinned tags, merged after the PR CI passed
- [Configuration guide (German)](../../../../.github/config/docker-base-image-monitor/README.md) — every input, more config examples, troubleshooting
