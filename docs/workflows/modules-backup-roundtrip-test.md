# Backup Round-Trip Test Module

Proves, before an image is released, that a stack's BackupHelper sidecar can back up **and restore** real data.

## Overview

The [BackupHelper](https://github.com/bauer-group/CS-BackupHelper) engine has its own unit and end-to-end tests. They prove the engine, not your stack. Every consumer wires the engine differently — its own compose file, its own `BACKUP_CONFIG_JSON`, plugin sources, volumes, uid 1000 permissions — and every release rebuilds the sidecar `FROM` the newest engine. A broken restore only shows up on the day it is needed.

This reusable workflow runs the complete cycle against the caller's own compose stack, in the caller's own repository:

- **Real stack, real data** — starts the stack from your compose file, seeds data through your application, backs it up, deletes it, restores it and checks that it is back
- **Images under test** — builds your images from the commit and makes Compose use them instead of the released ones
- **Strict snapshot checks** — every component error-free, required components present, no silently skipped files, archive checksum verified
- **A check that must discriminate** — your check script has to see the data before the backup, *not* see it after the deletion and see it again after the restore, so a restore that writes nothing cannot pass
- **No credentials in the repository** — passwords are generated per run and masked
- **Logs stay private** — runs in the consumer repository; diagnostics are uploaded there on failure only
- **Release gate** — exposes `result`, `snapshot-id` and `components` for `needs:` conditions
- **Every compose variant** (opt-in) — creates the external proxy network a Traefik or Coolify file expects, so the round trip runs once per variant in a matrix, see [Compose Variants](#compose-variants-traefik-coolify)

Everything marked opt-in is off by default: a caller that does not set those inputs runs exactly the cycle described below.

> **Not a matrix in the engine repository, on purpose.** Consumer stacks are mostly private. Running the round trip in each consumer keeps their logs and data where they belong, and tests the exact compose file and images that consumer is about to release.

## How It Works

```text
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐
│ Prepare .env     │──▶│ Build images     │──▶│ up --wait        │──▶│ Seed + check     │
│ template, over-  │   │ under test, tag  │   │ every service    │   │ (expect present) │
│ rides, secrets   │   │ as compose image │   │ running/healthy  │   │                  │
└──────────────────┘   └──────────────────┘   └──────────────────┘   └────────┬─────────┘
                                                                              │
┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐   ┌────────▼─────────┐
│ Stop app,        │◀──│ Mutate + check   │◀──│ verify           │◀──│ create, list,    │
│ restore,         │   │ (expect absent)  │   │ archive sha256   │   │ show: no errors  │
│ up --wait again  │   │                  │   │                  │   │                  │
└────────┬─────────┘   └──────────────────┘   └──────────────────┘   └──────────────────┘
         │
┌────────▼─────────┐   ┌──────────────────┐   ┌──────────────────┐
│ Check            │──▶│ healthcheck      │──▶│ down --volumes   │   on failure: ps, logs,
│ (expect present) │   │ snapshot fresh   │   │ (always)         │   manifest as artifact
└──────────────────┘   └──────────────────┘   └──────────────────┘
```

1. **Prepare** — `.env` is created from `env-template`; `prepare-script` (if set) fills secrets with a format of their own, then `env-overrides` and `generated-secrets` are written over it. `COMPOSE_FILE`, `COMPOSE_PROJECT_NAME` and `COMPOSE_PROFILES` are exported, so every later step — and your scripts — reach the stack with a plain `docker compose`.
2. **Build** — each `build-images` entry is built with `--pull` and tagged with the image reference its compose service resolves to. Compose then starts that build instead of pulling the released image. Before that, `external-networks` (if set) creates the external networks the configuration needs.
3. **Start** — the images of the started services are pulled (the `services` input and everything it depends on, or every service when `services` is empty), except the images under test. `docker compose up -d --wait` then waits until every service is running or healthy and one-shot dependencies have completed. On the fresh volumes of a run the sidecar is healthy, see [BackupHelper 1.7.7 and later](#backuphelper-177-and-later).
4. **Seed** — `seed-script` writes marker data; `check-script` must then report it **present**.
5. **Back up** — `backuphelper create` runs inside the sidecar and must exit `0`; from BackupHelper 1.7.7 on it exits `1` when a component failed. The new snapshot is found by comparing `list` before and after — also after a non-zero exit, so that *Inspect snapshot* can still name the failed component before the job fails. `show` must report every component without `error`, without warnings (unless allowed) and must include every `require-components` name. `verify` must confirm the archive checksum.
6. **Mutate** — `mutate-script` deletes the seeded data; `check-script` must now report it **absent**.
7. **Restore** — `services-to-stop-before-restore` are stopped, the snapshot is restored, and the stack is started again with `up --wait`.
8. **Check** — `check-script` must report the data **present** again.
9. **Healthcheck** — `backuphelper healthcheck` must report the new snapshot as fresh.
10. **Always** — on failure, `docker compose ps`, every service's log, the snapshot list and, once the snapshot was inspected, its manifest are uploaded as an artifact; the stack is removed with `down --volumes`, together with the networks `external-networks` created; the step summary shows each phase.

### BackupHelper 1.7.7 and later

The sidecar images are built `FROM ghcr.io/bauer-group/cs-backuphelper/backuphelper:latest`, so every round trip after an engine release tests that release. 1.7.7 changed the engine's [run status](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/cli.md#run-status) and its [healthcheck](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/deployment.md#the-functional-healthcheck), and with them where a broken backup stops the round trip:

- **A failed component fails *Create backup*.** A component that failed completely — a failed `pg_dump`, `mariadb-dump` or `mysqldump`, a plugin source that raised, a failed S3 source, a missing or unreadable path, a source without output — ends the run in `error`, and `create` exits `1`, which fails *Create backup*. The snapshot is still stored, so the module resolves its id and runs *Inspect snapshot* anyway: the step summary shows the component table with the failed component's error, the artifact contains `manifest.json`, and the `snapshot-id` and `components` outputs are set. The job then ends with `result: failure`; *Verify snapshot* and everything after it do not run. See [`backuphelper create` exits 1](#backuphelper-create-exits-1). Up to 1.7.6 `create` exited `0` as long as one component succeeded and the snapshot was stored, and *Inspect snapshot* reported the failed component.
- **A fresh stack is healthy.** The daemon records its start in `/data/.state/daemon.json` before the image's first health probe, and "no backup yet" is healthy for `BACKUP_HEALTHCHECK_MAX_AGE_HOURS` (default 26) after that start, so `up --wait` passes on the run's empty volumes. The sidecar is unhealthy, and `up --wait` fails, when its data dir is not writable by the user it runs as or when a run that `on_startup` started at boot failed before the first health probe.
- **A round trip that passed on 1.7.6 passes on 1.7.7, with two exceptions.** *Inspect snapshot* already demanded error-free components, and after a run that ended in `success` or `warning` the stricter healthcheck passes as before. First, a component without output (size 0, no error text): up to 1.7.6 it did not count as failed and passed `show`; 1.7.7 records it with the error `no output`, and `create` exits `1`. Second, a failed run other than the one under test, which 1.7.6 ignored: a failed component in another job of the same configuration now makes `create` exit `1`, and a failed `on_startup` run can fail `up --wait`, as described above.

## Quick Start

```yaml
jobs:
  backup-roundtrip:
    name: 🧪 Backup Round Trip
    permissions:
      contents: read
      packages: read
    uses: bauer-group/automation-templates/.github/workflows/modules-backup-roundtrip-test.yml@main
    with:
      compose-file: 'docker-compose.local.yml'
      profiles: 'backup'
      generated-secrets: 'DATABASE_PASSWORD'
      build-images: '[{"service": "app-backup", "context": "src/app-backup"}]'
      backup-service: 'app-backup'
      require-components: 'database files'
      services-to-stop-before-restore: 'app'
      seed-script: 'tests/backup-roundtrip/seed.sh'
      mutate-script: 'tests/backup-roundtrip/mutate.sh'
      check-script: 'tests/backup-roundtrip/check.sh'
    secrets: inherit
```

Ready-to-copy callers are in [`github/workflows/examples/backup-roundtrip/`](../../github/workflows/examples/backup-roundtrip/).

## Input Parameters

### Stack

| Parameter | Description | Default |
|-----------|-------------|---------|
| `compose-file` | Compose file of the stack, relative to `working-directory` | `'docker-compose.yml'` |
| `compose-files` | Several compose files as a JSON array, merged in order. Takes precedence over `compose-file`. Use it to add a CI-only override file | `''` |
| `working-directory` | Directory the stack is started from. The `.env` is written here, scripts and `build-images` paths are relative to it | `'.'` |
| `project-name` | Compose project name | `'backup-roundtrip'` |
| `profiles` | Comma-separated Compose profiles to activate — usually the one that enables the sidecar | `''` |
| `services` | Services to start (spaces or newlines). Empty starts every service of the active profiles; dependencies are always started. Only these services and their dependencies are pulled, so configured services the round trip does not need (workers, task runners) cost no download | `''` |
| `external-networks` | Networks to create before the stack starts (spaces, commas or newlines) — the proxy network of a Traefik or Coolify variant. `auto` creates every network the configuration declares `external: true`, by the name Compose resolved. Existing networks are left alone; created ones are removed at the end. See [Compose Variants](#compose-variants-traefik-coolify) | `''` |

### Environment

| Parameter | Description | Default |
|-----------|-------------|---------|
| `env-template` | File the `.env` is created from. A missing file starts from an empty `.env` | `'.env.example'` |
| `env-overrides` | Multiline `KEY=VALUE` pairs written over the template: CI memory limits, disabled sources, test settings. Existing keys are replaced at their position, so later lines that interpolate them still work. Lines starting with `#` are ignored. **Never real secrets** | `''` |
| `generated-secrets` | Variable names (spaces, commas or newlines) that receive a random 48-character hex value, masked in the log | `''` |
| `prepare-script` | Bash script run once the `.env` exists, before `env-overrides` and `generated-secrets` — for secrets with a format of their own, usually the repository's generator. Every value it adds or changes is masked. See [Secrets with a format of their own](#secrets-with-a-format-of-their-own) | `''` |

### Images under test

| Parameter | Description | Default |
|-----------|-------------|---------|
| `build-images` | JSON array of images to build from the repository, see [Building the images under test](#building-the-images-under-test) | `''` |
| `registry-login` | Log in to `ghcr.io` with the automatic `GITHUB_TOKEN` before building and pulling | `true` |

### Backup

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup-service` | **Required.** Compose service of the BackupHelper sidecar. It must run as a daemon; the CLI is executed inside it with `docker compose exec` | — |
| `require-components` | Component names the snapshot must contain (spaces, commas or newlines). Catches a source that is disabled, skipped (an S3 source with an empty bucket) or renamed | `''` |
| `allow-component-warnings` | Accept components that report warnings, such as files a filesystem source could not read | `false` |
| `services-to-stop-before-restore` | Services to stop before the restore — usually the application containers that hold database connections or write files. Started again afterwards | `''` |
| `restore-command` | Engine subcommand that restores. Change it only for a plugin that wraps restore, e.g. `'documenso restore'` | `'restore'` |
| `restore-args` | Arguments after the snapshot id. Keep `--force` — there is no terminal for the confirmation | `'--force'` |
| `run-healthcheck` | Run `backuphelper healthcheck` at the end | `true` |

### Test data

| Parameter | Description | Default |
|-----------|-------------|---------|
| `seed-script` | Bash script that writes marker data into the running stack | `''` |
| `mutate-script` | Bash script that deletes or damages the seeded data after the backup | `''` |
| `check-script` | Bash script that exits `0` when the seeded data is in the state `ROUNDTRIP_EXPECT` names. Required when `seed-script` or `mutate-script` is set | `''` |

Without scripts the module still tests the backup mechanics (create, show, verify, restore exit codes) and says so in the step summary — but not whether your data comes back. Without `mutate-script` the restore runs over intact data and a restore that writes nothing would also pass; the summary warns about that too.

### Timeouts

| Parameter | Description | Default |
|-----------|-------------|---------|
| `wait-timeout` | Seconds `docker compose up --wait` may take, for the first start and the restart after the restore | `600` |
| `script-timeout` | Seconds each seed, mutate or check run may take | `600` |
| `timeout-minutes` | Timeout of the whole job | `45` |

### Runner and diagnostics

| Parameter | Description | Default |
|-----------|-------------|---------|
| `free-disk-space` | Remove unused preinstalled toolchains first (frees 10+ GB). Turn it on for stacks with several GB of images. GitHub-hosted Linux runners only; ignored on self-hosted runners, whose disk is persistent | `false` |
| `artifact-name` | Name of the diagnostics artifact. Set a distinct name when the module is called more than once per run | `'backup-roundtrip-diagnostics'` |
| `artifact-retention-days` | Days the diagnostics artifact is kept | `7` |
| `runs-on` | Runner. String, or a JSON array for self-hosted | `'ubuntu-latest'` |

## Outputs

| Output | Description |
|--------|-------------|
| `snapshot-id` | Id of the snapshot that was created and restored (`YYYY-MM-DD_HH-MM-SS`). Also set when `create` failed but stored a snapshot |
| `components` | JSON array of the snapshot's components: `[{"name", "kind", "size", "error"}]`. Also set when `create` failed but stored a snapshot, with the failed component's `error` |
| `result` | Result of the round-trip job: `success`, `failure` or `cancelled` |

## Secrets

None. Registry access uses the automatic `GITHUB_TOKEN`; every password the stack needs is generated at runtime through `generated-secrets`. Callers pass `secrets: inherit` for consistency with the rest of the toolkit.

> Do not put production credentials into `env-overrides` or the repository to make a source work in CI. A source that needs a real external account is switched off for the test instead — see [Sources that need external services](#sources-that-need-external-services).

## Permissions

The module declares:

```yaml
permissions:
  contents: read   # checkout
  packages: read   # pull internal/private images from GHCR
```

A reusable workflow can only **restrict** the caller's permissions. Grant both on the calling job — a release pipeline usually runs with `contents: write` and more, which the round trip does not need:

```yaml
  backup-roundtrip:
    permissions:
      contents: read
      packages: read
    uses: bauer-group/automation-templates/.github/workflows/modules-backup-roundtrip-test.yml@main
```

A *partial* `permissions:` block that omits `packages` sets it to `none`, and pulls of internal images then fail. See [GHCR Internal Visibility](../ghcr-internal-visibility.md).

## Building the Images Under Test

`build-images` is a JSON array. Each entry:

| Field | Required | Description |
|-------|----------|-------------|
| `service` | ✅ | Compose service whose image reference the build is tagged as |
| `context` | ✅ | Build context, relative to `working-directory` |
| `dockerfile` | | Dockerfile path, relative to `working-directory`. Default: `<context>/Dockerfile` |
| `target` | | Build stage to target |
| `build-args` | | Newline-separated `KEY=VALUE` string, or a JSON object |

```yaml
build-images: |
  [
    {"service": "app",        "context": "src/app", "build-args": "APP_EDITION=community"},
    {"service": "app-backup", "context": "src/app-backup",
     "build-args": {"BACKUPHELPER_VERSION": "latest"}}
  ]
```

**Why `service` and not an image name:** the module asks Compose which reference the service resolves to *with your `.env`* — for example `ghcr.io/acme/app:stable` from `${APP_IMAGE}:${APP_VERSION}`, or a reference written literally in the compose file — and tags the build with exactly that. Compose finds the image locally and never pulls the released one. Services that share an image (five Zammad roles on one image) need a single entry.

- Builds always run with `--pull`, so a meta image `FROM ghcr.io/bauer-group/cs-backuphelper/backuphelper:latest` is tested against the newest engine.
- The sidecar is the minimum. Build the application images too when your release builds them: the round trip then tests the application version you are about to ship.
- Services with a `build:` section that are **not** listed are built by `docker compose up` itself — a development compose file works without `build-images`.

## Script Contract

The scripts are plain bash files in the caller repository, run with `bash <script>` (no executable bit needed) from `working-directory`.

### Environment

| Variable | Set for | Content |
|----------|---------|---------|
| `ROUNDTRIP_MARKER` | seed, mutate, check | Unique token per run, `rt-<run id>-<attempt>-<8 hex>` — only `[a-z0-9-]`. Tag everything you write with it |
| `ROUNDTRIP_PHASE` | all | `prepare`, `seed`, `mutate` or `check` |
| `ROUNDTRIP_EXPECT` | check | `present` or `absent` |
| `ROUNDTRIP_SNAPSHOT_ID` | mutate, check after the backup | Id of the snapshot under test |
| `ROUNDTRIP_BACKUP_SERVICE` | seed, mutate, check | The `backup-service` input |
| `COMPOSE_FILE`, `COMPOSE_PROJECT_NAME`, `COMPOSE_PROFILES` | seed, mutate, check | Set, so `docker compose exec -T <service> …` reaches the stack |

`prepare-script` runs before the stack exists, from `working-directory`, with only `ROUNDTRIP_PHASE=prepare`; it edits `.env` in place.

The `.env` is **not** sourced into the scripts — compose `.env` syntax is not shell syntax. Run commands inside the containers instead; they already have their credentials.

### Rules

1. **Seed** writes data that ends up in **every component** you want to prove: a database row *and* a file on each backed-up volume.
2. **Mutate** deletes it — through the application where possible, the way users lose data.
3. **Check** exits `0` only when **every** seeded item matches `ROUNDTRIP_EXPECT`. Check each item on its own: for `absent`, every item must be gone; for `present`, every item must be back with its exact content.
4. **Errors are not "absent".** A failing query or an unreachable container must fail the check, never count as "nothing found" — use `set -euo pipefail` and capture query results before comparing them.
5. **Pass the marker, do not paste it.** Hand it over as a psql variable, an environment variable or a command argument. Where a client has no variables (the MySQL client), assert its documented format `[a-z0-9-]` first, as in the example below.
6. Use `docker compose exec -T` (no TTY on a runner) and keep each run within `script-timeout`.

The same file may serve all three phases: pass it as `seed-script`, `mutate-script` and `check-script` and branch on `ROUNDTRIP_PHASE`.

### Example: PostgreSQL and a file volume

The CI-tested reference implementation is the module's own fixture: [`.github/workflows/tests/backup-roundtrip/`](../../.github/workflows/tests/backup-roundtrip/) (`seed.sh`, `mutate.sh`, `check.sh`).

```bash
#!/usr/bin/env bash
# seed.sh
set -euo pipefail
docker compose exec -T database psql -q -v ON_ERROR_STOP=1 -v marker="$ROUNDTRIP_MARKER" -U app -d app <<'SQL'
CREATE TABLE IF NOT EXISTS roundtrip_marker (marker text PRIMARY KEY);
INSERT INTO roundtrip_marker (marker) VALUES (:'marker');
SQL
docker compose exec -T app sh -c 'printf "%s\n" "$1" > "/srv/files/$1.txt"' _ "$ROUNDTRIP_MARKER"
```

```bash
#!/usr/bin/env bash
# check.sh
set -euo pipefail
case "$ROUNDTRIP_EXPECT" in present) WANT=1 ;; absent) WANT=0 ;; *) exit 2 ;; esac

ROWS=$(docker compose exec -T database psql -tA -v ON_ERROR_STOP=1 -v marker="$ROUNDTRIP_MARKER" -U app -d app <<'SQL'
SELECT count(*) FROM roundtrip_marker WHERE marker = :'marker';
SQL
)
CONTENT=$(docker compose exec -T app sh -c 'cat "$1" 2>/dev/null || true' _ "/srv/files/$ROUNDTRIP_MARKER.txt")

[ "$ROWS" = "$WANT" ] || { echo "database: $ROWS rows, expected $WANT"; exit 1; }
if [ "$ROUNDTRIP_EXPECT" = present ]; then
  [ "$CONTENT" = "$ROUNDTRIP_MARKER" ] || { echo "file missing or changed"; exit 1; }
else
  [ -z "$CONTENT" ] || { echo "file still present"; exit 1; }
fi
```

`mutate.sh` deletes the row (`DELETE … WHERE marker = :'marker'`) and the file (`rm -f`).

### Example: MySQL / MariaDB

The `mariadb`/`mysql` client has no query variables like psql. The marker is restricted to `[a-z0-9-]`; assert that before using it in SQL, and read the password inside the container (single quotes keep the runner's shell from expanding it):

```bash
#!/usr/bin/env bash
# roundtrip.sh - one script for all three phases (seed-script, mutate-script and check-script)
set -euo pipefail
[[ "$ROUNDTRIP_MARKER" =~ ^[a-z0-9-]+$ ]] || { echo "unexpected marker format" >&2; exit 2; }
sql() { docker compose exec -T mariadb sh -c 'exec mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" -N -B app'; }
FILE="/var/www/html/wp-content/uploads/roundtrip-$ROUNDTRIP_MARKER.txt"

case "$ROUNDTRIP_PHASE" in
  seed)
    sql <<< "CREATE TABLE IF NOT EXISTS roundtrip_marker (marker VARCHAR(64) PRIMARY KEY);
             INSERT INTO roundtrip_marker VALUES ('$ROUNDTRIP_MARKER');"
    docker compose exec -T wordpress sh -c 'echo "$2" > "$1"' _ "$FILE" "$ROUNDTRIP_MARKER" ;;
  mutate)
    sql <<< "DELETE FROM roundtrip_marker WHERE marker = '$ROUNDTRIP_MARKER';"
    docker compose exec -T wordpress rm -f "$FILE" ;;
  check)
    WANT=$([ "$ROUNDTRIP_EXPECT" = present ] && echo 1 || echo 0)
    ROWS=$(sql <<< "SELECT COUNT(*) FROM roundtrip_marker WHERE marker = '$ROUNDTRIP_MARKER';")
    FOUND=$(docker compose exec -T wordpress sh -c 'test -f "$1" && echo 1 || echo 0' _ "$FILE")
    [ "$ROWS" = "$WANT" ] && [ "$FOUND" = "$WANT" ] || { echo "rows=$ROWS file=$FOUND, expected $WANT"; exit 1; } ;;
