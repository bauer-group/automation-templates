# Standard Release Workflow Beispiel

Einfacher Release-Workflow für kleinere bis mittlere Projekte.

## Workflow Datei (.github/workflows/release.yml)

```yaml
name: 🚀 Standard Release

on:
  push:
    branches: [ main ]
    paths-ignore:
      - '**.MD'
      - 'docs/**'
  pull_request:
    types: [ closed ]
    branches: [ main ]
  workflow_dispatch:
    inputs:
      release-type:
        description: "Type of release"
        required: false
        default: 'simple'
        type: choice
        options:
          - simple
          - node
          - python
          - rust
          - java
          - go
      force-release:
        description: "Force create release"
        type: boolean
        default: false

permissions:
  contents: write
  pull-requests: write
  issues: write
  actions: read

jobs:
  # Validate conventional commits on PR
  validate-commits:
    name: 🔍 Validate Commits
    if: github.event_name == 'pull_request' && github.event.pull_request.merged == false
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Validate Conventional Commits
        uses: wagoid/commitlint-github-action@v5
        with:
          configFile: .github/config/commitlint.config.js

  # Main release job
  release:
    name: 📦 Release Management
    if: |
      (github.event_name == 'push' && !contains(github.event.head_commit.message, 'chore(main): release')) ||
      (github.event_name == 'pull_request' && github.event.pull_request.merged == true) ||
      github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
      version: ${{ steps.release.outputs.version }}
    
    steps:
      - name: 🚀 Checkout Repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: 📦 Run Release Please
        id: release
        uses: googleapis/release-please-action@v4
        with:
          config-file: .github/config/release-please-config.json
          manifest-file: .github/config/.release-please-manifest.json
          token: ${{ secrets.GITHUB_TOKEN }}

  # Post-release actions
  post-release:
    name: 🎯 Post-Release Actions
    if: needs.release.outputs.release_created == 'true'
    needs: release
    runs-on: ubuntu-latest
    
    steps:
      - name: 🚀 Checkout Repository
        uses: actions/checkout@v4

      - name: 📢 Notify Release
        uses: actions/github-script@v7
        with:
          script: |
            console.log('🎉 New release created: ${{ needs.release.outputs.tag_name }}');
            console.log('Version: ${{ needs.release.outputs.version }}');
```

## Konfigurationsdateien

### .github/config/release-please-config.json
```json
{
  "packages": {
    ".": {
      "release-type": "simple",
      "package-name": "my-project",
      "bump-minor-pre-major": false,
      "bump-patch-for-minor-pre-major": false,
      "draft": false,
      "prerelease": false,
      "include-v-in-tag": false,
      "include-component-in-tag": false
    }
  },
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

### .github/config/.release-please-manifest.json
```json
{
  ".": "0.1.0"
}
```

### .github/config/commitlint.config.js
```javascript
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor', 
      'test', 'chore', 'ci', 'build', 'revert'
    ]],
    'subject-case': [2, 'never', ['start-case', 'pascal-case', 'upper-case']],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 100]
  }
};
```

## Features

- ✅ **Conventional Commit Validation**: Automatische Validierung von Commit-Messages
- ✅ **Release-Please Integration**: googleapis/release-please für semantisches Versioning
- ✅ **Automatic Releases**: GitHub Releases werden automatisch erstellt
- ✅ **Flexible Release Types**: Unterstützung für verschiedene Projekt-Typen
- ✅ **Manual Overrides**: Force-Release Option für manuelle Releases

## Supported Release Types

- `simple`: Einfache Projekte ohne Package-Management
- `node`: Node.js Projekte (package.json)
- `python`: Python Projekte (pyproject.toml, setup.py)
- `rust`: Rust Projekte (Cargo.toml)
- `java`: Java Projekte
- `go`: Go Module

## Trigger Conditions

1. **Push auf main**: Automatisch wenn releasable Commits vorhanden
2. **PR merged**: Nach erfolgreichem Merge
3. **Manual**: Über workflow_dispatch mit konfigurierbaren Optionen
