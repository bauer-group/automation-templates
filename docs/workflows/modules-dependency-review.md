# Dependency Review Module

Blocks pull requests that introduce **known-vulnerable** or **disallowed-license**
dependencies, using GitHub's [dependency-review-action](https://github.com/actions/dependency-review-action).

## Overview

Trivy and OSV-Scanner scan the *merged* tree — they tell you about a bad dependency only
after it is already in the branch. Dependency Review runs at **PR time** and compares the
base vs. head dependency graph, so a risky dependency is caught **before merge**.

- **Pre-merge gate** — fails the PR check on new vulnerable/bad-license deps
- **License policy** — allow-list or deny-list by SPDX identifier
- **PR comment** — optional inline summary of introduced risk
- **Severity threshold** — configurable (`low` → `critical`)

> **Trigger requirement:** this module reads the pull-request diff, so the calling workflow
> **must** be triggered by `pull_request` (or `pull_request_target`).

## Quick Start

```yaml
name: Dependency Review
on: pull_request

jobs:
  dependency-review:
    uses: bauer-group/automation-templates/.github/workflows/modules-dependency-review.yml@main
```

### With license policy

```yaml
on: pull_request

jobs:
  dependency-review:
    uses: bauer-group/automation-templates/.github/workflows/modules-dependency-review.yml@main
    with:
      fail-on-severity: 'moderate'
      comment-summary-in-pr: 'always'
      deny-licenses: 'GPL-3.0, AGPL-3.0'
```

## Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `fail-on-severity` | Minimum failing severity: `low`, `moderate`, `high`, `critical` | `'high'` |
| `comment-summary-in-pr` | `always`, `on-failure`, `never` | `'on-failure'` |
| `allow-licenses` | SPDX allow-list (mutually exclusive with `deny-licenses`) | `''` |
| `deny-licenses` | SPDX deny-list (mutually exclusive with `allow-licenses`) | `''` |
| `fail-on-scopes` | Scopes to check: `runtime`, `development`, `unknown` | `'runtime'` |
| `runs-on` | Runner (string or JSON array for self-hosted) | `'ubuntu-latest'` |

> `allow-licenses` and `deny-licenses` are mutually exclusive — set at most one.

## Outputs

| Output | Description |
|--------|-------------|
| `review-result` | `success` / `failure` |

## Notes

- **Permissions:** declares `pull-requests: write` for the PR comment; `contents: read` for the diff.
- **Availability:** the dependency graph is free on public repos; private repos need GitHub Advanced Security.
- **No secret required.**

## References

- [dependency-review-action](https://github.com/actions/dependency-review-action)
- [About dependency review](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-dependency-review)