esac
```

For MySQL 8/9 mind the [authentication caveat](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/sources.md#mysql) of the engine's Alpine client — the round trip is exactly what surfaces it.

### Example: seeding through the application

Data written through the application exercises more than a raw `INSERT`: attachments land where the application puts them, with its ownership and permissions. CS-ZAMMAD's scripts create a ticket with an attachment via `rails runner`, delete it via the application, and let Zammad read the attachment back after the restore:

```bash
docker compose exec -T -e ROUNDTRIP_MARKER="$ROUNDTRIP_MARKER" zammad-railsserver \
  bundle exec rails r "$(cat <<'RUBY'
marker = ENV.fetch('ROUNDTRIP_MARKER')
UserInfo.current_user_id = 1
ticket = Ticket.create!(group_id: Group.find_by!(name: 'Users').id,
                        customer_id: User.find_by!(login: 'nicole.braun@zammad.org').id,
                        title: marker)
RUBY
)"
```

## Integration: Gating a Release

Add the round trip to the consumer's `docker-release.yml` and make the release job need it:

```yaml
on:
  push:
    branches: [main]
    paths-ignore: ['.github/**', '*.md', 'docs/**']   # docs-only pushes never start a stack
  pull_request:
    branches: [main]
    paths: ['src/**', 'docker-compose*.yml', '.env.example', 'tests/backup-roundtrip/**']
  workflow_dispatch:                                   # the base image monitor dispatches this
    inputs:
      force-release:
        type: boolean
        default: false

