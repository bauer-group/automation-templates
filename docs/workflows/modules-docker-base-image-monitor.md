# Docker Base Image Monitor Module

Detects when a Docker base image has been rebuilt upstream and triggers a rebuild of your own images.

## Overview

Base images like `n8nio/n8n:stable` or `ghcr.io/bauer-group/cs-iamstack/logto` are rebuilt regularly under the same tag. The tag does not change, so nothing signals that your derived image is now stale. This module polls the **digest** behind each tag and reacts when it moves.

- **Digest polling** — `docker manifest inspect` per configured image, multi-arch aware, with up to 3 attempts (10s/20s backoff) for transient registry errors such as `429 toomanyrequests`; auth errors and unknown tags fail at once
- **State in repository variables** — the last handled digest is stored per image and created automatically
- **Two reaction modes** — an empty commit that lets semantic-release cut a patch, and/or a `workflow_dispatch` of a target workflow
- **Release confirmation** — with a target workflow, a new digest counts as handled only once the dispatched run has succeeded; a failed run (for example a red release gate) is dispatched again by the next check, see [Release confirmation](#release-confirmation)
- **Coverage reporting** — the summary states how many of the configured images were actually verified

> **Requires a PAT.** Digest state lives in repository variables and the commit must trigger downstream workflows, neither of which `GITHUB_TOKEN` can do. See [Secrets](#secrets).

## Quick Start

```yaml
name: Check Base Images
on:
  schedule:
    - cron: '0 5 * * *'
  workflow_dispatch:

permissions:
  contents: read
  packages: read      # required for internal/private GHCR packages

jobs:
  check:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
    secrets: inherit
```

### Inline configuration instead of a config file

```yaml
jobs:
  check:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      images: '[{"name": "n8n", "image": "n8nio/n8n", "tag": "stable", "variable": "N8N_STABLE_DIGEST"}]'
    secrets: inherit
```

### Dispatching a build instead of committing

```yaml
jobs:
  check:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
      commit-and-release: false
      target-workflow: 'docker-release.yml'
    secrets: inherit
```

## Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `images` | Inline JSON array of images. Mutually exclusive with `config-file`; one of the two is required | `''` |
| `config-file` | Path to a JSON config file | `''` |
| `target-workflow` | Workflow file to dispatch when an update is found. The digest is stored once that run has succeeded, see [Release confirmation](#release-confirmation) | `''` |
| `target-workflow-ref` | Ref used for the dispatch | `'main'` |
| `target-workflow-inputs` | JSON object of inputs passed to the dispatch | `''` |
| `max-release-attempts` | Release runs dispatched for one digest before the monitor gives up and fails the job, see [Release confirmation](#release-confirmation). `0` = no limit | `3` |
| `commit-prefix` | Commit type prefix, drives the semantic-release bump | `'chore(deps)'` |
| `commit-and-release` | Create an empty commit to trigger a release | `true` |
| `dry-run` | Only check; do not write variables, commit or dispatch | `false` |
| `fail-on-unreachable-image` | Fail the job when a manifest cannot be read | `true` |
| `runs-on` | Runner. String, or a JSON array for self-hosted | `'ubuntu-latest'` |

## Outputs

| Output | Description |
|--------|-------------|
| `updates-found` | `true` if at least one image needs a release: a changed digest, or one whose dispatched release failed |
| `updated-images` | JSON array of image names that need a release (changed and retried) |
| `retried-images` | JSON array of image names whose dispatched release failed and that were dispatched again |
| `pending-images` | JSON array of image names whose dispatched release has not finished yet |
| `exhausted-images` | JSON array of image names whose release failed `max-release-attempts` times; they are no longer dispatched and the job fails |
| `new-digests` | JSON object mapping image name to its new digest |
| `triggered` | `true` if a commit was pushed or a workflow dispatched |
| `commit-sha` | SHA of the created commit |
| `dispatched-run-id` | Id of the run dispatched by this check (empty if none was dispatched) |
| `dispatched-run-url` | URL of the run dispatched by this check |
| `images-configured` | Number of images declared in the configuration |
| `images-checked` | Number of images whose digest was actually read |
| `unreachable-images` | JSON array of image references that could not be read |

## Configuration file

Schema: [`.github/config/docker-base-image-monitor/docker-base-images.schema.json`](../../.github/config/docker-base-image-monitor/docker-base-images.schema.json)

```json
{
  "images": [
    {
      "name": "logto",
      "image": "ghcr.io/bauer-group/cs-iamstack/logto",
      "tag": "stable",
      "variable": "LOGTO_STABLE_DIGEST",
      "description": "Logto identity service base image"
    }
  ],
  "settings": {
    "commit-prefix": "chore(deps)"
  }
}
```

Each image requires `name`, `image`, `tag` and `variable`. The `variable` name must match `^[A-Z][A-Z0-9_]*$` and is created automatically on first run.

## Release confirmation

With `target-workflow` set, dispatching the release is not the end of it. The release can still fail — a red [backup round-trip gate](./modules-backup-roundtrip-test.md), a failed build — and the image then stays on the old base. If the monitor stored the new digest at dispatch time, the next check would read it back, report "No update" and never try again.

So the digest variable is written only once the dispatched run has **succeeded**. In between, the run is recorded in a second variable, `<variable>_PENDING` (for example `ZAMMAD_DIGEST_PENDING`), as `{"digest": "…", "run_id": 123, "run_url": "…", "attempt": 1}`. Every check that sees the changed digest reads that run:

| Run of the recorded digest | Check does | Summary |
|----------------------------|------------|---------|
| No run recorded | Release commit (if enabled) and dispatch; the run is recorded | ✅ Updates found, 🚀 Workflow dispatched |
| Queued or running | Nothing | ⏳ Release still running |
| Could not be read (API error) | Nothing — a second release is never started on a transient error | ⏳ Release still running, ⚠️ Unknown |
| Succeeded | Stores the digest, removes `<variable>_PENDING` | ✅ Release confirmed |
| Failed, cancelled, timed out or deleted | Dispatches the release again and records the new run with the next attempt number; pushes a new release commit first if the failed run had already tagged its release, see [Retry commit](#retry-commit) | ❌ Release failed, with a link to the failed run and a `::warning::` annotation |
| Failed, and it was attempt `max-release-attempts` | Nothing is dispatched or committed; an `::error::` annotation, and the job fails | 🛑 Release retries exhausted |

The state is only read and written by the check, so the job does not wait for the release: with a daily schedule the digest is stored by the check after the successful run. A failed release is dispatched again by every check until it succeeds, a newer digest replaces it, or `max-release-attempts` runs (default 3) have failed. The limit matters because a retry after a tagged release cuts a new patch release each time: a build that stays broken would otherwise produce one per check. Once the limit is reached, the monitor stops dispatching and fails its job on every check, which keeps the problem visible instead of losing it. To start over after fixing the cause, delete the `<variable>_PENDING` variable; the next check then dispatches the release as for a new digest. A newer digest of the same image is a new update with attempt 1, whatever happened to the recorded run.

**What a confirmation covers.** The check sees only the conclusion of the run it dispatched. That covers the rebuilt images when the target workflow builds them itself, as `docker-release.yml` does in the container consumers. If `target-workflow` only cuts the release (for example a `release.yml` that runs semantic-release alone) and another workflow builds the images from the published release or tag, a failure of that build is not seen and not retried. A target workflow that skips its builds while still ending *success* is confirmed as well; with `commit-and-release: true` the [retry commit](#retry-commit) keeps a retry from ending in that state.

### Retry commit

A consumer's release workflow builds only when semantic-release cuts a release, and that needs a releasable commit after the last tag. Where the dispatched run failed decides whether one is there:

- **Before the release was tagged** (for example a red release gate): the base image commit of the first check is still unreleased. The retry dispatches again without a new commit, and the run releases that commit.
- **After the release was tagged** (the release job passed, then a build, scan or push job failed): the base image commit is already released. A bare dispatch would find nothing to release, skip every build and still end *success* — and the next check would confirm a digest that never reached an image. So the retry first pushes a new empty release commit, `<commit-prefix>: update base image <images>`, whose body names the failed run.

The check tells the two apart by looking for a base image commit (`<commit-prefix>: update base image …`) after the newest tag (`git describe --tags`). A commit written back after the tag, such as `chore: update Dockerfile version to …`, does not count. With `commit-and-release: false` no commit is created; the target workflow must then rebuild without one.

Without `target-workflow` (the release starts from the push of the release commit) there is no run to follow, and the digest is stored once the commit is pushed, as before. The same applies if GitHub answers a dispatch without a run id (only a GitHub Enterprise Server without `return_run_details`); the run then logs a warning.

**Existing callers** need no change. Digests stored before this behaviour count as handled. If a consumer's last dispatched release failed before this change, its digest was already stored and the monitor does not retry it; delete the digest variable (*Settings → Secrets and variables → Actions → Variables*) to have the next check treat the image as updated, or start the release manually.

## Unreachable images

A manifest can be unreadable for several reasons: the package is internal or private and the credentials lack read access, the tag does not exist, or the registry is rate-limiting.

Regardless of `fail-on-unreachable-image`, such an image is **never** counted as verified:

- the log carries an `::error::` annotation naming the image, with an authentication-specific hint where the registry indicated one
- the image is listed in the `unreachable-images` output
- the job summary reports `Coverage: N of M configured image(s) verified` and an **⚠️ Incomplete check** section

With the default `fail-on-unreachable-image: true` the job then fails. This is deliberate: a green run that reports "All base images are up to date" for images it never read is worse than a red one that says so.

Set it to `false` to downgrade to a warning — but note that the run will then report success while some images were never verified:

```yaml
    with:
      fail-on-unreachable-image: false
```

> The flag fires on **any** unreachable image, not only on authentication failures. A transient registry rate limit or a typo in a tag fails the job the same way.

## Secrets

| Secret | Required | Purpose |
|--------|----------|---------|
| `PAT_READWRITE_ORGANISATION` | yes | Variable read/write, checkout, commit and push, workflow dispatch and reading the dispatched run |
| `REGISTRY_READ_TOKEN` | no | GHCR login for registries outside this enterprise. Without it the login uses `github.token` |

Scopes of `PAT_READWRITE_ORGANISATION`:

- **Classic PAT:** `repo`
- **Fine-grained PAT:** Contents (Read/Write), Variables (Read/Write), Actions (Read/Write, only when `target-workflow` is used: dispatch and reading the run's result)

The PAT is **not** used for the registry login. Manifests of internal or private images are read with `github.token`, which needs `packages: read` from the calling workflow — see the notes below.

## Notes

- **Callers must grant `packages: read`** for internal or private GHCR packages. A reusable workflow can only restrict the caller's permissions, never extend them. A *partial* `permissions:` block that omits `packages` sets it to `none` and breaks the check; having no block at all does not. See [GHCR Internal Visibility](../ghcr-internal-visibility.md).
- The commit created on an update — or on a retry whose earlier release was already tagged — is **empty**; the actual state lives in repository variables. Its only purpose is to give semantic-release something to release. When `target-workflow` is set, its subject ends in `[skip ci]`: the release runs through `workflow_dispatch`, so push workflows are not started again on an unchanged tree. `[skip ci]` does not affect the dispatched run.
- State is stored **last**, after commit, push and dispatch. If any of these fails (or an image is unreachable), nothing is stored and the next run detects the same update again instead of reporting "No update". A failure while storing only means the next run repeats an already started release. With `target-workflow` the digest itself waits for the dispatched run, see [Release confirmation](#release-confirmation).
- The dispatch uses the REST endpoint with `return_run_details`, which accepts a workflow file name or id. A workflow **name** in `target-workflow`, which `gh workflow run` accepted, is resolved to its id first.
- `modules-auto-maintenance.yml` contains the same base image check as one of several maintenance tasks. Use this module when base image monitoring is all you need.

## References

- [GHCR Internal Visibility](../ghcr-internal-visibility.md)
- [Secrets Reference](../secrets-reference.md)
- [Module configuration guide](../../.github/config/docker-base-image-monitor/README.md)
- [Auto Maintenance Module](./modules-auto-maintenance.md)
