# 📜 SBOM Attestation

## Overview

The **`sbom-attest`** action creates a cryptographic attestation for an SBOM file using GitHub's built-in attestation infrastructure (Sigstore-based). This provides verifiable provenance proving the SBOM was generated in a specific workflow run, by a specific actor, from a specific commit.

Attestations are stored in GitHub's attestation store and can be verified with `gh attestation verify`.

## Features

- ✅ **GitHub-native**: Uses `actions/attest-sbom@v4` — no external tooling
- ✅ **Keyless signing**: Sigstore OIDC via GitHub Actions identity
- ✅ **Verifiable**: `gh attestation verify <file> --repo <owner/repo>`
- ✅ **CycloneDX + SPDX**: Supports both SBOM formats
- ✅ **Validation**: Checks SBOM file exists and is valid JSON before attesting
- ✅ **Summary output**: Attestation ID and verification command in step summary

## Quick Start

### Basic Usage

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      id-token: write
      attestations: write    # Required!
    steps:
      - uses: actions/checkout@v6

      - name: 📋 Generate SBOM
        run: trivy fs --format cyclonedx --output sbom.cdx.json .

      - name: 📜 Attest SBOM
        uses: bauer-group/automation-templates/.github/actions/sbom-attest@main
        with:
          sbom-path: sbom.cdx.json
```

### With Cosign Signing (Belt + Suspenders)

```yaml
      # Cosign signature (portable, works outside GitHub)
      - name: 🔏 Sign SBOM with Cosign
        uses: bauer-group/SEC-CRACompliance/.github/actions/cra-sbom-sign@main
        with:
          sbom-path: sbom.cdx.json

      # GitHub attestation (native, verifiable via gh CLI)
      - name: 📜 Attest SBOM
        uses: bauer-group/automation-templates/.github/actions/sbom-attest@main
        with:
          sbom-path: sbom.cdx.json
```

### In a CRA Release Pipeline

```yaml
jobs:
  cra-release:
    uses: bauer-group/SEC-CRACompliance/.github/workflows/cra-release.yml@main
    with:
      attest-sbom: true     # Enabled by default
      sign-sbom: true       # Cosign signing (also default)
    permissions:
      contents: write
      id-token: write
      attestations: write   # Required for attestation
      security-events: write
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `sbom-path` | **Yes** | — | Path to the SBOM file to attest |
| `sbom-format` | No | `cyclonedx-json` | SBOM format: `cyclonedx-json` or `spdx-json` |

## Outputs

| Output | Description |
|--------|-------------|
| `attestation-id` | GitHub attestation ID (empty if skipped) |
| `attested` | Whether attestation was created (`true`/`false`) |

## Prerequisites

The calling workflow **must** have these permissions:

```yaml
permissions:
  id-token: write       # For Sigstore OIDC token
  attestations: write   # For creating attestations
```

Without `attestations: write`, the action will fail silently.

## Verification

After a release, verify the attestation:

```bash
# Verify locally
gh attestation verify sbom.cdx.json --repo your-org/your-repo

# Verify from a release download
gh release download v1.0.0 --pattern 'sbom.cdx.json' --repo your-org/your-repo
gh attestation verify sbom.cdx.json --repo your-org/your-repo
```

## Cosign vs. GitHub Attestation

Both sign SBOM files, but serve different purposes:

| Feature | Cosign | GitHub Attestation |
|---------|--------|--------------------|
| **Portability** | Works anywhere (CLI) | GitHub-only |
| **Verification** | `cosign verify-blob` | `gh attestation verify` |
| **Storage** | `.sig` + `.cert` files | GitHub attestation store |
| **Key management** | Keyless (Sigstore) | Keyless (Sigstore via GitHub) |
| **Audit trail** | Rekor transparency log | GitHub audit log |

**Recommendation:** Use both for defense-in-depth. Cosign for portable verification, GitHub attestation for native integration.

## References

- [GitHub Artifact Attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations)
- [actions/attest-sbom](https://github.com/actions/attest-sbom)
- [Sigstore](https://sigstore.dev)
- [CRA Art. 10 Abs. 12](https://eur-lex.europa.eu/eli/reg/2024/2847) — Integrity of security updates