jobs:
  validate-compose:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    # ...

  backup-roundtrip:
    name: 🧪 Backup Round Trip
    needs: [validate-compose]
    permissions:
      contents: read
      packages: read
    uses: bauer-group/automation-templates/.github/workflows/modules-backup-roundtrip-test.yml@main
    with:
      # ... see Quick Start
    secrets: inherit

  release:
    needs: [validate-compose, backup-roundtrip]
    if: |
      (github.event_name == 'push' || github.event_name == 'workflow_dispatch') &&
      needs.validate-compose.result == 'success' &&
      needs.backup-roundtrip.result == 'success'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit
```

**When it runs.** Every release rebuilds the images `FROM` the newest bases, so every run that can release must pass the round trip — including the `workflow_dispatch` the [base image monitor](./modules-docker-base-image-monitor.md) starts when the BackupHelper engine image moves. That is the point: an engine update reaches production only after it restored this stack's data. When the round trip of such a dispatched run fails, the monitor does not store the new digest and dispatches the release again on its next check, until a run succeeds ([Release confirmation](./modules-docker-base-image-monitor.md#release-confirmation)). `paths-ignore` keeps documentation-only pushes from starting the stack at all; on pull requests, limit `paths` to what can change the stack.

**Cost.** Measured on GitHub-hosted runners: the module's own fixture (PostgreSQL, a file volume, a sidecar) takes under a minute. CS-ZAMMAD's full stack (Zammad's five roles, PostgreSQL, Elasticsearch, Redis, Memcached) takes 7 to 9 minutes: about 1.5 to free disk space, 1 to build both images, 2 to 3 for the first boot with migrations and the search index, 1.5 for the restore and the restart, the rest for seeding and checks through `rails runner`.

A complete pipeline is in [`gated-release-pipeline.yml`](../../github/workflows/examples/backup-roundtrip/gated-release-pipeline.yml).

## Compose Variants (Traefik, Coolify)

Most stacks ship several compose files: a local one with published ports, one for Traefik, one for Coolify. Operators deploy the variant, not the local file, and the variants differ in exactly the places a backup depends on — volume names, networks, the sidecar's environment. Run the round trip once per variant with a matrix:

```yaml
jobs:
  backup-roundtrip:
    name: 🧪 Backup Round Trip (${{ matrix.variant }})
    strategy:
      fail-fast: false            # one broken variant must not hide the others
      matrix:
        include:
          - variant: local
            compose-file: docker-compose.local.yml
          - variant: traefik
            compose-file: docker-compose.traefik.yml
          - variant: coolify
            compose-file: docker-compose.coolify.yml
    permissions:
      contents: read
      packages: read
    uses: bauer-group/automation-templates/.github/workflows/modules-backup-roundtrip-test.yml@main
    with:
      compose-file: ${{ matrix.compose-file }}
      profiles: 'backup'
      external-networks: 'auto'   # the proxy network the variant declares external
      env-overrides: |
        NGINX_SCHEME=http
      # ... the rest as for a single compose file
      artifact-name: 'backup-roundtrip-${{ matrix.variant }}-diagnostics'
    secrets: inherit

  release:
    needs: [backup-roundtrip]
    # 'success' only when every leg of the matrix passed
    if: needs.backup-roundtrip.result == 'success'
