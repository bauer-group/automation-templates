# Meta Repository Sync Examples

This directory contains example workflows for implementing meta repositories that automatically synchronize collections of related projects using Git submodules.

## Overview

A **meta repository** is a Git repository that bundles other repositories as submodules, organized by topics or categories. This pattern is useful for:

- 📦 **Plugin Collections** - Group all plugins for a platform (e.g., Shopware, WordPress)
- 🏢 **Technology Portfolios** - Organize projects by technology stack
- 📚 **Project Categories** - Bundle related projects together
- 🔍 **Discovery** - Make it easy to browse and explore your organization's projects

## Quick Start

### 1. Choose an Example

| Example | Use Case | Complexity |
|---------|----------|------------|
| [simple-sync.yml](simple-sync.yml) | Basic single-topic sync | ⭐ Beginner |
| [shopware5-plugins.yml](shopware5-plugins.yml) | Shopware 5 plugin collection | ⭐⭐ Intermediate |
| [multi-topic-portfolio.yml](multi-topic-portfolio.yml) | Multi-category organization | ⭐⭐⭐ Advanced |
| [with-notifications.yml](with-notifications.yml) | With Teams notifications | ⭐⭐⭐ Advanced |
| [trigger-from-plugin.yml](trigger-from-plugin.yml) | Push-based sync trigger | ⭐⭐ Intermediate |

### 2. Setup Steps

#### A. Create Meta Repository

```bash
# Create repository
gh repo create my-org/project-meta --public

# Clone it
git clone https://github.com/my-org/project-meta.git
cd project-meta
```

#### B. Copy Example Workflow

```bash
# Copy chosen example
cp examples/simple-sync.yml .github/workflows/sync.yml
```

#### C. Create Configuration

Create `.github/config/meta-repository/topics.json`:

```json
{
  "title": "My Project Collection",
  "description": "Automated collection of related projects",
  "groups": [
    {
      "topic": "my-topic",
      "folder": "Projects",
      "name": "My Projects",
      "description": "Collection of my projects",
      "remove_prefix": ""
    }
  ]
}
```

#### D. Commit and Push

```bash
git add .
git commit -m "feat: setup meta repository"
git push origin main

# Trigger manually
gh workflow run sync.yml
```

## Example Descriptions

### 📄 simple-sync.yml

**Perfect for:** First-time users, simple single-topic collections

**Features:**
- Single topic synchronization
- Weekly schedule
- Manual trigger support
- Basic configuration

**Use when:**
- You want to bundle repositories with one topic
- You need a straightforward setup
- You don't need advanced features

### 🛒 shopware5-plugins.yml

**Perfect for:** Shopware 5 plugin collections

**Features:**
- Per-topic prefix removal (configured in JSON)
- Auto-detects default branch
- Optimized for Shopware plugin naming conventions
- Comprehensive README generation
- JSON and TXT output formats
- Automatic cleanup of removed plugins

**Use when:**
- Managing Shopware 5 plugins
- Plugins follow naming convention (e.g., SWP-PluginName)
- You need clean submodule folder names

**Example Result:**
```
Repository: SWP-PaymentGateway
Submodule:  Plugins/PaymentGateway/
```

### 🏢 multi-topic-portfolio.yml

**Perfect for:** Large organizations with diverse technology stacks

**Features:**
- Multiple topic groups with per-topic prefix removal
- Auto-detects default branch
- Configuration validation
- Multiple sync schedules
- Extended timeout
- Metadata directory organization
- Automatic cleanup of removed repositories

**Use when:**
- Managing projects across multiple technologies
- Need organized portfolio view
- Want automated daily and weekly syncs

**Example topics.json:**
```json
{
  "groups": [
    {"topic": "dotnet", "folder": "DotNet", ...},
    {"topic": "python", "folder": "Python", ...},
    {"topic": "nodejs", "folder": "NodeJS", ...}
  ]
}
```

### 🔔 with-notifications.yml

**Perfect for:** Teams using Microsoft Teams

**Features:**
- Success/failure notifications to Teams
- Automatic issue creation on failure
- Detailed error reporting
- Integration with teams-notifications workflow

**Requirements:**
- `TEAMS_WEBHOOK_URL` secret configured
- teams-notifications workflow available

**Use when:**
- Team collaboration via Teams
- Need visibility into sync status
- Want automatic issue tracking

### 📡 trigger-from-plugin.yml

**Perfect for:** Real-time synchronization

