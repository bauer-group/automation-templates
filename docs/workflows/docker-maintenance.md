# Docker Image Maintenance

Automated Docker base image maintenance with automatic semantic releases.

| Solution | Complexity | Features | Best For |
|----------|------------|----------|----------|
| **Dependabot** | Simple | Native GitHub, no app install | Simple projects |
| **Renovate** | Advanced | Grouping, flexible rules | Complex projects |

## Quick Comparison

| Feature | Dependabot | Renovate |
|---------|------------|----------|
| App Installation | Not required | Required |
| PR Grouping | No (1 PR per image) | Yes |
| Schedule Options | Limited | Very flexible |
| Custom Rules | Basic | Advanced |
| Dependency Dashboard | No | Yes |

## Important: Semantic Release Compatibility

For automatic **PATCH** releases on base image updates, the commit message prefix must be `fix(docker)`:

| Commit Prefix | Semantic Release | Version Change |
|---------------|------------------|----------------|
| `fix(docker)` | PATCH | `1.0.0` → `1.0.1` |
| `chore(docker)` | No release | - |
| `feat(docker)` | MINOR | `1.0.0` → `1.1.0` |

Both configurations below use `fix(docker)` to ensure automatic releases.

### Other ecosystems and libraries

The same holds for every other ecosystem: the `commit-message` of each
`updates:` entry in `dependabot.yml` decides whether its merged update cuts a
release.

| Repository                                              | `commit-message` of the `updates:` entry                                                                                                                              | After the merge                                                  |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| Image or application - an update has to reach its users | `prefix: "fix(docker)"` for images (`docker`, `docker-compose`), `prefix: "fix(deps)"` for packages; `prefix-development: "chore(deps-dev)"` (npm, pip, uv, Composer) | PATCH release, image rebuilt                                     |
| Library - NuGet, npm, Composer or Cargo package         | `prefix: "chore(deps)"`, unless every update should publish a package                                                                                                 | No release - the update ships with the next `feat`/`fix` release |
| Any                                                     | `github-actions`: `prefix: "chore(ci)"`                                                                                                                               | No release - and never merged automatically                      |

A merged `fix(deps)` commit in a library publishes a new package for every
dependency update, and in a NuGet package it raises the minimum version every
consumer gets (a `PackageReference` version is a lower bound). Example:
[dotnet-library.yml](../../github/workflows/examples/docker-maintenance-dependabot/dotnet-library.yml).

Whether `chore(deps)` releases depends on the rules
`modules-semantic-release.yml` analyzes the commit with:

- **Default rules** (no `releaseRules` in
  `.github/config/release/semantic-release.json`, `force-release` off): no
  release.
