# 🔗 Action Resolver

A central module for automatic resolution of action paths for local and external workflow usage.

## 🎯 Purpose

This module solves the problem that reusable workflows don't know whether they are being called locally (within the automation-templates repository) or externally (from other repositories). It automatically provides the correct action path.

## 📋 Usage

### Basic Usage

```yaml
steps:
  - name: 🔗 Resolve Action Paths
    id: resolver
    uses: ${{ github.repository == 'bauer-group/automation-templates' && './.github/actions/action-resolver' || 'bauer-group/automation-templates/.github/actions/action-resolver@main' }}
    with:
      action-name: 'teams-notification'

  - name: Use Resolved Action
    uses: ${{ steps.resolver.outputs.action-path }}
    with:
      # Your action inputs here
```

### Advanced Configuration

```yaml
steps:
  - name: 🔗 Resolve Action Paths
    id: resolver
    uses: bauer-group/automation-templates/.github/actions/action-resolver@main
    with:
      action-name: 'security-scan'
      repository: 'bauer-group/automation-templates'  # Optional
      ref: 'v2.1.0'                                   # Optional, default: main
      current-repository: ${{ github.repository }}    # Optional, auto-detected
```

## 📊 Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `action-name` | ✅ | - | Name of the action (e.g. 'teams-notification', 'security-scan') |
| `repository` | ❌ | `bauer-group/automation-templates` | Repository containing the automation templates |
| `ref` | ❌ | `main` | Git reference (branch/tag) for external actions |
| `current-repository` | ❌ | `${{ github.repository }}` | Current repository context |

## 📤 Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `action-path` | Resolved action path | `./.github/actions/teams-notification` or `bauer-group/automation-templates/.github/actions/teams-notification@main` |
| `is-local` | Whether the action is being used locally | `true` or `false` |
| `repository-info` | Repository context information | `local` or `external:bauer-group/automation-templates@main` |

## 🔄 How It Works

1. **Local Usage** (within automation-templates):
   - Automatically detects that `github.repository == 'bauer-group/automation-templates'`
   - Returns relative path: `./.github/actions/ACTION-NAME`

2. **External Usage** (from other repositories):
   - Automatically detects external usage
   - Returns remote reference: `bauer-group/automation-templates/.github/actions/ACTION-NAME@REF`

## 💡 Benefits

- ✅ **Automatic Detection**: No manual path adjustments needed
- ✅ **Single Source of Truth**: Central configuration for all workflows
- ✅ **Version Control**: Supports specific tags/branches for external usage
- ✅ **Easy Maintenance**: Changes only needed in one place
- ✅ **Debugging**: Clear outputs for troubleshooting

## 🛠️ Integration into Existing Workflows

### Before Integration:
```yaml
steps:
  - uses: ./.github/actions/teams-notification  # Only works locally
```

### After Integration:
```yaml
steps:
  - name: 🔗 Resolve Action Paths
    id: resolver
    uses: bauer-group/automation-templates/.github/actions/action-resolver@main
    with:
      action-name: 'teams-notification'
      
  - uses: ${{ steps.resolver.outputs.action-path }}  # Works both locally and externally
```

## 🔧 Supported Actions

- All actions in the `.github/actions/` directory

## 🐛 Troubleshooting

The Action Resolver module provides detailed debug information:

```
🔍 Resolving action path for: teams-notification
📍 Current repository: user/my-repo
🎯 Target repository: bauer-group/automation-templates
🌐 Using external action path: bauer-group/automation-templates/.github/actions/teams-notification@main
🎉 Action resolution complete!
   Path: bauer-group/automation-templates/.github/actions/teams-notification@main
   Local: false
   Info: external:bauer-group/automation-templates@main
```

When troubleshooting, check:
1. Is the `action-name` spelled correctly?
2. Does the action exist in the specified repository?
3. Is the reference (branch/tag) available?