# .NET MSI Packaging Workflow

Package a published .NET application as a classic Windows Installer (`.msi`), sign it, and attach it to a GitHub Release.

## Overview

`dotnet-desktop-build.yml` can already produce an MSIX package, but MSIX is not a substitute in an industrial setting. It expects a signed package and a modern deployment story; shop-floor customers install per-machine from a file share, often onto locked-down images, and expect a plain `msiexec /i ... /qn` with a real upgrade code and a clean uninstall. This workflow produces exactly that.

It is deliberately a **standalone module** rather than more inputs on the desktop build: MSI authoring is its own concern, and consuming the published output of any earlier job keeps it usable with `dotnet-publish-binaries.yml`, `dotnet-desktop-build.yml`, or a hand-written publish step.

- **Three authoring shapes**: a `.wixproj`, a bare `.wxs`, or no WiX authoring at all
- **Per-machine install** into Program Files, with `MajorUpgrade` wired up
- **Optional Start Menu shortcut** without writing any XML
- **Authenticode signing** with an RFC 3161 timestamp, verified after signing
- **SHA-256 checksum** in `sha256sum -c` format
- **Release upload**, idempotent via `--clobber`

> **Siblings:** [`dotnet-publish-binaries.yml`](./dotnet-publish-binaries.md) produces the self-contained binaries this workflow packages. [`dotnet-publish-library.yml`](./dotnet-publish-library.md) publishes NuGet packages.

## Quick Start

No WiX authoring required — leave `wix-project-path` empty and the generated template installs the whole published folder:

```yaml
name: Package MSI

on:
  release:
    types: [ published ]

permissions:
  contents: read

jobs:
  publish:
    name: Publish win-x64
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-dotnet@v5
        with:
          dotnet-version: '8.0.x'
      - shell: bash
        run: |
          dotnet publish src/MyApp/MyApp.csproj \
            --configuration Release --runtime win-x64 --self-contained true \
            --output publish -p:PublishSingleFile=true
      - uses: actions/upload-artifact@v7
        with:
          name: app-win-x64
          path: publish

  msi:
    needs: publish
    permissions:
      contents: write
    uses: bauer-group/automation-templates/.github/workflows/dotnet-package-msi.yml@main
    with:
      source-artifact-name: 'app-win-x64'
      product-name: 'MyApp'
      manufacturer: 'BAUER GROUP'
      version: ${{ github.event.release.tag_name }}
      upgrade-code: '3f2504e0-4f89-41d3-9a0c-0305e82c3301'
      main-executable: 'MyApp.exe'
      create-shortcut: true
      sign-msi: true
      upload-to-release: true
    secrets: inherit
```

## The upgrade code

`upgrade-code` is the single most important input, and the one that is silently destructive to get wrong.

It is a GUID identifying **the product across all of its versions**. Windows Installer uses it to recognise that a new `.msi` replaces the installed one. Change it between releases — or let each build generate a fresh one — and every version installs *beside* the previous one instead of upgrading it, until the machine is full of copies and uninstalling becomes a manual archaeology exercise.

Generate it **once**, commit it to the workflow, and never touch it again:

```powershell
New-Guid
```

There is no safe default, so the workflow refuses to use the generated template without one.

## Versions

An MSI `ProductVersion` is **not** a semantic version:

| Constraint | Consequence |
|------------|-------------|
| `major.minor.build[.revision]`, numeric only | `1.2.3-rc.1` is not a legal ProductVersion |
| major ≤ 255, minor ≤ 255, build ≤ 65535 | A CalVer such as `20260825.1.0` overflows `major` |
| the **fourth field is ignored** when comparing versions | `1.2.3.4` and `1.2.3.9` are the same product to Windows Installer |

The workflow normalises and validates before WiX ever sees the value:

| Input `version` | Embedded ProductVersion | File name | Result |
|-----------------|------------------------|-----------|--------|
| `1.2.3` | `1.2.3` | `MyApp-1.2.3-x64.msi` | clean |
| `v1.2.3` | `1.2.3` | `MyApp-1.2.3-x64.msi` | leading `v` stripped |
| `1.2` | `1.2.0` | `MyApp-1.2-x64.msi` | padded |
| `1.2.3-rc.1` | `1.2.3` | `MyApp-1.2.3-rc.1-x64.msi` | **warning** — see below |
| `20260825.1.0` | — | — | **fails**, naming the 255 limit |

