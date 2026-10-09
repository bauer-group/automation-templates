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
      merge-method: 'squash'
      auto-approve: true
      # merge-update-types: 'patch,minor'  # default: patch
    secrets: inherit
```

#### 3. Have a PR CI

Nothing else to configure - no ruleset, no branch protection, no "Allow auto-merge".
The workflow waits for the CI of the PR itself, so a CI workflow that runs on
Dependabot PRs is all it needs. A PR on which no check passes is never merged.

#### Permissions

The workflow declares no permissions of its own, so the job token has exactly
what the calling workflow grants. A reusable workflow can only narrow its
caller's permissions: declaring the read scopes itself would make GitHub refuse
to start every caller that does not grant them.

| Permission             | Used for                                       | Public repository | Private repository                                                                                      |
|------------------------|------------------------------------------------|-------------------|---------------------------------------------------------------------------------------------------------|
| `contents: write`      | merging the PR                                 | required          | required                                                                                                |
| `pull-requests: write` | approving; reading the PR                      | required          | required                                                                                                |
| `checks: read`         | check runs and check suites of the head commit | not needed        | required - without it every PR stays open with a notice                                                 |
| `statuses: read`       | commit statuses of the head commit             | not needed        | required - without it every PR stays open with a notice                                                 |
| `actions: read`        | workflow runs of the head commit               | not needed        | recommended - without it the wait uses check suites alone (see [How Merging Works](#how-merging-works)) |

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

1. **Update type** - only the semver types in `merge-update-types` are merged
   (default `patch`). A `minor` or `major` update, or one whose type cannot be
   determined (digest, non-semver tag), stays open for review. The redpanda
   `26.1 → 26.2` bump that took a production stack down was a semver-*minor*.
2. **Wait for CI** - the job polls the check runs, check suites, commit
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
   concurrency group replaced it); telling the two apart needs the workflow
   runs, i.e. `actions: read` in private repositories.
3. **Merge** - only when no check failed and at least one passed. `neutral`
   and `skipped` are no failure (as for required status checks), but no pass
   either: a PR whose checks were all skipped stays open. Right before the
   merge the PR is read again: if it was closed, got a new head commit, was
   turned into a draft or cannot be merged (a conflict) in the meantime, it is
   not merged. Then the PR is approved (if `auto-approve` is on) and merged
   with `gh pr merge --match-head-commit`, so only the commit whose CI was
   checked can be merged. The approval names that commit too: approving
   without it would approve whatever commit is the PR's latest at that
   moment. Where GitHub Actions may not approve pull requests (an org or repo
   setting), the rejected approval is a notice and the merge goes ahead; it
   only fails if the base branch requires a review.

Every other outcome leaves the PR **open** with the job green, the decision as an
annotation and in the job summary:

| Situation                                                                | Annotation |
|--------------------------------------------------------------------------|------------|
| Update type not in `merge-update-types`, or unknown                      | notice     |
| Not every commit of the PR is a verified commit by Dependabot            | notice     |
| A check failed, was cancelled, timed out, needs action or went stale     | notice     |
| A workflow could not start (`startup_failure`)                           | notice     |
| No check ran on the PR, or all of them were skipped or neutral           | notice     |
| CI not finished and quiet after `ci-wait-minutes`                        | notice     |
| CI results not readable (private repo without `checks`/`statuses: read`) | notice     |
| The PR got a new head commit or was closed meanwhile                     | notice     |
| CI passed, but the PR is a draft or cannot be merged (e.g. a conflict)   | notice     |
| CI passed, but the merge was rejected (e.g. a required review)           | warning    |

A newer event on the same PR (e.g. Dependabot rebased it) cancels the run that is
still waiting.

### Limits

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
  3 minutes after everything else on the PR finished is not waited for.
- **Own workflow.** Call this workflow from a workflow of its own (as in the
  example). Jobs of the same workflow run that have not started yet are not
  waited for, because that run is this workflow's own.

### Workflow Options

| Input                | Description                                                                     | Default  |
|----------------------|---------------------------------------------------------------------------------|----------|
| `merge-method`       | squash, merge, or rebase                                                        | `squash` |
| `auto-approve`       | Approve the PR before merging it                                                | `true`   |
| `merge-update-types` | Semver update types to merge, comma separated: `patch`, `minor`, `major`        | `patch`  |
| `ci-wait-minutes`    | How long to wait for CI to finish and settle (10-60) before leaving the PR open | `60`     |
| `allow-major`        | Deprecated: `true` equals `merge-update-types: patch,minor,major`               | `false`  |

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
      merge-method: 'squash'
      auto-approve: true
    secrets: inherit
```

```yaml
# .github/workflows/docker-release.yml (triggered after merge)
name: Docker Release

on:
  push:
    branches: [main]
    paths:
      - 'src/**'

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit

  docker:
    needs: release
    if: needs.release.outputs.new-release-published == 'true'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      push: true
    secrets: inherit
```

**Result:** Base image update → PR merged → PATCH release → Docker image rebuilt and pushed.
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

| Annotation says                             | Fix                                                                                                                    |
|---------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| update type is not merged automatically     | Expected for minor/major; merge by hand, or widen `merge-update-types`                                                 |
| CI did not pass                             | Fix the check, or merge by hand; a re-run of the check alone does not merge - re-run this job, or `@dependabot rebase` |
| no check ran / none of the checks passed    | Add a PR CI workflow whose `paths:` cover the files Dependabot changes                                                 |
| job token cannot read the CI results        | Private repo: add `checks: read` and `statuses: read` to the caller's `permissions:`                                   |
| CI had not finished and settled after N min | Raise `ci-wait-minutes`, or merge by hand once CI is green                                                             |

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

- **CI must pass**: Dependabot PRs are merged only when no check failed and at least one passed, after CI has been complete and unchanged for 3 minutes (5 minutes after the start at the earliest)
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
