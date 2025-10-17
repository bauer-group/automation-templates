# 🔄 Meta Repository Submodule Sync

## Overview

The Meta Repository Sync workflow provides automated synchronization of Git submodules based on GitHub repository topics. It creates and maintains "meta repositories" that bundle related projects together, making it easy to manage collections of repositories as a single unit.

## Key Features

- ✅ **Topic-Based Grouping** - Organize repositories by GitHub topics
- ✅ **Automatic Submodule Management** - Add, update, and remove submodules automatically
- ✅ **Multiple Output Formats** - Generate JSON and TXT files for each topic group
- ✅ **README Generation** - Create comprehensive documentation from templates
- ✅ **Flexible Configuration** - JSON-based configuration for easy customization
- ✅ **Per-Topic Prefix Removal** - Clean repository names with topic-specific regex patterns
- ✅ **Auto Branch Detection** - Automatically detects and uses the repository's default branch
- ✅ **Scheduled Updates** - Automatic synchronization on schedules
- ✅ **Manual Triggers** - On-demand synchronization via workflow dispatch

## Use Cases

### 1. Plugin Collections (e.g., Shopware 5)
Bundle all plugins for a platform by topic:
- Topic: `shopware5-plugins` → Folder: `Plugins/`
- Automatically syncs all repositories with that topic
- Generates README with plugin list and descriptions

### 2. Technology Portfolio
Organize projects by technology stack:
- .NET projects → `DotNet/`
- Python projects → `Python/`
- Node.js projects → `NodeJS/`

### 3. Project Categories
Group by purpose or feature:
- Microservices
- Libraries
- Tools
- Documentation

## Quick Start

### 1. Create Meta Repository

```bash
# Create new repository for meta collection
gh repo create my-org/shopware5-meta --public

# Clone it
git clone https://github.com/my-org/shopware5-meta.git
cd shopware5-meta
```

### 2. Create Configuration

Create `.github/config/meta-repository/topics.json`:

```json
{
  "title": "🛒 Shopware 5 Plugins",
  "description": "Collection of all Shopware 5 plugins from our organization",
  "groups": [
    {
      "topic": "shopware5-plugins",
      "folder": "Plugins",
      "name": "Shopware 5 Plugins",
      "description": "Enthaltene Plugins",
      "remove_prefix": "^SWP[-_]"
    }
  ]
}
```

### 3. Create Workflow

Create `.github/workflows/sync.yml`:

```yaml
name: 🔄 Sync Submodules

on:
  workflow_dispatch:
  repository_dispatch:
    types: [trigger-from-repository]
  schedule:
    - cron: "45 23 * * 6"  # Weekly Saturday 23:45 UTC

permissions:
  contents: write
  actions: read

jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    with:
      config-file: '.github/config/meta-repository/topics.json'
      generate-readme: true
      generate-json: true
      generate-txt: true
      auto-commit: true
      # base-branch: ''  # Auto-detects default branch
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 4. Push and Run

```bash
git add .
git commit -m "feat: setup meta repository sync"
git push origin main

# Trigger manually
gh workflow run sync.yml
```

## Configuration Reference

### Configuration File Structure

The configuration file (`.github/config/meta-repository/topics.json`) has the following structure:

```json
{
  "title": "Repository Title",
  "description": "Repository description for README",
  "groups": [
    {
      "topic": "github-topic-name",
      "folder": "FolderName",
      "name": "Display Name",
      "description": "Group description",
      "remove_prefix": "^PREFIX[-_]"
    }
  ]
}
```

#### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Main title for the meta repository |
| `description` | Yes | Description shown in README header |
| `groups` | Yes | Array of topic group definitions |
| `groups[].topic` | Yes | GitHub topic to search for |
| `groups[].folder` | Yes | Folder name for submodules |
| `groups[].name` | Yes | Display name for the group |
| `groups[].description` | Yes | Description of the group |
| `groups[].remove_prefix` | No | Regex pattern to remove from repository names (topic-specific) |

### Workflow Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `config-file` | string | `.github/config/meta-repository/topics.json` | Path to configuration file |
| `organization` | string | `github.repository_owner` | GitHub organization name |
| `base-branch` | string | `''` (auto-detect) | Main branch name (auto-detects default branch if empty) |
| `readme-template` | string | `.github/config/meta-repository/README.template.md` | README template path |
| `generate-readme` | boolean | `true` | Generate README.md |
| `generate-json` | boolean | `true` | Generate JSON files per topic |
| `generate-txt` | boolean | `true` | Generate TXT files per topic |
| `output-directory` | string | `.` | Output directory for files |
| `submodule-depth` | number | `1` | Git clone depth (0 = full) |
| `auto-commit` | boolean | `true` | Auto-commit changes |
| `commit-message` | string | `🔄 Auto-sync: Update submodules and metadata` | Commit message |
| `runs-on` | string | `ubuntu-latest` | Runner OS |
| `timeout-minutes` | number | `30` | Job timeout |

### Workflow Outputs

| Output | Description |
|--------|-------------|
| `sync-summary` | Summary of sync operation |
| `repositories-synced` | Number of repositories synced |

## Examples

### Example 1: Simple Plugin Collection

**topics.json:**
```json
{
  "title": "Shopware 5 Plugins",
  "description": "All our Shopware plugins",
  "groups": [
    {
      "topic": "shopware5-plugins",
      "folder": "Plugins",
      "name": "Plugins",
      "description": "Shopware 5 plugin collection",
      "remove_prefix": "^SWP[-_]"
    }
  ]
}
```

**Workflow:**
```yaml
jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    with:
      config-file: '.github/config/meta-repository/topics.json'