A prerelease suffix is accepted but cannot be carried in an MSI. The full version stays in the file name, and the run logs a warning: two builds differing only in their prerelease suffix are **indistinguishable to Windows Installer** and will not upgrade one another. That is worth knowing before a rollout rather than during one.

## Authoring shapes

### Generated template (`wix-project-path` empty)

Installs the entire `source-path` folder per-machine under `Program Files\<product-name>`, with `MajorUpgrade` configured and an optional Start Menu shortcut. Right for a self-contained or single-file application that just needs to land on disk.

### Bare `.wxs`

Point `wix-project-path` at a `.wxs` and it is built with `wix build`. Preprocessor variables come from `preprocessor-variables` as newline-separated `name=value` pairs:

```yaml
with:
  wix-project-path: 'installer/Package.wxs'
  preprocessor-variables: |
    ProductName=MyApp
    PublishDir=publish
    ServiceAccount=LocalSystem
```

### `.wixproj`

Point `wix-project-path` at a `.wixproj` and it is built with `dotnet build` via `WixToolset.Sdk`. Right for a Windows service, custom actions, or a UI sequence.

The project keeps ownership of its own `DefineConstants`; the workflow passes plain MSBuild properties for it to map in. (Passing `-p:DefineConstants=` from the command line would *overwrite* whatever the project defines, which is why it does not.)

```xml
<Project Sdk="WixToolset.Sdk/7.0.0">
  <PropertyGroup>
    <OutputName>MyApp</OutputName>
    <OutputType>Package</OutputType>
    <DefineConstants>
      ProductName=$(ProductName);
      Manufacturer=$(Manufacturer);
      ProductVersion=$(ProductVersion);
      UpgradeCode=$(UpgradeCode);
      PublishDir=$(PublishDir)
    </DefineConstants>
  </PropertyGroup>
</Project>
```

## WiX version and the Open Source Maintenance Fee

`wix-version` defaults to `7.0.0` and is **pinned deliberately**. A floating version silently rolled repositories from v6 to v7 and broke their builds with `WIX7015`.

