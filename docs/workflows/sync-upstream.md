# 🔄 Sync Upstream

## Overview

`sync-upstream.yml` keeps a **forked repository** in sync with its upstream and, optionally, integrates the update into a working branch — so forks maintain themselves. It is the automated, professional replacement for hand-rolled "sync fork" scripts.

It runs in two stages:

- **Stage A — Sync mirror branch** (the GitHub *"Sync fork"* button): calls the native [`merge-upstream`](https://docs.github.com/en/rest/branches/branches#sync-a-fork-branch-with-the-upstream-repository) API to update the fork's mirror branch (e.g. `main`) from its upstream parent. A merge conflict raises a **warning** (and optionally opens a GitHub issue) instead of failing silently.
- **Stage B — Integrate into workspace** (optional): merges the freshly-synced mirror into the integration branch (e.g. `main` → `workspace`). On a clean merge it pushes with a PAT — which **triggers the downstream build** ([`fork-docker-build.yml`](fork-docker-build.md)). On conflict it aborts and warns.

```text
upstream/main ──(A: merge-upstream API)──▶ origin/main
     origin/main ──(B: git merge + push)──▶ origin/workspace ──▶ Fork Docker Build
```

## Key Features

- ✅ **Native "Sync fork"** — uses GitHub's `merge-upstream` API, exactly like the UI button
- ✅ **Configurable branches** — `mirror-branch` and `integrate-into` are inputs
- ✅ **Conflict = warning** — `::warning::` annotation, a summary table, and (optional) a de-duplicated GitHub issue with resolution steps
- ✅ **Self-maintaining chain** — a PAT-driven `workspace` push triggers the build automatically
- ✅ **Dry-run** — validate the fork relationship without changing anything
- ✅ **Runner-flex** — GitHub-hosted or self-hosted via `runs-on`

## Quick Start

Add this caller to the fork:

```yaml
name: 🔄 Sync Upstream

on:
  schedule:
    - cron: "0 4 * * 1" # weekly, Monday 04:00 UTC
  workflow_dispatch:
    inputs:
      mirror-branch:
        description: "Fork branch to sync from upstream"
        default: "main"
      integrate-into:
        description: "Integration branch to merge into (empty = skip)"
        default: "workspace"

permissions:
  contents: write
  issues: write

jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/sync-upstream.yml@main
    with:
      mirror-branch: ${{ github.event.inputs.mirror-branch || 'main' }}
      integrate-into: ${{ github.event.inputs.integrate-into || 'workspace' }}
    secrets: inherit
```

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `mirror-branch` | string | `main` | Fork branch to sync from upstream (the "Sync fork" target) |
| `integrate-into` | string | `''` | Integration branch to merge the mirror into. Empty = skip Stage B |
| `create-issue-on-conflict` | boolean | `true` | Open (or update) a GitHub issue on a merge conflict |
| `dry-run` | boolean | `false` | Only verify the fork relationship; do not sync, merge or push |
| `runs-on` | string | `ubuntu-latest` | Runner (string or JSON array for self-hosted) |
| `timeout-minutes` | number | `15` | Timeout per job |

## Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `MAINTENANCE_TOKEN` | recommended | PAT used for `merge-upstream` **and** the `workspace` push, so the downstream build is triggered |
| `PAT_READWRITE_ORGANISATION` | fallback | Backward-compatible PAT alias, used if `MAINTENANCE_TOKEN` is absent |

> **Why a PAT?** A push made with the default `GITHUB_TOKEN` does **not** trigger other workflows (GitHub's anti-recursion rule). Without a PAT, Stage B still merges and pushes, but the `workspace` push will **not** auto-trigger `fork-docker-build.yml`. The workflow warns when no PAT is configured. A classic PAT needs `repo` scope; a fine-grained PAT needs **Contents: Read/Write** (and **Issues: Read/Write** for conflict issues).

## Outputs

| Output | Description |
|--------|-------------|
| `mirror-status` | `synced` \| `up-to-date` \| `conflict` \| `not-a-fork` \| `error` \| `dry-run` |
| `mirror-merge-type` | `fast-forward` \| `merge` \| `none` |
| `workspace-status` | `integrated` \| `up-to-date` \| `conflict` \| `skipped` |

## Behaviour & branch model

This workflow implements the fork branch hierarchy: **mirror** branches (`main`, `dev`) are exact upstream copies (PR base, not built); **workspace** is the integration branch (fork default branch, image-build source). Stage A keeps the mirror current; Stage B carries upstream into the workspace, preserving the fork's own commits through a merge.

- **Requires a GitHub-native fork.** `merge-upstream` needs a `parent` repository. If the repo is not a fork, the run fails early with a clear message.
- **Conflicts do not hard-fail** — they surface as a warning + summary + issue, matching the *"emit a warning on conflict"* requirement. Manual resolution steps are included in the issue body (German).
- **Issue de-duplication** — a repeated conflict updates the existing open `sync`/`conflict` issue instead of opening a new one.

## Components

- **Reusable workflow:** `.github/workflows/sync-upstream.yml`
- **Examples:** `github/workflows/examples/sync-upstream/`
- **Related:** [`fork-docker-build.yml`](fork-docker-build.md) — triggered by the `workspace` push this workflow makes
