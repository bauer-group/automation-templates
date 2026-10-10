# Security Scan Module

Dependency vulnerability scanning with [Trivy](https://trivy.dev/) and opt-in secret
scanning with [Gitleaks](https://github.com/gitleaks/gitleaks), as one reusable workflow:
[`modules-security-scan.yml`](../../.github/workflows/modules-security-scan.yml). The work
is done by the [`security-scan`](../../.github/actions/security-scan/action.yml) composite
action, which can also be used directly as a step.

## Overview

- **Trivy** checks every dependency file it can read (lock files, manifests) for known
  vulnerabilities. Python projects with only a `pyproject.toml` are resolved first, so they
  are not silently skipped.
- **Gitleaks is opt-in** (`scan-engine: 'gitleaks'`). Enable it in repositories without
  GitHub secret scanning and push protection - see
  [Gitleaks is opt-in](../security/native-secret-scanning.md#gitleaks-is-opt-in).
- **Pull requests are scanned without `pull-requests: read`.** In private and internal
  repositories gitleaks-action needs that scope to list a pull request's commits; this
  workflow cannot pass it (see [Permissions](#permissions)), so there the pull request's
  commits are scanned with the gitleaks CLI. See
  [How Gitleaks scans each event](#how-gitleaks-scans-each-event).
- **"Not scanned" is never "clean".** A scan that did not complete reports `unknown` and
  fails the gate; a disabled Gitleaks reports `skipped` and says so in the summary.

## Quick Start

> **Copy-paste example:** [`github/workflows/examples/security/security-scan.yml`](../../github/workflows/examples/security/security-scan.yml)

```yaml
name: Security
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    permissions:
      contents: read
      security-events: write
      actions: read
    with:
      scan-engine: 'gitleaks'   # opt-in; the default 'none' runs Trivy only
    secrets: inherit            # GITLEAKS_LICENSE (organization repositories)
```

### Dependencies only (Gitleaks off, the default)

```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    permissions:
      contents: read
      security-events: write
      actions: read
    with:
      scan-type: 'vulnerabilities'
```

### Report-only while triaging

```yaml
    with:
      scan-engine: 'gitleaks'
      fail-on-findings: false
```

## Permissions

The workflow declares exactly these scopes, and the calling job must grant all of them:

```yaml
permissions:
  contents: read
  security-events: write
  actions: read
```

A called workflow can only **narrow** the caller's token, never widen it. If the caller
grants less than this list, GitHub refuses to start the run ("The nested job ... is
requesting ..., but is only allowed ..."): you get a run with no jobs and no log.

`pull-requests: read` is deliberately **not** in the list. gitleaks-action would need it on
pull requests of private and internal repositories, but adding it would make GitHub refuse
every existing caller that grants the three scopes above. The action detects a token that
cannot list the pull request's commits instead and scans them with the gitleaks CLI, which
needs no API access.

## Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scan-engine` | Secret scanner. `'none'`: Gitleaks off (notice in the run). `'gitleaks'`: Gitleaks on. `'both'`: still accepted, runs Gitleaks. `'gitguardian'`: deprecated, runs **no** secret scanner (warning in the run). | `'none'` |
| `scan-type` | `'all'`, `'secrets'` (Gitleaks only) or `'vulnerabilities'` (Trivy only) | `'all'` |
| `fail-on-findings` | Fail the job on a secret, an incomplete secret scan (`unknown`), or a critical/high/medium vulnerability | `true` |
| `exclude-paths` | Comma-separated paths skipped when resolving Python projects without a lock file. Gitleaks does not read it - configure Gitleaks exclusions in `.gitleaks.toml`. | `'.git,node_modules,vendor'` |
| `minimum-severity` | Deprecated and ignored (configured GitGuardian only) | `'medium'` |
| `runs-on` | Runner: a label string, or a JSON array for self-hosted runners | `'ubuntu-latest'` |

## Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `GITLEAKS_LICENSE` | Only with `scan-engine: 'gitleaks'` in an **organization** repository, for every run that uses gitleaks-action (see the table below) | License key for `gitleaks/gitleaks-action` (free from [gitleaks.io](https://gitleaks.io)). Pull request runs of private and internal repositories scan with the gitleaks CLI and do not read it. Dependabot-triggered runs read secrets from the **Dependabot** store, not the Actions store. |
| `GITGUARDIAN_API_KEY` | No | Deprecated and ignored (GitGuardian was removed) |

Use `secrets: inherit`. Details: [Secrets Reference](../secrets-reference.md#security-scanning).

## Outputs

| Output | Description |
|--------|-------------|
| `secrets-found` | `'true'`, `'false'`, `'unknown'` (the scan did not complete) or `'skipped'` (no secret scan ran, e.g. Gitleaks disabled). Only `'false'` means scanned and clean. |
| `secrets-count` | Number of findings, or `unknown` if the scan did not complete |
| `vulnerabilities-found` | `'true'`, `'false'`, or `'unknown'` when Trivy found no dependency file it can read |
| `security-score` | 0-100: 100, minus 50 for a secret finding, minus up to 50 for vulnerabilities |
| `scan-results` | `Security Scan Complete` or `Security Issues Found` |

Reports (Gitleaks SARIF, Trivy JSON, the summary) are uploaded as the
`security-scan-reports` artifact for 30 days.

## How Gitleaks scans each event

| Event | Runner | Commits scanned | Licence |
|-------|--------|-----------------|---------|
| `push` | `gitleaks/gitleaks-action` | The pushed commits | Required in organization repositories |
| `schedule`, `workflow_dispatch` | `gitleaks/gitleaks-action` | The full history | Required in organization repositories |
| `pull_request`, token **cannot** list the pull request's commits (private and internal repositories: always the case through this workflow) | gitleaks CLI | The pull request's own commits: `base.sha..head.sha` from the event, `--no-merges --first-parent` | Not needed |
| `pull_request`, token **can** list them (any token in a public repository, or one with `pull-requests: read` such as `modules-pr-validation`'s) | `gitleaks/gitleaks-action` | The pull request's commits, listed through the API | Required in organization repositories |

On a pull request the action first asks the API for the pull request's commits - the same
request gitleaks-action makes. If the token may not (any answer other than HTTP 200), the
run shows a notice and the CLI takes over:

- **Same version and rules** as gitleaks-action: gitleaks `8.24.3`, the repository's
  `.gitleaks.toml` if present, redacted output, the same SARIF report.
- **Verified download:** the release archive is checked against the release's own
  `checksums.txt` before it is unpacked; a mismatch is never executed.
- **Same range:** what the pull request adds on top of its base branch. A secret that is
  already on the base branch is not reported here - the push and scheduled scans own it.
- **Linux runners** (x64 and ARM64). On other runners the scan does not run and is
  reported as `unknown`, which fails the gate.

Callers whose token can list the commits keep running gitleaks-action exactly as before.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `RequestError [HttpError]: Resource not accessible by integration`, `status: 403`, on `GET /repos/.../pulls/<n>/commits` | gitleaks-action on a pull request of a private repository without `pull-requests: read`. Fixed: the action now detects this and uses the CLI. | Nothing to change in the caller. Re-run the failed check; callers on `@main` pick the fix up. |
| Run fails before any job starts: "The nested job ... is requesting ..., but is only allowed ..." | The calling job grants less than the [three scopes](#permissions) | Grant `contents: read`, `security-events: write`, `actions: read` on the calling job |
| `missing gitleaks license` | Push, schedule or dispatch run in an organization repository without `GITLEAKS_LICENSE` | Add the secret; for Dependabot runs also as a Dependabot secret (see [Secrets](#secrets)) |
| `Gitleaks range unavailable` | The checkout does not contain the pull request's base or head commit | The workflow checks out with `fetch-depth: 0`; when using the action directly, do the same |
| `Gitleaks CLI unavailable` | Pull request scan on a non-Linux runner | Run the scan on a Linux runner |
| `secrets-found: unknown`, "Gitleaks scan did not complete" | Gitleaks did not run to completion (see the step log above it) | Fix the cause; `unknown` is never treated as clean |
| Summary says *disabled - Gitleaks is opt-in* | `scan-engine` is `'none'` (the default) | Set `scan-engine: 'gitleaks'` if the repository has no native secret scanning |

## Related

- [Gitleaks is opt-in](../security/native-secret-scanning.md#gitleaks-is-opt-in) - when to enable it
- [TruffleHog Secret Scan Module](./modules-trufflehog-scan.md) - verified-first secret scanning
- [Secrets Reference](../secrets-reference.md#security-scanning)
- [gitleaks-action](https://github.com/gitleaks/gitleaks-action) and the [gitleaks CLI](https://github.com/gitleaks/gitleaks)
- [Reusable workflows: GITHUB_TOKEN permissions can only be downgraded](https://docs.github.com/en/actions/reference/workflows-and-actions/reusable-workflows)