**Features:**
- Push-based sync triggering
- Immediate updates when projects change
- Works from individual repositories

**Setup:**
1. Place in individual project repositories
2. Configure `META_REPO_TOKEN` secret (PAT)
3. Update `META_REPO` variable

**Use when:**
- Need immediate sync after changes
- Building CI/CD pipeline
- Want push-based architecture

## Configuration Examples

### Example 1: Shopware 5 Plugins

**File:** `.github/config/meta-repository/topics.json`

```json
{
  "title": "🛒 Shopware 5 Plugins",
  "description": "Collection of all our Shopware 5 plugins",
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

**Workflow:** Use [shopware5-plugins.yml](shopware5-plugins.yml)

### Example 2: Technology Stack

```json
{
  "title": "Technology Portfolio",
  "description": "All our projects organized by technology",
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
      "description": "Python packages and tools",
      "remove_prefix": "^(py|python)[-_]"
    }
  ]
}
```

**Workflow:** Use [multi-topic-portfolio.yml](multi-topic-portfolio.yml)

### Example 3: By Purpose

```json
{
  "title": "Project Categories",
  "description": "Projects organized by purpose",
  "groups": [
    {
      "topic": "microservices",
      "folder": "Microservices",
      "name": "Microservices",
      "description": "Backend microservices",
      "remove_prefix": ""
    },
    {
      "topic": "libraries",
      "folder": "Libraries",
      "name": "Shared Libraries",
      "description": "Reusable libraries and packages",
      "remove_prefix": "^lib[-_]"
    },
    {
      "topic": "tools",
      "folder": "Tools",
      "name": "Development Tools",
      "description": "CLI tools and utilities",
      "remove_prefix": "^tool[-_]"
    }
  ]
}
```

## Common Patterns

### Pattern 1: Single Topic

Simplest setup for bundling repositories with one topic.

```yaml
# Workflow
uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
with:
  config-file: '.github/config/meta-repository/topics.json'
```

```json
// Config
{
  "groups": [
    {
      "topic": "shopware5-plugins",
      "folder": "Plugins",
      "name": "Plugins",
      "description": "Plugin collection",
      "remove_prefix": "^SWP[-_]"
    }
  ]
}
```

### Pattern 2: Multi-Topic

Organize by multiple categories.

```json
{
  "groups": [
    {"topic": "frontend", "folder": "Frontend", "remove_prefix": "^fe[-_]", ...},
    {"topic": "backend", "folder": "Backend", "remove_prefix": "^be[-_]", ...},
    {"topic": "shared", "folder": "Shared", "remove_prefix": "", ...}
  ]
}
```

### Pattern 3: Per-Topic Prefix Removal

Clean repository names with topic-specific patterns.

```json
{
  "groups": [
    {
      "topic": "shopware5-plugins",
      "folder": "Plugins",
      "remove_prefix": "^SWP[-_]"
    },
    {
      "topic": "shopware5-themes",
      "folder": "Themes",
      "remove_prefix": "^SWT[-_]"
    }
  ]
}
```

**Result:**
```
Input:  SWP-PaymentGateway  → Output: Plugins/PaymentGateway/
Input:  SWT-CustomTheme     → Output: Themes/CustomTheme/
```

### Pattern 4: Event-Driven

Real-time updates from projects.

**Meta repo workflow:**
```yaml
on:
  repository_dispatch:
    types: [trigger-from-repository]
```

**Plugin workflow:**
```yaml
on:
  push:
    branches: [main]

jobs:
  notify:
    steps:
      - run: gh api repos/org/meta-repo/dispatches -f event_type=trigger-from-repository
```

## Workflow Parameters

### Quick Reference

For a complete list of all parameters, see **[PARAMETERS.md](PARAMETERS.md)**.

**Most commonly used parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `config-file` | string | `.github/config/meta-repository/topics.json` | Configuration file path |
| `include-private` | boolean | `false` | Include private repositories |
| `organization` | string | (auto) | GitHub organization name |
| `generate-readme` | boolean | `true` | Generate README.md |
| `auto-commit` | boolean | `true` | Auto-commit changes |
| `submodule-depth` | number | `1` | Git clone depth for submodules |

**Example:**

```yaml
with:
  config-file: '.github/config/meta-repository/topics.json'
  include-private: true
  generate-readme: true
  auto-commit: true