WiX v7 and later refuse to run at all unless the [Open Source Maintenance Fee](https://wixtoolset.org/osmf/) EULA is accepted. With `accept-eula: true` (the default) the workflow passes `--acceptEula` on the CLI path and `-p:AcceptEula` on the MSBuild path — **which means the pipeline performs that acceptance on your organisation's behalf on every run**. The fee applies above a US$10,000 annual revenue threshold.

To avoid that, pin to a 6.x release, which has no acceptance gate:

```yaml
with:
  wix-version: '6.0.2'
  accept-eula: false
```

Setting `accept-eula: false` while on v7 produces an explanation rather than a raw `WIX7015`.

## Signing

| Input / secret | Purpose |
|----------------|---------|
| `sign-msi` | Enable signing |
| `DOTNET_SIGNING_CERTIFICATE_BASE64` | Base64-encoded PFX. Takes precedence. |
| `DOTNET_SIGNING_CERTIFICATE_PASSWORD` | PFX password |
| `certificate-subject` | Subject of a certificate already in the machine store, used when no PFX is supplied |
| `timestamp-server` | RFC 3161 timestamp URL (default DigiCert) |

`signtool` is resolved from the installed Windows SDK rather than assumed to be on `PATH`, and the signature is **verified** after signing. An MSI that signs but does not verify is rejected on any machine with SmartScreen or WDAC enabled — better to fail in CI than at a customer.

The PFX is written to `RUNNER_TEMP`, used, and removed in a `finally` block so it does not survive a failed run.

## Input Parameters

### What to package

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `source-artifact-name` | string | `''` | Artifact from an upstream job holding the published application |
| `source-path` | string | `publish` | Directory holding the files to package; the artifact is extracted here |

### Product identity

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `product-name` | string | *required* | Shown in Add/Remove Programs; used as the install folder name |
| `version` | string | *required* | See [Versions](#versions) |
| `manufacturer` | string | repository owner | Shown in Add/Remove Programs |
| `upgrade-code` | string | `''` | See [The upgrade code](#the-upgrade-code) |
| `architecture` | string | `x64` | `x64`, `x86` or `arm64` |

### Authoring

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `wix-project-path` | string | `''` | `.wixproj`, `.wxs`, or empty for the generated template |
| `main-executable` | string | `''` | Shortcut target; generated template only |
| `create-shortcut` | boolean | `false` | Add a Start Menu shortcut; requires `main-executable` |
| `preprocessor-variables` | string | `''` | Newline-separated `name=value` pairs passed as `-d` |
| `msbuild-properties` | string | `''` | Extra properties for the `.wixproj` path |
| `wix-extensions` | string | `''` | Whitespace-separated extensions, cached **and** referenced with `-ext` |
| `wix-version` | string | `7.0.0` | Pinned WiX Toolset version |
| `accept-eula` | boolean | `true` | See [WiX version and the Open Source Maintenance Fee](#wix-version-and-the-open-source-maintenance-fee) |
| `dotnet-version` | string | `8.0.x` | SDK used for the WiX tool and `.wixproj` builds |

### Output

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `output-name` | string | `''` | File name without extension; default `<product>-<version>-<arch>` |
| `artifact-name` | string | `msi-package` | Workflow artifact name |
| `artifact-retention-days` | number | `30` | Artifact retention |
| `upload-to-release` | boolean | `false` | Attach `.msi` and `.sha256` to a Release |
| `release-tag` | string | `''` | Defaults to `v<version>` |

### Runner

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `runs-on` | string | `windows-latest` | Must be Windows. JSON array for self-hosted. |
| `timeout-minutes` | number | `30` | Job timeout |

## Outputs

| Output | Description |
|--------|-------------|
| `msi-name` | File name of the produced `.msi` |
| `product-version` | ProductVersion actually embedded |
| `sha256` | SHA-256 checksum of the `.msi` |

## Permissions

The job declares `contents: write` because `gh release upload` needs it. A workflow cannot vary its permissions by input, and a reusable workflow requesting a scope its caller withholds makes GitHub refuse to start the run at all — so it is declared unconditionally. Callers that never upload to a Release can leave `upload-to-release: false`.

## Troubleshooting

| Symptom | Cause |
|---------|-------|
| `WIX7015` | WiX v7 without EULA acceptance. Set `accept-eula: true` or pin `wix-version: '6.0.2'`. |
| The MSI installs beside the old version instead of upgrading | `upgrade-code` changed between releases. It must be constant for the life of the product. |
| "MSI version field out of range" | A CalVer or build number overflowed `major`/`minor` (255) or `build` (65535). |
| "Package source is empty" | The publish step produced nothing, or `source-path` does not match where the artifact was extracted. |
| "Shortcut target not found" | `main-executable` does not exist in `source-path`. A shortcut to a missing file installs fine and then fails for the user, so it is rejected at build time. |
| "signtool not found" | The runner has no Windows SDK. Use a GitHub-hosted `windows-latest` runner or install the SDK. |
| Undefined preprocessor variable in a `.wixproj` build | The project's `DefineConstants` does not map the MSBuild property through. See [`.wixproj`](#wixproj). |

## Examples

- [`msi-from-published-binaries.yml`](../../github/workflows/examples/dotnet-package-msi/msi-from-published-binaries.yml) — publish, package, sign, attach to a Release
- [`msi-with-custom-wix-project.yml`](../../github/workflows/examples/dotnet-package-msi/msi-with-custom-wix-project.yml) — a repository-owned WiX project

## Related Workflows

- [`dotnet-publish-binaries.yml`](./dotnet-publish-binaries.md) — self-contained binaries per RID
- [`dotnet-desktop-build.yml`](./dotnet-desktop-build.md) — WPF/WinForms builds and MSIX
- [`dotnet-publish-library.yml`](./dotnet-publish-library.md) — NuGet package publishing
