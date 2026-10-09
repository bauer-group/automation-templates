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
- **Upgrade of an existing installation** (opt-in) — the previous release seeds and backs up, the stack is upgraded to this commit like an operator does, data and healthcheck are checked, and the old snapshot is restored with the new sidecar, see [Upgrade from a Previous Release](#upgrade-from-a-previous-release)
- **Off-site copy and a new host** (opt-in) — a throwaway S3 server becomes the sidecar's S3 destination; the snapshot must reach the bucket, then the sidecar's local data is wiped and the restore has to pull it back from S3, see [Off-Site S3 and a New Host](#off-site-s3-and-a-new-host)
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

With `upgrade-from`, the stack of steps 3 to 5 is the previous release — checked right after the start, before anything is seeded; after *verify* it is upgraded to the images built from this commit, the check must see the data and the healthcheck must pass, and steps 6 to 9 run on the upgraded stack — the restore reads the old snapshot with the new sidecar. See [Upgrade from a Previous Release](#upgrade-from-a-previous-release).

With `s3-destination`, three phases join the cycle: after *verify* the archive and its manifest must be in the bucket with the local size; before the restore the sidecar's container and data dir are removed like on a new host, and its `list` must show the snapshot as off-site only; after the restore the snapshot must be local again — pulled back from S3 — and pass `verify`. See [Off-Site S3 and a New Host](#off-site-s3-and-a-new-host).
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
| `run-healthcheck` | Run `backuphelper healthcheck` at the end and, with `upgrade-from`, right after the upgrade | `true` |

### Upgrade from a previous release (opt-in)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `upgrade-from` | Start the stack with a previous release and upgrade it to this commit before the restore. `latest-release` (the newest release of this repository; a leading `v` of its tag is dropped for the image tag), one image tag for every `build-images` service (`'1.4.2'`), or a JSON object mapping `build-images` services to `latest-release`, a tag or a full image reference — services left out run this commit's image from the start. See [Upgrade from a Previous Release](#upgrade-from-a-previous-release) | `''` |
| `upgrade-from-compose-files` | Compose files the previous release starts from, as a JSON array — the files of this commit plus an override that restores the previous shape. Empty: the files of `compose-file`/`compose-files`. The upgrade switches to those | `''` |
| `upgrade-script` | Bash script run at the upgrade — after the old snapshot was taken, before the stack switches to the new images and compose files — for what the release notes tell operators to do, e.g. migrating the `.env`. `ROUNDTRIP_PHASE=upgrade`. Every value it adds to or changes in the `.env` is masked, as with `prepare-script` | `''` |

### Off-site S3 destination (opt-in)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `s3-destination` | Start a throwaway S3 server (MinIO) on the networks of the backup service and make it the sidecar's S3 destination. The snapshot must reach the bucket; the restore then runs on a "new host" and pulls it back from S3. See [Off-Site S3 and a New Host](#off-site-s3-and-a-new-host) | `false` |
| `s3-env` | Lines `setting VARIABLE` (whitespace between them, no `=`) naming the `.env` variables your compose file builds its S3 destination from. The module writes the server's values into them. Required: `endpoint`, `bucket`, `access-key`, `secret-key`; optional: `region`, `path-style`, `prefix`. Each setting names a variable of its own. The values are written after `env-overrides` and `generated-secrets`, so they win over both. Read only with `s3-destination`, so a matrix can switch S3 per leg | `''` |
| `s3-image` | Image of the S3 server: MinIO-compatible, with `curl` for the healthcheck | `'ghcr.io/bauer-group/cs-minio/minio:latest'` |
| `s3-client-image` | Image that provides the MinIO client `mc` (bucket creation, listing) | `'ghcr.io/bauer-group/cs-minio/minio-init:latest'` |

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

None. Registry access uses the automatic `GITHUB_TOKEN`; every password the stack needs is generated at runtime through `generated-secrets`, and the credentials of the throwaway S3 server (`s3-destination`) are generated and masked the same way. Callers pass `secrets: inherit` for consistency with the rest of the toolkit.

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
- The reference must be a tag. A service pinned by digest (`ghcr.io/acme/app@sha256:…`) names one exact registry image: no build can be tagged as it, so *Build images under test* (and *Pull previous release* for `upgrade-from`) fails with a message saying so. Give the service a tag for the round trip through `env-overrides` or a CI-only override file.

## Script Contract

The scripts are plain bash files in the caller repository, run with `bash <script>` (no executable bit needed) from `working-directory`.

### Environment

| Variable | Set for | Content |
|----------|---------|---------|
| `ROUNDTRIP_MARKER` | seed, mutate, check | Unique token per run, `rt-<run id>-<attempt>-<8 hex>` — only `[a-z0-9-]`. Tag everything you write with it |
| `ROUNDTRIP_PHASE` | all | `prepare`, `seed`, `mutate`, `check` or `upgrade` |
| `ROUNDTRIP_EXPECT` | check | `present` or `absent` |
| `ROUNDTRIP_SNAPSHOT_ID` | upgrade, mutate, check after the backup | Id of the snapshot under test |
| `ROUNDTRIP_PREVIOUS_RELEASE` | all after *Pull previous release* (`upgrade-from`) | The release tag `latest-release` resolved to (`v0.2.61`); empty for explicit tags |
| `ROUNDTRIP_PREVIOUS_IMAGES` | all after *Pull previous release* (`upgrade-from`) | JSON object: upgraded service → image of the previous release |
| `ROUNDTRIP_BACKUP_SERVICE` | seed, mutate, check | The `backup-service` input |
| `COMPOSE_FILE`, `COMPOSE_PROJECT_NAME`, `COMPOSE_PROFILES` | seed, mutate, check | Set, so `docker compose exec -T <service> …` reaches the stack |

`prepare-script` runs before the stack exists, from `working-directory`, with only `ROUNDTRIP_PHASE=prepare`; it edits `.env` in place. `upgrade-script` runs against the running previous release with the full environment above and `ROUNDTRIP_PHASE=upgrade`; it may edit `.env` too, see [Upgrade from a Previous Release](#upgrade-from-a-previous-release). For both, every `.env` value the script adds or changes is masked in the rest of the log (values of 8 characters or more, without surrounding quotes); neither should print secrets itself — anything printed before the masks are registered stays in the log.

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

**Cost.** Measured on GitHub-hosted runners: the module's own fixture (PostgreSQL, a file volume, a sidecar) takes under a minute, and 1 to 1.5 with `s3-destination` or `upgrade-from`. CS-ZAMMAD's full stack (Zammad's five roles, PostgreSQL, Elasticsearch, Redis, Memcached) takes 7 to 10 minutes (nine runs: 6 min 51 s to 10 min 9 s): about 1.5 to free disk space, 1 to build both images, 2 to 3 for the first boot with migrations and the search index, 1.5 for the restore and the restart, the rest for seeding and checks through `rails runner`. Its upgrade round trip with `s3-destination` takes 9.5 to 12 minutes per compose variant (six legs: 9 min 22 s to 11 min 53 s) — two boots of the full stack — and runs in parallel with the fresh one.

A complete pipeline is in [`gated-release-pipeline.yml`](../../github/workflows/examples/backup-roundtrip/gated-release-pipeline.yml).

## Upgrade from a Previous Release

Without `upgrade-from` every round trip starts on empty volumes with the images of this commit — a fresh installation. Operators do not install fresh: they run the previous release, with its data, its snapshots and its sidecar's run records, and upgrade. With `upgrade-from` the round trip does exactly that:

```yaml
      upgrade-from: 'latest-release'
```

| Phase | What happens |
|-------|--------------|
| Pull previous release | Before anything starts, the previous release's image of every upgraded service is pulled and tagged as the reference the service resolves to (`ghcr.io/acme/app:stable` ← `ghcr.io/acme/app:0.2.61`), so Compose starts it like an installed release. The images built from this commit wait under staging tags |
| Start, seed, back up | The previous release — its application and its sidecar — starts. *Check previous release* then demands that every reference still holds the previous image and that every container of a service on it runs that image; only then does it seed and take the snapshot. *Inspect* and *verify* run against its manifest |
| Upgrade | `upgrade-script` (if set) runs first. Then the stack switches to the compose files of this commit, the builds take over the references — what `docker compose pull` does with a floating tag — and `docker compose up -d --wait` recreates every container whose image changed, one-shot init services included. The id of each build is recorded before `up`; afterwards every reference must still hold it and every container of a service on it must run it, else the step fails |
| After the upgrade | `check-script` must see the data (`present`); `backuphelper healthcheck` must pass in the new sidecar, with the previous release's snapshot and run records in its data dir |
| Mutate, restore, check | As always — the restore reads the **old** snapshot with the **new** sidecar |

**Which release.** `upgrade-from` takes three forms:

| Form | Example | Previous image of a service that resolves to `ghcr.io/acme/app:stable` |
|------|---------|------|
| `latest-release` | `'latest-release'` | the newest published release of this repository (`GET /repos/{repo}/releases/latest`, pre-releases excluded): tag `v0.2.61` → `ghcr.io/acme/app:0.2.61` |
| A tag, for every `build-images` service | `'0.2.60'` | `ghcr.io/acme/app:0.2.60` — the repository of the reference, with this tag |
| A JSON object per service | `'{"app-backup": "ghcr.io/acme/app-backup:0.17.29", "app": "latest-release"}'` | per service: `latest-release`, a tag, or a full reference (anything with `/`, `:` or `@`). Services left out of the object run this commit's image from the start |

Services that share one image (Zammad's five roles on `zammad-railsserver`'s image) are upgraded together — the reference moves for all of them. The release must have published its images under the version tag (`docker-build.yml` does with `auto-tags`); a repository without a release, or with a tag that is no image tag, fails at *Pull previous release* with a message saying so. Private or internal images need `packages: read`, as for every pull.

**A release exists before its images.** `latest-release` reads the newest release when the job runs. The release flow creates the GitHub release first and its image jobs push the version tags afterwards — measured 1 min 40 s (CS-ZAMMAD `v0.2.62`) and 2 min 31 s (CS-n8n `v0.15.48`) later. A run that reaches *Pull previous release* inside that window fails, and so does every run after a release whose image job failed and never pushed. Because the release job needs the round trip, the next release then waits as well. The error says so; the way out is to re-run the failed image job of that release (or wait for the running one), or to set `upgrade-from` to the tag of the release before until its images are published.

**`pull_policy` of the services under test.** The test only means something when Compose runs the images the module tagged: the previous release at the start, the build of this commit after the upgrade. A service with `pull_policy: always` makes `up` pull the reference from the registry, one with `pull_policy: build` builds its own image — either replaces the tagged image, and the containers would then run the registry's or Compose's image while the reference looks right. The module therefore compares the containers with the image ids it tagged, not with whatever the reference holds after `up`, and fails at *Check previous release* or *Upgrade* when `up` replaced one. Keep `missing` (the default) or `never` for the round trip; when the production file sets `always`, override it in a CI-only file through `compose-files` (and `upgrade-from-compose-files`, if set).

**When the previous release has a different shape.** By default the previous release starts from the compose files of **this** commit — it is the *images* that are old. That is exactly right while the compose files and the `.env` stay compatible, which they are between neighbouring releases of most stacks. When they are not:

- **The previous release needs other compose settings** (an old source type, a removed variable, a different healthcheck): keep an override file that restores them and pass `upgrade-from-compose-files: '["docker-compose.yml", "tests/backup-roundtrip/previous-release.yml"]'`. The previous release starts from those files; the upgrade switches to `compose-file`/`compose-files`. The first file must lie in `working-directory` like the others, because Compose reads the `.env` from the first file's directory. CS-IAM's legacy-snapshot job is this pattern: the override sets the old `zitadel-postgres` source type.
- **The release notes ask operators to do something** (rename a variable, add a new required one, run a migration command against the old stack): put it in `upgrade-script`. It runs against the running previous release, after the old snapshot was taken and before the switch, and may edit `.env`; Compose picks the changes up at `up -d`. Every value it adds to or changes in the `.env` is masked, like a secret: a setting that is not secret and that the previous release can live with belongs in `env-overrides` instead, which both releases read from the start.
- **The shapes are too far apart** for an override (renamed services, moved volumes): pin `upgrade-from` to a release that is close enough, or keep a fresh round trip only — volume names must survive the upgrade for the data to.

The previous release's compose files are never checked out from its tag: the module cannot know which of them an operator used, and the data must live in the same named volumes before and after anyway.

A ready-to-copy caller is in [`upgrade-from-previous-release.yml`](../../github/workflows/examples/backup-roundtrip/upgrade-from-previous-release.yml).

## Off-Site S3 and a New Host

Without `s3-destination` every round trip restores from the copy in the sidecar's own data volume — the one copy that is gone when the host is gone. With it, the round trip proves the disaster-recovery path: the snapshot reaches an S3 bucket, and a sidecar with an empty data dir brings it back from there.

```yaml
      s3-destination: true
      # setting VARIABLE - the .env variables your compose file builds the
      # S3 destination from (here CS-ZAMMAD's)
      s3-env: |
        endpoint   ZAMMAD_BACKUP_S3_ENDPOINT_URL
        bucket     ZAMMAD_BACKUP_S3_BUCKET
        access-key ZAMMAD_BACKUP_S3_ACCESS_KEY
        secret-key ZAMMAD_BACKUP_S3_SECRET_KEY
        region     ZAMMAD_BACKUP_S3_REGION
```

Setting and variable are separated by whitespace, not `=`: secret scanners read a line like `access-key=ZAMMAD_BACKUP_S3_ACCESS_KEY` as a hard-coded credential (GitGuardian reported exactly that line as a *Generic High Entropy Secret*), so the module rejects the `=` form.

| Phase | What happens |
|-------|--------------|
| Prepare | The variables `s3-env` names are set in the `.env` — after `env-overrides` and `generated-secrets`, so they win: `endpoint` `http://roundtrip-s3:9000`, `bucket` `backup-roundtrip`, `access-key`/`secret-key` the server's generated (masked) credentials, `region` `us-east-1`, `path-style` `true`, `prefix` `backup-roundtrip/`. Unmapped optional settings keep your defaults. A generated override file adds the server `roundtrip-s3` to the project, on the networks of `backup-service`, and a client `roundtrip-s3-client` behind a profile of its own |
| Start | The server starts before the stack; the module creates the bucket (your configuration may set `ensure_bucket: false`, as it would against a real provider) |
| After *verify* | `<id>.tar.gz` (or `.age`/`.gpg`) and `<id>.manifest.json` must be in the bucket — under any prefix — and the archive must have the local size. A failed upload does **not** fail `create`: the run ends in `warning` and exits `0`, because the local copy exists. Only the bucket shows it |
| New host | After *mutate*, the sidecar's container is removed and its data dir `BACKUP_DATA_DIR` (default `/data`) is emptied with the sidecar's own image, also the run records in `.state/` — a volume or bind mount at that path, or the data dir below the deepest one above it (a `/data` volume holding `/data/backups`; the rest of that volume stays). A data dir on no mount went with the container. The sidecar starts again; `list` must show no local snapshot and the snapshot under test as `(off-site only)` |
| Restore | Unchanged — `restore <id>` finds no local copy and downloads archive and manifest from the bucket first (hydration) |
| After the restore | The snapshot must be local again and pass `verify` — the hydrated copy, not the one from before |

**What your stack needs:** an S3 destination in its `BACKUP_CONFIG_JSON` whose settings come from `.env` variables — the way every consumer exposes its off-site copy (`"bucket": "${APP_BACKUP_S3_BUCKET:-}"`, `"secret_key": "$${S3_SECRET_KEY}"` with `S3_SECRET_KEY: ${APP_BACKUP_S3_SECRET_KEY:-}`). A setting your compose file hard-codes cannot be pointed at the server; an empty bucket variable keeps the destination skipped in every run without `s3-destination`, so nothing changes there. The data volume may also be mounted into other services (read-only into the application): it is emptied, not removed.

**Region and addressing.** The server has no region configured and accepts any; mapping `region` is only needed when your compose file has no default for it. The engine uses path-style addressing by default (`force_path_style`), which MinIO needs; map `path-style` if your compose file makes it configurable.

**With `keep_local: false`** the engine deletes the local copy once the upload is verified, and *Create backup* finds no new local snapshot to inspect and verify. Keep the local copy in CI (`keep_local` through `env-overrides`) — the new-host phase removes it anyway. When the compose file hard-codes `"keep_local": false`, set it in a CI-only override file (`compose-files`) with the engine's [discrete env override](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/configuration.md#discrete-env-overrides) on the sidecar:

```yaml
# tests/backup-roundtrip/compose.ci.yml
services:
  app-backup:
    environment:
      BACKUP_JOBS__0__KEEP_LOCAL: "true"
```

A ready-to-copy caller is in [`offsite-s3-new-host.yml`](../../github/workflows/examples/backup-roundtrip/offsite-s3-new-host.yml).

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

The snapshot must exist locally in the sidecar for `show`, `verify` and `restore`. With an empty S3 bucket the engine keeps the local copy even when `keep_local` is `false`. A sidecar without a `/data` volume keeps the snapshot in the container's own filesystem, which is enough as long as the container is not recreated during the test. With `s3-destination` the bucket is set: keep `keep_local` at `true` for the test, see [Off-Site S3 and a New Host](#off-site-s3-and-a-new-host).

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

When `create` exited non-zero, the summary says so, with the exit code and whether a snapshot was stored. Opt-in phases add their rows only when they are configured — with `upgrade-from` *Pull previous release*, *Previous release runs* and *Upgrade to this commit*, plus a table of the previous release's images; with `s3-destination` *Off-site copy in S3*, *New host: local data wiped* and *Snapshot pulled back from S3*, plus a table of the objects in the bucket; with `external-networks` the networks the run created.

On failure (or cancellation) the artifact `artifact-name` contains `ps.txt`, `logs/<service>.log` for every service, `snapshots.txt`, `manifest.json` (once *Inspect snapshot* has run), the output of `create` and `restore`, and the runner's disk and memory state; with `s3-destination` also `s3-objects.json` (the bucket listing) and the generated `s3-destination.compose.yml`, which holds `.env` references only; with `upgrade-from` also `upgrade-plan.tsv` (service, previous image, reference). The `.env` is **never** included. Service logs are uploaded as they are — an application that logs its connection string logs the per-run generated password, which is worthless after the run. The same goes for the throwaway S3 server's log (`logs/roundtrip-s3.log`): MinIO prints its root credentials only when its output is a terminal (checked for RELEASE.2025-10-15, the version in the default image at the time of writing), and the module starts it without one; another `s3-image` may print them, but they too are generated per run and the server is removed with the job.

## Troubleshooting

### `backup-service '…' is not part of the configuration`

The sidecar sits behind a profile that is not active. Set `profiles: 'backup'` (or whatever your compose file uses).

### `upgrade-from: '…' could not be pulled`

The previous release did not publish that image under the tag, or the job may not read it. Check the package's tags (a release tag `v1.4.2` is looked up as image tag `1.4.2`), `registry-login` and `packages: read`. For an image that is published under another name, give the full reference in the JSON form.

With `latest-release`, the error adds that the latest release may not have its images yet: the release is created before its image jobs push the tags, or one of them failed. Re-run the failed image job of that release, or pin `upgrade-from` to the release before until the images are published, see [A release exists before its images](#upgrade-from-a-previous-release).

### `'up' replaced …, which held the previous release` / `'up' replaced the image under test …`

`docker compose up` put another image under a reference the module had tagged — at the start (*Check previous release*) or at the upgrade (*Upgrade*). A service on that reference has `pull_policy: always`, which pulls the registry's image over it, or `pull_policy: build`, which builds its own. The error shows both image ids. Set `pull_policy` to `missing` or `never` for the round trip, see [`pull_policy` of the services under test](#upgrade-from-a-previous-release). Nothing after the check runs: the stack runs neither the previous release nor the build under test.

### `upgrade-from: '…' runs …, not the previous release` / `upgrade: '…' runs … after 'up -d', not the build of this commit`

The reference holds the right image, but a container of that service runs another one: Compose did not recreate it after the reference moved (it was started outside Compose, or with `--no-recreate`), or it is left over from an earlier start. The data check is skipped: the stack is only half upgraded.

A warning `no started service runs …` means that no started container uses an upgraded image — the service is outside `services` and its dependencies, so its upgrade is not tested.

### The healthcheck fails right after the upgrade

The new sidecar judges the previous release's run records. A failed previous run, or a snapshot of the previous release with a failed component, keeps it unhealthy until a newer run succeeds — exactly what an operator would see after the same upgrade ([BackupHelper healthcheck](https://github.com/bauer-group/CS-BackupHelper/blob/main/docs/deployment.md#the-functional-healthcheck)). With several jobs, see the engine's notes on the healthcheck transition after an upgrade.

### `the archive of snapshot … is not in the bucket`

With `s3-destination`: the sidecar did not upload. `create` exited `0` anyway — a failed upload ends the run in `warning`. The sidecar's log (artifact) has the upload error. Usual causes: `s3-env` names a variable your compose file does not read for the destination (check `docker compose config` with the mapped values), the compose file hard-codes the endpoint or the bucket, or the sidecar is not on a network it shares with `roundtrip-s3`.

### `the new sidecar does not list snapshot … as off-site`

The sidecar that started on the empty data dir cannot see the bucket: `list` reads the off-site copies of the first job's S3 destination. Check that the destination is in the first job and that its settings survive a container restart (they come from the `.env`, not from a file in the data dir).

### `local snapshots survived the wipe`

*Simulate new host* emptied the data dir the sidecar's `BACKUP_DATA_DIR` names (default `/data`) — on its own mount, below a mount, or with the container — but the restarted sidecar still lists local snapshots. The sidecar keeps them somewhere else: `BACKUP_DATA_DIR` is set in a way the container's environment does not show (an entrypoint that exports it), or the data dir lies on a mount type that is not a volume or bind mount. The step log names the data dir and the mount it wiped.

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
- **Off-site storage is tested against MinIO only, and only with `s3-destination`.** Without it S3 destinations are skipped (empty bucket, the CI default). With it, upload and hydration run against a MinIO server over plain HTTP: provider specifics (AWS virtual-host addressing, R2 or B2 quirks), TLS and `ca_bundle` are not exercised.
- **Encryption is tested only if the stack enables it in CI.** A stack that encrypts in production needs a throwaway key pair in the test configuration to exercise decryption.
- **Linux runners with Docker Engine and a Compose v2 release that supports `up --wait --wait-timeout`.** `bash`, `jq` and `openssl` must be available — they are on GitHub-hosted runners.
- **One snapshot per run.** Retention, GFS pruning and the scheduler are not exercised.
- **One backup job per configuration.** `create` runs every job of `BACKUP_CONFIG_JSON`, but the module tests only the newest snapshot it produced, and the engine's `list`, `verify` and `restore` use the first job unless `--job` is given. A configuration with several jobs is therefore not covered completely; every consumer on the `jobs` schema defines exactly one today.
- **Restore is a full restore** unless `restore-args` narrows it with `--only`.
- **The upgrade test is one hop, with the compose files of this commit.** `upgrade-from` upgrades from one release, by switching images; the previous release starts from this commit's compose files unless `upgrade-from-compose-files` says otherwise. Skipped releases in between, bind-mounted data (paths differ between checkouts) and a restore of the previous release's data into a downgraded stack are not covered.
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
