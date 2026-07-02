# Sync Upstream — Example

Drop-in caller that keeps a **fork** in sync with its upstream and integrates the update into the workspace branch — so the fork maintains itself.

Full reference: [`docs/workflows/sync-upstream.md`](../../../../docs/workflows/sync-upstream.md).

## The self-maintaining chain

```text
schedule / manual
      │
      ▼
 sync-upstream.yml
   Stage A: merge-upstream API   upstream/main ─▶ origin/main   (the "Sync fork" button)
   Stage B: git merge + PAT push origin/main   ─▶ origin/workspace
                                                        │
                                                        ▼ (push event, via PAT)
                                              fork-docker-build.yml → GHCR
```

## Setup

1. Copy [`sync-upstream.yml`](sync-upstream.yml) to `.github/workflows/sync-upstream.yml` on the fork.
2. Add a **PAT** secret so the workspace push triggers the build:
   - Repository → Settings → Secrets and variables → Actions → **New repository secret**
   - Name: `PAT_READWRITE_ORGANISATION`
   - Classic PAT: `repo` + `workflow` · Fine-grained: **Contents** + **Workflows** + **Issues** (R/W)
3. Adjust the `mirror-branch` / `integrate-into` defaults if your branches differ.

> Without a PAT the sync + merge still run, but the `workspace` push will **not** trigger the downstream build (GitHub does not let a `GITHUB_TOKEN` push start other workflows). The workflow warns when no PAT is present.

## Prerequisites

- The repository must be a **GitHub-native fork** (created via *Fork*, with a `parent`). Stage A uses the `merge-upstream` API, which requires a parent. A non-fork fails early with a clear message.

## Conflicts

A merge conflict does **not** hard-fail the run. It emits a `::warning::`, writes a summary table, and (by default) opens a de-duplicated GitHub issue labelled `sync` / `conflict` / `automated` with manual resolution steps. Set `create-issue-on-conflict: false` to rely on the warning + summary only.

## Dry run

Trigger manually with `dry-run: true` to verify the fork relationship (parent detection) without syncing, merging, or pushing.

## Related

- [`fork-docker-build`](../fork-docker-build/README.md) — the build triggered by the workspace push
