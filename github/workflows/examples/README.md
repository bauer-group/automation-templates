# Beispiel-Workflows für externe Repositories

Diese Sammlung enthält Beispiel-Workflows, die in externen Repositories verwendet werden können.

## 📁 Verfügbare Beispiele

### 📄 `readme-example.yml`
**Verwendung:** README-Generierung für externe Projekte
```yaml
name: README Update
on:
  pull_request:
    branches: [ main ]
  workflow_dispatch:
jobs:
  readme:
    uses: bauer-group/automation-templates/.github/actions/readme-generate@main
```

### 🚀 `release-example.yml`
**Verwendung:** Release-Management für externe Projekte
```yaml
name: Release
on:
  push:
    branches: [ main ]
jobs:
  release:
    uses: bauer-group/automation-templates/.github/actions/release-please@main
```

### 🔧 `full-pipeline-example.yml`
**Verwendung:** Vollständige CI/CD-Pipeline
- README-Update bei PRs
- Release-Management bei Push zu main

## 🚀 Schnellstart

1. Kopieren Sie die gewünschten Beispiele in Ihr Repository (`.github/workflows/`)
2. Passen Sie die Parameter an Ihr Projekt an
3. Erstellen Sie die erforderlichen Konfigurationsdateien
4. Committen und pushen Sie die Änderungen

## 📋 Voraussetzungen

- GitHub Repository mit Actions aktiviert
- Für README-Generation: Template-Datei (z.B. `docs/README.template.md`)
- Für Release-Please: Konfigurationsdateien (optional)

## 🔧 Konfiguration

Siehe [../README-CONFIGURATION.md](../README-CONFIGURATION.md) für detaillierte Konfigurationshinweise.