- **Custom `releaseRules`**
  ([how they are read](semantic-release-config.md#what-is-read-from-your-config)):
  the rules decide. Every matching rule counts, in order, and a later match
  with `"release": false` overrides an earlier `"patch"`. This repository's
  own config has `{"type": "chore", "scope": "deps", "release": "patch"}`
  followed by `{"type": "chore", "release": false}`, so `chore(deps)`
  releases nothing here either. Only rules that leave `chore(deps)` at a
  release - the `chore`/`deps` patch rule without a later `chore` rule set to
  `false` - need another type that they do not release on, such as
  `build(deps)`.
- **`force-release: true`** (used only when the repository config has no
  `releaseRules`): every commit type releases, `chore(deps)` and
  `build(deps)` included.

---

## Complete Automation Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Dependabot or  │────▶│   Creates PR    │────▶│  Docker Build   │
│  Renovate Bot   │     │  fix(docker):   │     │  Validates PR   │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Docker Image   │◀────│ Semantic Release│◀────│  Auto-Merged    │
│  Push to GHCR   │     │  Creates PATCH  │     │  to main        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

With Dependabot, the merge is made with `GITHUB_TOKEN`, which starts no `push`
workflow. Set `release-workflow` and the workflow dispatches the release itself
after the merge and waits for its result - see
[Releasing the merged update](#releasing-the-merged-update).

---

## Option 1: Dependabot (Simple)

The simplest solution using GitHub's native Dependabot. Despite the name, it
merges Dependabot PRs of every ecosystem - base images, Compose files, npm,
pip, Composer, Cargo, NuGet and the others - see
[trigger scope](#3-decide-which-prs-reach-it-trigger-scope).

### Setup

#### 1. Create Dependabot Configuration

Create `.github/dependabot.yml` in your repository:

```yaml
version: 2
updates:
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "sunday"
      time: "06:30"
      timezone: "Etc/UTC"
    labels:
      - "dependencies"
      - "docker"
      - "automated"
    commit-message:
      prefix: "fix(docker)"
    open-pull-requests-limit: 5
```

Or copy the complete template from:
`.github/config/docker-maintenance-dependabot/dependabot.yml`

For every other ecosystem add an `updates:` entry of its own, with the commit
prefix from [Other ecosystems and libraries](#other-ecosystems-and-libraries) -
[all-ecosystems.yml](../../github/workflows/examples/docker-maintenance-dependabot/all-ecosystems.yml)
shows one for each.

#### 2. Create Maintenance Workflow

Create `.github/workflows/docker-maintenance.yml`:

```yaml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    # docker only: the Dockerfiles. With any other ecosystem in
    # dependabot.yml leave paths: out - see step 3.
    # Only files whose change also starts the required workflow - a PR that
    # does not start it stays open (not tested)
    paths:
      - 'Dockerfile'
      - 'src/Dockerfile'

permissions:
  contents: write       # merge
  pull-requests: write  # approve, read the PR
  checks: read          # check runs and suites - private repositories
  statuses: read        # commit statuses - private repositories
  actions: write        # dispatch the release; read workflow runs

jobs:
  maintenance:
    name: Auto-merge Dependabot PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      # The PR CI that builds and tests the update (empty: nothing is merged)
      required-workflows: .github/workflows/docker-release.yml
      # Dispatched after a merge - the merge itself starts no workflow
      release-workflow: .github/workflows/docker-release.yml
      merge-method: 'squash'
      auto-approve: true
      # merge-update-types: 'patch,minor'  # default: patch; below 1.0.0 a
      #                                    # minor update counts as major
    secrets: inherit
```

Without `release-workflow`, `actions: read` is enough; a release workflow on
`push` then runs with the next push to `main` that is not made with
`GITHUB_TOKEN`, or by hand.

#### 3. Decide which PRs reach it (trigger scope)

The workflow decides on Dependabot PRs of **every** ecosystem: an npm, pip,
Composer, Cargo or NuGet update goes through the same
[decision table](#decision-table) as a base image update. But it can only
decide on a PR whose event starts the calling workflow, so the caller's
`on.pull_request.paths` decide which Dependabot PRs reach it at all - before
any of the rules below apply.

##### Recommended trigger

| `dependabot.yml` updates                                                                       | Caller `paths:`           | Example                                                                                                                              |
|------------------------------------------------------------------------------------------------|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `docker` only (and `github-actions`, which is never merged automatically)                      | The Dockerfiles - or none | [simple-dependabot-maintenance.yml](../../github/workflows/examples/docker-maintenance-dependabot/simple-dependabot-maintenance.yml) |
| Any other ecosystem as well: `docker-compose`, `npm`, `pip`, `composer`, `cargo`, `nuget`, ... | **None**                  | [all-ecosystems.yml](../../github/workflows/examples/docker-maintenance-dependabot/all-ecosystems.yml)                               |

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    # No paths: - every Dependabot PR gets a decision and an annotation.
    # The required workflow's pull_request paths decide what is tested.
```

Why no `paths:` as soon as Dependabot updates more than base images:

- **Every Dependabot PR gets an explicit decision.** It is merged, or left
  open with an annotation and a job summary that say why. A PR outside the
  caller's `paths:` gets no run at all - no annotation, no summary - and
  waits unnoticed. One file the list misses (a `pnpm-lock.yaml` instead of a
  `package-lock.json`, a manifest in a subdirectory, a new ecosystem added to
  `dependabot.yml` later) silently turns automatic merging off for it.
- **Untested PRs stay open - visibly.** Whether an update is tested is
  decided where it belongs: by the `pull_request` `paths:` of the required
  workflow, which say what that workflow builds (see
  [Files per ecosystem](#files-per-ecosystem)). A PR it does not build stays
  open with *required workflow ... did not run for this change - not tested*,
  a GitHub Actions update with *GitHub Actions updates change the CI itself*.
- **It costs little.** The caller starts for every PR, but for a PR not
  opened by Dependabot its job is skipped at once - a skipped check, no
  runner time. A Dependabot PR that no required workflow tests is decided
  once CI is complete and quiet, 5 minutes after the start at the earliest.

With `paths:` (a repository that updates base images only):

- **A PR outside the caller's `paths:` never reaches the workflow.** No job
  runs, no annotation is written, no summary appears: the PR simply stays open
  until someone merges it by hand. Nothing tells you that it was not
  considered, so pick the paths on purpose.
- **Dockerfile-only paths mean: base image updates only.** An npm, pip or
  Composer update changes `package.json`/`package-lock.json`,
  `requirements*.txt`/`poetry.lock` or `composer.json`/`composer.lock` - not a
  Dockerfile - so it never starts the caller and stays a manual merge.
- **Keep them within the required workflow's paths.** A PR that reaches the
  caller but not the required workflow stays open with "did not run for this
  change - not tested".

| Caller `paths:` | Dependabot PR                                   | What happens                                                                                                            |
|-----------------|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `Dockerfile`    | `FROM` base image bump in `Dockerfile`          | Reaches the workflow - decided by the [decision table](#decision-table)                                                 |
| `Dockerfile`    | npm bump in `package.json` + lock file          | Caller does not start - PR stays open, no annotation, merge by hand                                                     |
| none            | npm bump in `package.json` + lock file          | Reaches the workflow - merged if a required workflow that builds these files ran and passed, else left open: not tested |
| none            | pip bump in a file no required workflow watches | Reaches the workflow - left open with "did not run for this change - not tested"                                        |
| none            | GitHub Actions bump in `.github/workflows/`     | Reaches the workflow - left open: a CI change is never merged automatically                                             |

The `pull_request` `types:` matter as well: keep `opened`, `synchronize`
(Dependabot rebased or updated the PR), `reopened` and `ready_for_review`, so
every new head commit gets its own decision.

##### Files per ecosystem

The files a Dependabot PR changes, by `package-ecosystem`. They are what the
required workflow's `pull_request` `paths:` have to match for the update to be
tested - and with Dockerfile-only caller `paths:`, what never reaches the
workflow. In `paths:`, prefix a name with `**/` to match it in every
directory, or name the directory from `dependabot.yml` (`'web/package.json'`).

| `package-ecosystem` | Manifest files                                                                                                                                                                     | Lock files                                                                |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `docker`            | `Dockerfile` and every file whose name contains it (`Dockerfile.prod`, `worker.Dockerfile`), `Containerfile`, Kubernetes manifests (`*.yaml`/`*.yml` with `apiVersion` and `kind`) | -                                                                         |
| `docker-compose`    | `docker-compose.yml`, `compose.yaml` and their variants (`docker-compose.override.yml`, `compose.prod.yaml`)                                                                       | -                                                                         |
| `npm`               | `package.json`                                                                                                                                                                     | `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `pnpm-lock.yaml` |
| `pip`               | `requirements*.txt` (any requirements `.txt`, `.in` for pip-compile), `pyproject.toml`, `Pipfile`, `setup.py`, `setup.cfg`                                                         | `poetry.lock`, `Pipfile.lock`                                             |
| `uv`                | `pyproject.toml`                                                                                                                                                                   | `uv.lock`                                                                 |
| `composer`          | `composer.json`                                                                                                                                                                    | `composer.lock`                                                           |
| `cargo`             | `Cargo.toml`                                                                                                                                                                       | `Cargo.lock`                                                              |
| `nuget`             | `*.csproj`, `*.fsproj`, `*.vbproj`, `Directory.Packages.props`, `Directory.Build.props`, `packages.config`, `global.json` (MSBuild SDKs), `.config/dotnet-tools.json`              | `packages.lock.json`                                                      |
| `dotnet-sdk`        | `global.json` (`sdk.version`)                                                                                                                                                      | -                                                                         |
| `gomod`             | `go.mod`                                                                                                                                                                           | `go.sum`                                                                  |
| `terraform`         | `*.tf`                                                                                                                                                                             | `.terraform.lock.hcl`                                                     |
| `github-actions`    | `.github/workflows/*.yml`, `action.yml`                                                                                                                                            | - (never merged automatically, no `paths:` needed)                        |

A PR may change only the lock file (an update of an indirect dependency), so
list both, the manifest and its lock file.

**Cover a file only where the workflow builds it.** Add a manifest and its
lock file to the `pull_request` `paths:` of a required workflow only if that
workflow's PR run builds or tests them:

- `package.json`/`package-lock.json` in the workflow that runs `npm ci` and
  the tests - or in the one that builds the image, if the Dockerfile runs
  `npm ci` in a build stage.
- `*.csproj`/`Directory.Packages.props` in the workflow that runs
  `dotnet build` and `dotnet test`; `global.json` only if it sets up the SDK
  from it (`global-json-file`).
- Compose files in the workflow that starts the stack from them (e.g. the
  backup round trip), not in one that only builds an image.

A run that does not use a file still passes, and that pass would merge an
update nothing exercised. An ecosystem no required workflow builds - Terraform
without a `terraform plan` on PRs, say - stays open as "not tested", which is
the honest outcome; review and merge such PRs by hand.

Ready-to-copy callers for each case are in
[`github/workflows/examples/docker-maintenance-dependabot/`](../../github/workflows/examples/docker-maintenance-dependabot/).

#### 4. Name the PR CI that must pass

Nothing else to configure - no ruleset, no branch protection, no "Allow auto-merge".
The workflow waits for the CI of the PR itself and merges only when every
workflow listed in `required-workflows` has run on the PR and passed. With
`required-workflows` empty (the default) it merges **nothing** and leaves each
PR open with a notice that says how to set it. A passed check alone proves
nothing: secret scans, notification and labeler jobs pass on every PR
without building anything.

##### Choosing `required-workflows`

List the workflow files - as paths such as `.github/workflows/docker-release.yml`,
comma or newline separated - whose `pull_request` run builds and tests what
Dependabot changes:

- **The build and test of the image**, e.g. the `docker-release.yml` that
  builds the PR with `docker-build.yml` (`push: false`). Where its PR run
  includes the backup round trip, the round trip is part of what must pass.
- **Every other workflow that has to vouch for the update**, e.g. a separate
  test workflow. Every listed workflow must pass.
- **Not** this caller workflow, a notification, labeler or summary workflow,
  and not one that runs only on `push`, `pull_request_target` or
  `workflow_run`: only `pull_request` runs of the PR's own branch count.
- **Built from the merge ref.** A `pull_request` run checks out
  `refs/pull/<n>/merge` by default: the PR head merged onto the base branch,
  the combination the [tested-base check](#only-the-combination-ci-tested)
  vouches for. A required workflow that checks out the PR head instead
  (`actions/checkout` with `ref: ${{ github.event.pull_request.head.sha }}`)
  tests the update on the head's own parent, which may be an older base. Keep
  the default checkout in required workflows - the reusable build, compose
  validation and backup round trip workflows of this repository use it.

The required workflow must start for every file this caller's `paths:` lists,
so keep the caller's `paths:` within the required workflow's `pull_request`
`paths:`. Without caller `paths:` the required workflow's own `paths:` decide
alone. A Dependabot PR that changes a file the required workflow does not
watch stays open with "did not run for this change - not tested" - nothing
tested it.

##### Several required workflows: every one must run and pass

`required-workflows` is an AND, not an OR: a PR is merged only if **every**
listed workflow has a `pull_request` run for its head commit that succeeded.
A listed workflow that did not run - its `paths:` miss the changed files -
leaves the PR open, even when all the others passed. With several ecosystems
this decides which updates can be merged at all.

Example: an image whose Dockerfile builds a web frontend with `npm ci`, and a
Python test suite in `tests/`. The caller has no `paths:` and requires both
workflows:

```yaml
required-workflows: |
  .github/workflows/docker-release.yml
  .github/workflows/tests.yml
# docker-release.yml - pull_request paths: Dockerfile, package.json, package-lock.json, src/**
# tests.yml          - pull_request paths: tests/**, requirements-dev.txt, src/**
```

| Dependabot PR | Changed files                       | `docker-release.yml` | `tests.yml`  | Outcome                                                                  |
|---------------|-------------------------------------|----------------------|--------------|--------------------------------------------------------------------------|
| `docker`      | `Dockerfile`                        | runs                 | does not run | Left open: `tests.yml` did not run for this change - not tested          |
| `npm`         | `package.json`, `package-lock.json` | runs                 | does not run | Left open: `tests.yml` did not run for this change - not tested          |
| `pip`         | `requirements-dev.txt`              | does not run         | runs         | Left open: `docker-release.yml` did not run for this change - not tested |

No Dependabot PR starts both workflows, so none is ever merged. Two ways out:

1. **One required workflow that builds and tests everything** - a `ci.yml`
   whose `pull_request` `paths:` list every manifest and lock file it builds.
   Each ecosystem it builds merges once it passed, every other one stays open
   as "not tested". See
   [all-ecosystems.yml](../../github/workflows/examples/docker-maintenance-dependabot/all-ecosystems.yml).
2. **Let each listed workflow start for the ecosystems that should merge -
   only where it builds them.** If `tests.yml` builds the image and runs the
   tests against it, add `Dockerfile`, `package.json` and `package-lock.json`
   to its `paths:`: docker and npm updates then start both workflows and are
   merged when both passed. `docker-release.yml` does not install
   `requirements-dev.txt`, so it gets no path for it, and the pip update stays
   open for review.

A workflow that is **not** listed still counts when it runs: if it fails, the
PR stays open (row 11 of the [decision table](#decision-table)). Listing it
only adds the demand that it runs - so list the workflows that run for every
Dependabot PR that should be merged, and no others.

Keep **one caller per repository**. One caller per ecosystem, each with its
own `required-workflows`, does not make an OR either: the job's concurrency
group is per PR (`docker-maintenance-dependabot-pr-<number>`), so callers
started by the same PR cancel each other and the last one decides alone.

A PR that changes CI is never merged automatically, whatever
`required-workflows` says: a GitHub Actions update
(`package-ecosystem: "github-actions"`) and any PR that changes a file under
`.github/`. A `pull_request` run uses the PR's own version of a changed
workflow, so it would vouch for itself, and a changed workflow that runs only
on `push` or `schedule` does not run before the merge at all. Such PRs stay
open with a notice; review and merge them by hand. A caller that only handles
GitHub Actions updates (e.g. filtered on `.github/workflows/**`) merges
nothing.

An existing caller of this workflow merges nothing until it sets
`required-workflows`; in private repositories it also needs the three read
permissions below.

##### Common setups

| Repository                                                                                                           | `required-workflows`                                                     | Example                                                                                                                          |
|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| Container stack whose release pipeline runs the backup round trip on PRs                                             | `.github/workflows/docker-release.yml`                                   | [with-backup-roundtrip-gate.yml](../../github/workflows/examples/docker-maintenance-dependabot/with-backup-roundtrip-gate.yml)   |
| Image without a backup sidecar, own build and test workflow                                                          | `.github/workflows/ci.yml`                                               | [own-build-and-test-workflow.yml](../../github/workflows/examples/docker-maintenance-dependabot/own-build-and-test-workflow.yml) |
| Image build and a separate test suite, both must pass                                                                | `.github/workflows/docker-release.yml` and `.github/workflows/tests.yml` | [multiple-required-workflows.yml](../../github/workflows/examples/docker-maintenance-dependabot/multiple-required-workflows.yml) |
| Several ecosystems (docker, Compose, npm, pip, Composer, Cargo, NuGet), one CI workflow builds and tests all of them | `.github/workflows/ci.yml`, caller without `paths:`                      | [all-ecosystems.yml](../../github/workflows/examples/docker-maintenance-dependabot/all-ecosystems.yml)                           |
| .NET library published to NuGet, `dotnet build` and `dotnet test` on PRs                                             | `.github/workflows/ci.yml`                                               | [dotnet-library.yml](../../github/workflows/examples/docker-maintenance-dependabot/dotnet-library.yml)                           |
| No PR CI at all (yet)                                                                                                | leave unset - nothing is merged, every PR gets a notice                  | [no-pr-ci-manual-merge.yml](../../github/workflows/examples/docker-maintenance-dependabot/no-pr-ci-manual-merge.yml)             |

Leaving `required-workflows` unset is a deliberate choice, not a
misconfiguration, when no workflow builds and tests the PR: the job then
records every Dependabot PR in its summary and leaves it for review. Merging
"because nothing failed" would merge updates nothing has tested.

#### Permissions

The workflow declares no permissions of its own, so the job token has exactly
what the calling workflow grants. A reusable workflow can only narrow its
caller's permissions: declaring the read scopes itself would make GitHub refuse
to start every caller that does not grant them.

| Permission             | Used for                                                                                        | Public repository | Private repository                                                        |
|------------------------|-------------------------------------------------------------------------------------------------|-------------------|---------------------------------------------------------------------------|
| `contents: write`      | merging the PR                                                                                  | required          | required                                                                  |
| `pull-requests: write` | approving; reading the PR                                                                       | required          | required                                                                  |
| `checks: read`         | check runs and check suites of the head commit                                                  | not needed        | required - without it every PR stays open with a notice                   |
| `statuses: read`       | commit statuses of the head commit                                                              | not needed        | required - without it every PR stays open with a notice                   |
| `actions: read`        | workflow runs of the head commit - whether the required workflows passed                        | not needed        | required - without it every PR stays open with a notice                   |
| `actions: write`       | with `release-workflow`: dispatching the release and reading its run (includes `actions: read`) | required          | required - without it the merged update is not released and the job fails |

Public repositories need none of the three read scopes because their CI results
are public; probed with a job token that had only `contents` and
`pull-requests`, which read check runs, check suites, statuses and workflow
runs in a public repository and got HTTP 403 for all of them in private ones.
Granting the read scopes in public repositories as well does no harm and keeps
the workflow working if the repository is made private.

`actions: write` is needed only with `release-workflow`, and replaces
`actions: read` there. Starting a workflow is a write in every repository,
public or private. A caller that sets `release-workflow` without granting it
gets its PRs merged and the job then fails with *Release not started: ... grant
'actions: write' in the calling workflow's permissions* - the merged update
waits for the next release.

> Rulesets with required status checks are **not** the way to gate this:
> GitHub Actions cannot be a ruleset bypass actor, so such a ruleset on `main`
> also blocks semantic-release, which pushes the release commit with the
> `GITHUB_TOKEN`.

### How Merging Works

The job runs only for PRs opened by `dependabot[bot]`, and only on events
Dependabot raised (it opened the PR or pushed to it): a person pushing to the
branch never starts a merge. Every commit of the PR must be a verified commit
by `dependabot[bot]`; `dependabot/fetch-metadata` checks only the first one.
Nothing from the PR is checked out or run, and PR data reaches the scripts
only through environment variables.

A maintainer may re-run the job, e.g. after CI was fixed by a re-run. A re-run
keeps the actor and the privileges of the first run and replays its event, so
it can only merge that event's head commit - and only while it is still the
PR's head. A re-run of a job that already merged the PR finds it merged: it
warns *Dependabot PR already merged* and neither merges nor releases (see
[Release After a Dependabot Merge Failed](#release-after-a-dependabot-merge-failed)).

1. **No CI change** - a GitHub Actions update stays open at once. So does
   any PR with a changed file under `.github/` - also the old path of a file
   moved out of it - or whose changed files cannot be listed in full (none,
   or GitHub's maximum of 3000); the files are read before the wait starts.
   Its CI cannot vouch for such a PR (see
   [Choosing `required-workflows`](#choosing-required-workflows)).
2. **Required workflows set** - with `required-workflows` empty nothing is
   merged: the job ends at once with a notice, without waiting for CI.
3. **Update type** - only the semver types in `merge-update-types` are merged
   (default `patch`). A `minor` or `major` update, or one whose type cannot be
   determined (digest, non-semver tag), stays open for review. The redpanda
   `26.1 → 26.2` bump that took a production stack down was a semver-*minor*.
   Below 1.0.0 any update may break: a minor update of a `0.y.z` version and
   a patch update of a `0.0.z` version count as `major`, checked for every
   dependency of the PR - see [Updates below 1.0.0](#updates-below-100).
4. **Wait for CI** - the job polls the check runs, check suites, commit
   statuses and workflow runs of the PR head commit (every 30 s, after 5 min
   every 60 s, after 15 min every 3 min), leaving out its own job and other
   runs of this workflow. It waits while anything is pending - a queued
   workflow run, one whose later jobs have not been created yet, a running
   job, a pending status. It decides only on a **complete and quiet** state:
   no earlier than 5 min after it started, and only after nothing has changed
   for 3 min. A check that appears late - a workflow GitHub starts with a
   delay, a code scanning result posted after its analysis job - restarts the
   quiet period and is waited for. A cancelled workflow run counts as failed,
   unless a newer run of the same workflow exists for the same commit (its
   concurrency group replaced it).
5. **Required workflows passed** - on that complete and quiet state, every
   workflow in `required-workflows` must have a run for the PR's head commit,
   triggered by `pull_request` on a branch of this repository (not a fork PR
   on the same commit), whose latest attempt concluded `success`; of several
   such runs (e.g. after `reopened`) the newest counts. A required workflow
   that did not run - its `paths:` do not match the changed files - or that
   concluded `skipped` (all of its jobs were skipped) or `neutral` leaves the
   PR open: it was not tested. Other checks that passed do not replace it.
6. **Merge** - only when, in addition, no check failed. `neutral` and
   `skipped` checks are no failure (as for required status checks). Right
   before the merge the PR is read again: if it was closed, got a new head
   commit, was turned into a draft or cannot be merged (a conflict) in the
   meantime, it is not merged. Then the PR is approved (if `auto-approve` is
   on) and merged with `gh pr merge --match-head-commit`, so only the commit
   whose CI was checked can be merged. The approval names that commit too:
   approving without it would approve whatever commit is the PR's latest at
   that moment. Where GitHub Actions may not approve pull requests (an org or
   repo setting), the rejected approval is a notice and the merge goes ahead;
   it only fails if the base branch requires a review. After the merge call
   the PR is read back: only a PR that GitHub reports as merged counts (`gh`
   also succeeds when it only added the PR to a merge queue).
7. **Tested base** - last, right before the merge call, the head of the base
   branch is read. It must still be the commit CI tested the PR on - see
   [Only the combination CI tested](#only-the-combination-ci-tested). If it
   has moved, the PR is not merged and Dependabot is asked to rebase it.
8. **Release** - with `release-workflow` set, and only after this run merged
   the PR, the release workflow is dispatched on the base branch and the job
   waits for its run - see
   [Releasing the merged update](#releasing-the-merged-update).

#### Decision table

The rules are checked in this order; the first one that applies decides. Every
outcome other than a merge leaves the PR **open** with the job green, the
decision as an annotation and in the job summary (with the checks seen on the
head commit). Only invalid inputs - and, after a merge, a release that was
not started or did not succeed ([release outcomes](#release-outcomes)) - turn
the job red.

| #   | Stage            | Situation                                                                                                                                 | Outcome                               | Annotation |
|-----|------------------|-------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------|------------|
| 1   | Trigger          | The PR changes no file in the caller's `on.pull_request.paths` ([trigger scope](#3-decide-which-prs-reach-it-trigger-scope))              | Caller does not run - PR stays open   | none       |
| 2   | Job filter       | PR not opened by `dependabot[bot]`, or the event was raised by someone else (a person pushed to the branch)                               | Job skipped - PR stays open           | none       |
| 3   | Inputs           | `merge-method`, `ci-wait-minutes`, `merge-update-types` or `required-workflows` is invalid                                                | ❌ Job fails                          | error      |
| 4   | Ecosystem        | GitHub Actions update (`package-ecosystem: "github-actions"`)                                                                             | ⏸️ Left open - a CI change            | notice     |
| 5   | Required CI      | `required-workflows` is not set - automatic merging is off                                                                                | ⏸️ Left open, without waiting for CI  | notice     |
| 6   | Update type      | Type unknown (digest, non-semver tag), or not in `merge-update-types` ([0.x updates](#updates-below-100) count stricter)                  | ⏸️ Left open for review               | notice     |
| 6a  | Update type      | The versions of the updated dependencies cannot be read, so the [0.x rule](#updates-below-100) cannot be checked                          | ⏸️ Left open for review               | notice     |
| 7   | PR state         | The PR was closed or got a new head commit meanwhile (checked on every poll)                                                              | ⏹️ Not merged by this run             | notice     |
| 7a  | PR state         | The PR was merged before this run decided - by hand, or by the first attempt of a job that is re-run                                      | ⏹️ Not merged by this run, no release | warning    |
| 8   | Commits          | Not every commit of the PR is a verified commit by Dependabot                                                                             | ⏸️ Left open                          | notice     |
| 9   | Changed files    | A changed file under `.github/` (also the old path of a moved file), or the file list is not complete                                     | ⏸️ Left open - a CI change            | notice     |
| 10  | Permissions      | CI results not readable (private repo without `checks`/`statuses`/`actions: read`)                                                        | ⏸️ Left open                          | notice     |
| 11  | CI result        | A check failed, was cancelled, timed out, needs action, went stale or could not start (`startup_failure`) - decided as soon as it is seen | ⏸️ Left open                          | notice     |
| 12  | CI wait          | CI not finished and quiet after `ci-wait-minutes`                                                                                         | ⏸️ Left open                          | notice     |
| 13  | CI wait          | CI results could not be read after three API errors in a row                                                                              | ⚠️ Left open                          | warning    |
| 14  | Required CI      | A required workflow did not run for this change, ran only for a fork, or concluded `skipped`/`neutral`                                    | ⏸️ Left open - not tested             | notice     |
| 15  | Before the merge | The PR could not be read again right before the merge                                                                                     | ⚠️ Left open                          | warning    |
| 16  | Before the merge | The PR is a draft or cannot be merged (e.g. a conflict - Dependabot rebases it)                                                           | ⏸️ Left open                          | notice     |
| 17  | Approval         | `auto-approve` is on, but GitHub Actions may not approve PRs here                                                                         | Merge goes ahead without the approval | notice     |
| 17a | Tested base      | The base branch moved since CI ran, or the PR's base branch was changed ([tested combination](#only-the-combination-ci-tested))           | 🔄 Left open - rebase requested       | notice     |
| 17b | Tested base      | As 17a, without [`DEPENDABOT_REBASE_TOKEN`](#the-rebase-token): no command is posted, the notice asks a person to comment it              | 🔄 Left open - rebase not requested   | notice     |
| 17c | Tested base      | As 17a, but posting `@dependabot rebase` with the token failed (expired, revoked, missing permission)                                     | ⚠️ Left open - rebase not requested   | warning    |
| 17d | Tested base      | The head of the base branch could not be read                                                                                             | ⚠️ Left open                          | warning    |
| 18  | Merge            | The merge was rejected (e.g. the base branch requires a review)                                                                           | ⚠️ Left open                          | warning    |
| 18a | Merge            | The merge call succeeded, but the PR reads back as not merged (a merge queue only queued it)                                              | ⚠️ Not merged by this run, no release | warning    |
| 18b | After the merge  | A push landed on the base branch in the moment between the base check and the merge call                                                  | ✅ Merged - onto an untested base     | warning    |
| 18c | After the merge  | The PR could not be read back after the merge call: `gh` reported the merge, the merge commit is unknown                                  | ✅ Merged - merge commit unknown      | warning    |
| -   | -                | None of the above: every required workflow passed, no check failed, CI complete and quiet, base unchanged                                 | ✅ Merged (`--match-head-commit`)     | -          |

A newer event on the same PR (e.g. Dependabot rebased it) cancels the run that is
still waiting; the run for the new head commit decides.

#### Only the combination CI tested

A `pull_request` run does not test the PR's branch alone: it tests
`refs/pull/<n>/merge`, the PR head merged onto the base branch **as it was
when the event fired** (the event's `pull_request.base.sha`, the first parent
of that merge commit). Every required workflow run of the event, and every
re-run of it, tested that one combination. Merging after the base branch has
moved would put a combination on `main` that no CI ran on.

So the workflow reads the head of the base branch last - after the approval,
immediately before the merge call - and merges only if it is still that
commit. Otherwise the PR stays open (job green, reason `base-moved`) and
Dependabot is asked to rebase it:

| The base branch moved because ...                                      | What happens                                                                                                                                                                                                                                                               |
|------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| an unrelated push landed on `main` while CI ran                        | Not merged. `@dependabot rebase` - the rebased PR is a new head commit, CI runs on it, and its run of this workflow decides again                                                                                                                                          |
| another Dependabot PR was merged first (two PRs opened together)       | The first one is merged; the second is not - it was tested without the first. It is rebased onto the first one's merge commit and tested again                                                                                                                             |
| a release run pushed its `chore(release)` commit after the first merge | Same: the next PR is rebased and tested again - each Dependabot update lands on `main` exactly as CI tested it                                                                                                                                                             |
| someone changed the PR's base branch                                   | Not merged; the rebase onto the new base branch is tested again                                                                                                                                                                                                            |
| a push lands in the second between the check and the merge call        | Merged - GitHub's merge call pins the head, not the base. A warning *Merged onto an untested base* names the base; the release run builds and tests that merge before it publishes - if its release is [pinned to the commit it tested](#what-no-broken-release-relies-on) |

This relies on the required workflows building that merge commit: see
*Built from the merge ref* under
[Choosing `required-workflows`](#choosing-required-workflows).

The command is posted **once per head commit**: a `@dependabot rebase` or
`@dependabot recreate` comment made after the head commit was created counts
as pending, and no second one is posted - if its author is the repository's
owner, an organization member or a collaborator (`author_association`
`OWNER`, `MEMBER` or `COLLABORATOR`): a person, or the rebase token's user in
an earlier run of this workflow. Dependabot refuses commands from anyone
without push access, so an outsider's comment on a public repository, or one
by `github-actions[bot]`, does not count and the command is posted all the
same. A member or collaborator with read access only counts as well; if
Dependabot refused their command, comment `@dependabot rebase` yourself.

##### The rebase token

Dependabot takes commands only from users with push access. A comment made
with the job's `GITHUB_TOKEN` is authored by `github-actions[bot]`, and
Dependabot answers it with *Sorry, only users with push access can use that
command* - the PR would never be rebased. The workflow therefore posts the
command with the optional secret `DEPENDABOT_REBASE_TOKEN`:

| What              | Setting                                                                                                                                                                                                                               |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Token             | Fine-grained personal access token of a user (or machine user) with push access to the repository                                                                                                                                     |
| Repository access | The repositories whose Dependabot PRs it rebases                                                                                                                                                                                      |
| Permissions       | *Pull requests: Read and write* - it posts one comment (GitHub's permission reference lists that endpoint under *Issues: write* as well; whether that alone suffices on a pull request is not verified here)                          |
| Where to store it | **Dependabot secret** `DEPENDABOT_REBASE_TOKEN` (*Settings → Secrets and variables → Dependabot*, or at the organization). A Dependabot PR's workflows see Dependabot secrets only - an Actions secret of that name stays empty there |
| How it is passed  | `secrets: inherit` in the caller, as in every example; or explicitly: `secrets: DEPENDABOT_REBASE_TOKEN: ${{ secrets.DEPENDABOT_REBASE_TOKEN }}`                                                                                      |

The token is used for that one comment and nothing else; the merge, the
approval and every read use the job token. Without it, a PR whose base moved
stays open with the notice *Comment '@dependabot rebase' on the PR to have it
tested again* - a person with push access comments it, and the rebased PR is
merged automatically once its CI passed.

**Keep the token narrow.** *Pull requests: write* is more than a comment: it
also submits reviews, and an approval by a user with push access counts
toward required reviews. So:

- issue it to a **dedicated machine user**, not to a person's account;
- limit it to **only the selected repositories** whose Dependabot PRs it
  rebases, with no other permission;
- give it a **short expiry** and renew it - an expired token shows as the
  warning *rebase could not be requested*, never as a merge.

#### Updates below 1.0.0

[SemVer 4](https://semver.org/#spec-item-4): a `0.y.z` version is initial
development - anything may change at any time. Dependabot still reports
`0.3.1 → 0.4.0` as semver-*minor* and `0.0.3 → 0.0.4` as semver-*patch*, so a
caller that merges `minor` updates would merge a breaking 0.x release. The
workflow therefore counts update types the way npm's caret ranges do
(`^0.3.1` allows `< 0.4.0`, `^0.0.3` allows `< 0.0.4`):

| Previous version       | New version            | Dependabot reports | Counted as  | Why                                            |
|------------------------|------------------------|--------------------|-------------|------------------------------------------------|
| `0.3.1`                | `0.3.2`                | patch              | patch       | within `^0.3.1` - unchanged                    |
| `0.3.1`                | `0.4.0`                | minor              | **major**   | 0.x minor treated as major                     |
| `0.0.3`                | `0.0.4`                | patch              | **major**   | 0.0.x patch treated as major                   |
| `0.0.3`                | `0.1.0`                | minor              | **major**   | 0.x minor treated as major                     |
| `0.9.2`                | `1.0.0`                | major              | major       | unchanged                                      |
| `1.2.3`                | `1.3.0`                | minor              | minor       | 1.0.0 or later - unchanged                     |
| `v0.3.1`               | `v0.4.0`               | minor              | **major**   | a leading `v` is read                          |
| `0.3.1-rc.1`           | `0.4.0+build.7`        | minor              | **major**   | a pre-release or build suffix is read          |
| `0.3.1-alpine3.20`     | `0.4.0-alpine3.20`     | minor              | **major**   | an image variant reads as a pre-release suffix |
| `0.3-alpine`           | `0.4-alpine`           | minor              | minor       | not `X.Y.Z` - the reported type counts         |
| `18-alpine`            | `19-alpine`            | major              | major       | not `X.Y.Z` - the reported type counts         |
| `2024-01-15`, a digest | `2024-02-01`, a digest | as reported        | as reported | not `X.Y.Z` - the reported type counts         |

- **Only plain `X.Y.Z` versions are read**, both the previous and the new
  one: three numbers without leading zeros, optionally a leading `v`, a
  `-pre-release` and a `+build` suffix. Any other version keeps the update
  type Dependabot reported - it never fails the job.
- **The previous version decides** whether the rule applies: `0.y.z` turns a
  minor update into a major one, `0.0.z` a patch update as well. A patch
  update of `0.y.z` with `y > 0` stays a patch.
- **Every dependency of the PR is checked** - the `updated-dependencies-json`
  of `dependabot/fetch-metadata` lists each with its own versions and update
  type. In a grouped update the strictest dependency decides: one
  `0.3.1 → 0.4.0` among ten patch updates makes the PR a major update.
- **Logged**: each dependency counted as major gets a line such as
  `0.x minor treated as major: lib 0.3.1 -> 0.4.0`; the notice of a PR left
  open and the job summary (*Update Type*) name it as well.
- **Versions not readable** (no `jq` on the runner, unexpected output of
  `fetch-metadata`): the PR is **left open** with a notice, reason
  `versions-unreadable`. Without the versions the rule cannot be checked, and
  a merge gate does not merge what it could not check. The job does not fail.

What this means for `merge-update-types`:

| `merge-update-types` | `0.3.1 → 0.3.2` | `0.3.1 → 0.4.0`           | `0.0.3 → 0.0.4`           |
|----------------------|-----------------|---------------------------|---------------------------|
| `patch` (default)    | merged          | left open                 | left open (merged before) |
| `patch,minor`        | merged          | left open (merged before) | left open (merged before) |
| `patch,minor,major`  | merged          | merged                    | merged                    |

"Merged" always means: after the required CI passed, as for every other
update.

**Example.** A caller with `merge-update-types: 'patch,minor'`; Dependabot
updates an image tag from `0.3.1` to `0.4.0`. The guard's log reads:

```text
Merged update types: patch minor
Required workflows: .github/workflows/docker-release.yml
Ecosystem: docker, update type: version-update:semver-minor
0.x minor treated as major: example/tool 0.3.1 -> 0.4.0
Decision: ok=false reason=update-type
```

The PR stays open with the notice *semver-major update (0.x minor treated as
major: example/tool 0.3.1 -> 0.4.0) - left open for review. Merged
automatically: patch minor (input merge-update-types).* Review the release
notes and merge it by hand, or add `major` to `merge-update-types` to let the
required CI decide such updates as well.

### Releasing the merged update

The merge is made with the job's `GITHUB_TOKEN`, and GitHub starts no workflow
run for a push made with that token - so a release workflow on `push` to `main`
never sees a Dependabot merge. `workflow_dispatch` is exempt from that rule.
With `release-workflow` set, the workflow therefore starts the release itself:

1. **Only after a merge.** The release is dispatched only when this run merged
   the PR and read it back as merged - never for a PR left open, closed,
   superseded, on a moved base, only added to a merge queue, or whose merge
   failed, and never for a CI change (those are never merged).
2. **Dispatch** of `release-workflow` with `workflow_dispatch` on the PR's base
   branch (`main`), with the job token - three attempts at most, and never a
   second release run:
   - a **rate limit** refused the request, so no run exists: retried;
   - after a **server or network error** the run may exist all the same
     (GitHub created it, the answer was lost): the workflow first looks for
     it, uses it if it is there, and dispatches again only if it is not;
   - an **HTTP 422** is tried once more without `return_run_details` (a
     GitHub that does not know the parameter); a second 422 means the
     workflow cannot be dispatched;
   - **HTTP 403 and 404** are final.
3. **Find the run.** GitHub answers the dispatch with the run it created
   (`return_run_details`). A GitHub that answers without it (HTTP 204) or does
   not know the parameter gets the run looked up for up to 2 minutes: a
   `workflow_dispatch` run of that workflow on the base branch, created since
   the dispatch, whose commit is the merge commit. Its URL goes into the job
   summary and the `release-run-url` output.
4. **Wait** up to `release-wait-minutes` (default 60, at most 180) for the run
   to complete - every 30 s, after 10 min every 60 s. `0` dispatches and
   reports the run without waiting for it.
5. **Judge it.** Only the conclusion `success` keeps the job green. Every
   other one - `failure`, `cancelled`, `timed_out`, `startup_failure`,
   `action_required`, `skipped`, `neutral` - and a run still going at the
   deadline fail the job with an error annotation that names the run. A broken
   release is loud, never silent.

The job summary shows the chain, for example:

| Step                   | Result                                                      |
|------------------------|-------------------------------------------------------------|
| **Merge**              | ✅ Merged into `main` as `3f9c2a1b7d40`                     |
| **Release dispatched** | `.github/workflows/docker-release.yml` on `main` - run link |
| **Release result**     | ✅ Succeeded                                                |

#### Release outcomes

| Situation                                                                                | Job      | Annotation                                                               |
|------------------------------------------------------------------------------------------|----------|--------------------------------------------------------------------------|
| The release run concluded `success`                                                      | ✅ green | -                                                                        |
| `release-wait-minutes: 0` - dispatched, run linked, not waited for                       | ✅ green | notice *Release started*                                                 |
| Dispatch refused: no `actions: write` (HTTP 403)                                         | ❌ fails | error *Release not started*                                              |
| Dispatch refused: no `workflow_dispatch` trigger, or the workflow is disabled (HTTP 422) | ❌ fails | error *Release not started*                                              |
| Dispatch refused: the file does not exist on the base branch (HTTP 404)                  | ❌ fails | error *Release not started*                                              |
| Dispatch failed three times (server error, rate limit), and no run of it was found       | ❌ fails | error *Release not started*                                              |
| The run was not found within 2 min                                                       | ❌ fails | error *Release not confirmed* (a warning with `release-wait-minutes: 0`) |
| The run concluded anything but `success`                                                 | ❌ fails | error *Release failed*                                                   |
| The run had not completed after `release-wait-minutes`                                   | ❌ fails | error *Release not finished*                                             |
| The run could not be read five times in a row                                            | ❌ fails | error *Release not confirmed*                                            |

In every failed case the update **is merged** - only its release is missing
or broken. Fix the cause, then re-run the release run's failed jobs; if no
release run was started or it failed before its release job, running the
release workflow by hand works as well. The next release ships the update in
any case.

#### What "no broken release" relies on

This workflow decides what is merged, and makes a release that fails loud:
the job turns red and names the run. What is **published** - and whether a
failure can leave something half published - is decided by the release
workflow. With a pipeline like the one below, it depends on where the run
fails - and on whether its release is pinned to the commit it tested:

| The release run ...                                                                                                                  | Published                                                                                                                  |
|--------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| fails before its release job - a build, test or backup round trip job the release job `needs:`                                       | **nothing**                                                                                                                |
| fails in the release job (semantic-release) or after it - the image rebuild and push (registry error, build error, a secret missing) | the version tag, the GitHub release and the release commit may exist **without the image**                                 |
| succeeds, but a push landed on `main` while it was going - release pinned to the tested commit (`ref: ${{ github.sha }}`)            | **nothing by this run**: semantic-release sees `main` ahead of it; the run that tested the newer `main` releases both      |
| succeeds, but a push landed on `main` while it was going - release **not** pinned                                                    | a version tagged on the newer `main`, its image built from the older commit without the later change - **silently broken** |

The last row is why the release has to be pinned (see *Release the commit
the run tested* below): it is the one broken release that stays silent.
The second row is the window such a pipeline leaves open: semantic-release
publishes the version first, and the image job that `needs: release` builds
and pushes it afterwards. A failure there is a broken release - loud, but
not prevented. Re-run the run's failed jobs once the cause is fixed
(`gh run rerun <run id> --failed`): jobs that succeeded are not run again
and their outputs are used, so the image job builds the version the release
job created. Starting the release workflow anew - or re-running all jobs -
would not help: it finds the version released already, creates nothing and
skips the image. If semantic-release itself failed after it had pushed the
tag or the release commit (e.g. while it created the GitHub release),
re-running the failed release job finds that version taken as well and the
image job is skipped again: build and push the image for that tag by hand.
To narrow the window:

- **Fail before the release:** prove registry access (login, a probe push)
  in a job the release job needs, so a missing secret or a registry outage
  stops the run before anything is tagged.
- **Publish what was tested:** push the image the gate built and tested
  under an immutable tag (the commit SHA, or by digest), and let the job
  after the release only add the version tags to that digest - instead of a
  second build.

The release workflow has to provide the rest:

- **`on: workflow_dispatch`** - without the trigger the dispatch is refused.
- **Release on dispatch.** Jobs gated to `push` only
  (`if: github.event_name == 'push'`) are skipped on a dispatch; a run that
  skips everything concludes `skipped` and fails this job. Allow
  `workflow_dispatch` as well.
- **Gate publishing on the tests with `needs:`.** The release job needs every
  build, test and round trip job and checks their results; the image builds
  that push need the release job. A failed test then skips everything that
  publishes, the run concludes `failure`, and this job turns red:

  ```yaml
  release:
    needs: [validate-compose, validate-scripts, backup-roundtrip]
    if: |
      (github.event_name == 'push' || github.event_name == 'workflow_dispatch') &&
      needs.validate-compose.result == 'success' &&
      needs.validate-scripts.result == 'success' &&
      needs.backup-roundtrip.result == 'success'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      ref: ${{ github.sha }}   # release the commit this run tested
    secrets: inherit

  docker-build:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: true
    secrets: inherit
  ```

  A complete pipeline:
  [gated-release-pipeline.yml](../../github/workflows/examples/backup-roundtrip/gated-release-pipeline.yml).
- **Release the commit the run tested.** Call `modules-semantic-release.yml`
  with `ref: ${{ github.sha }}`, as above. The run builds and tests
  `github.sha` - the base branch as it was when the run started, the merged
  update included - and its image jobs build that commit too. Without `ref`
  the release job resets to the tip of `main` when it starts: a merge or push
  that lands while the run's gate is still going (the next Dependabot merge,
  whose own run this workflow dispatches) is tagged by this run without being
  tested by it and is missing from its image, and the later run then finds
  nothing left to release. Both runs succeed - the broken image is silent.
  Pinned, semantic-release publishes nothing when `main` has moved on (*The
  local branch main is behind the remote one, therefore a new version won't
  be published* - checked with semantic-release 25.0.9), the run still
  succeeds, and the later run, which built and tested the newer `main`,
  releases both. Then the run publishes exactly what it tested, and its gate
  also catches what PR CI cannot: a combination merged onto a base CI did
  not test (*Merged onto an untested base*) is built and tested before
  anything is published.
  **The trade-off:** a push that starts no release run of its own - a
  `paths-ignore`d documentation push, a `[skip ci]` commit of an automation -
  leaves the earlier update unreleased until the next run. That is a missed
  release, not a broken one, and the job summary still says *Succeeded*;
  start the release workflow by hand to release it.
- **Let each dispatched run finish.** A run cancelled by a later one
  concludes `cancelled` and fails this job, although the later run releases
  both updates. With `concurrency:` on the release workflow, set
  `cancel-in-progress: false` - and know that this alone still cancels: by
  default a concurrency group keeps at most one *pending* run, and a newer
  one cancels it. With `queue: max` up to 100 runs wait their turn
  ([GitHub: concurrency](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs)).
  A waiting run's time counts against `release-wait-minutes`. Each merge here
  follows a rebase and a full CI run of the next PR, so two waiting release
  runs are rare.
- **Commit types.** Whether the run publishes anything is semantic-release's
  call: a `chore(deps)` commit releases nothing by default, and the run still
  succeeds - see [Other ecosystems and libraries](#other-ecosystems-and-libraries).
  The same holds for a pinned run whose `main` has moved on (above): *Release
  result: Succeeded* means the run succeeded, not that it published a
  version - its own summary says which.

**Who notices a red job.** GitHub mails a failed run to the user who triggered
it - here `dependabot[bot]`, so nobody gets mail. The failure shows as a red
*Docker Maintenance* check on the merged PR and in the Actions tab; route
failed runs to a channel (e.g. a Teams notification on `workflow_run`
completed) to have it reach a person.

#### Check the first dispatched release

GitHub restricts workflows *triggered by Dependabot* - by `push`,
`pull_request`, `pull_request_review` and `pull_request_review_comment`
events: they get a read-only `GITHUB_TOKEN` by default and Dependabot secrets
only
([GitHub: Dependabot on GitHub Actions](https://docs.github.com/en/code-security/dependabot/troubleshooting-dependabot/troubleshooting-dependabot-on-github-actions)).
`workflow_dispatch` is not on that list, and the dispatch is made with the
job token, so the release run is **expected** to run as
`github-actions[bot]`, with the release workflow's own `permissions:` and the
repository's Actions secrets. GitHub documents neither the actor nor the
secrets of a run dispatched this way, and this has not been verified end to
end yet. On the first automatic merge in a repository, open the release run
linked in the job summary and check:

1. **Actor** - the run shows as triggered by `github-actions[bot]`, not
   `dependabot[bot]`.
2. **Secrets** - the jobs that log in to a registry, sign or notify found
   their secrets (no empty login, no skipped signing).
3. **Result** - the run concluded `success`, and the version tag, the GitHub
   release and the image exist.

If GitHub treats the run as a Dependabot run after all, it sees Dependabot
secrets only. A step that requires an Actions secret then fails, the run
fails, and this job turns red naming it. A step that skips itself without
its secret (optional signing, a notification) does not fail - that is what
the second check is for. Either way, store the secrets the release needs as
**Dependabot secrets** as well (*Settings → Secrets and variables →
Dependabot*); the release workflow's explicit `permissions:` already lift the
token's read-only default, which GitHub allows for Dependabot runs.

The release commit the run pushes with `GITHUB_TOKEN` starts no further
workflow.

### Limits

- **Only `.github/` counts as CI.** A GitHub Actions update and a PR that
  changes a file under `.github/` stay open. CI code elsewhere - a local action
  used as `uses: ./actions/build`, a script the workflow runs - is tested by
  the PR's own run like any other file. Keep workflows and their actions
  under `.github/`.
- **A required workflow counts as a whole.** Its run must conclude
  `success`; which of its jobs run is up to the workflow. A job it skips by
  its own `if:` (e.g. a round trip that runs only for some paths) does not
  stop the merge. Choose workflows whose PR run always builds and tests.
- **0.x versions are recognised in plain `X.Y.Z` form only.** A tag such as
  `0.3-alpine` or a date keeps the update type Dependabot reported, so a
  `0.3-alpine → 0.4-alpine` update is a minor one for `merge-update-types`.
  Keep `minor` out of it for images with such tags, or merge them by hand -
  see [Updates below 1.0.0](#updates-below-100).
- **Matched by file path.** A required workflow that is renamed or moved no
  longer matches: every PR stays open with "did not run" until
  `required-workflows` is updated.
- **No release by the merge itself.** The merge is made with the job's
  `GITHUB_TOKEN`, and GitHub starts no workflow run for a push made with that
  token. Without `release-workflow` a release workflow on `push` to `main`
  runs with the next push that is not made by that token, or when it is
  started by hand; with it, the release is dispatched after the merge - see
  [Releasing the merged update](#releasing-the-merged-update).
- **The release is waited for in the same job.** The runner stays busy for up
  to `release-wait-minutes` after the merge (the job timeout is 255 minutes,
  enough for the longest CI and release waits). Lower it, or set `0` to only
  dispatch, if the release workflow is reliably watched elsewhere.
- **One merge at a time.** Every Dependabot PR is merged only on the base CI
  tested it on, so of several PRs that passed CI together one is merged and
  each of the others is rebased and tested again (see
  [Only the combination CI tested](#only-the-combination-ci-tested)). Each
  round costs one CI run per PR, and without `DEPENDABOT_REBASE_TOKEN` it
  waits for someone to comment `@dependabot rebase`.
- **The last second before the merge.** The base check and the merge are two
  API calls, and GitHub's merge call pins the head commit, not the base. A
  push in between is merged onto, and reported as *Merged onto an untested
  base* (decision table row 18b). A release pipeline that tests `main` before
  it publishes (such as one gated by the backup round trip) and releases the
  very commit it tested (`ref: ${{ github.sha }}`, see
  [what "no broken release" relies on](#what-no-broken-release-relies-on)) is
  what catches such a combination. The gap could be closed: instead of the
  merge call, fast-forward the base branch to the very commit CI tested
  (`refs/pull/<n>/merge`, the event's `github.sha`) with
  `PATCH /repos/{owner}/{repo}/git/refs/heads/<base>` and `force: false`,
  which GitHub refuses if the base moved; GitHub then marks the PR merged, as
  its head is part of the base branch. That fits `merge-method: merge` as
  is (a squash needs a commit with that tree on the tested base first) and is
  not implemented here.
- **Required workflows on other events.** The tested base is the one of the
  event that started this run; a required workflow that does not run on that
  event (`opened`, `synchronize`, `reopened` - the `pull_request` default)
  is judged by its run of an earlier event. Keep the default `types:` in
  required workflows.
- **No merge queue.** The workflow merges directly. On a base branch that
  requires a merge queue, `gh pr merge` only queues the PR: the PR reads back
  as not merged, the job warns *Dependabot PR not merged* and starts no
  release. The queue merges it later with its own checks, outside this
  workflow; this workflow is built for base branches without rulesets (see
  the note under [Permissions](#permissions)).
- **Workflows started by `workflow_run`** are not waited for: GitHub attaches
  such a run to the latest commit of the default branch, not to the PR's head
  commit, so it is not part of the PR's checks. Run the gate in a workflow that
  is triggered by `pull_request`.
- **Checks later than the quiet period.** A check that first appears more than
  3 minutes after everything else on the PR finished is not waited for. A
  required workflow that has not appeared by then leaves the PR open.
- **Own workflow.** Call this workflow from a workflow of its own (as in the
  example). Jobs of the same workflow run that have not started yet are not
  waited for, because that run is this workflow's own.

### Workflow Options

| Input                  | Description                                                                                                                            | Default           |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------------|-------------------|
| `required-workflows`   | PR CI workflow files that must have run on the PR and passed, comma or newline separated, e.g. `.github/workflows/ci.yml`              | `''` (no merge)   |
| `merge-method`         | squash, merge, or rebase                                                                                                               | `squash`          |
| `auto-approve`         | Approve the PR before merging it                                                                                                       | `true`            |
| `merge-update-types`   | Semver update types to merge: `patch`, `minor`, `major`; [0.x updates](#updates-below-100) count stricter                              | `patch`           |
| `ci-wait-minutes`      | How long to wait for CI to finish and settle (10-60) before leaving the PR open                                                        | `60`              |
| `release-workflow`     | Release workflow file dispatched on the base branch after a merge, e.g. `.github/workflows/docker-release.yml`; needs `actions: write` | `''` (no release) |
| `release-wait-minutes` | How long to wait for the dispatched release run (0-180); a run that does not succeed within it fails the job. `0`: do not wait         | `60`              |
| `allow-major`          | Deprecated: `true` equals `merge-update-types: patch,minor,major`                                                                      | `false`           |
| `runs-on`              | Runner label, or a JSON array of labels for self-hosted runners                                                                        | `ubuntu-latest`   |

See [Choosing `required-workflows`](#choosing-required-workflows).

| Secret                    | Description                                                                                                                                                                   | Required |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `DEPENDABOT_REBASE_TOKEN` | Token of a user with push access that posts `@dependabot rebase` when the base branch moved since CI ran - a **Dependabot** secret, see [the rebase token](#the-rebase-token) | no       |

| Output            | Description                                                                                                           |
|-------------------|-----------------------------------------------------------------------------------------------------------------------|
| `merged`          | `true` if this run merged the PR                                                                                      |
| `release-run-url` | URL of the dispatched release run; empty if none was dispatched or it was not found                                   |
| `release-result`  | `success`, `failed`, `timeout`, `not-waited`, `not-found`, `unreadable` or `dispatch-failed`; empty without a release |

### Examples

See [`github/workflows/examples/docker-maintenance-dependabot/`](../../github/workflows/examples/docker-maintenance-dependabot/README.md):

| Example                                                                                                                              | Use case                                                                                                                         |
|--------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| [simple-dependabot-maintenance.yml](../../github/workflows/examples/docker-maintenance-dependabot/simple-dependabot-maintenance.yml) | Smallest caller: Dockerfile updates, one PR CI workflow                                                                          |
| [with-backup-roundtrip-gate.yml](../../github/workflows/examples/docker-maintenance-dependabot/with-backup-roundtrip-gate.yml)       | Container stack: merge only after the PR run of `docker-release.yml`, backup round trip included, passed                         |
| [own-build-and-test-workflow.yml](../../github/workflows/examples/docker-maintenance-dependabot/own-build-and-test-workflow.yml)     | No backup sidecar: the repository's own build and test workflow vouches; Docker and npm updates, caller without `paths:`         |
| [multiple-required-workflows.yml](../../github/workflows/examples/docker-maintenance-dependabot/multiple-required-workflows.yml)     | Image build and a separate test suite - both must have run on the PR and passed                                                  |
| [all-ecosystems.yml](../../github/workflows/examples/docker-maintenance-dependabot/all-ecosystems.yml)                               | Docker, Compose, npm, pip, Composer, Cargo and NuGet updates: caller without `paths:`, one `ci.yml` builds and tests all of them |
| [dotnet-library.yml](../../github/workflows/examples/docker-maintenance-dependabot/dotnet-library.yml)                               | .NET library: NuGet updates tested by `dotnet build` and `dotnet test`, `chore(deps)` so that no update publishes a package      |
| [no-pr-ci-manual-merge.yml](../../github/workflows/examples/docker-maintenance-dependabot/no-pr-ci-manual-merge.yml)                 | No PR CI yet: `required-workflows` left unset on purpose - nothing is merged, every PR is reported                               |

---

## Option 2: Renovate (Advanced)

More powerful solution with grouping and advanced rules.

### Setup

#### 1. Install Renovate GitHub App

Install [Renovate GitHub App](https://github.com/apps/renovate) on your repository.

#### 2. Create Renovate Configuration

Create `renovate.json` in your repository root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>bauer-group/automation-templates//.github/config/docker-maintenance-renovate/docker-maintenance"
  ]
}
```

The preset includes:
- `commitMessagePrefix: "fix(docker):"` for semantic release compatibility
- Schedule: Sundays at 06:30 UTC
- Auto-merge for patch and minor updates
- Manual review required for major updates

#### 3. Create Maintenance Workflow

Create `.github/workflows/docker-maintenance.yml`:

```yaml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths:
      - 'Dockerfile'
      - 'src/Dockerfile'

permissions:
  contents: write
  pull-requests: write

jobs:
  maintenance:
    name: Auto-merge Renovate PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-renovate.yml@main
    with:
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

#### 4. Enable Auto-Merge and Branch Protection

1. Go to **Settings** → **General** → **Pull Requests** → Enable **"Allow auto-merge"**
2. Go to **Settings** → **Branches** → Add branch protection rule for `main`
3. Enable **"Require status checks to pass before merging"** and select relevant checks

### Workflow Options

| Input            | Description                | Default                  |
|------------------|----------------------------|--------------------------|
| `merge-method`   | squash, merge, or rebase   | `squash`                 |
| `auto-approve`   | Automatically approve PRs  | `true`                   |
| `allowed-actors` | Comma-separated bot actors | `renovate[bot],renovate` |

### Renovate Features

#### PR Grouping

All Docker updates grouped into single PR:

```json
{
  "packageRules": [
    {
      "matchDatasources": ["docker"],
      "groupName": "docker-base-images"
    }
  ]
}
```

#### Dependency Dashboard

Renovate creates an issue showing:
- Pending updates
- Open PRs
- Update history
- Manual triggers

#### Custom Schedule

```json
{
  "schedule": ["after 6:30am on sunday"],
  "timezone": "Etc/UTC"
}
```

### Examples

See `github/workflows/examples/docker-maintenance-renovate/`:

1. [simple-docker-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/simple-docker-maintenance.yml)
2. [comprehensive-docker-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/comprehensive-docker-maintenance.yml)
3. [multi-registry-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/multi-registry-maintenance.yml)
4. [custom-schedule-maintenance.yml](../../github/workflows/examples/docker-maintenance-renovate/custom-schedule-maintenance.yml)

---

## Combining with Docker Release

For full automation (like PDF-Toolbox), combine maintenance with release workflow:

```yaml
# .github/workflows/docker-maintenance.yml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths:
      - 'src/Dockerfile'

permissions:
  contents: write
  pull-requests: write
  checks: read
  statuses: read
  actions: write        # dispatch the release after the merge

jobs:
  maintenance:
    name: Auto-merge Dependabot PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      # The PR run of docker-release.yml has to pass before the merge ...
      required-workflows: .github/workflows/docker-release.yml
      # ... and its dispatched run releases the merged update.
      release-workflow: .github/workflows/docker-release.yml
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

```yaml
# .github/workflows/docker-release.yml - builds every PR (the required workflow
# the maintenance workflow waits for) and, on a push or a dispatch, releases
# only what it built and tested in the same run (the release pinned to
# github.sha, the commit the run built)
name: Docker Release

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
  pull_request:
    branches: [main]
    paths:
      - 'src/**'  # covers the maintenance workflow's paths
  # Dispatched by the maintenance workflow after a Dependabot merge
  workflow_dispatch:

# What docker-build.yml and modules-semantic-release.yml declare: a called
# workflow gets no more than its caller grants.
permissions:
  contents: write
  issues: write
  pull-requests: write
  packages: write
  security-events: write
  attestations: write
  id-token: write
  actions: read

jobs:
  # Every event: the image is built (and tested) without pushing it.
  build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: false
    secrets: inherit

  # Push or dispatch only, and only after the build passed: a failed build
  # skips the release and the image push, and the run concludes failure.
  release:
    needs: build
    if: github.event_name != 'pull_request' && needs.build.result == 'success'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      # The commit this run built and tested. If main moved on meanwhile,
      # nothing is released here - the run for the newer main releases both.
      ref: ${{ github.sha }}
    secrets: inherit

  docker:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: true
    secrets: inherit
```

**Result:** Base image update → PR built and tested → merged on the base CI
tested → release dispatched → build on `main` → PATCH release of the commit
that was built → image rebuilt and pushed, and a green *Docker Maintenance*
job. If the build on `main` fails, nothing is published; if the image rebuild
or push after the release fails, the version tag and GitHub release exist
without the image (see
[What "no broken release" relies on](#what-no-broken-release-relies-on)). In
either case the *Docker Maintenance* job turns red and names the release run.
If another update lands on `main` while the run builds, this run releases
nothing, and the run started for that update releases both.
A stack with a backup sidecar gates the release on the backup round trip as
well:
[gated-release-pipeline.yml](../../github/workflows/examples/backup-roundtrip/gated-release-pipeline.yml).

---

## Troubleshooting

### Dependabot PR Not Merged

The workflow completes but the PR stays open.

**Cause:** the job left it open on purpose. The annotation and the job summary
say why - see the [decision table](#decision-table). The usual ones:

| Annotation says                                        | Fix                                                                                                                                                  |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| automatic merging is off: required-workflows           | Set `required-workflows`, see [Choosing `required-workflows`](#choosing-required-workflows)                                                          |
| update type is not merged automatically                | Expected for minor/major; merge by hand, or widen `merge-update-types`                                                                               |
| semver-major update (0.x minor/0.0.x patch ...)        | Expected below 1.0.0, any update may break: review and merge by hand, or add `major` to `merge-update-types`                                         |
| versions of the updated dependencies could not be read | No `jq` on a self-hosted runner: install it. Otherwise merge by hand - the 0.x rule could not be checked                                             |
| change the CI itself / changes CI files                | Expected: review and merge by hand. GitHub Actions updates and PRs that change `.github/` are never merged automatically                             |
| CI did not pass                                        | Fix the check, or merge by hand; a re-run of the check alone does not merge - re-run this job, or `@dependabot rebase`                               |
| required workflow ... did not run for this change      | Its `pull_request` `paths:` miss the changed files: merge by hand, or add them there if it builds them ([files per ecosystem](#files-per-ecosystem)) |
| required workflow ... (run N, attempt M: skipped)      | All of its jobs were skipped on the PR, so it tested nothing: merge by hand, or fix its `if:` conditions                                             |
| job token cannot read the CI results                   | Private repo: add `checks: read`, `statuses: read` and `actions: read` to the caller's `permissions:`                                                |
| CI had not finished and settled after N min            | Raise `ci-wait-minutes`, or merge by hand once CI is green                                                                                           |
| ... moved from ... (tested by CI) to ...               | Another PR or a release commit landed first: comment `@dependabot rebase`, or store the [rebase token](#the-rebase-token)                            |
| rebase could not be requested                          | `DEPENDABOT_REBASE_TOKEN` expired, was revoked or lacks *Pull requests: write*: renew it; comment `@dependabot rebase` meanwhile                     |
| Dependabot: *only users with push access ...*          | The rebase token's user has no push access to the repository - use one who has                                                                       |

Do **not** add a ruleset with required status checks for this - it is not needed
and blocks semantic-release (see above).

### No Docker Maintenance Run for a Dependabot PR

The PR has no `Docker Maintenance` check at all - no annotation, no summary.

**Cause:** the caller workflow never started: the PR changes no file in its
`on.pull_request.paths` (row 1 of the [decision table](#decision-table)).
With Dockerfile-only paths this is expected for npm, pip, Composer and GitHub
Actions updates - they are merged by hand. To have every Dependabot PR decided,
remove the caller's `paths:` - recommended as soon as `dependabot.yml` updates
more than base images - and add each ecosystem's manifest and lock files to the
`pull_request` `paths:` of the required workflow that builds them, see
[Recommended trigger](#recommended-trigger) and
[Files per ecosystem](#files-per-ecosystem).

A `Docker Maintenance` check that is there but *skipped* is row 2 instead: the
PR was not opened by Dependabot, or the event was raised by someone else (a
person pushed to the branch).

### No Semantic Release Created

| Problem | Solution |
|---------|----------|
| Commit prefix is `chore(docker)` | Change to `fix(docker)` in dependabot.yml or renovate.json |
| Semantic release not configured | Add `modules-semantic-release.yml` workflow |
| A Dependabot merge released nothing, job summary says *No release started: release-workflow is not set* | Set `release-workflow` and grant `actions: write` - see [Releasing the merged update](#releasing-the-merged-update) |

### Release After a Dependabot Merge Failed

The PR was merged, but the *Docker Maintenance* job is red. The job summary
shows *Merge → Release dispatched → Release result*; the error annotation says
which step failed:

| Annotation says                                                   | Fix                                                                                                                             |
|-------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------|
| Release not started: ... grant 'actions: write'                   | Add `actions: write` to the caller's `permissions:` (it replaces `actions: read`)                                               |
| Release not started: ... needs an 'on: workflow_dispatch' trigger | Add `workflow_dispatch:` to the release workflow's `on:`, or enable the workflow                                                |
| Release not started: ... was not found on main                    | `release-workflow` names a file that does not exist on the base branch - fix the path                                           |
| Release failed: ... concluded 'failure'                           | A job failed: before the release job nothing is published; after it the image may be missing. Fix it, re-run the failed jobs    |
| Release failed: ... concluded 'cancelled'                         | Another run cancelled it (`concurrency` with `cancel-in-progress: true`) - set it to `false`; the later run released the update |
| Release failed: ... concluded 'skipped'                           | Every job skipped on `workflow_dispatch` - allow that event in the release job's `if:`                                          |
| Release failed: ... concluded 'startup_failure'                   | The release workflow is invalid (syntax, a called workflow, permissions) - see the run's annotations                            |
| Release not finished: ... still in_progress after N min           | The release takes longer than `release-wait-minutes` - raise it (at most 180); the run itself goes on, check its result there   |
| Release not confirmed: ... was not found within 2 min             | Rare: GitHub did not return the run, and it was not listed in time - check the workflow's runs                                  |

In every case the update is on `main`. Once the cause is fixed, re-run the
release run's failed jobs - after a failure behind the release job that is
the only way to get the image of that version built. Start the release
workflow by hand only if it was not started or failed before its release
job.

**Re-running this job does not retry the release.** A re-run finds the PR
merged already: it ends green with the warning *Dependabot PR already merged*,
and its summary says so - it neither merges nor dispatches anything. The red
attempt stays in the run's history; retry the release itself:

```bash
gh run rerun <release run id> --failed         # re-run the failed jobs of the release run
gh workflow run docker-release.yml --ref main  # not started, or failed before its release job
```

### Renovate Auto-Merge Not Working

The Renovate workflow uses GitHub's native auto-merge, which only waits for
**required** status checks:

1. Enable auto-merge in repository settings
2. Check branch protection rules allow auto-merge
3. Verify workflow is present and running
4. Check GitHub Actions logs for errors

### Dependabot Not Creating PRs

1. Verify `.github/dependabot.yml` exists
2. Check Settings → Security → Dependabot is enabled
3. Verify `package-ecosystem: "docker"` is configured
4. Check `directory` points to folder with Dockerfile

### Renovate Not Creating PRs

1. Check if Renovate App is installed
2. Check Dependency Dashboard issue for status
3. Verify `renovate.json` syntax

---

## Security Considerations

- **Tested by the named CI**: Dependabot PRs are merged only when every workflow in `required-workflows` ran on the PR's head commit and passed and no other check failed, after CI has been complete and unchanged for 3 minutes (5 minutes after the start at the earliest). A passed check that tests nothing (e.g. a secret scan or a notification job) is not enough, and without `required-workflows` nothing is merged
- **CI changes stay open**: a GitHub Actions update or a PR that changes `.github/` is never merged automatically - a `pull_request` run uses the PR's own version of a changed workflow, and push- or schedule-only workflows do not run before the merge
- **Pinned merge**: the Dependabot merge and its approval name the head commit whose CI was checked
- **Release only after a merge, failures loud**: `release-workflow` is dispatched only after this run merged the PR, needs nothing but `actions: write` on the job token, and a release run that does not succeed fails the job. What gets published is gated by the release workflow's own tests, and is what they ran on only if its release is pinned to the commit the run tested (`ref: ${{ github.sha }}`) - see [what "no broken release" relies on](#what-no-broken-release-relies-on), also for the window a pipeline that tags before it pushes leaves open
- **Released without a person in between**: with `release-workflow`, a merged dependency update is built and released by the dispatched run - with the release workflow's write permissions and the repository's secrets (registry credentials, signing keys) - without anyone looking at it first. Without it, the release waited for the next human push. That is a supply-chain trade-off to accept knowingly: an update whose harmful change passes the required CI reaches the registry automatically. Keep `merge-update-types` narrow (the default `patch`), the release gated on its tests, and `release-workflow` unset where a person should approve each release
- **Only the tested combination**: a Dependabot PR is merged only while the base branch is still at the commit its CI was merged onto; otherwise it is rebased and tested again. The optional `DEPENDABOT_REBASE_TOKEN` is used for that one `@dependabot rebase` comment and nothing else; keep it on a machine user, limited to the selected repositories and short-lived (see [the rebase token](#the-rebase-token))
- **Dependabot only**: the Dependabot job acts only on Dependabot's PRs, on events Dependabot raised, with verified Dependabot commits only; it never checks out PR code
- **Auto-approve optional**: Can be disabled for manual review
- **Audit trail**: All updates tracked in PRs and git history
- **Update types**: Dependabot merges patch updates only unless `merge-update-types` widens it, and below 1.0.0 a minor update (and below 0.1.0 a patch update) counts as major; Renovate leaves majors for review

## Related Documentation

- [Docker Build Workflow](./docker-build.md)
- [Semantic Release Config Contract](./semantic-release-config.md)
- [Backup Round-Trip Test](./modules-backup-roundtrip-test.md) - the PR gate a container stack names in `required-workflows`
- [Docker Base Image Monitor](./modules-docker-base-image-monitor.md) - rebuilds on floating tags (`stable`, `latest`) that Dependabot cannot track
- [Examples](../../github/workflows/examples/docker-maintenance-dependabot/README.md)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Renovate Documentation](https://docs.renovatebot.com/)
