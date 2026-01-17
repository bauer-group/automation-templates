# Semantic Release Action

Automated semantic versioning and release creation with changelog generation.

## Overview

This composite action provides standardized semantic-release configuration with support for repository-specific customization. It uses the [conventional commits](https://www.conventionalcommits.org/) specification to determine version bumps.

## Features

- Automatic version bumping based on commit messages
- Changelog generation with categorized sections
- Support for breaking changes via `!` suffix (e.g., `feat!:`, `fix!:`)
- Repository-specific configuration merging
- Extra plugin support (e.g., `semantic-release-dotnet`)

## Quick Start

### Using the Workflow Module

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

### Using the Action Directly

```yaml
- name: Semantic Release
  uses: bauer-group/automation-templates/.github/actions/semantic-release@main
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    branches: main
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `token` | GitHub token for authentication | Yes | - |
| `branches` | Branches to release from | No | `main` |
| `dry-run` | Run without creating release | No | `false` |
| `force-release` | Force release even without conventional commits | No | `false` |
| `extra-plugins` | Additional semantic-release plugins to install | No | `''` |
| `node-version` | Node.js version to use | No | `20` |

## Outputs

| Output | Description |
|--------|-------------|
| `release-created` | Whether a release was created (`true`/`false`) |
| `version` | The new version number (e.g., `1.2.3`) |
| `tag` | The git tag (e.g., `v1.2.3`) |
| `changelog` | The changelog content for this release |

## Default Release Rules

By default, the following commit types trigger releases:

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat` | Minor | `feat: add new feature` |
| `fix` | Patch | `fix: resolve bug` |
| `perf` | Patch | `perf: improve performance` |
| `revert` | Patch | `revert: undo change` |
| `refactor` | Patch | `refactor: restructure code` |
| Breaking change (`!`) | Major | `feat!: breaking change` |

### Non-releasing Commit Types

These commit types do **not** trigger releases by default:

- `docs` - Documentation changes
- `style` - Code style changes
- `chore` - Maintenance tasks
- `test` - Test changes
- `build` - Build system changes
- `ci` - CI configuration changes

## Breaking Changes

Breaking changes are detected via the `!` suffix on any commit type:

```
feat!: remove deprecated API endpoint

BREAKING CHANGE: The /api/v1/users endpoint has been removed.
Use /api/v2/users instead.
```

This triggers a **major** version bump (e.g., `1.2.3` → `2.0.0`).

## Repository Configuration

You can customize the release behavior by creating a configuration file at:

```
.github/config/release/semantic-release.json
```

### Configuration Merging

The action merges your repository config with the standard configuration:

| Setting | Behavior |
|---------|----------|
| `releaseRules` | **Replaces** default rules if defined |
| `changelogFile` | Overrides default (`CHANGELOG.md`) |
| `git.assets` | Overrides default (`["CHANGELOG.md"]`) |
| `git.message` | Overrides default commit message |
| Extra plugins | **Added** to standard plugins |

### Example Repository Config

```json
{
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.md"
    }],
    ["semantic-release-dotnet", {
      "paths": ["Directory.Build.props"]
    }],
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.md", "Directory.Build.props"],
      "message": "chore(release): ${nextRelease.version}\n\n${nextRelease.notes}"
    }],
    "@semantic-release/github"
  ]
}
```

### What Gets Extracted

From your repository config, the action extracts:

1. **releaseRules** - Custom rules from `@semantic-release/commit-analyzer`
2. **changelogFile** - From `@semantic-release/changelog`
3. **git.assets** - From `@semantic-release/git`
4. **git.message** - From `@semantic-release/git`
5. **Extra plugins** - Any plugin not in the standard set

### Standard Plugins (Always Included)

These plugins are always configured by the action:

- `@semantic-release/commit-analyzer` - Analyzes commits
- `@semantic-release/release-notes-generator` - Generates release notes
- `@semantic-release/changelog` - Updates CHANGELOG.md
- `@semantic-release/git` - Commits changes
- `@semantic-release/github` - Creates GitHub release

## Force Release Mode

When `force-release: true`, all commit types trigger a patch release:

```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      force-release: true
```

This is useful for:
- Initial releases
- Forcing a release without conventional commits
- CI/CD testing

## Changelog Sections

Generated changelogs are organized into sections:

| Section | Commit Types |
|---------|--------------|
| Features | `feat` |
| Bug Fixes | `fix` |
| Performance | `perf` |
| Reverts | `revert` |
| Refactoring | `refactor` |
| Documentation (hidden) | `docs` |
| Styles (hidden) | `style` |
| Chores (hidden) | `chore` |
| Tests (hidden) | `test` |
| Build (hidden) | `build` |
| CI (hidden) | `ci` |

Hidden sections are not included in the changelog but commits are still tracked.

## Integration with .NET Publishing

For .NET libraries, combine with the publish workflow:

```yaml
name: Release & Publish

on:
  push:
    branches: [main]

permissions:
  contents: write
  packages: write
  id-token: write

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
      push-to-github: true
    secrets: inherit
```

## Troubleshooting

### No Release Created

If no release is created:

1. Check commit messages follow conventional commits format
2. Verify commits are on the configured branch
3. Check if `dry-run` is enabled
4. Review workflow logs for "No releasable changes"

### Breaking Changes Not Detected

Ensure you're using the `!` suffix correctly:

```bash
# Correct
git commit -m "feat!: breaking change"

# Also correct (with scope)
git commit -m "feat(api)!: breaking change"

# Incorrect (no !)
git commit -m "feat: BREAKING CHANGE in body"
```

### Custom Rules Not Applied

If custom `releaseRules` are ignored:

1. Verify config file path: `.github/config/release/semantic-release.json`
2. Check JSON syntax is valid
3. Ensure rules are under `@semantic-release/commit-analyzer` plugin

### Git Message Escaping Issues

If commit messages cause JSON errors:

- The action handles `\n` escape sequences automatically
- Ensure your config uses proper JSON string escaping
- Multi-line messages are supported

## Related

- [modules-semantic-release.yml](../../workflows/modules-semantic-release.yml) - Reusable workflow
- [dotnet-publish-library.yml](../../workflows/dotnet-publish-library.yml) - .NET publishing workflow
- [Conventional Commits](https://www.conventionalcommits.org/) - Commit message specification
