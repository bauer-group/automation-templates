# .NET Binary Publishing Workflow

This document describes the .NET binary publishing system provided by the automation-templates repository. The workflow builds self-contained, single-file .NET applications for one or more runtime identifiers (RIDs) in parallel and uploads the resulting archives — together with SHA-256 checksums — to a GitHub Release.

## Overview

The .NET binary publishing system provides:

- **Reusable Workflow**: Single entry point for cross-platform CLI / app binary releases
- **Configurable RID Matrix**: Defaults to `linux-x64`, `linux-arm64`, `win-x64` — opt-in for macOS / `win-arm64` / musl / niche RIDs
- **Self-Contained Builds**: No .NET runtime required on target machines
- **Single-File Bundles**: One executable per platform, with optional compression and trimming
- **Cross-Platform Archives**: `.tar.gz` for Linux/macOS, `.zip` for Windows
- **SHA-256 Checksums**: Computed via PowerShell-Core (single cross-platform implementation, `sha256sum -c` compatible)
- **Pre-Build Artifact Hook**: Download generated sources (Kiota / OpenAPI / T4) once upstream, fan out to every RID job
- **GitHub Release Upload**: Idempotent via `--clobber`, runs after semantic-release tagged the commit
- **Workflow Artifacts**: Archives are also kept as workflow artifacts (14d retention) for forensic access
- **MSBuild Property Escape**: Plumb arbitrary `-p:Key=Value` properties (signing, codegen toggles, custom flags)

> **Sibling workflow:** [`dotnet-publish-library.yml`](./dotnet-publish-library.md) packs and pushes NuGet packages (libraries **and** `PackAsTool` tool packages). The binaries workflow is **not** a NuGet workflow — use both side-by-side when shipping a CLI as both a `dotnet tool install --global` *and* a standalone download.

## Quick Start

### Basic Usage

Minimal caller — uses all defaults (3 RIDs, single-file, self-contained, SHA-256, upload to `v<version>` Release):

```yaml
name: Publish Binaries

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to embed and tag to upload to'
        required: true

permissions:
  contents: write

jobs:
  publish:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@main
    with:
      project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
      assembly-name: 'myapp'
      version: ${{ inputs.version }}
    secrets: inherit
```

Result on a successful run: 3 archives + 3 `.sha256` files attached to the `v<version>` Release:

```text
myapp-1.2.3-linux-x64.tar.gz       myapp-1.2.3-linux-x64.tar.gz.sha256
myapp-1.2.3-linux-arm64.tar.gz     myapp-1.2.3-linux-arm64.tar.gz.sha256
myapp-1.2.3-win-x64.zip            myapp-1.2.3-win-x64.zip.sha256
```

### With Semantic Release Integration

Typical end-to-end release pipeline. `semantic-release` decides whether to cut a release based on conventional commits; only on success the binary publish runs against the freshly created tag.

```yaml
name: Release & Publish

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      force-release:
        description: 'Force create release'
        type: boolean
        default: false

permissions:
  contents: write

jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'MyApp.slnx'
      run-tests: true

  release:
    needs: validate
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
      force-release: ${{ inputs.force-release || false }}
    secrets: inherit

  publish-binaries:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@main
    with:
      project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
      assembly-name: 'myapp'
      version: ${{ needs.release.outputs.version }}
    secrets: inherit
```

### Combined: Tool Package + Self-Contained Binaries

Ship the CLI two ways from one pipeline — as a `dotnet tool install -g`-able NuGet package **and** as standalone download per platform:

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
    secrets: inherit

  publish-tool:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
      release-version: ${{ needs.release.outputs.version }}
      push-to-github: true   # uploads .nupkg to GitHub Packages
    secrets: inherit

  publish-binaries:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@main
    with:
      project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
      assembly-name: 'myapp'
      version: ${{ needs.release.outputs.version }}
    secrets: inherit