```

**Result:**
```
Plugins/
  ├── PluginOne/
  ├── PluginTwo/
  └── PluginThree/
shopware5-plugins.json
shopware5-plugins.txt
README.md
```

### Example 2: Multi-Category Organization

**topics.json:**
```json
{
  "title": "Technology Portfolio",
  "description": "Our complete technology stack",
  "groups": [
    {
      "topic": "dotnet",
      "folder": "DotNet",
      "name": ".NET Projects",
      "description": ".NET applications and libraries",
      "remove_prefix": ""
    },
    {
      "topic": "python",
      "folder": "Python",
      "name": "Python Projects",
      "description": "Python packages and scripts",
      "remove_prefix": "^(py|python)[-_]"
    },
    {
      "topic": "docker",
      "folder": "Docker",
      "name": "Container Images",
      "description": "Docker images and compositions",
      "remove_prefix": "^docker[-_]"
    }
  ]
}
```

**Result:**
```
DotNet/
  ├── App1/
  └── Library1/
Python/
  ├── Package1/
  └── Script1/
Docker/
  └── Image1/
dotnet.json
dotnet.txt
python.json
python.txt
docker.json
docker.txt
README.md
```

### Example 3: Custom README Template

Create `.github/config/meta-repository/README.template.md`:

```markdown
# {{TITLE}}

> {{DESCRIPTION}}

**Organization:** {{ORGANIZATION}}
**Updated:** {{DATE}}

## Projects

{{GROUPS}}

## Custom Section

Add your own content here - it will be preserved
between placeholder replacements.
```

The workflow will replace:
- `{{TITLE}}` - From config `title`
- `{{DESCRIPTION}}` - From config `description`
- `{{ORGANIZATION}}` - GitHub organization
- `{{DATE}}` - Current date/time
- `{{GROUPS}}` - Auto-generated project tables

### Example 4: With Repository Dispatch

Allow individual repositories to trigger meta repo sync:

**In individual project (e.g., a plugin):**

```yaml
name: Notify Meta Repository

on:
  push:
    branches: [main]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Meta Repository Sync
        run: |
          gh api repos/my-org/shopware5-meta/dispatches \
            -f event_type='trigger-from-repository'
        env:
          GH_TOKEN: ${{ secrets.PAT_TOKEN }}
```

**In meta repository:**

```yaml
on:
  repository_dispatch:
    types: [trigger-from-repository]
```

## Advanced Configuration

### Per-Topic Prefix Removal

Each topic group can have its own prefix removal pattern. This is useful when different categories use different naming conventions:

```json
{
  "groups": [
    {
      "topic": "shopware5-plugins",
      "folder": "Plugins",
      "name": "Shopware 5 Plugins",
      "description": "Plugins",
      "remove_prefix": "^SWP[-_]"
    },
    {
      "topic": "shopware5-themes",
      "folder": "Themes",
      "name": "Shopware 5 Themes",
      "description": "Themes",
      "remove_prefix": "^SWT[-_]"
    },
    {
      "topic": "shopware5-tools",
      "folder": "Tools",
      "name": "Tools",
      "description": "Development tools",
      "remove_prefix": ""
    }
  ]
}
```

**Example:**
- Repository: `SWP-PaymentGateway` → Submodule: `Plugins/PaymentGateway/`
- Repository: `SWT-CustomTheme` → Submodule: `Themes/CustomTheme/`
- Repository: `deployment-scripts` → Submodule: `Tools/deployment-scripts/`

### Multiple Patterns

Use regex alternation for multiple prefixes:

```json
{
  "remove_prefix": "^(SWP|BAUER|ORG)[-_]"
}
```

### Auto Branch Detection

The workflow automatically detects the repository's default branch if `base-branch` is not specified or empty:

```yaml
with:
  # Leave empty or omit for auto-detection
  base-branch: ''
