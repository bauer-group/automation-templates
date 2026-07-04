# GitHub-Native Secret Scanning & Push Protection

GitHub Advanced Security (GHAS) ships two features that complement — not replace —
our CI scanners (Gitleaks, GitGuardian, TruffleHog):

| Layer | Tool | When it acts | What it catches |
|-------|------|--------------|-----------------|
| **Pre-receive (push)** | Native **Push Protection** | *Before* a commit reaches the remote | Blocks a known secret pattern at `git push` time |
| **Repository (post-push)** | Native **Secret Scanning** | Continuously, on the default branch | Alerts on secrets already committed |
| **CI (pull request / schedule)** | Gitleaks + GitGuardian + **TruffleHog** | On every PR / scheduled run | Depth, custom rules, and **live verification** of found credentials |

> **Why keep both?** Native push protection is the cheapest possible gate — it stops a
> secret before it ever leaves the developer's machine. Our CI scanners add breadth
> (custom detectors, git history) and **verification** (TruffleHog confirms whether a
> leaked credential is actually live). Defense in depth: the pre-receive hook blocks the
> obvious, CI catches the rest.

## Availability

- **Public repositories:** Secret scanning and push protection are **free**.
- **Private/internal repositories:** Require a **GitHub Advanced Security** license
  (GitHub Enterprise / Team with GHAS).

## Enable via the UI (recommended)

**Per repository:** `Settings → Code security and analysis` →
- **Secret scanning** → *Enable*
- **Push protection** → *Enable*

**Org-wide (all repos):** `Organization → Settings → Code security and analysis` →
*Enable all* + *Automatically enable for new repositories*.

## Enable via API / `gh` (automation)

Requires a token with **admin** rights on the repository (`repo` + `admin:org` for the
org-level call). Do **not** hardcode the token — pass it via environment/secret manager.

```bash
# Per repository
gh api -X PATCH "repos/$OWNER/$REPO" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

```bash
# Org-wide default for all new repositories
gh api -X PATCH "orgs/$ORG" \
  -f 'secret_scanning_enabled_for_new_repositories=true' \
  -f 'secret_scanning_push_protection_enabled_for_new_repositories=true'
```

> **Optional maintenance workflow:** the two `gh api` calls above can be wrapped in a
> scheduled workflow (`workflow_dispatch` + `cron`) that enforces the setting across the
> org. It is intentionally **not** shipped as a module here because it needs a
> privileged admin PAT — enable it deliberately, scoped to a dedicated automation
> identity, rather than by default.

## How a developer experiences push protection

```text
$ git push
remote: error: GH013: Repository rule violations found for refs/heads/feature.
remote:   —— GitHub Push Protection ————————————————————————————
remote:   Secret detected: AWS Access Key ID
remote:   commit: 3f2a…  path: config/prod.env:12
remote:   Fix: remove the secret, or (if a false positive) bypass with a reason.
```

The developer removes the secret (or, for a genuine false positive, bypasses with a
documented reason that is audit-logged) — the leak never reaches the remote.

## Related

- [Secret scanning (docs.github.com)](https://docs.github.com/en/code-security/secret-scanning)
- [Push protection (docs.github.com)](https://docs.github.com/en/code-security/secret-scanning/push-protection-for-repositories-and-organizations)
- [`modules-trufflehog-scan.yml`](../workflows/modules-trufflehog-scan.md) — CI verification layer
- [`modules-security-scan.yml`](../../.github/workflows/modules-security-scan.yml) — Gitleaks + GitGuardian
