# TruffleHog Secret Scan Module

Verified-first secret detection using [TruffleHog](https://github.com/trufflesecurity/trufflehog) — 800+ detectors that **actively verify** whether a found credential is live.

## Overview

TruffleHog complements the existing Gitleaks + GitGuardian scanners. Where Gitleaks uses
regex + entropy (fast, but noisy) and GitGuardian adds ML, TruffleHog's differentiator is
**verification**: it calls the provider's API to confirm a detected secret actually works.
A *verified* finding is a confirmed live exposure — not a maybe.

- **Verification** — `--results=verified` reports only live credentials by default
- **Two scan modes** — `filesystem` (current working tree) and `git-history` (full history)
- **SARIF → Security tab** — findings appear under Code Scanning (category `trufflehog`), with verified secrets as `error` and unverified as `warning`
- **0–100 score** — verified secrets weigh far heavier than unverified ones
- **Pinned version** — installs a fixed TruffleHog release (no floating `latest`)

## Quick Start

> **Copy-paste example:** [`github/workflows/examples/security/trufflehog-secret-scan.yml`](../../github/workflows/examples/security/trufflehog-secret-scan.yml)

```yaml
name: Secret Scan
on: [push, pull_request]

jobs:
  trufflehog:
    uses: bauer-group/automation-templates/.github/workflows/modules-trufflehog-scan.yml@main
```

### Full history scan (scheduled)

```yaml
on:
  schedule:
    - cron: '0 3 * * 1'   # weekly deep scan

jobs:
  trufflehog:
    uses: bauer-group/automation-templates/.github/workflows/modules-trufflehog-scan.yml@main
    with:
      scan-mode: 'git-history'
```

### Include unverified findings (stricter, noisier)

```yaml
jobs:
  trufflehog:
    uses: bauer-group/automation-templates/.github/workflows/modules-trufflehog-scan.yml@main
    with:
      include-unverified: true
      fail-on-findings: false   # report-only while triaging
```

## Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `scan-mode` | `filesystem` (working tree) or `git-history` (full history) | `'filesystem'` |
| `only-verified` | Report only verified (live) secrets | `true` |
| `include-unverified` | Include unverified + unknown results (overrides `only-verified`) | `false` |
| `exclude-paths` | Comma-separated paths to exclude | `'.git,node_modules,vendor,target,dist,build'` |
| `fail-on-findings` | Fail the workflow if secrets are found | `true` |
| `config-path` | Custom TruffleHog exclude-paths file (one regex per line) | `''` |
| `trufflehog-version` | Pinned TruffleHog version | `'3.95.8'` |
| `runs-on` | Runner (string or JSON array for self-hosted) | `'ubuntu-latest'` |

## Outputs

| Output | Description |
|--------|-------------|
| `secrets-found` | Whether any secrets were found (`'true'`/`'false'`) |
| `secrets-count` | Total number of secrets found |
| `verified-count` | Number of **verified (live)** secrets |
| `security-score` | Score 0–100 (verified secrets penalized heaviest) |
| `scan-status` | `pass` / `warning` / `fail` |

## How it relates to the other secret scanners

| Scanner | Method | Strength | Module |
|---------|--------|----------|--------|
| **Gitleaks** | Regex + entropy | Fast, custom rules | [modules-security-scan.yml](../../.github/workflows/modules-security-scan.yml) |
| **GitGuardian** | ML + policies | Enterprise policy, IaC | (same module) |
| **TruffleHog** | Detectors + **live verification** | Confirms real exposure | this module |
| **Native push protection** | Pre-receive hook | Blocks before push | [native-secret-scanning.md](../security/native-secret-scanning.md) |

> TruffleHog is deliberately a **standalone** module. Its output contract
> (`secrets-found` / `secrets-count` / `security-score` / `scan-status`) matches the other
> secret scanners, so it can later be wired into the `security-scan-meta` orchestrator as a
> third engine without changes.

## Notes

- **No secret required.** Verification uses only the credentials TruffleHog *finds*; there is no TruffleHog service key.
- **SARIF is generated locally.** TruffleHog has no native SARIF exporter, so the action converts its JSON output to SARIF 2.1.0 before uploading.
- `git-history` mode checks out full history (`fetch-depth: 0`); `filesystem` mode uses a shallow checkout for speed.

## References

- [TruffleHog](https://github.com/trufflesecurity/trufflehog)
- [Verified vs. unverified results](https://github.com/trufflesecurity/trufflehog#verification)