```

**Detection order:**
1. Uses `base-branch` input if provided
2. Queries GitHub API for repository default branch
3. Falls back to git symbolic-ref
4. Tries `main`, then `master`
5. Fails if no valid branch found

This ensures the workflow works with repositories using `main`, `master`, or custom default branches.

### Custom Output Directory

```yaml
with:
  output-directory: 'metadata'
```

Result:
```
metadata/
  ├── shopware5-plugins.json
  └── shopware5-plugins.txt
Plugins/
  └── ...
```

### Submodule Clone Depth

```yaml
with:
  submodule-depth: 0  # Full history
  # or
  submodule-depth: 1  # Shallow clone (default, faster)
```

## Integration Patterns

### Pattern 1: Scheduled Sync

```yaml
on:
  schedule:
    - cron: "0 2 * * 1"  # Every Monday 2 AM
```

### Pattern 2: Manual + Scheduled

```yaml
on:
  workflow_dispatch:  # Manual trigger
  schedule:
    - cron: "45 23 * * 6"  # Weekly automatic
```

### Pattern 3: Event-Driven

```yaml
on:
  repository_dispatch:
    types: [trigger-from-repository]
```

### Pattern 4: Push-Based (for config changes)

```yaml
on:
  push:
    paths:
      - '.github/config/meta-repository/**'
```

## Output Files

### JSON Format

Each topic generates a `{topic}.json` file:

```json
[
  {
    "name": "SWP-PaymentGateway",
    "default_branch": "main",
    "html_url": "https://github.com/org/SWP-PaymentGateway",
    "git_url": "git://github.com/org/SWP-PaymentGateway.git",
    "description": "Payment gateway integration",
    "topics": ["shopware5-plugins", "payment"],
    "updated_at": "2025-01-15T10:30:00Z"
  }
]
```

### TXT Format

Simple list for scripting:

```
SWP-PaymentGateway
SWP-ShippingModule
SWP-TaxCalculator
```

### README.md

Auto-generated with:
- Project tables by group
- Links to repositories
- Last update timestamp
- Usage instructions

## Troubleshooting

### Issue: Submodules not updating

**Solution:**
```bash
# Manually update submodules
git submodule update --remote --recursive

# Or force sync
gh workflow run sync.yml
```

### Issue: JSON file not found

**Cause:** Configuration file missing or incorrect path

**Solution:**
```yaml
with:
  config-file: '.github/config/meta-repository/topics.json'
```

### Issue: Permissions error

**Cause:** Missing write permissions

**Solution:**
```yaml
permissions:
  contents: write  # Required for commits
  actions: read    # Required for workflow
```

### Issue: Repositories not found

**Cause:** Topic not applied to repositories

**Solution:**
1. Check repository topics on GitHub
2. Verify organization name is correct
3. Ensure GITHUB_TOKEN has access

## Best Practices

### 1. Use Descriptive Topics

```json
{
  "topic": "shopware5-plugins",  // Good: specific
  "topic": "plugins",            // Avoid: too generic
}
```

### 2. Organize by Purpose

Group related projects together:
```json
{
  "groups": [
    {"topic": "shopware5-plugins", "folder": "Plugins"},
    {"topic": "shopware5-themes", "folder": "Themes"},
    {"topic": "shopware5-tools", "folder": "Tools"}
  ]
}
```

### 3. Use Meaningful Folder Names

```json
{
  "folder": "Plugins",           // Good: clear
  "folder": "p",                 // Avoid: unclear
}
```

### 4. Keep README Template Updated

Maintain a custom template for organization-specific content.

### 5. Schedule During Low Activity

```yaml
schedule:
  - cron: "45 23 * * 6"  # Late Saturday night
```

### 6. Use Repository Dispatch for Real-Time Updates

Allow individual projects to trigger immediate sync.

## Related Workflows

- [Shopware 5 Build](shopware5-build.md) - Build and release Shopware plugins
- [Repository Cleanup](repository-cleanup.md) - Maintain repository health
- [Documentation](documentation.md) - Auto-generate documentation

## Support

For issues or questions:
1. Check [troubleshooting](#troubleshooting) section
2. Review [examples](#examples)
3. Open an issue in the automation-templates repository

## See Also

- [Configuration Examples](.github/config/meta-repository/)
- [README Template](.github/config/meta-repository/README.template.md)
- [Example Configurations](.github/config/meta-repository/*.json)
