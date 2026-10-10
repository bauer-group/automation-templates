# Docker Maintenance (Dependabot) — Examples

Callers of [`docker-maintenance-dependabot.yml`](../../../../.github/workflows/docker-maintenance-dependabot.yml): merge a Dependabot PR only after the CI you name has run on it and passed — no ruleset, no branch protection, no "Allow auto-merge".

Full reference: [`docs/workflows/docker-maintenance.md`](../../../../docs/workflows/docker-maintenance.md#option-1-dependabot-simple).

## Examples

| Example | Use case |
|---------|----------|
| [simple-dependabot-maintenance.yml](simple-dependabot-maintenance.yml) | Smallest caller: Dockerfile updates, one PR CI workflow |
| [with-backup-roundtrip-gate.yml](with-backup-roundtrip-gate.yml) | Container stack: merged only after the PR run of `docker-release.yml` — image builds and the [backup round trip](../backup-roundtrip/gated-release-pipeline.yml) — passed; private-repository permissions |
| [own-build-and-test-workflow.yml](own-build-and-test-workflow.yml) | Image without a backup sidecar: the repository's own `ci.yml` vouches; Docker and npm updates both let through |
| [multiple-required-workflows.yml](multiple-required-workflows.yml) | Image build and a separate test suite: both have to run on the PR and pass |
| [no-pr-ci-manual-merge.yml](no-pr-ci-manual-merge.yml) | No PR CI yet: `required-workflows` deliberately unset — nothing is merged, every PR is reported for review |

## Setup

1. **Let Dependabot open the PRs.** Copy [`.github/config/docker-maintenance-dependabot/dependabot.yml`](../../../../.github/config/docker-maintenance-dependabot/dependabot.yml) to `.github/dependabot.yml` and keep `commit-message.prefix: "fix(docker)"`, so a merged update releases a patch version. Internal or private base images need Dependabot's own registry secrets — see the comment in that file.
2. **Name the CI that vouches for an update** in `required-workflows`: the workflow files whose `pull_request` run builds and tests what Dependabot changes. Not this caller, not a notification, labeler or scan job — they pass on every PR without testing anything.
3. **Choose the trigger scope.** The caller's `on.pull_request.paths` decide which Dependabot PRs reach the workflow at all; a PR outside them stays open without any annotation. List exactly the files Dependabot changes for the ecosystems that may be merged, and keep them within the `pull_request` `paths:` of every required workflow — see [Decide which PRs reach it](../../../../docs/workflows/docker-maintenance.md#3-decide-which-prs-reach-it-trigger-scope).
4. **Grant the permissions** in the caller: `contents: write` and `pull-requests: write`, plus `checks: read`, `statuses: read` and `actions: read` in private repositories. The reusable workflow declares none of its own.
5. **Copy an example** to `.github/workflows/docker-maintenance.yml` and adjust `paths:` and `required-workflows`.

## What decides a merge

| Check | A PR is merged only if |
|-------|------------------------|
| Trigger | It changes a file in the caller's `paths:` and was opened by Dependabot, on an event Dependabot raised |
| CI change | It is no GitHub Actions update and changes no file under `.github/` |
| Required CI | `required-workflows` is set |
| Update type | The semver update type is in `merge-update-types` (default `patch`). Below 1.0.0 a minor update (`0.3.1 → 0.4.0`) and a patch update of `0.0.z` (`0.0.3 → 0.0.4`) count as major — every dependency of a grouped PR is checked, see [Updates below 1.0.0](../../../../docs/workflows/docker-maintenance.md#updates-below-100) |
| Commits | Every commit is a verified commit by Dependabot |
| CI | Every required workflow has a `pull_request` run for the head commit that succeeded, no check failed, and CI was complete and quiet for 3 minutes |
| Merge | The PR is still open, on the same head commit, no draft and mergeable — the merge is pinned with `--match-head-commit` |

Every other outcome leaves the PR open with the job green and the reason as an annotation and in the job summary. The full, ordered list is the [decision table](../../../../docs/workflows/docker-maintenance.md#decision-table).

> **The merge starts no release.** It is made with the job's `GITHUB_TOKEN`, and GitHub starts no workflow for that push. The release follows with the next push to `main` that is not made by that token, or when the release workflow is run by hand — see [Limits](../../../../docs/workflows/docker-maintenance.md#limits).

## Related

- [Docker Base Image Monitor](../../../../docs/workflows/modules-docker-base-image-monitor.md) — rebuilds on floating tags (`stable`, `latest`) that Dependabot cannot track
- [Backup Round-Trip Test](../backup-roundtrip/README.md) — the PR gate of a Container-Solution stack
- [Renovate variant](../docker-maintenance-renovate/) — grouping and dashboards, with GitHub's native auto-merge
