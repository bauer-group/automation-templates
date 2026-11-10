# Docker Base Image Monitor Module

Detects when a Docker base image has been rebuilt upstream and triggers a rebuild of your own images.

## Overview

Base images like `n8nio/n8n:stable` or `ghcr.io/bauer-group/cs-iamstack/logto` are rebuilt regularly under the same tag. The tag does not change, so nothing signals that your derived image is now stale. This module polls the **digest** behind each tag and reacts when it moves.

- **Digest polling** — `docker manifest inspect` per configured image, multi-arch aware, with up to 3 attempts (10s/20s backoff) for transient registry errors such as `429 toomanyrequests`; auth errors and unknown tags fail at once
- **Tag from the Dockerfile** — an entry with `dockerfile` is watched on the tag of its FROM line, so a Dependabot bump of that line moves the monitor with it, see [Tag from the Dockerfile](#tag-from-the-dockerfile)
- **State in repository variables** — the last handled digest is stored per image and created automatically
- **Two reaction modes** — an empty commit that lets semantic-release cut a patch, and/or a `workflow_dispatch` of a target workflow
- **Release confirmation** — with a target workflow, a new digest counts as handled only once the dispatched run has succeeded; a failed run (for example a red release gate) is dispatched again by the next check, see [Release confirmation](#release-confirmation)
- **Coverage reporting** — the summary states how many of the configured images were actually verified

> **Requires a PAT.** Digest state lives in repository variables and the commit must trigger downstream workflows, neither of which `GITHUB_TOKEN` can do. See [Secrets](#secrets).

> **A release failed, or the job is red with "Release retries exhausted"?** Go to [Operator recovery](#operator-recovery). How a digest moves from "dispatched" to "stored" is shown in [State variables and lifecycle](#state-variables-and-lifecycle).

**Contents:** [Quick Start](#quick-start) · [Input Parameters](#input-parameters) · [Outputs](#outputs) · [Configuration file](#configuration-file) · [Tag from the Dockerfile](#tag-from-the-dockerfile) · [Migrating an existing entry](#migrating-an-existing-entry) · [Schedule slots](#schedule-slots) · [Release confirmation](#release-confirmation) · [State variables and lifecycle](#state-variables-and-lifecycle) · [Operator recovery](#operator-recovery) · [Unreachable images](#unreachable-images) · [Secrets](#secrets) · [Examples](#examples)

## Quick Start

```yaml
name: Check Base Images
on:
  schedule:
    # Example slot (22:07 UTC). Take your repository's own slot from the
    # slot table: docs/workflows/modules-docker-base-image-monitor.md#schedule-slots
    - cron: '7 22 * * *'
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

Never copy the cron as is: every caller runs at a slot of its own, see [Schedule slots](#schedule-slots).

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

### Release commit and dispatch (Container-Solution default)

What the container stacks run: an empty `chore(deps)` release commit gives semantic-release something to release, and the dispatched `docker-release.yml` (`force-release`) releases it and rebuilds the images. The digest is stored once that run has succeeded.

```yaml
jobs:
  check:
    permissions:
      contents: read
      packages: read
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
      target-workflow: 'docker-release.yml'
      target-workflow-inputs: '{"force-release": "true"}'
    secrets: inherit
```

Complete callers - daily check, several images, dry run - are in [`github/workflows/examples/docker-base-image-monitor/`](../../github/workflows/examples/docker-base-image-monitor/README.md).

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
| `unresolved-images` | JSON array of names of entries with `dockerfile` that were not checked - their tag could not be read, or their `variable` is shared with an entry on another image:tag - and that fail the job, see [Fails instead of guessing](#fails-instead-of-guessing). `[]` when there is none; set by the step that resolves the tags, so also when the check failed |

## Configuration file

Schema: [`.github/config/docker-base-image-monitor/docker-base-images.schema.json`](../../.github/config/docker-base-image-monitor/docker-base-images.schema.json)

```json
{
  "images": [
    {
      "name": "python",
      "image": "python",
      "dockerfile": "src/directory-sync/Dockerfile",
      "variable": "PYTHON_ALPINE_DIGEST",
      "description": "Tag from the FROM line of src/directory-sync/Dockerfile"
    },
    {
      "name": "logto",
      "image": "ghcr.io/bauer-group/cs-iamstack/logto",
      "tag": "stable",
      "variable": "LOGTO_STABLE_DIGEST",
      "description": "Logto identity service base image, pulled at runtime"
    }
  ],
  "settings": {
    "commit-prefix": "chore(deps)"
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | Shown in logs, the summary and the release commit |
| `image` | yes | Repository without tag (`n8nio/n8n`, `library/postgres`, `ghcr.io/…`). With `dockerfile` also the cross-check for the FROM line |
| `variable` | yes | Repository variable holding the handled digest, `^[A-Z][A-Z0-9_]*$`, created on the first run |
| `tag` | without `dockerfile` | The tag to watch. With `dockerfile` leave it out: a different value is reported as stale and ignored |
| `dockerfile` | no | Path of the Dockerfile, relative to the repository root, whose FROM line names the tag - see [Tag from the Dockerfile](#tag-from-the-dockerfile). One Dockerfile per entry: an image several Dockerfiles build on gets [one entry per Dockerfile](#one-entry-per-dockerfile) |
| `stage` | no | With `dockerfile`: the stage (`FROM … AS <stage>`) whose FROM line counts, for a Dockerfile that uses the image with different tags |
| `from-index` | no | Alternative to `stage`: the FROM line counted from 0, as `COPY --from=<n>` counts stages |
| `description` | no | Free text |

Use `dockerfile` for every image that is the base of a Dockerfile in the repository - pinned tags that Dependabot bumps (`python:3.15-alpine`, `postgres:18`) and floating ones (`stable`, `latest`) alike: the Dockerfile is then the only place the tag is written down. `tag` remains for images no Dockerfile of the repository names, such as one a stack pulls at runtime, and for one exception:

> **Keep `tag` when the release builds the image with a `--build-arg` that overrides the ARG of the FROM line.** The ARG default is then not what is built, so the Dockerfile names the wrong tag to watch. XPD-SonarQube is such a case: it watches the floating `sonarqube:community` on purpose. Every release the monitor dispatches picks the newest plugin-compatible `SONARQUBE_VERSION`, passes it as `--build-arg` and writes it back into the ARG. Watching the ARG default (`26.8.0.126808-community`) would never signal a new SonarQube release, and the automatic upgrade would stop.

Name new variables without the version Dependabot bumps (`POSTGRES_ALPINE_DIGEST`, not `POSTGRES_18_ALPINE_DIGEST`); existing names stay valid, they are only names.

### Tag from the Dockerfile

**Why.** Dependabot bumps the FROM line of a Dockerfile, never `base-images.json`. With a fixed `tag` the monitor kept watching a tag the image was no longer built on: a rebuild whenever the unused tag moved, and none when the real one did - the security rebuilds the monitor exists for. On 2026-11-10, once auto-merge let tag bumps through on their own, eight repositories (CS-BackupHelper, CS-IAM, CS-MinIO, CS-NocoDB, CS-Outline, CS-RabbitMQ, IP-Shlink-MCPServer, IP-ZAMMAD-MCPServer) were monitored on `python:3.14-alpine` while they built on `python:3.15-alpine`.

**How.** Before the check, the [`docker-base-image-resolve`](../../.github/actions/docker-base-image-resolve/action.yml) action reads the Dockerfile of every entry with `dockerfile` and takes the tag from its FROM line, resolved as BuildKit resolves it for a build without `--build-arg`:

| FROM line | Watched tag |
|-----------|-------------|
| `ARG PYTHON_VERSION=3.15` before the first FROM, then `FROM python:${PYTHON_VERSION}-alpine` | `3.15-alpine` - also `$VAR`, `${VAR:-default}`, `${VAR-default}`, `${VAR:+x}`, `${VAR+x}` and defaults built from earlier ARGs |
| `FROM ${BASE_IMAGE}:${BASE_VERSION}` | image and tag from the ARG defaults |
| `FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS build` | `1.26-alpine` - flags and the stage name are skipped |
| `FROM python:3.15-alpine@sha256:…` | `3.15-alpine` - see digest pins below |
| `FROM python` | `latest` |
| `FROM build` (an earlier stage) | none - not an image, skipped |

Comment lines, blank lines and `\` continuations are read as BuildKit reads them, also inside a continued instruction. The body of a heredoc (`RUN <<EOF` … `EOF`, also in COPY and ADD) is part of its instruction, so the `from PIL import Image` of a Python heredoc is no FROM line. ARGs declared after the first FROM belong to a stage and do not reach later FROM lines, as in a build.

Which FROM line counts:

- **No selector:** the FROM lines that use `image`. Several are fine as long as they agree on the tag - the `builder`, `test` and `prod` stages of one `python:3.15-alpine`. Different tags of the image fail the check with both lines named: set a selector. So does a FROM line whose image or tag cannot be read - an ARG without a default, a line that cannot be parsed - since it may use `image` on another tag; only a line whose repository is written out as another image (`FROM golang:${GO_VERSION}`) is known not to. Give the ARG a default, or select the line to monitor.
- **`stage`:** the line `FROM … AS <stage>`, case-insensitive.
- **`from-index`:** the n-th FROM line, counted from 0.

`image` stays the **cross-check**. If no FROM line uses `image`, or the line that `stage` or `from-index` selects names another image, the entry gets an `::error::` on the Dockerfile that lists the FROM lines found, and it is not checked, see [Fails instead of guessing](#fails-instead-of-guessing). The monitor never switches to another image silently. `python`, `library/python` and `docker.io/library/python` are the same image. If `tag` is set as well and differs, the Dockerfile wins and a `::notice::` on the FROM line says the configured tag is stale.

**Not resolved:** `--build-arg` values the release passes (the ARG default counts - where the release overrides the FROM line's ARG, keep `tag`, see the exception above), and the `# escape=` parser directive.

**Digest pins.** A FROM line pinned to a digest builds on that digest, not on whatever the tag points to. Dependabot updates such pins itself. The monitor still watches the tag and releases when it moves, a rebuild that only changes the image once the pin has been updated as well.

**Requirements.** `python3` on the runner - preinstalled on GitHub-hosted Ubuntu runners; without it the entries with `dockerfile` are not checked, see below. Without an entry with `dockerfile` the step does nothing, needs no Python, and the check runs on the configured tags exactly as before.

#### One entry per Dockerfile

An entry reads one Dockerfile. When an image is the base of several - `node:24-alpine` in three Dockerfiles of CS-BillingStack - give **each Dockerfile an entry of its own**, each with its own `variable`. The Dockerfiles do not move together: Dependabot updates each `docker` directory in a pull request of its own, and auto-merge lets each one through on its own. CS-MinIO already builds `src/minio-worker` on `python:3.14-alpine` and `src/minio-init` on `3.15-alpine`. An entry for only one of them leaves the others unwatched - the drift `dockerfile` removes, back again. Entries that share a `variable` but resolve to different image:tag pairs are not checked, see [Fails instead of guessing](#fails-instead-of-guessing): both would be compared with the one stored digest, and every check would release again.

```json
{
  "images": [
    { "name": "node-api",    "image": "node", "dockerfile": "src/api/Dockerfile",    "variable": "NODE_ALPINE_DIGEST" },
    { "name": "node-worker", "image": "node", "dockerfile": "src/worker/Dockerfile", "variable": "NODE_ALPINE_WORKER_DIGEST" }
  ]
}
```

While the Dockerfiles share a tag, a move of it is still **one** release: every update of a check goes into one release commit and one dispatch. A Dockerfile that only a test builds needs no entry. A new variable has no stored digest, so its first check releases once; while both Dockerfiles use the same tag, seed it from the existing entry instead: `gh variable set NODE_ALPINE_WORKER_DIGEST --body "$(gh variable get NODE_ALPINE_DIGEST)"`.

#### Fails instead of guessing

An entry whose tag cannot be read is **not checked** in that run - neither on a guessed tag nor on a configured `tag`. Its `<variable>` and `<variable>_PENDING` are left as they are. This applies to that entry alone:

- every other image is checked, released, confirmed and stored as usual
- the entry gets an `::error::` on its Dockerfile (on the FROM line where one applies), a **🛑 Tag not read from the Dockerfile** section in the summary, and is listed in the `unresolved-images` output; the coverage line counts it as configured, not verified
- the job fails in its last step, after the summary - as with [exhausted release retries](#release-confirmation). A Dockerfile refactor that renames a stage, moves the file or adds an ARG without a default must not hold back the security rebuilds of the repository's other images. `fail-on-unreachable-image` does not change this: the cause is in the repository, not in a registry

Once the entry is fixed, the next check reads its tag again and releases if the digest moved in the meantime. The cases:

- the Dockerfile does not exist, or the path leaves the repository
- no FROM line uses `image`, or the selected line names another image or an earlier stage
- the image appears with different tags and no `stage` or `from-index` is set
- the FROM line uses an ARG without a default (`ARG VERSION`, `FROM python:${VERSION}`) - its value only exists at build time. Give the ARG a default, or write `${VERSION:-3.15-alpine}`. The same for an ARG whose default uses such an ARG (`ARG MAJOR`, `ARG VERSION=${MAJOR}.15`), however the FROM line uses it
- without a selector: a FROM line whose image or tag cannot be read, next to the lines that use `image`
- the FROM line pins only a digest (`python@sha256:…`), so there is no tag to watch
- the tag or the digest is not valid
- the entry shares its `variable` with an entry checked on another image:tag (the entries with `dockerfile` are left out; one without `dockerfile` is checked as before)
- `stage` together with `from-index`, a stage that does not exist, an index past the last FROM line

If the resolver cannot run at all - no `python3` on a self-hosted runner, or an error of the resolver itself - every entry with `dockerfile` is handled this way, and the entries without one are still checked.

### A tag bump releases once more

When Dependabot bumps the FROM tag, the next check compares the digest of the **new** tag with the stored digest of the **old** one, finds them different and releases once: attempt 1, confirmed and stored like any new digest. `<variable>`, `<variable>_PENDING`, release confirmation and `max-release-attempts` work exactly as before - only the tag behind the variable changed. From then on a move of the old tag is ignored and a move of the new one is released.

That release confirms more than it fixes: the bump has usually released the image on the new tag already. Dependabot commits it as `fix(docker): bump …`, which the gated release pipeline releases as a patch. On 2026-11-10, CS-BackupHelper #25 became 1.10.9 and IP-ZAMMAD-MCPServer #9 became 6.1.9 within five minutes, CS-Outline #75 became 0.6.42 within eight, each with a successful *Release & Docker Build* on the bump commit. The monitor cannot tell, because it does not store which tag a digest belongs to, and one extra patch release per bump is cheaper than a second piece of state. To skip it, store the new tag's digest by hand after the bump: take it from the **New digests** block of a [dry run](../../github/workflows/examples/docker-base-image-monitor/dry-run.yml) and `gh variable set <variable> --body sha256:…`.

### Migrating an existing entry

Entries without `dockerfile` keep working unchanged; nothing has to be migrated at once.

1. Add `dockerfile` with the path of the Dockerfile whose FROM line uses the image, and remove `tag`. Is the image the base of several Dockerfiles, add [one entry per Dockerfile](#one-entry-per-dockerfile). Does the release override the FROM line's ARG with a `--build-arg`, keep `tag` (see the exception under [Configuration file](#configuration-file)).
2. Keep `name` and `variable` as they are. A new variable has no stored digest, so its first check would release once.
3. Run the check with `dry-run: true`. The log shows `🧭 <name>: <image>:<tag> from <Dockerfile> line <n>`; a `::notice::` names a tag that had drifted.
4. If the configured tag had drifted, the first real check releases once, because the stored digest is the old tag's. That release is the rebuild the drifted entry held back. To skip it, store the digest by hand as in [A tag bump releases once more](#a-tag-bump-releases-once-more).

The change touches only the config, so commit it with `[skip ci]` (for example `ci(monitor): took the base image tags from the Dockerfiles [skip ci]`). When migrating many repositories, stagger the pushes rather than pushing them all at once.

## Schedule slots

Every caller of this module runs at a **slot of its own** from the [slot table](#slot-table). The callers' `schedule` comments point here. The table covers every scheduled caller in the bauer-group and covalida organisations that dispatches a forced release - this module and [`modules-auto-maintenance`](./modules-auto-maintenance.md) alike.

**Why.** All 39 callers once ran at `0 10 * * *`. When a base image many of them share moved - `backuphelper:latest` (11 repositories), `python:3.14-alpine` (11), `node:24-alpine` (4) - up to ~11 release builds started in the same minute, and Docker Hub answered BuildKit's manifest requests with `429 Too Many Requests` although the builds were logged in: its abuse limit counts per IP, not per account.

| Date | What failed |
|------|-------------|
| 2026-10-15 | 31 monitors at once; three builds throttled after their release was tagged and ended half-published - the reason for the one retry per build in [`docker-build`](../../.github/actions/docker-build/action.yml) |
| 2026-11-06 | `postgres:18` throttled in the CS-DocumentSigning backup round trips |
| 2026-11-07 | `node:24-alpine` throttled: CS-DocumentSigning v0.19.1 was tagged, its main image never published |
| 2026-11-08 | A GitHub release asset answered `504` in the same 10:10-10:15 UTC window |

Dependabot runs outside the slot grid (00:07-09:52 UTC, reserve 22:07-23:52 UTC), on Sunday from 13:30 UTC - see [Dependabot schedule](./docker-maintenance.md#dependabot-schedule).

GitHub also delays scheduled runs under load, and may drop them, at the [start of every hour](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).

**Rules**

- **Grid:** 15 minutes on odd minutes (`:07`, `:22`, `:37`, `:52`), 00:07-09:52 UTC, reserve 22:07-23:52 UTC; never a full hour.
- **Producers first:** CS-BackupHelper (00:07) and CS-MinIO (00:22) build internal base images, so their consumers pick up a new image the same night.
- **Shared base image:** repositories that share one are at least 30 minutes apart; only the two producers are 15 minutes apart.
- **Heavy builds on `hh:07`.**
- **Template consumers after their producer**, from 08:07.

### Slot table

`backuphelper` is `ghcr.io/bauer-group/cs-backuphelper/backuphelper:latest`, `cs-minio/*` the images of `ghcr.io/bauer-group/cs-minio`. CET = UTC+1 (MEZ), CEST = UTC+2 (MESZ).

| UTC | CET / CEST | Repository | Base images |
|-----|------------|------------|-------------|
| 00:07 | 01:07 / 02:07 | CS-BackupHelper | **Producer** of `backuphelper`; `python:3.14-alpine` |
| 00:22 | 01:22 / 02:22 | CS-MinIO | **Producer** of `cs-minio/*`; `golang:1.26-alpine`, `node:22-alpine`, `python:3.14-alpine`, `alpine:3.23` |
| 00:37 | 01:37 / 02:37 | CS-StatusMonitor | `uptime-kuma:2` |
| 00:52 | 01:52 / 02:52 | CS-LinkStack | `linkstack:latest` |
| 01:07 | 02:07 / 03:07 | CS-DocumentSigning | `backuphelper`, `node:24-alpine`, `golang:1.26-alpine` |
| 01:22 | 02:22 / 03:22 | CS-Rustdesk | `rustdesk-server(-pro):latest` |
| 01:37 | 02:37 / 03:37 | CS-MTASTS | `python:3.14-alpine` |
| 01:52 | 02:52 / 03:52 | CS-AIRouter | `litellm-non_root:main-stable` |
| 02:07 | 03:07 / 04:07 | CS-Outline | `backuphelper`, `cs-minio/*`, `python:3.14-alpine`, `pgvector`, `redis:8-alpine` |
| 02:22 | 03:22 / 04:22 | CS-CloudflareTunnel | `cloudflared:latest`, `golang:1.26-alpine` |
| 02:37 | 03:37 / 04:37 | IP-CloudflareTerraform | `backuphelper`, opentofu |
| 02:52 | 03:52 / 04:52 | CS-NGINXProxy | `nginx-proxy-manager:2` |
| 03:07 | 04:07 / 05:07 | CS-BillingStack | `backuphelper`, `node:24-alpine`, `golang:1.26-alpine`, `golang:1.25`, ruby, nginx, rust, debian, clickhouse, redpanda; **producer** of `cs-billingstack/*:stable` |
| 03:22 | 04:22 / 05:22 | COM-WhistleblowerApp | `globaleaks:latest` |
| 03:37 | 04:37 / 05:37 | CS-NATS | `nats:2-alpine`, `python:3.14-alpine`, nats-box, nats-exporter |
| 03:52 | 04:52 / 05:52 | CS-PairDrop | `linuxserver/pairdrop`, coturn, `alpine:latest` |
| 04:07 | 05:07 / 06:07 | CS-IAM | `backuphelper`, `python:3.14-alpine`, `postgres:18-alpine`, zitadel, `alpine:3.23` |
| 04:22 | 05:22 / 06:22 | OT-CAN2IP | `rust:1.98-trixie`, `distroless/static` |
| 04:37 | 05:37 / 06:37 | IP-ZAMMAD-MCPServer | `python:3.14-alpine` |
| 04:52 | 05:52 / 06:52 | CS-FileServer | `debian:stable-slim`, `python:3.15-slim-trixie`, `node:lts-alpine`, `nginx:alpine` |
| 05:07 | 06:07 / 07:07 | CS-IAMStack | `backuphelper`, `python:3.14-alpine`, `node:24-alpine`, `postgres:18-alpine`, logto; **producer** of `cs-iamstack/*:stable` |
| 05:22 | 06:22 / 07:22 | IP-Kleinanzeigen-MCPServer | `python:3.14-slim` |
| 05:37 | 06:37 / 07:37 | CS-ZAMMAD | `backuphelper`, `zammad:7` |
| 05:52 | 06:52 / 07:52 | OT-CAN2IP-WebUI | `node:24-alpine`, `nginx-unprivileged:alpine` |
| 06:07 | 07:07 / 08:07 | CS-NocoDB | `backuphelper`, `python:3.14-alpine`, nocodb |
| 06:22 | 07:22 / 08:22 | CS-URLShortener | shlink, `postgres:18` |
| 06:37 | 07:37 / 08:37 | CS-WordPressStack | `backuphelper`, wordpress, mariadb, `redis:8-alpine`, `nginx:stable`, `debian:stable-slim` |
| 06:52 | 07:52 / 08:52 | CS-RabbitMQ | `rabbitmq:4-management`, `python:3.14-alpine`, traefik-certs-dumper |
| 07:07 | 08:07 / 09:07 | CS-AIChat | `backuphelper`, `librechat:latest` |
| 07:22 | 08:22 / 09:22 | IP-Shlink-MCPServer | `redis:8-alpine`, `python:3.14-alpine` |
| 07:37 | 08:37 / 09:37 | IP-n8n-MCPServer | `node:26-alpine` |
| 07:52 | 08:52 / 09:52 | XPD-SonarQube | `backuphelper`, `postgres:18-alpine`, sonarqube, busybox |
| 08:07 | 09:07 / 10:07 | covalida/SaaS-CovalidaBilling | Consumer of `cs-billingstack/*:stable`; default of CS-BillingStack `template/consumer` |
| 08:22 | 09:22 / 10:22 | covalida/SaaS-CovalidaIAM | Consumer of `cs-iamstack/*:stable`; default of CS-IAMStack `template/consumer` |
| 08:37 | 09:37 / 10:37 | CS-DVCS (`modules-auto-maintenance`) | `python:3.14-alpine` |
| 08:52 | 09:52 / 10:52 | covalida/SaaS-PPWRCompliacePlatform | `node:24-slim`, `postgres:18`, `cs-minio/*`, valkey, nginx |
| 09:07 | 10:07 / 11:07 | CS-n8n (`modules-auto-maintenance`) | n8n, n8n runners, `python:3.14-alpine`, searxng, n8n-sandbox |
| 09:22 | 10:22 / 11:22 | covalida/SaaS-TrustCenter | `node:24-alpine` |
| 09:37 | 10:37 / 11:37 | covalida/SaaS-AccessibilityToolkit | `node:24-slim`, playwright, `postgres:18-alpine`, `redis:8-alpine`, `cs-minio/*` |
| 09:52 | 10:52 / 11:52 | *free* | |
| 22:07 | 23:07 / 00:07 | *free (reserve)* | |
| 22:22 | 23:22 / 00:22 | *free (reserve)* | |
| 22:37 | 23:37 / 00:37 | *free (reserve)* | |
| 22:52 | 23:52 / 00:52 | *free (reserve)* | |
| 23:07 | 00:07 / 01:07 | *free (reserve)* | |
| 23:22 | 00:22 / 01:22 | *free (reserve)* | |
| 23:37 | 00:37 / 01:37 | *free (reserve)* | |
| 23:52 | 00:52 / 01:52 | *free (reserve)* | |

### Adding a repository

1. List its base images: the `base-images.json` entries and the `FROM` lines its release builds.
2. Take the first *free* slot whose neighbours within 30 minutes, before and after, share none of them.
3. Write it minute first: 08:37 UTC is `cron: '37 8 * * *'`, 01:07 UTC is `'7 1 * * *'`.
4. Enter the repository in its row of the slot table **in the same change**. A slot that exists only in a caller is invisible to the next repository. Moving a repository works the same way.

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

## State variables and lifecycle

Each configured image owns up to two repository variables (*Settings → Secrets and variables → Actions → Variables*). Both are written by the monitor with `PAT_READWRITE_ORGANISATION`; a dry run writes neither.

| Variable | Holds | Written | Removed |
|----------|-------|---------|---------|
| `<variable>`, e.g. `N8N_STABLE_DIGEST` | The digest whose release is done: confirmed by a successful run, or (without `target-workflow`) whose release commit was pushed | By the check that confirms the release; created on first use | Never |
| `<variable>_PENDING`, e.g. `N8N_STABLE_DIGEST_PENDING` | `{"digest", "run_id", "run_url", "attempt"}` of the release dispatched for a new digest | On every dispatch for that digest, with the attempt number | By the check that finds the run succeeded |

With `target-workflow`, a new digest goes through these states - one step per scheduled check; the job never waits for the release itself:

```text
 check N: digest differs from <variable>
   │  release commit (commit-and-release) + workflow_dispatch of target-workflow
   ▼
 <variable>_PENDING = {digest, run_id, attempt: 1}        <variable> = old digest
   │
   │  every later check reads the recorded run
   ├── queued / running / unreadable ──▶ ⏳ nothing changes, read again next check
   ├── succeeded ─────────────────────▶ ✅ <variable> = new digest, _PENDING removed
   ├── failed, cancelled, timed out or deleted, attempt < max-release-attempts
   │      ──▶ ❌ dispatched again (with a new release commit if the failed run
   │             had already tagged its release), _PENDING attempt + 1
   └── failed, attempt = max-release-attempts
          ──▶ 🛑 nothing dispatched; the job fails on every check until
                 _PENDING is deleted or a newer digest appears
```

A newer digest of the same image starts over with attempt 1 at any point: the record of the older digest no longer matches and is replaced by the next dispatch.

A new image - no `<variable>` yet - counts as moved: its first real check releases once. To add an image without a release, run a [dry run](../../github/workflows/examples/docker-base-image-monitor/dry-run.yml) first and store the digest from its **New digests** block in `<variable>` (`gh variable set`).

## Operator recovery

The summary of every check names the state of each image and links the release run. What to do:

| Summary / annotation | Meaning | Action |
|----------------------|---------|--------|
| ⏳ **Release still running** | The recorded run is queued or running | None. If it hangs in the queue (e.g. no runner picks it up), cancel it: the next check counts it as failed and dispatches the next attempt |
| ⏳ **Release still running**, ⚠️ Unknown | The run could not be read (API error) | None - a second release is never started on a read error. If it persists, check that the PAT can read workflow runs (fine-grained: Actions) |
| ❌ **Release failed** and a `::warning::` | The run failed; the monitor has already dispatched attempt *n + 1* | Fix the cause in the linked run (red backup round trip, build or scan failure). Nothing to do on the monitor |
| 🛑 **Release retries exhausted**, job red | `max-release-attempts` runs failed; nothing is dispatched any more | Fix the cause, then delete `<variable>_PENDING` and run the check: it dispatches attempt 1. Was the last failure transient (a flaky test, a registry outage)? Re-run the linked run instead: the record keeps its run id, and the next check confirms the successful re-run and stores the digest |
| Released by hand meanwhile, and that run succeeded | The record still points at the failed run, so the next check would dispatch once more | Store the recorded digest as handled and delete the record (commands below) |
| An upstream digest must not be released (known-bad build) | - | Store that digest as handled (commands below); the next newer digest is detected as usual |
| A digest was stored although its release failed (stored before release confirmation existed) | The monitor reports "No update" | Delete `<variable>`: the next check treats the image as updated |

Delete a `_PENDING` record only while no release run for it is queued or running: without the record, the next check dispatches a second release.

```bash
REPO=bauer-group/CS-Example      # your repository
VAR=N8N_STABLE_DIGEST            # "variable" of the image in the config

# State of every monitored image
gh variable list --repo "$REPO" | grep _DIGEST
gh variable get "${VAR}_PENDING" --repo "$REPO"      # {"digest":...,"run_id":...,"attempt":...}

# Start over after "Release retries exhausted" (cause fixed)
gh variable delete "${VAR}_PENDING" --repo "$REPO"
gh workflow run check-base-images.yml --repo "$REPO" # or wait for the schedule

# Mark the recorded digest as handled (released by hand, or deliberately skipped)
DIGEST=$(gh variable get "${VAR}_PENDING" --repo "$REPO" | jq -r .digest)
gh variable set "$VAR" --body "$DIGEST" --repo "$REPO"
gh variable delete "${VAR}_PENDING" --repo "$REPO"

# Have the next check treat the image as updated
gh variable delete "$VAR" --repo "$REPO"
```

The digest the monitor compares is not always the one `docker pull` prints: for a multi-arch tag it is the first platform manifest (sorted by architecture), for a single-arch tag the image config digest. Take it from the `_PENDING` record or from the **New digests** block of the check summary instead of computing it.

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

## Examples

Ready-to-copy callers are in [`github/workflows/examples/docker-base-image-monitor/`](../../github/workflows/examples/docker-base-image-monitor/README.md):

| Example | Use case |
|---------|----------|
| [daily-release-dispatch.yml](../../github/workflows/examples/docker-base-image-monitor/daily-release-dispatch.yml) | Daily check that dispatches `docker-release.yml` with `force-release`; the digest is stored once the release succeeded |
| [multi-image-config.yml](../../github/workflows/examples/docker-base-image-monitor/multi-image-config.yml) with [multi-image-base-images.json](../../github/workflows/examples/docker-base-image-monitor/multi-image-base-images.json) | Several images - Docker Hub and internal GHCR packages - in one config file, one release for all of them |
| [dry-run.yml](../../github/workflows/examples/docker-base-image-monitor/dry-run.yml) | Checks a config change on its pull request and on demand, without storing, committing or dispatching |

## References

- [GHCR Internal Visibility](../ghcr-internal-visibility.md)
- [Secrets Reference](../secrets-reference.md)
- [Module configuration guide](../../.github/config/docker-base-image-monitor/README.md)
- [Auto Maintenance Module](./modules-auto-maintenance.md)
- [Backup Round-Trip Test](./modules-backup-roundtrip-test.md) - the release gate whose failures the monitor retries
- [Docker Maintenance (Dependabot)](./docker-maintenance.md) - updates of pinned tags, merged after the PR CI passed