```

What a variant usually needs on a runner:

| Need | How |
|------|-----|
| The proxy network (`networks: proxy: {external: true, name: ${PROXY_NETWORK}}`). On a host Traefik or Coolify owns it; without it `up` refuses to start | `external-networks: 'auto'` creates every network the configuration declares external, by its resolved name. Explicit names work too (`external-networks: 'coolify'`) |
| Variables the variant requires (`${SERVICE_HOSTNAME:?}`, `${PROXY_NETWORK:?}`, Coolify's `SERVICE_FQDN_*` / `SERVICE_PASSWORD_*` that Coolify fills on deployment) | `env-overrides` for plain values, `generated-secrets` for passwords |
| No published ports — the proxy routes to the container | Nothing: the scripts reach the services with `docker compose exec`, never over a port |
| Services that only work behind the real proxy or with an external account (a Cloudflare tunnel with its token, an OAuth proxy) | Leave them out with `services`, or switch them off through their toggle |
| A distinct diagnostics artifact per leg | `artifact-name` with the matrix value |

The proxy itself is not started: Traefik labels, Coolify's routing and TLS are not exercised, only everything behind them. `fail-fast: false` keeps the other legs running when one fails, and `needs.<job>.result` of a matrix job is `success` only when every leg passed — a single `needs` condition gates the release on all variants.

A ready-to-copy caller is in [`compose-variants-matrix.yml`](../../github/workflows/examples/backup-roundtrip/compose-variants-matrix.yml).

## Fitting a Stack

### Sources that need external services

Sources that talk to a SaaS API (Cloudflare), need a token that only exists after manual setup (an application API export), or read a production bucket cannot work on a runner. Switch them off through the toggle your compose file already exposes:

```yaml
env-overrides: |
  BACKUP_API_EXPORT=false        # renders "enabled": false for that source
