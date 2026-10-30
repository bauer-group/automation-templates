# 📜 SBOM Attestation

## Overview

The **`sbom-attest`** action creates a Sigstore-signed GitHub attestation for an SBOM. What the attestation is *about* depends on whether you name the artifact the SBOM describes:

| Mode | Inputs | Attestation | Answers |
|------|--------|-------------|---------|
| **image** | `subject-name` + `subject-digest` | SBOM attestation, subject = image digest, predicate = SBOM | "Which components does this image contain?" |
| **file** | neither | Build provenance, subject = the SBOM file | "Was this SBOM file produced by this workflow?" |

Use **image** mode whenever there is a pushed image: it is the only mode that `gh attestation verify oci://…` can find. **file** mode suits an SBOM published as a release asset, where the file itself is what consumers download and verify.

Attestations are stored in GitHub's attestation store and can be verified with `gh attestation verify`.

## Features

- ✅ **GitHub-native**: Uses `actions/attest@v4` — no external tooling
- ✅ **Keyless signing**: Sigstore OIDC via GitHub Actions identity
- ✅ **Binds SBOM to image**: image mode attests the pushed digest, not just the file
- ✅ **CycloneDX + SPDX**: Supports both SBOM formats
- ✅ **Validation**: Checks the SBOM is valid JSON and that the subject is complete before attesting
- ✅ **Summary output**: Attestation kind, subject, ID and verification command in the step summary

## Quick Start

### Attest the SBOM for a pushed image

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write        # push the image (and, with push-to-registry, the attestation)
      id-token: write
      attestations: write    # Required!
    steps:
      # ... build and push, e.g. with docker/build-push-action (id: build)

      - name: 📋 Generate SBOM
        run: syft ghcr.io/org/image:1.2.3 -o cyclonedx-json --file sbom.cdx.json

      - name: 📜 Attest SBOM
        uses: bauer-group/automation-templates/.github/actions/sbom-attest@main
        with:
          sbom-path: sbom.cdx.json
          subject-name: ghcr.io/org/image          # no tag
          subject-digest: ${{ steps.build.outputs.digest }}
```

`docker-build.yml` does this for you with `generate-sbom: true` and `attest-sbom: true`.

### Provenance for an SBOM file (release asset)

```yaml
      - name: 📜 Attest SBOM file
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
| `sbom-path` | **Yes** | — | Path to the SBOM file (CycloneDX or SPDX JSON) |
| `sbom-format` | No | `cyclonedx-json` | Shown in the step summary only; `actions/attest` detects the format from the file |
| `subject-name` | No | — | Fully-qualified image name **without tag** (e.g. `ghcr.io/org/image`). Set together with `subject-digest` |
| `subject-digest` | No | — | Digest of the pushed image, `sha256:<64 hex>`. Set together with `subject-name` |
| `push-to-registry` | No | `false` | Also store the attestation in the registry next to the image (image mode only; needs registry write access) |

Setting only one of `subject-name` / `subject-digest` is an error rather than a silent fallback to file mode.

## Outputs

| Output | Description |
|--------|-------------|
| `attestation-id` | GitHub attestation ID (empty if skipped) |
| `attested` | Whether attestation was created (`true`/`false`) |
| `mode` | `image` or `file` |

## Prerequisites

The calling workflow **must** have these permissions:

```yaml
permissions:
  id-token: write       # For Sigstore OIDC token
  attestations: write   # For creating attestations
```

`push-to-registry: true` additionally needs write access to the registry (`packages: write` for GHCR). No artifact storage record is created, so `artifact-metadata: write` is not needed.

## Verification

```bash
# image mode: verify the image, by tag or digest
gh attestation verify oci://ghcr.io/org/image:1.2.3 --repo your-org/your-repo

# file mode: verify the downloaded SBOM file
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
- [actions/attest](https://github.com/actions/attest)
- [Sigstore](https://sigstore.dev)
- [CRA Art. 10 Abs. 12](https://eur-lex.europa.eu/eli/reg/2024/2847) — Integrity of security updates
