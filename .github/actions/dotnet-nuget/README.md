# .NET NuGet Build & Pack Action

Build, test, sign, and package .NET libraries for NuGet publishing.

## Overview

This composite action provides comprehensive .NET library build and packaging capabilities with support for:

- Multi-target framework builds
- Assembly signing (SNK)
- Code coverage collection
- Symbol package generation
- Multi-package solutions
- NuGet/GitHub Packages publishing

## Quick Start

```yaml
- name: Build & Pack
  uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary/MyLibrary.csproj'
    run-tests: true
    create-package: true
```

## Inputs

### Build Configuration

| Input | Description | Default |
|-------|-------------|---------|
| `project-path` | Path to .csproj or .sln file | **Required** |
| `working-directory` | Working directory for commands | `.` |
| `configuration` | Build configuration (Debug/Release) | `Release` |
| `dotnet-version` | SDK version(s), comma-separated | `10.0.x` |
| `target-frameworks` | Target frameworks (semicolon-separated) | Auto-detect |
| `artifact-suffix` | Suffix for artifact names | `''` |

### Testing

| Input | Description | Default |
|-------|-------------|---------|
| `run-tests` | Run tests if projects exist | `true` |
| `test-project-path` | Path to test project | Auto-detect |
| `test-filter` | Test filter expression | `''` |
| `collect-coverage` | Enable code coverage | `true` |
| `coverage-threshold` | Minimum coverage % (0 to disable) | `0` |

### Versioning

| Input | Description | Default |
|-------|-------------|---------|
| `package-version` | Explicit version (overrides all) | `''` |
| `release-version` | Version from release workflow | `''` |
| `version-suffix` | Pre-release suffix | `''` |
| `update-project-version` | Update version in project files | `false` |

### Assembly Signing

| Input | Description | Default |
|-------|-------------|---------|
| `sign-assembly` | Enable SNK signing | `false` |
| `snk-base64` | Base64-encoded .snk file | `''` |
| `delay-sign` | Use delay signing | `false` |

### Packaging

| Input | Description | Default |
|-------|-------------|---------|
| `create-package` | Create NuGet package | `true` |
| `include-symbols` | Include .snupkg | `true` |
| `include-source` | Include source in symbols | `true` |
| `deterministic-build` | Enable deterministic builds | `true` |

### Publishing

| Input | Description | Default |
|-------|-------------|---------|
| `push-to-nuget` | Publish to NuGet.org | `false` |
| `push-to-github` | Publish to GitHub Packages | `false` |
| `skip-duplicate` | Skip if version exists | `true` |
| `nuget-source` | NuGet source URL | `https://api.nuget.org/v3/index.json` |
| `nuget-api-key` | NuGet API key | `''` |
| `github-token` | GitHub token | `''` |

### Caching

| Input | Description | Default |
|-------|-------------|---------|
| `cache-enabled` | Enable NuGet caching | `true` |
| `cache-nuget-lockfile` | Use packages.lock.json for cache | `false` |

### Summary

| Input | Description | Default |
|-------|-------------|---------|
| `generate-summary` | Generate GitHub step summary | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `version` | Package version |
| `package-path` | Path to main .nupkg file (first package) |
| `symbols-path` | Path to .snupkg file (first package) |
| `package-name` | Full package name with version (first package) |
| `package-count` | Number of packages created |
| `package-names` | JSON array of all package names |
| `build-succeeded` | Whether build succeeded |
| `test-passed` | Whether tests passed |
| `test-skipped` | Whether tests were skipped |
| `coverage-percentage` | Code coverage percentage |
| `pushed-to-nuget` | Whether pushed to NuGet.org |
| `pushed-to-github` | Whether pushed to GitHub Packages |

## Multi-Package Solutions

When building a solution with multiple projects, all packages are created and can be published:

```yaml
- name: Build Solution
  id: build
  uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.sln'
    create-package: true
    push-to-github: true
    github-token: ${{ secrets.GITHUB_TOKEN }}

- name: Show Results
  run: |
    echo "Created ${{ steps.build.outputs.package-count }} packages"
    echo "Packages: ${{ steps.build.outputs.package-names }}"
```

### Package Names Output Format

The `package-names` output is a JSON array:

```json
["MyLibrary.Core.1.0.0", "MyLibrary.Data.1.0.0", "MyLibrary.Api.1.0.0"]
```

Parse it in subsequent steps:

```yaml
- name: Process Packages
  run: |
    echo '${{ steps.build.outputs.package-names }}' | jq -r '.[]' | while read pkg; do
      echo "Package: $pkg"
    done
```

## Assembly Signing

### Generate SNK File

```bash
# Using .NET SDK
sn -k MyProject.snk

# Convert to base64
base64 -w 0 MyProject.snk > MyProject.snk.base64
```

### Use in Workflow

```yaml
- name: Build with Signing
  uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.csproj'
    sign-assembly: true
    snk-base64: ${{ secrets.DOTNET_SIGNKEY_BASE64 }}
```

## Version Detection

Version is determined in this order:

1. `package-version` input (explicit override)
2. `release-version` input (from semantic-release)
3. Git tag (`refs/tags/v1.2.3` → `1.2.3`)
4. `Directory.Build.props` (`<VersionPrefix>` or `<Version>`)
5. Project file (`<Version>`)
6. Default: `1.0.0-preview.{run_number}`

### Pre-release Versions

```yaml
- uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.csproj'
    version-suffix: 'beta'  # Results in: 1.0.0-beta.123
```

## Code Coverage

Coverage is collected using Coverlet:

```yaml
- uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.csproj'
    run-tests: true
    collect-coverage: true
    coverage-threshold: 80  # Fail if below 80%
```

Coverage reports are generated in Cobertura format at `TestResults/coverage.cobertura.xml`.

## Test Discovery

Tests are automatically discovered by searching for:

1. Explicit `test-project-path` if provided
2. Projects with `Tests` or `Test` in the name
3. Projects in `tests/` or `test/` directories

If no test projects are found, tests are skipped gracefully.

## Deterministic Builds

Enabled by default for:

- Reproducible builds
- SourceLink support
- Better debugging experience

```yaml
- uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.csproj'
    deterministic-build: true  # Default
```

## GitHub Step Summary

When `generate-summary: true` (default), a summary is added to the GitHub Actions UI showing:

- Build status
- Test results and coverage
- Package information
- Publishing status

## Examples

### Basic Library Build

```yaml
- uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.csproj'
```

### Full Publishing Pipeline

```yaml
- uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.sln'
    dotnet-version: '8.0.x,9.0.x'
    run-tests: true
    collect-coverage: true
    coverage-threshold: 80
    sign-assembly: true
    snk-base64: ${{ secrets.DOTNET_SIGNKEY_BASE64 }}
    create-package: true
    include-symbols: true
    push-to-nuget: true
    nuget-api-key: ${{ secrets.NUGET_API_KEY }}
    push-to-github: true
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

### Multi-Target Framework

```yaml
- uses: bauer-group/automation-templates/.github/actions/dotnet-nuget@main
  with:
    project-path: 'src/MyLibrary.csproj'
    dotnet-version: '8.0.x,9.0.x,10.0.x'
    target-frameworks: 'net8.0;net9.0;net10.0'
```

## Related

- [dotnet-publish-library.yml](../../workflows/dotnet-publish-library.yml) - Reusable workflow
- [Documentation](../../../docs/workflows/dotnet-publish-library.md) - Full documentation