```

The engine skips a source with `"enabled": false`, and an `s3` source or destination with an empty bucket. Pair this with `require-components` for everything that **must** be in the snapshot, so a toggle cannot hide a source you meant to test. If the compose file has no toggle, add a CI-only override file through `compose-files`.

A stack whose **only** source is external (for example a Cloudflare configuration export) cannot seed data on a runner; the module can then only test the mechanics, or not be used.

### Secrets with a format of their own

`generated-secrets` produces 48 hex characters, which fits passwords and most keys. Some applications want more: an RSA private key as base64 PEM (Lago), exactly 32 characters (a Zitadel master key), base64 of 32 bytes (a LogTo vault key). Repositories that need those usually ship a generator already — let it fill the `.env`:

```bash
#!/usr/bin/env bash
# tests/backup-roundtrip/prepare.sh
set -euo pipefail
python3 scripts/generate-env.py --update   # fills the remaining CHANGE_ME values in .env
```

```yaml
prepare-script: 'tests/backup-roundtrip/prepare.sh'
```

The script runs once the `.env` has been created from the template and before `env-overrides` and `generated-secrets`, so both still win over it. Every `.env` line it adds or changes is masked in the log (values of 8 characters or more, without surrounding quotes). It should not print secrets itself — anything it prints before the masks are registered stays in the log.

Use whatever mode your generator has for "fill the open values": `--update` where it exists, otherwise regenerate the file (`--force`). At this point the `.env` is a fresh copy of the template, so regenerating it loses nothing.

### Plugin sources inside the stack

Plugin sources that talk to the application in the same stack (an n8n workflow export, a NocoDB REST export) work as long as the application is up — `up --wait` ensures that when the application has a healthcheck. If the plugin needs credentials that are created after the first start (an API token), either create them in the seed script or disable the source as above.

### Memory and disk on GitHub-hosted runners

Production defaults (2 GB `shared_buffers`, 1 GB Elasticsearch heap) do not belong on a 2-core runner. Lower them through `env-overrides`; they are ordinary `.env` variables in a well-built stack. Turn on `free-disk-space` when the images add up to several GB.

### uid 1000 sidecars

The engine runs as uid 1000. A filesystem source can only back up what uid 1000 can read and only restore into what it can write. If the application runs as root or another uid, the round trip fails at `show` (warnings for skipped files) or at the restore (`Permission denied`) — which is exactly what it is for. Fix the ownership in the stack (an init container that `chown`s the volume), not in the test.

### No local data volume, `keep_local: false`

The snapshot must exist locally in the sidecar for `show`, `verify` and `restore`. With an empty S3 bucket the engine keeps the local copy even when `keep_local` is `false`. A sidecar without a `/data` volume keeps the snapshot in the container's own filesystem, which is enough as long as the container is not recreated during the test.

### One-shot backup services

The CLI runs with `docker compose exec`, so `backup-service` must be the daemon service. A service that only runs on demand (`command: ["--help"]`, used with `docker compose run`) cannot be the target; use the scheduler service of the same image.

## Step Summary and Diagnostics

Every run writes a summary with the result of each phase, the snapshot's components and the images under test:

```text
## 🧪 Backup Round-Trip Test
✅ Passed - snapshot 2026-10-08_09-14-46 was created, verified and restored.

