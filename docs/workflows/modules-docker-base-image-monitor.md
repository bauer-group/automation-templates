# Docker Base Image Monitor Module

Detects when a Docker base image has been rebuilt upstream and triggers a rebuild of your own images.

## Overview

Base images like `n8nio/n8n:stable` or `ghcr.io/bauer-group/cs-iamstack/logto` are rebuilt regularly under the same tag. The tag does not change, so nothing signals that your derived image is now stale. This module polls the **digest** behind each tag and reacts when it moves.

- **Digest polling** — `docker manifest inspect` per configured image, multi-arch aware
- **State in repository variables** — the last seen digest is stored per image, created automatically
- **Two reaction modes** — an empty commit that lets semantic-release cut a patch, and/or a `workflow_dispatch` of a target workflow
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
| `target-workflow` | Workflow file to dispatch when an update is found | `''` |
| `target-workflow-ref` | Ref used for the dispatch | `'main'` |
| `target-workflow-inputs` | JSON object of inputs passed to the dispatch | `''` |
| `commit-prefix` | Commit type prefix, drives the semantic-release bump | `'chore(deps)'` |
| `commit-and-release` | Create an empty commit to trigger a release | `true` |
| `dry-run` | Only check; do not write variables, commit or dispatch | `false` |
| `fail-on-unreachable-image` | Fail the job when a manifest cannot be read | `true` |
| `runs-on` | Runner. String, or a JSON array for self-hosted | `'ubuntu-latest'` |

## Outputs

| Output | Description |
|--------|-------------|
| `updates-found` | `true` if at least one digest changed |
| `updated-images` | JSON array of image names that changed |
| `new-digests` | JSON object mapping image name to its new digest |
| `triggered` | `true` if a commit was pushed or a workflow dispatched |
| `commit-sha` | SHA of the created commit |
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
| `PAT_READWRITE_ORGANISATION` | yes | Variable read/write, checkout, commit and push, workflow dispatch, and the GHCR login |

Scopes:

- **Classic PAT:** `repo` + `read:packages`
- **Fine-grained PAT:** Contents (Read/Write), Variables (Read/Write), Actions (Read/Write, only when `target-workflow` is used), Packages (Read)

The `read:packages` scope is what allows reading manifests of internal or private images. Without it the login succeeds and the manifest read is then denied, which produces a confusing failure.

## Notes

- **Callers must grant `packages: read`** for internal or private GHCR packages. A reusable workflow can only restrict the caller's permissions, never extend them. A *partial* `permissions:` block that omits `packages` sets it to `none` and breaks the check; having no block at all does not. See [GHCR Internal Visibility](../ghcr-internal-visibility.md).
- The commit created on an update is **empty** — the actual state lives in repository variables. Its only purpose is to give semantic-release something to release.
- `modules-auto-maintenance.yml` contains the same base image check as one of several maintenance tasks. Use this module when base image monitoring is all you need.

## References

- [GHCR Internal Visibility](../ghcr-internal-visibility.md)
- [Secrets Reference](../secrets-reference.md)
- [Module configuration guide](../../.github/config/docker-base-image-monitor/README.md)
- [Auto Maintenance Module](./modules-auto-maintenance.md)
