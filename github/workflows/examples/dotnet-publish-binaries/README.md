# .NET Binary Publishing Examples

Example workflows for building and publishing .NET applications as self-contained single-file binaries per RID, with the archives attached to a GitHub Release.

## Examples

### [basic-binaries.yml](basic-binaries.yml)

Minimal workflow. Builds 3 binaries (default RIDs: `linux-x64`, `linux-arm64`, `win-x64`) and uploads them to a Release tagged `v<version>`. Triggered via `workflow_dispatch` with a `version` input.

```yaml
uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@main
with:
  project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
  assembly-name: 'myapp'
  version: ${{ inputs.version }}
```

### [release-workflow.yml](release-workflow.yml)

Full CI/CD pipeline with semantic-release integration:

1. PR validation (build + test) via `dotnet-build.yml`
2. Semantic release creation on main (conventional commits drive the version bump)
3. Self-contained binaries published per RID, attached to the created Release

### [with-generated-sources.yml](with-generated-sources.yml)

Same as `release-workflow.yml`, plus a `prepare-sources` job that generates a Kiota OpenAPI client **once** and feeds every RID job via an artifact. Eliminates redundant per-RID codegen work — important when the generator runs for 10s+ each time.

```yaml
download-artifact-name: 'cli-generated-sources'
download-artifact-path: 'src/MyApp.CLI/Generated'
extra-msbuild-properties: '-p:KiotaSkip=true -p:PackAsTool=false'
```

### [custom-platforms.yml](custom-platforms.yml)

Override the default 3-RID matrix with a 7-RID configuration covering macOS (Apple Silicon + Intel), Windows ARM64, and Alpine Linux (musl).

```yaml
platforms: |
  [
    { "rid": "linux-x64",       "os": "ubuntu-latest",  "archive": "tar" },
    { "rid": "linux-arm64",     "os": "ubuntu-latest",  "archive": "tar" },
    { "rid": "linux-musl-x64",  "os": "ubuntu-latest",  "archive": "tar" },
    { "rid": "win-x64",         "os": "windows-latest", "archive": "zip" },
    { "rid": "win-arm64",       "os": "windows-latest", "archive": "zip" },
    { "rid": "osx-arm64",       "os": "macos-latest",   "archive": "tar" },
    { "rid": "osx-x64",         "os": "macos-13",       "archive": "tar" }
  ]
```

### [optimized-binary.yml](optimized-binary.yml)

Maximum optimization: trimming + ReadyToRun + compression + `.pdb` inclusion. Read the trade-off notes inside the file before enabling — `publish-trimmed` can strip reflection-only types and break the binary silently.

### [combined-tool-and-binaries.yml](combined-tool-and-binaries.yml)

Ship the CLI **two ways** from one release pipeline:

1. As a `dotnet tool install -g`-able NuGet package via [`dotnet-publish-library.yml`](../../../../docs/workflows/dotnet-publish-library.md)
2. As self-contained per-platform binaries via `dotnet-publish-binaries.yml`

Both consume the same semantic-release version and attach to the same `vX.Y.Z` tag. The user picks the install path that fits their environment.

## Default Platform Matrix

The workflow defaults to 3 RIDs covering the realistic majority of CLI / app audiences:

| RID | Runner | Archive |
|-----|--------|---------|
| `linux-x64` | `ubuntu-latest` | `.tar.gz` |
| `linux-arm64` | `ubuntu-latest` | `.tar.gz` |
| `win-x64` | `windows-latest` | `.zip` |

Opt-in RIDs (see [custom-platforms.yml](custom-platforms.yml)):

- `win-arm64` — Surface Pro X, Copilot+ PCs
- `osx-arm64` — Apple Silicon Macs
- `osx-x64` — Intel Macs (needs `macos-13` runner)
- `linux-musl-x64` / `linux-musl-arm64` — Alpine Linux, static linking

> **Why macOS is opt-in:** GitHub-hosted macOS runners cost ~10x as many Action minutes as Linux runners on private repos. Default-on would be a significant cost decision per release.

## Features

All examples produce:

- Self-contained single-file binaries (no .NET runtime on target machine)
- Compressed bundle (`EnableCompressionInSingleFile=true` by default)
- SHA-256 checksum file per archive (`sha256sum -c` compatible format)
- LICENSE + README staged alongside the binary in the archive
- Per-RID workflow artifact (14-day retention) — independent of the Release upload

## Outputs

Access publish information in subsequent jobs:

```yaml
post-publish:
  needs: publish-binaries
  steps:
    - run: |
        echo "Version: ${{ needs.publish-binaries.outputs.version }}"
        echo "Tag: ${{ needs.publish-binaries.outputs.release-tag }}"
        echo "RIDs attempted: ${{ needs.publish-binaries.outputs.published-platforms }}"
```

## Hash Verification for Consumers

Each archive ships with a `.sha256` sidecar in `sha256sum -c` format. Document verification in your release notes:

```bash
# Linux / macOS
sha256sum -c myapp-1.2.3-linux-x64.tar.gz.sha256

# Windows PowerShell
(Get-FileHash -Algorithm SHA256 .\myapp-1.2.3-win-x64.zip).Hash -eq `
  (Get-Content .\myapp-1.2.3-win-x64.zip.sha256).Split(' ')[0]
```

## Related

- [dotnet-publish-binaries.yml](../../../../.github/workflows/dotnet-publish-binaries.yml) — reusable workflow
- [Full Documentation](../../../../docs/workflows/dotnet-publish-binaries.md) — input reference, troubleshooting, best practices
- [dotnet-publish-library.yml](../../../../.github/workflows/dotnet-publish-library.yml) — sibling workflow for NuGet packages (libraries + tools)
- [dotnet-build.yml](../../../../.github/workflows/dotnet-build.yml) — build + test only (no publish)
