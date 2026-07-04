# CodeQL Analysis Module

First-class [CodeQL](https://codeql.github.com/) static analysis (SAST) as a reusable workflow.

## Overview

Until now the repo only used `codeql-action/upload-sarif` to push *other* tools' results to
the Security tab. This module runs **CodeQL analysis itself** — GitHub's semantic code
analysis engine that finds injection flaws, unsafe deserialization, path traversal, and
hundreds of other source-level vulnerabilities.

> **Intended for downstream product repositories.** The automation-templates repo is mostly
> YAML/shell and gains little from CodeQL. Consume this module from repos that ship real
> application code.

- **Multi-language** — one matrix job per language
- **Build modes** — `none` (interpreted langs), `autobuild`, or `manual`
- **Query suites** — `default`, `security-extended` (default), `security-and-quality`
- **Native SARIF** — results go straight to Security tab → Code scanning

## Quick Start

> **Copy-paste example:** [`github/workflows/examples/security/codeql-analysis.yml`](../../github/workflows/examples/security/codeql-analysis.yml)

```yaml
name: CodeQL
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 4 * * 1'

jobs:
  codeql:
    uses: bauer-group/automation-templates/.github/workflows/modules-codeql.yml@main
    with:
      languages: 'javascript-typescript,python'
```

### Compiled language with autobuild

```yaml
jobs:
  codeql:
    uses: bauer-group/automation-templates/.github/workflows/modules-codeql.yml@main
    with:
      languages: 'java-kotlin,csharp'
      build-mode: 'autobuild'
      queries: 'security-and-quality'
```

## Input Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `languages` | Comma-separated CodeQL languages (required) | — |
| `build-mode` | `none`, `autobuild`, or `manual` | `'none'` |
| `queries` | `default`, `security-extended`, `security-and-quality` | `'security-extended'` |
| `config-file` | Path to a custom CodeQL config | `''` |
| `fail-on-findings` | Fail if analysis does not complete for all languages | `false` |
| `runs-on` | Runner (string or JSON array for self-hosted) | `'ubuntu-latest'` |

**Supported `languages` values:** `actions`, `cpp`, `csharp`, `go`, `java-kotlin`,
`javascript-typescript`, `python`, `ruby`, `rust`, `swift`.

## Outputs

| Output | Description |
|--------|-------------|
| `analysis-complete` | Whether analysis completed for all languages (`'true'`/`'false'`) |

## Notes

- **Permissions:** the module declares `security-events: write` — required to upload results.
- **Private repos** need GitHub Advanced Security for code scanning.
- Findings are viewed in **Security tab → Code scanning**, not as workflow outputs.

## References

- [CodeQL documentation](https://codeql.github.com/docs/)
- [CodeQL Action](https://github.com/github/codeql-action)
- [Supported languages & build modes](https://docs.github.com/en/code-security/code-scanning/creating-an-advanced-setup-for-code-scanning/codeql-code-scanning-for-compiled-languages)