```

The project's `.csproj` must declare `<PackAsTool>true</PackAsTool>` for the tool path — see the [Project Configuration](#project-configuration) section.

> **Tip — shared codegen artifact:** If the project uses build-time codegen (Kiota / OpenAPI / T4), both workflows accept the same `download-artifact-name` / `download-artifact-path` / `extra-msbuild-properties` inputs. Run the generator ONCE in an upstream `prepare-sources` job and fan its output out to both `publish-tool` and `publish-binaries` — see [With Pre-Generated Sources](#with-pre-generated-sources-kiota--openapi--t4) below for the prepare-sources job, then add the same `download-artifact-*` inputs to `publish-tool` as well.

### With Pre-Generated Sources (Kiota / OpenAPI / T4)

When the project needs codegen at build time (e.g., a Kiota-generated API client), generating the sources once in an upstream job and fanning them out via an artifact is dramatically faster than re-running the generator in every RID job:

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit

  prepare-sources:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-dotnet@v5
        with:
          dotnet-version: '10.0.x'
      - run: dotnet tool restore
      - name: Generate Kiota client
        run: |
          dotnet kiota generate \
            --openapi contracts/openapi.json \
            --language CSharp \
            --output src/MyApp.CLI/Generated \
            --namespace-name MyApp.CLI.Generated \
            --class-name MyApiClient \
            --clean-output
      - uses: actions/upload-artifact@v7
        with:
          name: cli-generated-sources
          path: src/MyApp.CLI/Generated/
          retention-days: 1
          if-no-files-found: error

  publish-binaries:
    needs: [release, prepare-sources]
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@main
    with:
      project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
      assembly-name: 'myapp'
      version: ${{ needs.release.outputs.version }}
      download-artifact-name: 'cli-generated-sources'
      download-artifact-path: 'src/MyApp.CLI/Generated'
      extra-msbuild-properties: '-p:KiotaSkip=true -p:PackAsTool=false'
    secrets: inherit
```

The `extra-msbuild-properties` value above tells the project's in-csproj Kiota MSBuild target to no-op (generated sources are already on disk) and disables `PackAsTool` semantics for the per-RID publish (we want self-contained binaries, not a tool-bundled IL package).

### Custom Platform Matrix

Override the default to ship additional / fewer RIDs. Each platform entry is `{ "rid", "os", "archive" }`:

```yaml
publish-binaries:
  uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@main
  with:
    project-path: 'src/MyApp.CLI/MyApp.CLI.csproj'
    assembly-name: 'myapp'
    version: ${{ needs.release.outputs.version }}
    platforms: |
      [
        { "rid": "linux-x64",   "os": "ubuntu-latest",  "archive": "tar" },
        { "rid": "linux-arm64", "os": "ubuntu-latest",  "archive": "tar" },
        { "rid": "win-x64",     "os": "windows-latest", "archive": "zip" },
        { "rid": "win-arm64",   "os": "windows-latest", "archive": "zip" },
        { "rid": "osx-arm64",   "os": "macos-latest",   "archive": "tar" }
      ]
  secrets: inherit
```

