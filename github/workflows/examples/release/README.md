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
| --------- | ---------- |
| `tagFormat` | Custom tag format (e.g. `console-v${version}`) |
| `releaseRules` | Replaces default rules if defined |
| `changelogFile` | Overrides default |
| `git.assets` | Overrides default |
| `git.message` | Overrides default |
| Extra plugins | Added to standard set |

### Custom Tag Format (`tagFormat`)

Use `tagFormat` when a repository contains multiple logical products and you need
scoped tags (e.g. `console-v1.0.0` instead of `v1.0.0`).

```json
{
  "tagFormat": "console-v${version}",
  "branches": ["feature/admin-console-v2"],
  "plugins": [...]
}
```

> **Important: Initial Tag Required**
>
> When you introduce a custom `tagFormat` to an existing repository, semantic-release
> searches for previous tags matching that pattern. If **none exist**, it treats the
> repository as having **no release history** and analyzes **every commit ever made**.
>
> On large repositories (forks, monorepos) this causes:
>
> 1. Thousands of commits analyzed — extremely long build times
> 2. The `@semantic-release/github` success step tries to comment on every associated
>    PR/issue, which exhausts the GitHub API rate limit
> 3. The job runs in a retry loop for minutes until it eventually fails with
>    `graphql_rate_limit`
>
> **Fix:** Before the first release with a new `tagFormat`, create an anchor tag on
> the commit where the new versioning should begin:
>
> ```bash
> # Example: start console versioning from current HEAD
> git tag console-v0.0.0
> git push origin console-v0.0.0
> ```
>
> This tells semantic-release "everything before this tag is already released" and it
> will only analyze commits after that point.
>
> **Tip:** To prevent the success step from commenting on PRs/issues entirely (recommended
> for repositories with large history), configure `@semantic-release/github` in your
> repo config:
>
> ```json
> ["@semantic-release/github", {
>   "successComment": false,
>   "failComment": false,
>   "releasedLabels": false
> }]
> ```

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

## Troubleshooting

### Release job runs for 15+ minutes and fails with `graphql_rate_limit`

**Symptom:** The `@semantic-release/github` success step loops with
`Request quota exhausted for request POST /graphql` until the job times out.

**Cause:** semantic-release found no previous tag matching the configured pattern
(either default `v*` or a custom `tagFormat`). It analyzed every commit in the
repository and then tried to comment on all associated PRs/issues, exhausting the
GitHub GraphQL API rate limit.

**Fix:**

1. Create an anchor tag at the point where versioning should start:

   ```bash
   git tag v0.0.0          # for default tagFormat
   git tag console-v0.0.0  # for tagFormat: "console-v${version}"
   git push origin <tag>
   ```

2. Optionally disable success comments in your repo config (see [Custom Tag Format](#custom-tag-format-tagformat) above).

### Release creates version `1.0.0` instead of expected patch/minor

This happens when no matching previous tag exists. Semantic-release defaults to
`1.0.0` for the first release. Create an anchor tag at the desired starting version
(e.g. `v0.0.0` or `console-v0.22.5`) to establish a baseline.

## Related

- [modules-semantic-release.yml](../../../../.github/workflows/modules-semantic-release.yml) - Reusable workflow
- [semantic-release action](../../../../.github/actions/semantic-release/) - Composite action
