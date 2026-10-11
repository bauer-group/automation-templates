# Docker Maintenance (Dependabot) — Examples

Callers of [`docker-maintenance-dependabot.yml`](../../../../.github/workflows/docker-maintenance-dependabot.yml): merge a Dependabot PR only after the CI you name has run on it and passed — no ruleset, no branch protection, no "Allow auto-merge" — and release the merged update by dispatching your release workflow. Despite the name, this works for every Dependabot ecosystem: base images, Compose files, npm, pip, Composer, Cargo, NuGet and the others.

Full reference: [`docs/workflows/docker-maintenance.md`](../../../../docs/workflows/docker-maintenance.md#option-1-dependabot-simple).

## Examples

| Example | Use case |
|---------|----------|
| [simple-dependabot-maintenance.yml](simple-dependabot-maintenance.yml) | Smallest caller: Dockerfile updates, one PR CI workflow, the same workflow dispatched as the release after the merge |
| [with-backup-roundtrip-gate.yml](with-backup-roundtrip-gate.yml) | Container stack: merged only after the PR run of `docker-release.yml` — image builds and the [backup round trip](../backup-roundtrip/gated-release-pipeline.yml) — passed; then released by the same pipeline, which publishes only after its round trip on `main` passed |
| [own-build-and-test-workflow.yml](own-build-and-test-workflow.yml) | Image without a backup sidecar: the repository's own `ci.yml` vouches, a separate `release.yml` publishes; Docker and npm updates both let through, caller without `paths:` |
| [multiple-required-workflows.yml](multiple-required-workflows.yml) | Image build and a separate test suite: both have to run on the PR and pass |
| [all-ecosystems.yml](all-ecosystems.yml) | Docker, Compose, npm, pip, Composer, Cargo and NuGet: caller without `paths:`, one `ci.yml` builds and tests all of them — what it does not build stays open as "not tested" |
| [dotnet-library.yml](dotnet-library.yml) | .NET library: NuGet and SDK updates tested by `dotnet build`, `dotnet test` and `dotnet pack`; `chore(deps)` so that no update publishes a package |
| [no-pr-ci-manual-merge.yml](no-pr-ci-manual-merge.yml) | No PR CI yet: `required-workflows` deliberately unset — nothing is merged, every PR is reported for review |

## Setup

1. **Let Dependabot open the PRs.** Copy [`.github/config/docker-maintenance-dependabot/dependabot.yml`](../../../../.github/config/docker-maintenance-dependabot/dependabot.yml) to `.github/dependabot.yml` and keep `commit-message.prefix: "fix(docker)"`, so a merged update releases a patch version. Add one `updates:` entry per further ecosystem ([all-ecosystems.yml](all-ecosystems.yml) has one for each): `fix(deps)` in an application, `chore(deps)` in a library unless every update should publish a package — see [Other ecosystems and libraries](../../../../docs/workflows/docker-maintenance.md#other-ecosystems-and-libraries). Internal or private registries and feeds need Dependabot's own secrets — see the comment in that file.
2. **Name the CI that vouches for an update** in `required-workflows`: the workflow files whose `pull_request` run builds and tests what Dependabot changes. Not this caller, not a notification, labeler or scan job — they pass on every PR without testing anything. Several listed workflows are an AND: each has to run on the PR and pass, so list only workflows that run for every update that should be merged — see [Several required workflows](../../../../docs/workflows/docker-maintenance.md#several-required-workflows-every-one-must-run-and-pass).
3. **Choose the trigger scope.** The caller's `on.pull_request.paths` decide which Dependabot PRs reach the workflow at all; a PR outside them stays open without any annotation. With more than the `docker` ecosystem, give the caller **no `paths:`**: every Dependabot PR then gets a decision and an annotation, and the required workflow's `pull_request` `paths:` decide what is tested — list a manifest and its lock file there only where that workflow builds them ([files per ecosystem](../../../../docs/workflows/docker-maintenance.md#files-per-ecosystem)). With base images only, the Dockerfiles are enough — see [Recommended trigger](../../../../docs/workflows/docker-maintenance.md#recommended-trigger).
4. **Grant the permissions** in the caller: `contents: write` and `pull-requests: write`, plus `checks: read`, `statuses: read` and `actions: read` in private repositories — `actions: write` instead of `actions: read` when `release-workflow` is set (step 8). The reusable workflow declares none of its own.
5. **Copy an example** to `.github/workflows/docker-maintenance.yml` and adjust `paths:`, `required-workflows` and `release-workflow`.
6. **Give the PR CI its secrets.** A Dependabot PR's CI runs with Dependabot secrets, not Actions secrets: credentials it needs (a private npm, NuGet or Composer feed, a registry login) belong under *Settings → Secrets and variables → Dependabot* as well, or it fails on every Dependabot PR and the PR stays open.
7. **Optional: let PRs on a moved base be rebased automatically.** Only the combination CI tested is merged; a PR whose base branch moved in the meantime is rebased and tested again. Dependabot refuses `@dependabot rebase` from the job token, so store a fine-grained token of a user with push access (*Pull requests: Read and write*) as the **Dependabot** secret `DEPENDABOT_REBASE_TOKEN` — see [The rebase token](../../../../docs/workflows/docker-maintenance.md#the-rebase-token). Without it such a PR waits for a person to comment `@dependabot rebase`.
8. **Release the merged update.** The merge is made with `GITHUB_TOKEN`, which starts no workflow. Set `release-workflow` to your release workflow (e.g. `.github/workflows/docker-release.yml`) and grant `actions: write`: after a merge — and only then — it is dispatched on the base branch, its run is linked in the job summary, and the job waits for it (`release-wait-minutes`, default 60). A run that does not succeed fails the job. The release workflow needs `on: workflow_dispatch`, must release on that event, must publish nothing unless its own build and tests passed (`needs:`), and must release the commit it tested (`ref: ${{ github.sha }}` on `modules-semantic-release.yml` — else a merge that lands during its run is tagged untested and missing from its image). A failure after its semantic release (the image push) still leaves a version without its image — loud, not prevented; see [What "no broken release" relies on](../../../../docs/workflows/docker-maintenance.md#what-no-broken-release-relies-on). On the first automatic merge, [check the dispatched release](../../../../docs/workflows/docker-maintenance.md#check-the-first-dispatched-release): its actor, its secrets and its result.

## What decides a merge

| Check | A PR is merged only if |
|-------|------------------------|
| Trigger | It changes a file in the caller's `paths:` (if it has any) and was opened by Dependabot, on an event Dependabot raised |
| CI change | It is no GitHub Actions update and changes no file under `.github/` |
| Required CI | `required-workflows` is set |
| Update type | The semver update type is in `merge-update-types` (default `patch`). Below 1.0.0 a minor update (`0.3.1 → 0.4.0`) and a patch update of `0.0.z` (`0.0.3 → 0.0.4`) count as major — every dependency of a grouped PR is checked, see [Updates below 1.0.0](../../../../docs/workflows/docker-maintenance.md#updates-below-100) |
| Commits | Every commit is a verified commit by Dependabot |
| CI | Every required workflow (all of them, not one) has a `pull_request` run for the head commit that succeeded, no check failed, and CI was complete and quiet for 3 minutes |
| Merge | The PR is still open, on the same head commit, no draft and mergeable — the merge is pinned with `--match-head-commit` |
| Tested base | The base branch is still at the commit CI tested the PR on. If it moved (another PR or a release commit landed first), the PR is rebased with `@dependabot rebase` and tested again — see [Only the combination CI tested](../../../../docs/workflows/docker-maintenance.md#only-the-combination-ci-tested) |

Every other outcome leaves the PR open with the job green and the reason as an annotation and in the job summary. The full, ordered list is the [decision table](../../../../docs/workflows/docker-maintenance.md#decision-table).

## After the merge

| `release-workflow` | What happens |
|--------------------|--------------|
| set (needs `actions: write`) | Dispatched on the base branch after the merge; the job summary shows *Merge → Release dispatched (run) → Release result*. The job fails if the dispatch is refused or the run does not conclude `success` within `release-wait-minutes` — see [Release outcomes](../../../../docs/workflows/docker-maintenance.md#release-outcomes) |
| not set | No release: the merge is made with `GITHUB_TOKEN`, and GitHub starts no workflow for that push. A release workflow on `push` runs with the next push to `main` that is not made by that token, or when it is run by hand — whether that releases the update depends on its commit type (`fix(...)` releases, `chore(deps)` does not by default) |

## Related

- [Docker Base Image Monitor](../../../../docs/workflows/modules-docker-base-image-monitor.md) — rebuilds on floating tags (`stable`, `latest`) that Dependabot cannot track
- [Backup Round-Trip Test](../backup-roundtrip/README.md) — the PR gate of a Container-Solution stack
- [Renovate variant](../docker-maintenance-renovate/) — grouping and dashboards, with GitHub's native auto-merge