See [Platform Matrix](#platform-matrix) for the full list of supported / opt-in RIDs.

## Configuration

### Default Platforms

| RID | Runner | Archive | Status | Notes |
|-----|--------|---------|--------|-------|
| `linux-x64` | `ubuntu-latest` | `tar.gz` | **Default** | Server / container dominant architecture |
| `linux-arm64` | `ubuntu-latest` | `tar.gz` | **Default** | Growing fast via AWS Graviton, Ampere, Raspberry Pi 5 |
| `win-x64` | `windows-latest` | `zip` | **Default** | Windows desktop is overwhelmingly Intel / AMD x64 |
| `win-arm64` | `windows-latest` | `zip` | Opt-in | Niche: Surface Pro X, Copilot+ PCs |
| `osx-arm64` | `macos-latest` | `tar.gz` | Opt-in | Apple Silicon — enable for macOS developer audience |
| `osx-x64` | `macos-13` | `tar.gz` | Opt-in | Intel Macs (auto-discontinued on `macos-latest`) — pin runner |
| `linux-musl-x64` | `ubuntu-latest` | `tar.gz` | Opt-in | Alpine Linux / static linking |
| `linux-bionic-arm64` | `ubuntu-latest` | `tar.gz` | Opt-in | Android-compatible glibc fork |

> **Why macOS is opt-in:** GitHub-hosted macOS runners cost ~10x as many Action minutes as Linux runners on private repos. Defaulting them on would be a financially significant decision per release. Callers with a macOS-using audience opt in explicitly.

### Publishing Options

| Goal | Configuration |
|------|---------------|
| Smallest binary | `publish-trimmed: true`, `enable-compression-in-single-file: true` (slower first-launch) |
| Fastest startup | `publish-ready-to-run: true`, `enable-compression-in-single-file: false` |
| Largest compatibility | `publish-trimmed: false` (default) — reflection-only types preserved |
| Debuggable | `include-pdb: true`, `enable-compression-in-single-file: false` |
| Framework-dependent | `self-contained: false`, `publish-single-file: false` — requires .NET runtime on target |

## Input Parameters

### Project Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `project-path` | Path to `.csproj` to publish (single project, not solution) | **Required** |
| `assembly-name` | Output binary name without extension. Must match `<AssemblyName>` in the csproj. | **Required** |
| `version` | Version to embed in the binary (e.g., `1.2.3`). Typically from `needs.release.outputs.version`. | **Required** |
| `working-directory` | Working directory for all commands | `'.'` |
| `configuration` | Build configuration (Debug/Release) | `'Release'` |
| `dotnet-version` | .NET SDK version (e.g., `10.0.x`). Ignored if `global-json-file` is set. | `'10.0.x'` |
| `global-json-file` | Path to `global.json` for pinning the SDK version | `''` |

### Versioning & Release Target

| Parameter | Description | Default |
|-----------|-------------|---------|
| `release-tag` | Git tag name to upload assets to | `'v<version>'` |
| `checkout-ref` | Git ref to checkout for the build | `'refs/tags/<release-tag>'` |

### Platform Matrix

| Parameter | Description | Default |
|-----------|-------------|---------|
| `platforms` | JSON array of `{ rid, os, archive }` objects (see [Platform Matrix](#platform-matrix)) | 3 RIDs (`linux-x64`, `linux-arm64`, `win-x64`) |
| `fail-fast` | Cancel sibling matrix jobs when one platform fails | `false` |

### Publish Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `self-contained` | Produce self-contained binaries (no .NET runtime required on target) | `true` |
| `publish-single-file` | Bundle everything into one executable | `true` |
| `publish-trimmed` | Enable IL trimming (smaller binary; risk of stripping reflected-only types) | `false` |
| `publish-ready-to-run` | AOT-compile to native R2R code (faster startup, larger binary) | `false` |
| `include-native-libraries-for-self-extract` | Embed native libraries inside the single-file bundle | `true` |
| `enable-compression-in-single-file` | Compress the single-file bundle | `true` |
| `extra-msbuild-properties` | Additional MSBuild properties appended to `dotnet publish` (e.g., `-p:KiotaSkip=true -p:PackAsTool=false`) | `''` |
| `extra-publish-args` | Raw additional arguments appended to `dotnet publish` | `''` |

### Archive Contents

| Parameter | Description | Default |
|-----------|-------------|---------|
| `archive-name-template` | Archive base name. Tokens: `{assembly}`, `{version}`, `{rid}`. | `'{assembly}-{version}-{rid}'` |
| `include-files` | Newline-separated list of extra files to stage (LICENSE, README, ...). Missing files are silently skipped. | `LICENSE\nREADME.md` |
| `include-pdb` | Include the `.pdb` symbol file alongside the binary | `false` |
| `generate-checksums` | Compute SHA-256 for each archive and upload it as `<archive>.sha256` | `true` |

### Pre-Build Artifact (Optional)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `download-artifact-name` | Name of an artifact produced by an upstream job to download before publish | `''` |
| `download-artifact-path` | Filesystem path the artifact is extracted into (relative to `working-directory`) | `''` |

### Release Upload

| Parameter | Description | Default |
|-----------|-------------|---------|
| `upload-to-release` | Upload archives to the GitHub Release identified by `release-tag` | `true` |
| `release-asset-clobber` | Overwrite existing assets on the Release (`gh release upload --clobber`) | `true` |

### Runner Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `timeout-minutes` | Per-platform job timeout in minutes | `30` |
| `cache-enabled` | Enable NuGet package caching (per-RID cache key) | `true` |

## Secrets

| Secret | Required When | Description |
|--------|---------------|-------------|
| `DOTNET_SIGNKEY_BASE64` | Strong-name signing enabled via `extra-msbuild-properties` | Base64-encoded `.snk` file. The caller is responsible for wiring it into a project property (signing is intentionally not opinionated here — see [Code Signing](#code-signing)). |

> **Note:** The workflow does not require any NuGet-related secret. Binary releases are uploaded to the GitHub Release via the auto-provisioned `GITHUB_TOKEN` (no manual secret configuration).

## Outputs

| Output | Description |
|--------|-------------|
| `version` | Version that was embedded in the binaries (echoes the input) |
| `release-tag` | Tag the assets were uploaded to (resolved from `release-tag` input or defaulted to `v<version>`) |
| `published-count` | Number of platforms in the matrix (regardless of success) |
| `published-platforms` | JSON array of RIDs that were attempted |

## Platform Matrix

Each platform entry has three keys:

| Key | Type | Description |
|-----|------|-------------|
| `rid` | string | .NET runtime identifier (e.g., `linux-x64`, `osx-arm64`). See the [official RID catalog](https://learn.microsoft.com/dotnet/core/rid-catalog). |
| `os` | string | GitHub Actions runner image label (e.g., `ubuntu-latest`, `windows-latest`, `macos-13`) |
| `archive` | string | Archive format: `tar` (produces `.tar.gz`) or `zip` |

### Ready-to-Use Platform Snippets

```jsonc
// Linux
{ "rid": "linux-x64",         "os": "ubuntu-latest",  "archive": "tar" }
{ "rid": "linux-arm64",       "os": "ubuntu-latest",  "archive": "tar" }
{ "rid": "linux-musl-x64",    "os": "ubuntu-latest",  "archive": "tar" }
{ "rid": "linux-musl-arm64",  "os": "ubuntu-latest",  "archive": "tar" }
{ "rid": "linux-bionic-arm64","os": "ubuntu-latest",  "archive": "tar" }

// Windows
{ "rid": "win-x64",   "os": "windows-latest", "archive": "zip" }
{ "rid": "win-arm64", "os": "windows-latest", "archive": "zip" }
{ "rid": "win-x86",   "os": "windows-latest", "archive": "zip" }

// macOS
{ "rid": "osx-arm64", "os": "macos-latest", "archive": "tar" }
{ "rid": "osx-x64",   "os": "macos-13",     "archive": "tar" }   // Intel Macs need pinned runner
```

### Self-Hosted Runners

Each platform entry's `os` field accepts the same runner labels as a normal `runs-on:`. For self-hosted runners, pass a JSON-encoded array:

```yaml
platforms: |
  [
    { "rid": "linux-x64",   "os": "[\"self-hosted\", \"linux\", \"x64\"]",   "archive": "tar" },
    { "rid": "linux-arm64", "os": "[\"self-hosted\", \"linux\", \"arm64\"]", "archive": "tar" }
  ]
```

> **Note:** When using self-hosted runners, also set `cache-enabled: false` — the GitHub Actions cache is not available on self-hosted infrastructure by default.

## Project Configuration

### Required Project Settings

Your `.csproj` should declare the executable name and (if shipping as a tool too) tool semantics:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <AssemblyName>myapp</AssemblyName>
    <RootNamespace>MyApp.CLI</RootNamespace>

    <!-- When ALSO shipping as `dotnet tool install -g`: -->
    <PackAsTool>true</PackAsTool>
    <ToolCommandName>myapp</ToolCommandName>
  </PropertyGroup>

  <!-- Conditional single-file settings — activate only when publishing per-RID -->
  <PropertyGroup Condition="'$(RuntimeIdentifier)' != ''">
    <PublishSingleFile>true</PublishSingleFile>
    <SelfContained>true</SelfContained>
    <IncludeNativeLibrariesForSelfExtract>true</IncludeNativeLibrariesForSelfExtract>
    <EnableCompressionInSingleFile>true</EnableCompressionInSingleFile>
  </PropertyGroup>
</Project>
```

The condition `'$(RuntimeIdentifier)' != ''` ensures the single-file properties are only active during per-RID publish — they are bypassed during `dotnet pack` (tool path) and during local `dotnet build`.

### Conflict: `PackAsTool` vs. `PublishSingleFile`

`PackAsTool` produces an IL-bundled framework-dependent NuGet package; `PublishSingleFile` produces a per-RID native bundle. The two cannot coexist in the same MSBuild invocation. The standard escape:

```yaml
extra-msbuild-properties: '-p:PackAsTool=false'
```

This deactivates tool-pack semantics for the per-RID publish; the tool-pack workflow ([dotnet-publish-library.yml](./dotnet-publish-library.md)) runs separately and leaves `PackAsTool=true` (its default).

## How It Works

The workflow runs two job stages:

### 1. Matrix Publish (`publish`)

For each entry in `platforms`, in parallel:

1. **Resolve tag + ref**: Default `release-tag` to `v<version>`, default `checkout-ref` to `refs/tags/<release-tag>`
2. **Checkout** the exact ref (typically the tag semantic-release just created)
3. **Setup .NET SDK** (honoring `global-json-file` if set)
4. **NuGet cache** keyed per-RID (each RID restores a different native runtime package set)
5. **Download artifact** (optional, between checkout and any `dotnet` invocation — see [MSBuild ordering](#why-must-the-artifact-download-run-before-restore))
6. **Restore** with `--runtime <rid>`
7. **Publish** with `--runtime <rid>`, single-file/self-contained MSBuild properties + caller's `extra-msbuild-properties` / `extra-publish-args`
8. **Stage** the binary + extras (LICENSE/README/...) into a folder named after `archive-name-template`
9. **Archive** (`tar.gz` on Linux/macOS, `zip` on Windows via PowerShell-Core `Compress-Archive`)
10. **Checksum** via PowerShell-Core `Get-FileHash` (single cross-platform implementation, `sha256sum -c` compatible output)
11. **Upload to Release** via `gh release upload <tag> <archive> <sha256> --clobber`
12. **Upload as workflow artifact** (always, even on failure of later steps) — 14-day retention

### 2. Summary (`summary`)

Runs `if: always()` so the GitHub UI gets a step summary even when one RID fails. Renders the platform table + matrix aggregate result.

### Why must the artifact download run before restore?

MSBuild evaluates `<Compile Include="**/*.cs">` **once at project load**. Source files that appear on disk after that moment are not in the compilation. This means: if the Kiota / OpenAPI / T4 generated sources are downloaded *after* `dotnet restore` or `dotnet publish` starts, they will be silently absent from the build — producing a compile error or, worse, silently building an obsolete code path.

The workflow places the artifact-download step strictly between checkout/SDK-setup and the restore step. Do not reorder.

## Code Signing

The workflow exposes signing as a pass-through via `extra-msbuild-properties` rather than baking opinionated signing logic in. This keeps the workflow agnostic to the actual signing toolchain (SignTool for Windows authenticode, `codesign` for macOS, GPG-detached for tarballs, ...).

### Strong-Name Signing (.NET-internal)

```yaml
with:
  extra-msbuild-properties: |
    -p:SignAssembly=true
    -p:AssemblyOriginatorKeyFile=$(MSBuildThisFileDirectory)build/MyApp.snk
secrets:
  DOTNET_SIGNKEY_BASE64: ${{ secrets.DOTNET_SIGNKEY_BASE64 }}
```

Note: The workflow accepts the secret but does **not** auto-decode it — the caller is responsible for any preceding job that writes `MyApp.snk` to the expected path. (Pattern matches `dotnet-publish-library.yml`, which decodes via its dedicated composite action.)

### Authenticode / `codesign` Post-Build

Run a per-platform signing job *after* the binary publish completes, downloading the workflow artifact, signing the unpacked binary, and re-uploading. Don't try to inline platform-specific signing into the matrix — it would balloon the surface area and tightly couple the workflow to one signing provider.

## Best Practices

### 1. Pin to a Tag, Not a Branch

When consuming this workflow from a release pipeline, pin to a semver tag rather than `@main` to avoid surprise breaking changes:

```yaml
uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-binaries.yml@v1.4.0
```

### 2. Default `fail-fast: false`

Keep `fail-fast: false` (the default) so one bad RID (e.g., transient ARM runner outage) doesn't abort the successful builds. You can always re-run just the failed matrix leg.

### 3. Match `assembly-name` Exactly

The workflow assumes `publish/<rid>/<assembly-name>(.exe)?` exists after `dotnet publish`. If `<AssemblyName>` in the `.csproj` differs from the workflow input, the staging step fails with "no such file." Keep them in sync — ideally derive both from the same source of truth.

### 4. Use Pre-Build Sources Artifact for Codegen

If the project uses Kiota / OpenAPI / T4 / similar build-time codegen, run it **once** in an upstream job and feed the matrix via `download-artifact-name`. Per-RID re-generation is 7+ minutes of wasted compute on a 6-RID matrix.

### 5. Include LICENSE and README

The defaults already include `LICENSE` and `README.md`. Keep them — distributing a binary without the license is a compliance risk. Override `include-files` only to *add* (e.g., `THIRD-PARTY-NOTICES.txt`).

### 6. Hash Verification for Users

Document SHA-256 verification in your release notes:

```bash
# Linux / macOS
sha256sum -c myapp-1.2.3-linux-x64.tar.gz.sha256

# Windows PowerShell
(Get-FileHash -Algorithm SHA256 .\myapp-1.2.3-win-x64.zip).Hash -eq `
  (Get-Content .\myapp-1.2.3-win-x64.zip.sha256).Split(' ')[0]
```

### 7. Trimming: Test Before Enabling

`publish-trimmed: true` cuts binary size by ~30–50%, but the trimmer is aggressive — types only accessed via reflection (DI containers, `Newtonsoft.Json` converters, plugin loaders) can be stripped silently. Enable on a feature branch first and run smoke tests against the trimmed binary before turning it on in main.

## Troubleshooting

### "no such file or directory: publish/<rid>/<assembly-name>"

The staging step couldn't find the published binary at the expected path. Causes:

1. **`assembly-name` mismatch**: Verify `<AssemblyName>` in the `.csproj` matches the workflow input exactly (no `.exe` suffix, no `.dll`)
2. **OutputType not `Exe`**: Library projects (`OutputType=Library`) don't produce an executable. Check the `.csproj`.
3. **Conditional publish properties**: If the `.csproj` has `Condition="'$(RuntimeIdentifier)' != ''"` around `<PublishSingleFile>`, ensure no other condition (TFM, Configuration) is also blocking it.

### "asset already exists" on upload

`gh release upload` rejects existing assets unless `--clobber` is passed. The workflow uses `--clobber` by default. If you've set `release-asset-clobber: false`, either:

1. Delete the existing asset manually
2. Bump the version to a fresh tag
3. Re-enable `release-asset-clobber: true`

### Kiota / Generated Sources "type or namespace not found"

Symptoms: the build fails with `CS0246: The type or namespace name 'MyApiClient' could not be found` even though the artifact downloaded successfully.

Cause: the artifact was downloaded *after* the `dotnet restore` or `dotnet publish` step started. MSBuild's `@(Compile)` item group is evaluated once at project load.

Fix: Ensure `download-artifact-name` is set on this workflow's input — it places the download in the correct position (between checkout and restore). Don't try to add a separate download step in the caller; it won't run in time.

### "PackAsTool and PublishSingleFile are mutually exclusive"

The project has `<PackAsTool>true</PackAsTool>` set unconditionally, conflicting with the per-RID single-file publish.

Fix: Add `-p:PackAsTool=false` to `extra-msbuild-properties`:

```yaml
with:
  extra-msbuild-properties: '-p:PackAsTool=false'
```

### macOS Job Times Out

Default `timeout-minutes` is 30. macOS NuGet restore is slow (no native package mirror) — first-run can exceed 30 minutes for large dependency graphs.

Fix: Either increase the timeout or warm the cache via an earlier scheduled run:

```yaml
with:
  timeout-minutes: 45
```

### "Resource not accessible by integration" on `gh release upload`

The job's `GITHUB_TOKEN` lacks `contents: write`. The workflow declares `permissions: contents: write` on the job, but the **caller's** workflow-level permissions can still constrict this.

Fix: At the caller level, set:

```yaml
permissions:
  contents: write
```

### Trimming Strips Required Types

After enabling `publish-trimmed: true`, the binary throws `TypeLoadException` or `MissingMethodException` at runtime.

Fix: Use `<TrimmerRootAssembly Include="ProblematicAssembly" />` in the `.csproj`, or `DynamicallyAccessedMembers` annotations in code, or fall back to `publish-trimmed: false`. The trimmer doc has a [diagnostics warning list](https://learn.microsoft.com/dotnet/core/deploying/trimming/trimming-options) — treat them as errors during the trim-enable rollout.

## Comparison: When to Use What

| Need | Workflow |
|------|----------|
| Library (`.dll`) → NuGet.org | [`dotnet-publish-library.yml`](./dotnet-publish-library.md) |
| CLI tool (`dotnet tool install -g`) | [`dotnet-publish-library.yml`](./dotnet-publish-library.md) (with `<PackAsTool>true</PackAsTool>`) |
| Standalone binary per OS / arch | **`dotnet-publish-binaries.yml`** (this workflow) |
| WPF / WinForms / MAUI desktop app | [`dotnet-desktop-build.yml`](./dotnet-desktop-build.md) |
| Plain build + test (no publish) | [`dotnet-build.yml`](./dotnet-build.md) |

Combine `dotnet-publish-library.yml` + `dotnet-publish-binaries.yml` in one pipeline to ship a CLI as both a NuGet tool and a per-OS download — see [Combined: Tool Package + Self-Contained Binaries](#combined-tool-package--self-contained-binaries).

## Examples

Ready-to-copy caller workflows live under [`github/workflows/examples/dotnet-publish-binaries/`](../../github/workflows/examples/dotnet-publish-binaries/):

| Example | Purpose |
|---------|---------|
| [`basic-binaries.yml`](../../github/workflows/examples/dotnet-publish-binaries/basic-binaries.yml) | Minimal `workflow_dispatch` caller — defaults for everything |
| [`release-workflow.yml`](../../github/workflows/examples/dotnet-publish-binaries/release-workflow.yml) | Full pipeline: PR validation → semantic-release → binary publish |
| [`with-generated-sources.yml`](../../github/workflows/examples/dotnet-publish-binaries/with-generated-sources.yml) | Kiota / OpenAPI codegen fan-out via shared artifact |
| [`custom-platforms.yml`](../../github/workflows/examples/dotnet-publish-binaries/custom-platforms.yml) | 7-RID matrix including macOS, win-arm64, Alpine musl |
| [`optimized-binary.yml`](../../github/workflows/examples/dotnet-publish-binaries/optimized-binary.yml) | Trimming + ReadyToRun + compression (with trade-off notes) |
| [`combined-tool-and-binaries.yml`](../../github/workflows/examples/dotnet-publish-binaries/combined-tool-and-binaries.yml) | Ship as `dotnet tool` **and** standalone binaries from one pipeline |

## Related Workflows

- [`dotnet-publish-library.yml`](./dotnet-publish-library.md): Pack and push NuGet packages (libraries and tools)
- [`dotnet-build.yml`](./dotnet-build.md): Build and test workflow without publishing
- [`dotnet-desktop-build.yml`](./dotnet-desktop-build.md): Desktop application builds (WPF, WinForms, MAUI, MSIX)
- [`modules-semantic-release.yml`](./modules-semantic-release.md): Semantic versioning and release tag creation

## Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
