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

With Dependabot, the step from the merge to the release is not automatic: the
merge is made with `GITHUB_TOKEN`, which starts no `push` workflow - see
[Limits](#limits).

---

## Option 1: Dependabot (Simple)

The simplest solution using GitHub's native Dependabot.

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

#### 2. Create Maintenance Workflow

Create `.github/workflows/docker-maintenance.yml`:

```yaml
name: Docker Maintenance

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
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
  actions: read         # workflow runs - private repositories

jobs:
  maintenance:
    name: Auto-merge Dependabot PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      # The PR CI that builds and tests the update (empty: nothing is merged)
      required-workflows: .github/workflows/docker-release.yml
      merge-method: 'squash'
      auto-approve: true
      # merge-update-types: 'patch,minor'  # default: patch
    secrets: inherit
```

#### 3. Name the PR CI that must pass

Nothing else to configure - no ruleset, no branch protection, no "Allow auto-merge".
The workflow waits for the CI of the PR itself and merges only when every
workflow listed in `required-workflows` has run on the PR and passed. With
`required-workflows` empty (the default) it merges **nothing** and leaves each
PR open with a notice that says how to set it. A passed check alone proves
nothing: GitGuardian, notification and AI-summary jobs pass on every PR
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

The required workflow must start for every file this caller's `paths:` lists,
so keep the caller's `paths:` within the required workflow's `pull_request`
`paths:`. A Dependabot PR that changes a file the required workflow does not
watch stays open with "did not run for this change - not tested" - nothing
tested it.

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

#### Permissions

The workflow declares no permissions of its own, so the job token has exactly
what the calling workflow grants. A reusable workflow can only narrow its
caller's permissions: declaring the read scopes itself would make GitHub refuse
to start every caller that does not grant them.

| Permission             | Used for                                                                 | Public repository | Private repository                                      |
|------------------------|--------------------------------------------------------------------------|-------------------|---------------------------------------------------------|
| `contents: write`      | merging the PR                                                           | required          | required                                                |
| `pull-requests: write` | approving; reading the PR                                                | required          | required                                                |
| `checks: read`         | check runs and check suites of the head commit                           | not needed        | required - without it every PR stays open with a notice |
| `statuses: read`       | commit statuses of the head commit                                       | not needed        | required - without it every PR stays open with a notice |
| `actions: read`        | workflow runs of the head commit - whether the required workflows passed | not needed        | required - without it every PR stays open with a notice |

Public repositories need none of the three read scopes because their CI results
are public; probed with a job token that had only `contents` and
`pull-requests`, which read check runs, check suites, statuses and workflow
runs in a public repository and got HTTP 403 for all of them in private ones.
Granting the read scopes in public repositories as well does no harm and keeps
the workflow working if the repository is made private.

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
PR's head.

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
   it only fails if the base branch requires a review.

Every other outcome leaves the PR **open** with the job green, the decision as an
annotation and in the job summary:

| Situation                                                                          | Annotation |
|------------------------------------------------------------------------------------|------------|
| `required-workflows` is not set - automatic merging is off                         | notice     |
| Update type not in `merge-update-types`, or unknown                                | notice     |
| Not every commit of the PR is a verified commit by Dependabot                      | notice     |
| The PR changes CI: a GitHub Actions update, or a changed file under `.github/`     | notice     |
| A check failed, was cancelled, timed out, needs action or went stale               | notice     |
| A workflow could not start (`startup_failure`)                                     | notice     |
| A required workflow did not run for this change, or concluded `skipped`/`neutral`  | notice     |
| CI not finished and quiet after `ci-wait-minutes`                                  | notice     |
| CI results not readable (private repo without `checks`/`statuses`/`actions: read`) | notice     |
| CI results could not be read after three API errors in a row                       | warning    |
| The PR got a new head commit or was closed meanwhile                               | notice     |
| CI passed, but the PR is a draft or cannot be merged (e.g. a conflict)             | notice     |
| CI passed, but the PR could not be read again right before the merge               | warning    |
| CI passed, but the merge was rejected (e.g. a required review)                     | warning    |

A newer event on the same PR (e.g. Dependabot rebased it) cancels the run that is
still waiting.

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
- **Matched by file path.** A required workflow that is renamed or moved no
  longer matches: every PR stays open with "did not run" until
  `required-workflows` is updated.
- **No release by the merge itself.** The merge is made with the job's
  `GITHUB_TOKEN`, and GitHub starts no workflow run for a push made with that
  token. A release workflow on `push` to `main` therefore runs with the next
  push that is not made by that token, or when it is started by hand.
- **Base branch moved since CI ran.** The merge does not require the PR to be
  up to date with its base branch, just like GitHub's auto-merge without
  "Require branches to be up to date". A PR with a conflict stays open
  (Dependabot rebases it). Two updates merged one after the other are each
  tested on their own, not together - a release pipeline that tests `main`
  before it releases (such as one gated by the backup round trip) catches a
  combination that breaks.
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

| Input                | Description                                                                                                                       | Default         |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------|-----------------|
| `required-workflows` | PR CI workflow files that must have run on the PR and passed, comma or newline separated, e.g. `.github/workflows/ci.yml`         | `''` (no merge) |
| `merge-method`       | squash, merge, or rebase                                                                                                          | `squash`        |
| `auto-approve`       | Approve the PR before merging it                                                                                                  | `true`          |
| `merge-update-types` | Semver update types to merge, comma separated: `patch`, `minor`, `major`                                                          | `patch`         |
| `ci-wait-minutes`    | How long to wait for CI to finish and settle (10-60) before leaving the PR open                                                   | `60`            |
| `allow-major`        | Deprecated: `true` equals `merge-update-types: patch,minor,major`                                                                 | `false`         |
| `runs-on`            | Runner label, or a JSON array of labels for self-hosted runners                                                                   | `ubuntu-latest` |

See [Choosing `required-workflows`](#choosing-required-workflows).

### Examples

See `github/workflows/examples/docker-maintenance-dependabot/`:

- [simple-dependabot-maintenance.yml](../../github/workflows/examples/docker-maintenance-dependabot/simple-dependabot-maintenance.yml)

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
  actions: read

jobs:
  maintenance:
    name: Auto-merge Dependabot PRs
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      required-workflows: .github/workflows/docker-release.yml
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

```yaml
# .github/workflows/docker-release.yml - builds the PR (the required workflow
# the maintenance workflow waits for) and releases after the merge
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
  release:
    if: github.event_name == 'push'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit

  docker:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: true
    secrets: inherit

  docker-pr:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: false
    secrets: inherit
```

**Result:** Base image update → PR built → PR merged → PATCH release → Docker image rebuilt and pushed.
With the Dependabot workflow the release starts with the next push to `main`
that is not made by `GITHUB_TOKEN`, or when the release workflow is run by hand
(`workflow_dispatch`) - see [Limits](#limits).

---

## Troubleshooting

### Dependabot PR Not Merged

The workflow completes but the PR stays open.

**Cause:** the job left it open on purpose. The annotation and the job summary
say why - see the table under [How Merging Works](#how-merging-works). The
usual ones:

| Annotation says                                   | Fix                                                                                                                         |
|---------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| automatic merging is off: required-workflows      | Set `required-workflows`, see [Choosing `required-workflows`](#choosing-required-workflows)                                 |
| update type is not merged automatically           | Expected for minor/major; merge by hand, or widen `merge-update-types`                                                      |
| change the CI itself / changes CI files           | Expected: review and merge by hand. GitHub Actions updates and PRs that change `.github/` are never merged automatically    |
| CI did not pass                                   | Fix the check, or merge by hand; a re-run of the check alone does not merge - re-run this job, or `@dependabot rebase`      |
| required workflow ... did not run for this change | Its `pull_request` `paths:` miss the changed files: merge by hand, and keep the caller's `paths:` within the workflow's     |
| required workflow ... (run N, attempt M: skipped) | All of its jobs were skipped on the PR, so it tested nothing: merge by hand, or fix its `if:` conditions                    |
| job token cannot read the CI results              | Private repo: add `checks: read`, `statuses: read` and `actions: read` to the caller's `permissions:`                       |
| CI had not finished and settled after N min       | Raise `ci-wait-minutes`, or merge by hand once CI is green                                                                  |

Do **not** add a ruleset with required status checks for this - it is not needed
and blocks semantic-release (see above).

### No Semantic Release Created

| Problem | Solution |
|---------|----------|
| Commit prefix is `chore(docker)` | Change to `fix(docker)` in dependabot.yml or renovate.json |
| Semantic release not configured | Add `modules-semantic-release.yml` workflow |

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

- **Tested by the named CI**: Dependabot PRs are merged only when every workflow in `required-workflows` ran on the PR's head commit and passed and no other check failed, after CI has been complete and unchanged for 3 minutes (5 minutes after the start at the earliest). A passed check that tests nothing (e.g. GitGuardian) is not enough, and without `required-workflows` nothing is merged
- **CI changes stay open**: a GitHub Actions update or a PR that changes `.github/` is never merged automatically - a `pull_request` run uses the PR's own version of a changed workflow, and push- or schedule-only workflows do not run before the merge
- **Pinned merge**: the Dependabot merge and its approval name the head commit whose CI was checked
- **Dependabot only**: the Dependabot job acts only on Dependabot's PRs, on events Dependabot raised, with verified Dependabot commits only; it never checks out PR code
- **Auto-approve optional**: Can be disabled for manual review
- **Audit trail**: All updates tracked in PRs and git history
- **Update types**: Dependabot merges patch updates only unless `merge-update-types` widens it; Renovate leaves majors for review

## Related Documentation

- [Docker Build Workflow](./docker-build.md)
- [Semantic Release Workflow](./semantic-release.md)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [Renovate Documentation](https://docs.renovatebot.com/)
