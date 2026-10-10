# GitHub-Native Secret Scanning & Push Protection

GitHub Advanced Security (GHAS) ships two features that complement — not replace —
our CI scanners (TruffleHog, and Gitleaks where it is enabled):

| Layer | Tool | When it acts | What it catches |
|-------|------|--------------|-----------------|
| **Pre-receive (push)** | Native **Push Protection** | *Before* a commit reaches the remote | Blocks a known secret pattern at `git push` time |
| **Repository (post-push)** | Native **Secret Scanning** | Continuously, on the default branch | Alerts on secrets already committed |
| **CI (pull request / schedule)** | **TruffleHog** + Gitleaks (opt-in) | On every PR / scheduled run | Depth, custom rules, and **live verification** of found credentials |

> **Why keep both?** Native push protection is the cheapest possible gate — it stops a
> secret before it ever leaves the developer's machine. Our CI scanners add breadth
> (custom detectors, git history) and **verification** (TruffleHog confirms whether a
> leaked credential is actually live). Defense in depth: the pre-receive hook blocks the
> obvious, CI catches the rest.

## Gitleaks is opt-in

Since 2026-10 no template runs Gitleaks unless the caller asks for it. Where native
secret scanning and push protection are on, Gitleaks repeats the same pattern search,
and in an organization repository it needs a `GITLEAKS_LICENSE` secret that Dependabot
runs do not receive from the Actions secrets — so with Gitleaks on by default, every
Dependabot pull request failed on "missing gitleaks license". The templates are also used
by repositories that have no native secret scanning, so Gitleaks stays implemented and
can be switched on per repository.

**Enable it when** the repository has **no** GitHub secret scanning and push protection,
typically a private repository in an organization without GitHub Secret Protection
(GHAS). Check a repository with:

```bash
gh api "repos/$OWNER/$REPO" --jq '.security_and_analysis | {
  secret_scanning: .secret_scanning.status,
  push_protection: .secret_scanning_push_protection.status }'
```

Both `enabled`: Gitleaks is optional. Either one `disabled`, or `null` (no access to the
setting, or not available on the plan): enable Gitleaks.

**How:** set the engine input of the template you call to `'gitleaks'`. The default is
`'none'` everywhere; `'both'` is still accepted and also runs Gitleaks.

| Template | Input |
|----------|-------|
| [`modules-security-scan.yml`](../../.github/workflows/modules-security-scan.yml) | `scan-engine: 'gitleaks'` |
| [`modules-pr-validation.yml`](../../.github/workflows/modules-pr-validation.yml) | `security-scan-engine: 'gitleaks'` |
| [`python-semantic-release.yml`](../workflows/python-semantic-release.md) | `security-engine: 'gitleaks'` |
| [`esp32-build.yml`](../workflows/esp32-build.md), [`stm32-build.yml`](../workflows/stm32-build.md), [`platformio-build.yml`](../workflows/platformio-build.md), [`zephyr-build.yml`](../workflows/zephyr-build.md) | `security-scan-engine: 'gitleaks'` |
| [`security-scan`](../../.github/actions/security-scan/action.yml) / [`security-scan-meta`](../../.github/actions/security-scan-meta/action.yml) actions | `scan-engine: 'gitleaks'` |
| [`makefile-build.yml`](../workflows/makefile-build.md) | `security-scan: true` (was already opt-in) |

```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    with:
      scan-engine: 'gitleaks'
    secrets: inherit   # GITLEAKS_LICENSE
```

**Licence:** `gitleaks/gitleaks-action` needs a `GITLEAKS_LICENSE` (free from
[gitleaks.io](https://gitleaks.io)) in repositories owned by an organization; personal
repositories need none. Store it as an Actions secret **and**, if Dependabot opens pull
requests in the repository, as a **Dependabot** secret
(*Settings → Secrets and variables → Dependabot*) — Dependabot-triggered runs read only
that store. See [Secrets Reference](../secrets-reference.md#security-scanning).

**Pull requests:** gitleaks-action lists a pull request's commits through the API, which
needs `pull-requests: read`. `modules-security-scan.yml` cannot pass that scope (a called
workflow can only narrow the caller's token), so the `security-scan` action detects the
missing scope and scans the same commits with the gitleaks CLI instead. Those runs -
Dependabot's included - need **no** licence. Where the token does carry the scope (for
example `modules-pr-validation.yml`), gitleaks-action runs as before. Details:
[How Gitleaks scans each event](../workflows/modules-security-scan.md#how-gitleaks-scans-each-event).

With Gitleaks off, the scans do not fail or report "not scanned" because of it: the run
shows a notice, and the summaries say *disabled - Gitleaks is opt-in* instead of a clean
secret result. The security score then covers dependencies (Trivy) only.

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
- [`modules-security-scan.yml`](../workflows/modules-security-scan.md) — Trivy + Gitleaks (opt-in)
