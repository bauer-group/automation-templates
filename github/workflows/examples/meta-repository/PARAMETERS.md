# Meta Repository Sync - Complete Parameter Reference

Complete reference for all input parameters of the `meta-repository-sync.yml` workflow.

## Table of Contents

- [Configuration Parameters](#configuration-parameters)
- [Repository Settings](#repository-settings)
- [README Configuration](#readme-configuration)
- [Output Formats](#output-formats)
- [Submodule Options](#submodule-options)
- [Git Settings](#git-settings)
- [Runner Configuration](#runner-configuration)
- [Complete Example](#complete-example)

## Configuration Parameters

### config-file

**Type:** `string`
**Default:** `.github/config/meta-repository/topics.json`
**Required:** No

Path to JSON configuration file defining topic groups.

**Example:**
```yaml
with:
  config-file: '.github/config/meta-repository/topics.json'
```

**Configuration Format:**
```json
{
  "title": "Project Collection",
  "description": "Automated collection of projects",
  "groups": [
    {
      "topic": "my-topic",
      "folder": "Projects",
      "name": "My Projects",
      "description": "Collection description",
      "remove_prefix": "^prefix[-_]"
    }
  ]
}
```

### organization

**Type:** `string`
**Default:** (auto-detected from repository owner)
**Required:** No

GitHub organization name to fetch repositories from.

**Example:**
```yaml
with:
  organization: 'my-org'
```

**Auto-Detection:**
If not specified, uses `github.repository_owner` (the organization/user that owns the workflow repository).

### include-private

**Type:** `boolean`
**Default:** `false`
**Required:** No

Include private repositories in addition to public ones.

**Example:**
```yaml
with:
  include-private: true  # Include both public and private repos
```

**Values:**
- `false` - Only public repositories (faster)
- `true` - All repositories (public + private)

**⚠️ Important for Private Repositories:**

To access private repositories, you **must** provide a Personal Access Token (PAT) with `repo` scope:

```yaml
jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    secrets:
      GITHUB_PAT: ${{ secrets.GITHUB_PAT }}  # Required for private repos
    with:
      include-private: true
```

**Setup:**
1. Create a PAT at https://github.com/settings/tokens with `repo` scope
2. Add the PAT as a repository/organization secret named `GITHUB_PAT`
3. Pass it via `secrets` parameter as shown above

**🔒 Security Note:**
The `GITHUB_PAT` is **only used for reading** private repositories from your organization. All write operations (checkout, commit, push) use the default `github.token` for security. This follows the principle of least privilege.

**Recommended Token Scopes:**
- ✅ `repo` (or `public_repo` if you only need public repos)
- ❌ Do NOT grant additional scopes like `workflow`, `admin:org`, etc.

**Behavior:**
- When `include-private: true` **AND** `GITHUB_PAT` is provided → Uses GITHUB_PAT for reading org repos (read-only)
- When `include-private: true` **BUT** `GITHUB_PAT` is NOT provided → Shows warning, uses github.token (limited access)
- When `include-private: false` → Uses github.token (public repos only)
- **All git operations** (checkout, commit, push) → Always uses github.token

## Repository Settings

### base-branch

**Type:** `string`
**Default:** (auto-detected)
**Required:** No

Main branch name to use for git operations.

**Example:**
```yaml
with:
  base-branch: 'main'
```

**Auto-Detection:**
If empty, detects default branch via:
1. GitHub API (`repos/{owner}/{repo}` endpoint)
2. Git symbolic-ref
3. Fallback to 'main' or 'master'

## README Configuration

### readme-template

**Type:** `string`
**Default:** `.github/config/meta-repository/README.template.md`
**Required:** No

Path to README template file.

**Example:**
```yaml
with:
  readme-template: '.github/config/meta-repository/README.template.md'
```

**Template Placeholders:**
- `{{TITLE}}` - From config `title`
- `{{DESCRIPTION}}` - From config `description`
- `{{ORGANIZATION}}` - Organization name
- `{{DATE}}` - Sync timestamp (UTC)
- `{{GROUPS}}` - Generated repository tables

### generate-readme

**Type:** `boolean`
**Default:** `true`
**Required:** No

Generate README.md from template and configuration.

**Example:**
```yaml
with:
  generate-readme: true
```

**Values:**
- `true` - Generate README.md
- `false` - Skip README generation

## Output Formats

### generate-json

**Type:** `boolean`
**Default:** `true`
**Required:** No

Generate JSON files for each topic group.

**Example:**
```yaml
with:
  generate-json: true
```

**Output:** `{topic}.json` containing repository metadata:
```json
[
  {
    "name": "repo-name",
    "default_branch": "main",
    "html_url": "https://github.com/org/repo",
    "description": "Repository description",
    "topics": ["topic1", "topic2"],
    "updated_at": "2024-01-01T00:00:00Z"
  }
]
```

### generate-txt

**Type:** `boolean`
**Default:** `true`
**Required:** No

Generate TXT files for each topic group.

**Example:**
```yaml
with:
  generate-txt: true
```

**Outputs:**
- `{topic}.txt` - Repository names with prefix
- `{topic}.noprefix.txt` - Cleaned repository names (without prefix)

### output-directory

**Type:** `string`
**Default:** `.`
**Required:** No

Directory for output files (JSON/TXT).

**Example:**
```yaml
with:
  output-directory: 'metadata'
```

**Result:**
```
metadata/
├── shopware5-plugins.json
├── shopware5-plugins.txt
└── shopware5-plugins.noprefix.txt
```

## Submodule Options

### submodule-depth

**Type:** `number`
**Default:** `1`
**Required:** No

Git clone depth for submodules.

**Example:**
```yaml
with:
  submodule-depth: 1  # Shallow clone
```

**Values:**
- `1` - Shallow clone (fastest, minimal history)
- `0` - Full history (slower, needed for git operations)
- `>1` - Specific depth

**Recommendations:**
- Use `1` for most cases (faster sync)
- Use `0` if you need full git history
- Use `>1` for specific history depth requirements

## Git Settings

### auto-commit

**Type:** `boolean`
**Default:** `true`
**Required:** No

Automatically commit and push changes.

**Example:**
```yaml
with:
  auto-commit: true
```

**Values:**
- `true` - Automatically commit and push changes
- `false` - Leave changes uncommitted (for manual review)

### commit-message

**Type:** `string`
**Default:** `🔄 Auto-sync: Update submodules and metadata`
**Required:** No

Commit message template.

**Example:**
```yaml
with:
  commit-message: '🔄 Weekly sync: Update plugin collection'
```

**Tips:**
- Use descriptive messages
- Include emojis for better visual scanning
- Follow conventional commits format

## Runner Configuration

### runs-on

**Type:** `string`
**Default:** `ubuntu-latest`
**Required:** No

Runner OS to use for the job.

**Example:**
```yaml
with:
  runs-on: 'ubuntu-22.04'
```

**Common Values:**
- `ubuntu-latest` - Latest Ubuntu (recommended)
- `ubuntu-22.04` - Ubuntu 22.04 LTS
- `ubuntu-20.04` - Ubuntu 20.04 LTS
- `windows-latest` - Latest Windows (not recommended)
- `macos-latest` - Latest macOS (not recommended)

**Note:** This workflow is optimized for Ubuntu runners.

### timeout-minutes

**Type:** `number`
**Default:** `30`
**Required:** No

Job timeout in minutes.

**Example:**
```yaml
with:
  timeout-minutes: 45  # For large organizations
```

**Recommendations:**
- **Small orgs (<50 repos):** 10-15 minutes
- **Medium orgs (50-200 repos):** 20-30 minutes
- **Large orgs (>200 repos):** 45-60 minutes

**Maximum:** Depends on GitHub plan
- Free: 6 hours
- Pro: 6 hours
- Enterprise: 24 hours

## Complete Example

```yaml
name: 🔄 Meta Repository Sync

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:
  repository_dispatch:
    types: [trigger-from-repository]

permissions:
  contents: write
  actions: read

jobs:
  sync:
    name: Synchronize Repository Collection
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    secrets:
      GITHUB_PAT: ${{ secrets.GITHUB_PAT }}  # Required for private repositories
    with:
      # Configuration
      config-file: '.github/config/meta-repository/topics.json'
      organization: 'my-org'
      include-private: true

      # Repository Settings
      base-branch: 'main'

      # README Configuration
      generate-readme: true
      readme-template: '.github/config/meta-repository/README.template.md'

      # Output Formats
      generate-json: true
      generate-txt: true
      output-directory: '.'

      # Submodule Options
      submodule-depth: 1

      # Git Settings
      auto-commit: true
      commit-message: '🔄 Auto-sync: Update repositories'

      # Runner Configuration
      runs-on: 'ubuntu-latest'
      timeout-minutes: 30
```

## Output Reference

### Workflow Outputs

The workflow provides the following outputs:

| Output | Description | Example |
|--------|-------------|---------|
| `sync-summary` | Summary of sync operation | "Synced 35 repositories: 2 added, 5 updated, 1 removed" |
| `repositories-synced` | Number of repositories synced | "35" |

**Usage in dependent jobs:**
```yaml
jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    secrets:
      GITHUB_PAT: ${{ secrets.GITHUB_PAT }}
    with:
      # ... parameters ...

  notify:
    needs: sync
    runs-on: ubuntu-latest
    steps:
      - name: Show Summary
        run: echo "${{ needs.sync.outputs.sync-summary }}"
```

### Generated Files

For each topic group with topic `my-topic`:

| File | Description | Content |
|------|-------------|---------|
| `my-topic.json` | Full repository metadata | JSON array with repo details |
| `my-topic.txt` | Repository names (original) | One name per line, with prefix |
| `my-topic.noprefix.txt` | Repository names (cleaned) | One name per line, without prefix |
| `README.md` | Generated documentation | Markdown with repository tables |

**Example:**

Topic: `shopware5-plugins`, Prefix: `^SWP[-_]`

```
# shopware5-plugins.txt
SWP-AmazonToolkit
SWP-ArticleWeight
SWP-BootstrapIntegration

# shopware5-plugins.noprefix.txt
AmazonToolkit
ArticleWeight
BootstrapIntegration
```

## Parameter Combinations

### Recommended for Production

```yaml
with:
  include-private: true
  generate-readme: true
  generate-json: true
  generate-txt: true
  auto-commit: true
  submodule-depth: 1
  timeout-minutes: 30
```

### Recommended for Development/Testing

```yaml
with:
  include-private: false  # Faster
  generate-readme: true
  generate-json: false  # Skip for speed
  generate-txt: false   # Skip for speed
  auto-commit: false    # Manual review
  submodule-depth: 1
  timeout-minutes: 15
```

### Recommended for Large Organizations

```yaml
with:
  include-private: true
  generate-readme: true
  generate-json: true
  generate-txt: true
  auto-commit: true
  submodule-depth: 1
  timeout-minutes: 60    # Increased timeout
  output-directory: 'metadata'  # Organized structure
```

## See Also

- [Example Workflows](.)
- [Configuration Guide](../../../.github/config/meta-repository/)
- [Workflow Source](../../../.github/workflows/meta-repository-sync.yml)
- [Main Documentation](../../../docs/README.template.MD)
