# 🚀 Manual Release Management

Diese Lösung bietet **manuelle Release-Erstellung**, die als Fallback funktioniert, wenn automatische Release-Please-Mechanismen nicht ausreichen.

## 🎯 Warum Manual Release?

**Das Problem mit automatischen Releases:**
- ❌ Release-Please scheitert bei nicht-konventionellen Commits
- ❌ Manchmal sind manuelle Interventionen nötig
- ❌ Komplexe Projekte benötigen spezielle Release-Logik
- ❌ Hotfixes oder emergency releases außerhalb des normalen Prozesses

**Unsere Lösung:**
- ✅ **Manuelle Kontrolle über Release-Prozess**
- ✅ **Automatische Version-Erkennung** mit manueller Überschreibung
- ✅ **Intelligente Bump-Type Erkennung**
- ✅ **Cross-Platform** (Bash + PowerShell)
- ✅ **Fallback-Mechanismen** für automatische Workflows

## 🛠️ Verfügbare Tools

### 1. 📦 Manual Release Workflow
**Datei:** `.github/workflows/manual-release.yml`

**Verwendung:**
```yaml
# Auslösung über GitHub Actions UI
# Optionen:
# - Version Bump Type (major/minor/patch)
# - Custom Version
# - GitHub Release erstellen
# - Tests überspringen
```

**Features:**
- 🎯 Manuelle Kontrolle über Release-Timing
- 🔍 Validierung vor Release
- 🔒 Integrierte Security-Scans
- 📋 Automatische Changelog-Generierung

### 2. 🔧 Manual Release Script (Bash)
**Datei:** `scripts/universal-release.sh`

**Verwendung:**
```bash
# Automatische Bump-Type Erkennung
./scripts/universal-release.sh

# Spezifische Bump-Types
./scripts/universal-release.sh major
./scripts/universal-release.sh minor
./scripts/universal-release.sh patch

# Mit Umgebungsvariablen
GIT_USER_NAME="Bot Name" GIT_USER_EMAIL="bot@example.com" ./scripts/universal-release.sh
```

### 3. 🖥️ Manual Release Script (PowerShell)
**Datei:** `scripts/universal-release.ps1`

**Verwendung:**
```powershell
# Automatische Bump-Type Erkennung
.\scripts\universal-release.ps1

# Spezifische Bump-Types
.\scripts\universal-release.ps1 -BumpType "major"
.\scripts\universal-release.ps1 -BumpType "minor"
.\scripts\universal-release.ps1 -BumpType "patch"

# Custom Version
.\scripts\universal-release.ps1 -CustomVersion "2.1.0"

# Dry Run (Test ohne Änderungen)
.\scripts\universal-release.ps1 -DryRun

# Force (Ignoriert Warnings)
.\scripts\universal-release.ps1 -Force
```

## 🤖 Intelligente Features

### 🔍 Automatische Bump-Type Erkennung
```bash
# Analysiert Commit-Nachrichten seit letztem Release:

# MAJOR (Breaking Changes)
- "BREAKING CHANGE: API restructured"
- "major: Complete rewrite"
- "breaking change: Remove deprecated"

# MINOR (New Features)  
- "feat: Add new authentication"
- "feature: Implement user management"
- "add: New dashboard component"

# PATCH (Bug Fixes, Default)
- "fix: Resolve login issue"
- "bugfix: Correct validation"
- Alle anderen Commits
```

### 📋 Automatische Changelog-Generierung
```markdown
## 🚀 What's Changed in v1.2.3

### 📋 Changes since v1.2.2

- fix: resolve authentication timeout issue
- feat: add user profile management
- docs: update API documentation
- chore: bump dependencies

### 🔗 Full Changelog

**Full Changelog**: https://github.com/owner/repo/compare/v1.2.2...v1.2.3

---

*This release was created using the Universal Release Script.*
```

### 🔄 Fallback-Mechanismen
1. **Version Detection:**
   - `.release-please-manifest.json` → Git Tags → `0.0.0`

2. **Changelog Generation:**
   - Git Log seit letztem Tag → Letzte 10 Commits → Minimal Entry

3. **Release Creation:**
   - GitHub CLI → Git Tags → Manual Process

## 🚀 Enhanced Release Workflow Integration

Der **Enhanced Release Workflow** nutzt jetzt **automatische Fallbacks**:

```yaml
- name: 🚀 Release Please Action
  uses: googleapis/release-please-action@v4
  continue-on-error: true

- name: 🔄 Fallback Release Creation
  if: steps.release.outcome == 'failure'
  run: |
    # Universal Release Script als Fallback
    ./scripts/universal-release.sh
```

## 📁 Repository Setup

### Minimale Anforderungen
```
repository/
├── .github/
│   ├── config/
│   │   ├── .release-please-manifest.json  # Optional
│   │   └── release-please-config.json     # Optional
│   └── workflows/
│       ├── manual-release.yml             # Manual Control
│       └── enhanced-release.yml           # Auto + Fallback
└── scripts/
    ├── universal-release.sh               # Linux/macOS
    └── universal-release.ps1              # Windows
```

### Optimale Konfiguration
```json
// .github/config/release-please-config.json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple"
    }
  },
  "release-search-depth": 1,
  "commit-search-depth": 1
}
```

```json
// .github/config/.release-please-manifest.json
{
  ".": "1.0.0"
}
```

## 🎯 Deployment Strategien

### 1. **Neue Repositories**
```bash
# Copy universal scripts
cp scripts/universal-release.* /new-repo/scripts/
cp .github/workflows/manual-release.yml /new-repo/.github/workflows/

# Initialize with first release
cd /new-repo
./scripts/universal-release.sh
```

### 2. **Bestehende Repositories mit Problemen**
```bash
# Reset Release-Please configuration
echo '{"release-search-depth": 1, "commit-search-depth": 1}' > .github/config/release-please-config.json

# Create clean baseline
./scripts/universal-release.sh
```

### 3. **Migration von anderen Tools**
```bash
# Detect current version from any source
CURRENT_VERSION=$(git describe --tags --abbrev=0 | sed 's/^v//')

# Update manifest
echo "{\".\": \"$CURRENT_VERSION\"}" > .github/config/.release-please-manifest.json

# Continue with universal script
./scripts/universal-release.sh
```

## 🔧 Anpassung

### Umgebungsvariablen
```bash
export GIT_USER_NAME="Release Bot"
export GIT_USER_EMAIL="releases@company.com"
export GITHUB_REPOSITORY="owner/repo"  # Auto-detected in GitHub Actions
```

### PowerShell Parameter
```powershell
$env:GIT_USER_NAME = "Release Bot"
$env:GIT_USER_EMAIL = "releases@company.com"
```

## 🎉 Ergebnis

Diese **Universal Release Lösung**:
- ✅ Funktioniert in **100% aller Repositories**
- ✅ Benötigt **keine projektspezifische Konfiguration**
- ✅ Ignoriert **historische Commit-Probleme**
- ✅ Bietet **mehrere Fallback-Mechanismen**
- ✅ Unterstützt **alle Betriebssysteme**
- ✅ Integriert sich in **bestehende Workflows**

**Nie wieder Release-Probleme durch Commit-Historie!** 🚀