| Phase               | Result    |
| Seed test data      | ✅ Passed |
| Create backup       | ✅ Passed |
| Inspect snapshot    | ✅ Passed |
| Remove seeded data  | ✅ Passed |
| Restore snapshot    | ✅ Passed |
| Check restored data | ✅ Passed |
| Backup healthcheck  | ✅ Passed |
```

When `create` exited non-zero, the summary says so, with the exit code and whether a snapshot was stored.

On failure (or cancellation) the artifact `artifact-name` contains `ps.txt`, `logs/<service>.log` for every service, `snapshots.txt`, `manifest.json` (once *Inspect snapshot* has run), the output of `create` and `restore`, and the runner's disk and memory state. The `.env` is **never** included. Service logs are uploaded as they are — an application that logs its connection string logs the per-run generated password, which is worthless after the run.

## Troubleshooting

### `backup-service '…' is not part of the configuration`

The sidecar sits behind a profile that is not active. Set `profiles: 'backup'` (or whatever your compose file uses).

### `network … declared as external, but could not be found`

The compose file — usually a Traefik or Coolify variant — joins a network the proxy owns on a real host. Set `external-networks: 'auto'`, see [Compose Variants](#compose-variants-traefik-coolify).

### `backuphelper create` exits 1

The run ended in `error`: a component failed (since BackupHelper 1.7.7), the snapshot was stored on no destination, or the run aborted — a `pre_backup` hook raised or the disk filled up while bundling. A snapshot with a failed component is still stored: the module resolves it and runs *Inspect snapshot*, whose annotations, step summary table and `manifest.json` in the artifact name the failed component and its `error`. The summary also states the exit code. When no snapshot was stored at all, the error says so and only `create.log` and the service logs remain.

For a failed component, `create.log` reports `job <job> snapshot <id> finished: error`. A source that raised — a plugin source, a path the sidecar cannot read — also logged `source <name> (<type>) failed: …` there. A failed dump, a missing path, a failed S3 source or a source without output did not; their reason is only in the manifest, which *Inspect snapshot* reads for you.

### `'backuphelper create' exited 0 but no new local snapshot appeared`

The engine ran zero jobs. The usual cause is a `BACKUP_CONFIG_JSON` the engine does not recognise — for example the pre-engine format with top-level `sources`, `s3` and `retention` keys, whose unknown keys are ignored, leaving an empty job list. Run `docker compose exec <sidecar> backuphelper config` locally: `"jobs": []` confirms it. Migrate the config to the `jobs` schema ([engine configuration](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/configuration.md)).

### `required component '…' is missing`

The source was disabled (`"enabled": false`), skipped (an `s3` source with an empty bucket) or produces a different component name. Database sources are named after the database unless `name` is set.

### `component '…' reported warnings`

A filesystem source skipped entries it could not read — usually root-owned files on a volume the uid 1000 sidecar backs up. Those files would be missing after a real restore. Fix the ownership in the stack; use `allow-component-warnings: true` only for warnings you have understood and accept.

### `up --wait` fails or times out

- A service without a healthcheck that exits is reported as failed. One-shot services are fine when another service depends on them with `condition: service_completed_successfully`; otherwise exclude them through `services`.
- First boots of large applications (migrations, search index builds) take minutes. Raise `wait-timeout`.
- A container killed for memory shows `exit 137` in `ps.txt`. Lower memory limits through `env-overrides`.
- The backup sidecar is unhealthy (BackupHelper 1.7.7 and later): its data dir is not writable by the user it runs as, or a run started by `on_startup` failed. `docker compose exec <sidecar> backuphelper healthcheck` prints the reason. Empty volumes are not a cause, see [BackupHelper 1.7.7 and later](#backuphelper-177-and-later).

### The check fails with "expected absent"

The mutate script did not remove everything the check looks at — or the check reads something the mutation does not touch. Both would let a broken restore pass, which is why the module checks this state.

### The check fails after the restore

This is the failure the module exists for. Compare `manifest.json` (was the component backed up, how big) with `restore.log` (was it restored, any errors) and the application logs.

### Pulls fail with `denied` or `unauthorized`

The calling job does not grant `packages: read`, or the package is private to another organisation. See [Permissions](#permissions).

## Limitations

- **The images are built, not the released artifacts.** The release job rebuilds the images after the round trip; a base image digest can move in the minutes between the two builds. The window is small, but it exists.
- **Off-site storage is not tested.** S3 destinations are skipped when the bucket is empty, which is the CI default. Restoring from S3 (hydration) is covered by the engine's own end-to-end tests, not by this module.
- **Encryption is tested only if the stack enables it in CI.** A stack that encrypts in production needs a throwaway key pair in the test configuration to exercise decryption.
- **Linux runners with Docker Engine and a Compose v2 release that supports `up --wait --wait-timeout`.** `bash`, `jq` and `openssl` must be available — they are on GitHub-hosted runners.
- **One snapshot per run.** Retention, GFS pruning and the scheduler are not exercised.
- **One backup job per configuration.** `create` runs every job of `BACKUP_CONFIG_JSON`, but the module tests only the newest snapshot it produced, and the engine's `list`, `verify` and `restore` use the first job unless `--job` is given. A configuration with several jobs is therefore not covered completely; every consumer on the `jobs` schema defines exactly one today.
- **Restore is a full restore** unless `restore-args` narrows it with `--only`.
- **Compose variants run without their proxy.** `external-networks` creates the proxy network, but Traefik or Coolify is not started; routing, labels and TLS are not tested.

## Related Modules

- [modules-docker-base-image-monitor.yml](./modules-docker-base-image-monitor.md) — dispatches the release pipeline when the engine image moves
- [modules-validate-compose.yml](./modules-validate-compose.md) — static compose validation, run it before the round trip
- [Semantic Release Config Contract](./semantic-release-config.md) — the release the round trip gates
- [docker-build.yml](./docker-build.md) — builds and publishes the images afterwards

## References

- [BackupHelper CLI](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/cli.md)
- [BackupHelper restore](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/restore.md)
- [Docker Compose `up --wait`](https://docs.docker.com/reference/cli/docker/compose/up/)
- [GHCR Internal Visibility](../ghcr-internal-visibility.md)
- [Secrets Reference](../secrets-reference.md)
