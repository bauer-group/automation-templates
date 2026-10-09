# Backup Round-Trip Test — Examples

Callers of [`modules-backup-roundtrip-test.yml`](../../../../.github/workflows/modules-backup-roundtrip-test.yml): start the stack, seed data, back it up with the BackupHelper sidecar, delete the data, restore it and prove it is back — before an image is released.

Full reference: [`docs/workflows/modules-backup-roundtrip-test.md`](../../../../docs/workflows/modules-backup-roundtrip-test.md).

## Examples

| Example | Use case |
|---------|----------|
| [minimal-postgres-filesystem.yml](minimal-postgres-filesystem.yml) | Smallest useful round trip: one PostgreSQL database and one file volume, on pull requests and on demand |
| [gated-release-pipeline.yml](gated-release-pipeline.yml) | Complete `docker-release.yml`: validation, round trip, semantic release and image builds — no release unless the round trip passed |
| [plugin-and-external-sources.yml](plugin-and-external-sources.yml) | A plugin source that talks to the application in the stack (tested) and one that needs an external SaaS account (switched off), with `require-components` guarding the rest |
| [offsite-s3-new-host.yml](offsite-s3-new-host.yml) | The snapshot must reach an S3 bucket (a throwaway MinIO), and the restore runs on a "new host" whose data dir was wiped - it has to pull the snapshot back from S3 |
| [compose-variants-matrix.yml](compose-variants-matrix.yml) | One round trip per compose variant (local, Traefik, Coolify) in a matrix; `external-networks: 'auto'` creates the proxy networks the variants declare external |

## Setup

1. **Make the sidecar testable.** The backup service must run as a daemon (`docker compose exec` reaches it), and every source you cannot run on a runner needs an `enabled` toggle in `.env` — see [Sources that need external services](../../../../docs/workflows/modules-backup-roundtrip-test.md#sources-that-need-external-services).
2. **Write the scripts** under `tests/backup-roundtrip/`:
   - `seed.sh` — writes data tagged with `$ROUNDTRIP_MARKER` into every component you want to prove (a database row *and* a file on each volume)
   - `mutate.sh` — deletes it again
   - `check.sh` — exits `0` when every seeded item matches `$ROUNDTRIP_EXPECT` (`present` or `absent`)

   The CI-tested reference for PostgreSQL plus a file volume is the module's own fixture in [`.github/workflows/tests/backup-roundtrip/`](../../../../.github/workflows/tests/backup-roundtrip/); a MySQL/MariaDB variant is in the [script contract](../../../../docs/workflows/modules-backup-roundtrip-test.md#example-mysql--mariadb).
3. **Copy an example** to `.github/workflows/` and adjust compose file, profiles, `build-images`, `backup-service`, `require-components` and the services to stop for the restore.
4. **Generate every password** with `generated-secrets` — or, for secrets with a format of their own (RSA keys, exact lengths, base64), call the repository's generator from a `prepare-script` — and lower memory limits with `env-overrides`. Never commit credentials to make the stack start.
5. **Grant `packages: read`** on the calling job, so internal images can be pulled.

## What a run proves

| Phase | Proof |
|-------|-------|
| Seed + check | The check sees the seeded data (`present`) |
| Create + show | A new snapshot exists; every component is error-free, warning-free and every required component is in it |
| Verify | The archive matches the manifest checksum |
| Mutate + check | The check no longer sees the data (`absent`) — so it can tell the difference |
| Restore + check | The data is back (`present`) after the stack was restarted |
| Healthcheck | The sidecar reports the new snapshot as fresh |
| S3 (`s3-destination`) | Archive and manifest reached the bucket; after the sidecar's data dir was wiped, the restore pulled the snapshot back from S3 and it passed `verify` |

## Related

- [Docker Base Image Monitor](../../../../docs/workflows/modules-docker-base-image-monitor.md) — dispatches the gated pipeline when the engine image moves
- [Docker Compose Validation](../../../../docs/workflows/modules-validate-compose.md) — static validation before the round trip
- [BackupHelper engine](https://github.com/bauer-group/CS-BackupHelper)
