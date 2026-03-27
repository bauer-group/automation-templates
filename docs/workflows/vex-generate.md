# 📋 OpenVEX Document Generation

## Overview

The **`vex-generate`** action creates [OpenVEX](https://github.com/openvex/spec) (Vulnerability Exploitability eXchange) documents from vulnerability scan results. It auto-generates `under_investigation` statements for all discovered CVEs and merges optional manual triage overrides maintained by the security team.

OpenVEX documents answer the question: *"Is this vulnerability actually exploitable in my product?"* — essential for CRA compliance (Annex I Part II) and effective vulnerability communication.

## Features

- ✅ **Auto-generation**: Creates VEX statements from Trivy JSON scan output
- ✅ **Manual triage**: Merges team-maintained override decisions (not_affected, affected, fixed)
- ✅ **Zero dependencies**: Pure `jq`-based, no `vexctl` binary required
- ✅ **OpenVEX v0.2.0**: Follows the official OpenVEX specification
- ✅ **Product auto-detection**: Derives product ID from GitHub repository context
- ✅ **Merge semantics**: Manual overrides take precedence over auto-generated statements
- ✅ **Summary output**: GitHub Step Summary with statement counts

## Quick Start

### Basic Usage

```yaml
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: 🛡️ Vulnerability Scan
        id: scan
        uses: aquasecurity/trivy-action@0.33.1
        with:
          scan-type: fs
          format: json
          output: vulnerability-report.json

      - name: 📋 Generate VEX
        uses: bauer-group/automation-templates/.github/actions/vex-generate@main
        with:
          vulnerability-report: vulnerability-report.json
```

### With Manual Triage Overrides

```yaml
      - name: 📋 Generate VEX
        uses: bauer-group/automation-templates/.github/actions/vex-generate@main
        with:
          vulnerability-report: vulnerability-report.json
          vex-overrides: security/vex-overrides.json
          product-id: 'pkg:npm/@myorg/mypackage'
```

### In a CRA Release Pipeline

```yaml
jobs:
  cra-release:
    uses: bauer-group/SEC-CRACompliance/.github/workflows/cra-release.yml@main
    with:
      generate-vex: true
      vex-overrides: security/vex-overrides.json
    permissions:
      contents: write
      id-token: write
      attestations: write
      security-events: write
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `vulnerability-report` | No | `vulnerability-report.json` | Path to Trivy JSON vulnerability report |
| `vex-overrides` | No | `security/vex-overrides.json` | Path to manual VEX triage overrides file |
| `output-file` | No | `vex.openvex.json` | Output filename for the VEX document |
| `product-id` | No | Auto-detected | Product identifier (e.g., `pkg:github/owner/repo`) |
| `author-name` | No | `BAUER GROUP Automation` | VEX document author |

## Outputs

| Output | Description |
|--------|-------------|
| `vex-path` | Absolute path to the generated VEX document |
| `total-statements` | Total number of VEX statements |
| `override-count` | Number of manual override statements merged |
| `auto-generated-count` | Number of auto-generated `under_investigation` statements |

## Manual Triage Overrides

Create a `security/vex-overrides.json` in your repository to document triage decisions:

```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://github.com/your-org/your-repo/vex/overrides",
  "author": "Security Team",
  "role": "Document Author",
  "timestamp": "2026-01-01T00:00:00Z",
  "version": 1,
  "statements": [
    {
      "vulnerability": { "@id": "CVE-2024-1234" },
      "products": [{ "@id": "pkg:github/your-org/your-repo" }],
      "status": "not_affected",
      "justification": "vulnerable_code_not_in_execute_path",
      "impact_statement": "The affected function is never called in our codebase."
    }
  ]
}
```

### VEX Status Values

| Status | Meaning |
|--------|---------|
| `not_affected` | Vulnerability exists in dependency but is not exploitable in this product |
| `affected` | Vulnerability is exploitable — remediation required |
| `fixed` | Vulnerability has been remediated |
| `under_investigation` | Assessment pending (auto-generated default) |

## Output Format

The generated `vex.openvex.json` follows OpenVEX v0.2.0:

```json
{
  "@context": "https://openvex.dev/ns/v0.2.0",
  "@id": "https://github.com/your-org/your-repo/vex/abc12345",
  "author": "BAUER GROUP Automation",
  "role": "Document Author",
  "timestamp": "2026-03-28T10:00:00Z",
  "version": 1,
  "statements": [
    {
      "vulnerability": { "@id": "CVE-2024-5678" },
      "products": [{ "@id": "pkg:github/your-org/your-repo" }],
      "status": "under_investigation",
      "timestamp": "2026-03-28T10:00:00Z"
    }
  ]
}
```

## References

- [OpenVEX Specification](https://github.com/openvex/spec)
- [CISA VEX Use Cases](https://www.cisa.gov/sbom)
- [CRA Annex I Part II No. 2](https://eur-lex.europa.eu/eli/reg/2024/2847) — Vulnerability handling