```

👉 **See [PARAMETERS.md](PARAMETERS.md) for complete parameter reference with examples.**

### Output Files

The workflow generates multiple output files per topic group:

| File Pattern | Description | Example |
|--------------|-------------|---------|
| `{topic}.json` | Full repository metadata | `shopware5-plugins.json` |
| `{topic}.txt` | Repository names with prefix | `shopware5-plugins.txt` |
| `{topic}.noprefix.txt` | Cleaned repository names | `shopware5-plugins.noprefix.txt` |

**Example:**

For topic `shopware5-plugins` with `remove_prefix: "^SWP[-_]"`:

```txt
# shopware5-plugins.txt (original names)
SWP-AmazonToolkit
SWP-ArticleWeight
SWP-BootstrapIntegration

# shopware5-plugins.noprefix.txt (cleaned names)
AmazonToolkit
ArticleWeight
BootstrapIntegration
```

## Secrets Required

| Secret | Required | Purpose |
|--------|----------|---------|
| `GITHUB_TOKEN` | Auto-available | Repository access and commits (automatically provided) |
| `GH_PAT` | **For private repos** | Personal Access Token with `repo` scope for accessing private repositories |
| `META_REPO_TOKEN` | For triggers | Cross-repo dispatch (PAT with repo scope) |
| `TEAMS_WEBHOOK_URL` | For notifications | Microsoft Teams integration |

### ⚠️ Important: Private Repository Access

To include private repositories in your meta repository sync, you **must** provide a Personal Access Token (PAT):

**Setup:**
1. Create a PAT at https://github.com/settings/tokens with `repo` scope
2. Add the PAT as a repository or organization secret named `GH_PAT`
3. Pass it via `secrets` in your workflow:

```yaml
jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    secrets:
      GH_PAT: ${{ secrets.GH_PAT }}  # Required for private repos
    with:
      include-private: true
```

**Why is this needed?**
The default `GITHUB_TOKEN` provided by GitHub Actions has limited permissions and may not have access to all private repositories in your organization. A PAT with `repo` scope ensures full access to both public and private repositories.

## Best Practices

### 1. Use Descriptive Topics

✅ **Good:**
- `shopware5-plugins`
- `dotnet-libraries`
- `python-data-science`

❌ **Avoid:**
- `plugins` (too generic)
- `misc` (unclear)
- `projects` (too broad)

### 2. Organize Logically

Group by:
- Technology stack (dotnet, python, nodejs)
- Purpose (microservices, libraries, tools)
- Platform (shopware, wordpress, magento)

### 3. Use Per-Topic Prefix Removal

Configure prefix removal for each topic individually:

```json
{
  "groups": [
    {"topic": "shopware5-plugins", "remove_prefix": "^SWP[-_]"},
    {"topic": "shopware5-themes", "remove_prefix": "^SWT[-_]"},
    {"topic": "tools", "remove_prefix": ""}
  ]
}
```

This allows different naming conventions per category.

### 4. Keep README Updated

Use custom template for organization-specific content:

```markdown
# {{TITLE}}

> {{DESCRIPTION}}

## Our Custom Section

Add team-specific content here.

{{GROUPS}}
```

### 5. Schedule Wisely

```yaml
schedule:
  - cron: "45 23 * * 6"  # Low-traffic time
```

### 6. Monitor Sync Status

Use notifications or check workflow runs regularly.

## Troubleshooting

### Submodules Not Appearing

**Check:**
1. Topics applied to repositories?
2. Organization name correct?
3. GITHUB_TOKEN has access?

### Workflow Fails

**Check:**
1. Configuration JSON valid?
2. Permissions set correctly?
3. Paths in config correct?

### README Not Generated

**Check:**
1. `generate-readme: true` set?
2. Template file exists?
3. Placeholders correct?

## Next Steps

1. **Choose example** based on your needs
2. **Create meta repository**
3. **Copy example workflow**
4. **Create configuration**
5. **Apply topics** to your repositories
6. **Test** with manual trigger
7. **Monitor** first scheduled run

## Related Documentation

- [Meta Repository Sync Documentation](../../../docs/workflows/meta-repository-sync.md)
- [Configuration Reference](../../../.github/config/meta-repository/)
- [Workflow Reference](../../../.github/workflows/meta-repository-sync.yml)

## Support

For questions or issues:
1. Review this README
2. Check [documentation](../../../docs/workflows/meta-repository-sync.md)
3. Review [workflow source](../../../.github/workflows/meta-repository-sync.yml)
4. Open issue in automation-templates repo
