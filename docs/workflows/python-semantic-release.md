# Python Semantic Release System

Diese Dokumentation beschreibt das moderne Python CI/CD System mit automatischem Semantic Versioning und PyPI Publishing.

## Übersicht

Das Python System bietet zwei spezialisierte Workflows:

- **`python-build.yml`** - Für **Anwendungen** (Django, FastAPI, ML, CLI-Tools)
- **`python-semantic-release.yml`** - Für **Packages** (PyPI Publishing mit Semantic Versioning)

## Python Build Workflow (`python-build.yml`)

Für Python-Anwendungen ohne PyPI Publishing.

### Features:
- ✅ Multi-Python Version Support (3.8-3.13)
- ✅ Intelligente Dependency-Erkennung (pip, poetry, pipenv)
- ✅ Umfassende Tests (pytest, unittest, coverage)
- ✅ Code Quality (ruff, bandit, safety)
- ✅ Security Scanning
- ✅ Docker Integration
- ✅ Artifact Generation

### Verwendung:
```yaml
jobs:
  python-ci:
    uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main
    with:
      python-version: '3.12'
      run-tests: true
      collect-coverage: true
      run-security-scan: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

## Python Semantic Release (`python-semantic-release.yml`)

Für Python-Packages mit automatischem Semantic Versioning und PyPI Publishing.

### Features:
- ✅ **Semantic Versioning** - Automatische Versionierung basierend auf Conventional Commits
- ✅ **Trusted Publishing** - Sichere PyPI-Authentifizierung ohne API-Token
- ✅ **Changelog Generation** - Automatische CHANGELOG.md Erstellung
- ✅ **GitHub Releases** - Automatische Release-Erstellung
- ✅ **Multi-File Versioning** - Synchronisation von pyproject.toml und __init__.py
- ✅ **Umfassende Tests** - Quality Gates vor Release
- ✅ **Security Scanning** - Sicherheitsprüfungen
- ✅ **Wheel Testing** - Lokale Package-Installation Tests
- ✅ **Documentation Updates** - Automatische Dokumentation nach Release

### Verwendung:
```yaml
jobs:
  python-release:
    uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main
    with:
      python-version: '3.12'
      run-tests: true
      build-local-wheel: true
      skip-pypi: false
      update-documentation: true
      update-security-policy: true
    secrets: inherit
```

## Konfiguration

### pyproject.toml Setup
```toml
[tool.semantic_release]
# Version management
version_toml = ["pyproject.toml:project.version"]
version_variables = [
    "src/your_package/__init__.py:__version__",
]

# Git & Release configuration
branch = "main"
build_command = "python -m build"
upload_to_vcs_release = true

# Changelog configuration
changelog_file = "CHANGELOG.md"
changelog_sections = [
    {section = "breaking", name = "Breaking Changes"},
    {section = "feat", name = "Features"},
    {section = "fix", name = "Bug Fixes"},
    {section = "perf", name = "Performance Improvements"},
    {section = "refactor", name = "Code Refactoring"},
    {section = "style", name = "Code Style"},
    {section = "build", name = "Build System"},
    {section = "docs", name = "Documentation"},
    {section = "test", name = "Tests"},
    {section = "ci", name = "CI/CD"},
    {section = "chore", name = "Chores"},
    {section = "revert", name = "Reverts"},
]

# Commit parsing
commit_parser = "conventional"

[tool.semantic_release.commit_parser_options]
allowed_tags = ["feat", "fix", "docs", "style", "refactor", "perf", "test", "chore", "ci", "build", "revert"]
minor_tags = ["feat"]
patch_tags = ["fix", "perf"]
```

## Conventional Commits

### Version Bumps:
- **Major** (X.0.0): `feat!:` oder `fix!:` oder `BREAKING CHANGE:`
- **Minor** (0.X.0): `feat:`
- **Patch** (0.0.X): `fix:`, `perf:`

### Keine Version Bumps (nur Changelog):
- `docs:` - Dokumentation
- `style:` - Code-Formatierung
- `refactor:` - Code-Umstrukturierung
- `test:` - Tests
- `ci:` - CI/CD
- `chore:` - Wartung
- `build:` - Build-System
- `revert:` - Rückgängig machen

## Trusted Publishing Setup

### 1. PyPI Konfiguration:
1. Gehe zu https://pypi.org/manage/account/publishing/
2. Füge "pending publisher" hinzu:
   - **PyPI project name**: `your-package-name`
   - **Owner**: `your-github-username`
   - **Repository**: `your-repo-name`
   - **Workflow name**: `release.yml`
   - **Environment**: (leer lassen)

### 2. Workflow Trigger:
```yaml
on:
  push:
    branches: [main]
    paths-ignore:
      - '*.md'
      - 'docs/**'
```

## Projektstruktur

```
your-repo/
├── src/your_package/
│   ├── __init__.py          # __version__ = "1.0.0"
│   └── main.py
├── tests/
│   └── test_*.py
├── pyproject.toml           # Semantic release config
├── README.md
├── CHANGELOG.md             # Auto-generiert
└── .github/workflows/
    └── release.yml          # Dein Workflow
```

## Beispiele

### Vollständiges Beispiel:
Siehe [examples/python-semantic-release-example.yml](../../examples/python-semantic-release-example.yml)

### pyproject.toml Template:
Siehe [examples/pyproject.toml](../../examples/pyproject.toml)

## Migration von alten Workflows

### Von python-automatic-release.yml:
```diff
- uses: bauer-group/automation-templates/.github/workflows/python-automatic-release.yml@main
+ uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main
```

### Von python-publish.yml:
```diff
- uses: bauer-group/automation-templates/.github/workflows/python-publish.yml@main
+ uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main
  with:
-   registry: 'pypi'
+   skip-pypi: false
    secrets: inherit
```

## Vorteile des neuen Systems

- ✅ **Moderne Architektur** - python-semantic-release (2024 Standard)
- ✅ **Automatisches Versioning** - Basierend auf Commit-Messages
- ✅ **Sicheres Publishing** - Trusted Publishing ohne API-Token
- ✅ **Vollständige Integration** - Tests, Security, Docs, alles in einem
- ✅ **Bessere Performance** - Weniger Workflow-Overhead
- ✅ **Professionelle Changelogs** - Strukturiert und automatisch

## Support

Für Fragen und Probleme:
- [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- [Examples Directory](../../examples/)
- [Workflow Documentation](python-build.md)