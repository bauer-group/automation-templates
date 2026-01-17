# Release Examples

Example workflows for automated versioning and release creation.

## Examples

### [semantic-release.yml](semantic-release.yml)

Standard semantic-release workflow with changelog generation.

Uses conventional commits to determine version bumps:
- `feat:` → Minor version
- `fix:` → Patch version
- `feat!:` or `fix!:` → Major version (breaking change)

### [simple-release.yml](simple-release.yml)

Basic release workflow for manual version management.

## Using the Module

For most use cases, use the reusable workflow module:

```yaml
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: main
    secrets: inherit
```

## Repository Configuration

Customize release behavior with `.github/config/release/semantic-release.json`:

```json
{
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.md"
    }],
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.md"],
      "message": "chore(release): ${nextRelease.version}"
    }],
    "@semantic-release/github"
  ]
}
```

## Configuration Merging

The action merges your config with standard settings:

| Setting | Behavior |
|---------|----------|
| `releaseRules` | Replaces default rules if defined |
| `changelogFile` | Overrides default |
| `git.assets` | Overrides default |
| `git.message` | Overrides default |
| Extra plugins | Added to standard set |

## Integration Examples

### With .NET Publishing

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit

  publish:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main
    with:
      project-path: 'src/MyLibrary.sln'
      release-version: ${{ needs.release.outputs.version }}
      push-to-nuget: true
    secrets: inherit
```

### With Docker Build

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit

  docker:
    needs: release
    if: needs.release.outputs.release-created == 'true'
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      image-name: myapp
      tag: ${{ needs.release.outputs.version }}
    secrets: inherit
```

## Related

- [modules-semantic-release.yml](../../../../.github/workflows/modules-semantic-release.yml) - Reusable workflow
- [semantic-release action](../../../../.github/actions/semantic-release/) - Composite action
