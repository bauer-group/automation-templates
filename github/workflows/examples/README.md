# 🚀 Enhanced Release Workflow

Diese Sammlung enthält das volls### 4. Repository Secrets (optional)

Für erweiterte Features konfiguriere optional:

**Gitleaks Pro (für Organisationen):**
- `GITLEAKS_LICENSE`: Gitleaks Pro Lizenzschlüssel für erweiterte Features

**GitGuardian Enterprise:**
- `GITGUARDIAN_API_KEY`: GitGuardian API Schlüssel für Enterprise-Features

**Package Publishing:**
- `NPM_TOKEN`: Für NPM Package Publishing
- `DOCKER_REGISTRY_TOKEN`: Für Docker Image Publishing

**Hinweis:** Der Workflow funktioniert vollständig mit nur `GITHUB_TOKEN` (automatisch verfügbar)hanced Release Management System mit **googleapis/release-please** Integration.

## 📦 Workflow Features

### [Enhanced Release Example](enhanced-release-example.md)

Der umfassende Enterprise-Workflow mit allen Security-, Compliance- und Artifact-Features.

**Core Features:**

- ✅ **googleapis/release-please** Integration
- ✅ Conventional Commit Validation mit erweiterten Regeln
- ✅ Automatische Releases mit intelligenter Versionierung
- ✅ README Auto-Update mit Template-System

**Security & Compliance:**

- ✅ Dual-Engine Security Scanning (Gitleaks + GitGuardian)
- ✅ SPDX License Compliance mit SBOM-Generierung
- ✅ Vulnerability Assessment
- ✅ Secret Detection

**Automation & CI/CD:**

- ✅ Umfassende Artifact-Generierung (Docker, NPM, Binaries)
- ✅ Automatisches PR-Management mit intelligenten Merge-Regeln
- ✅ Branch Cleanup und Repository-Wartung
- ✅ Detaillierte Reports und Monitoring

**Geeignet für:**

- Alle Projektgrößen (skalierbar konfigurierbar)
- Enterprise-Projekte mit Security-Anforderungen
- Compliance-kritische Anwendungen
- Teams mit automatisierten Workflows

## 🔧 Setup Instructions

### 1. Workflow-Dateien kopieren

Kopiere den Enhanced Release Workflow in dein Repository:

```bash
# Enhanced Release Workflow
.github/workflows/enhanced-release.yml
.github/config/release-please-config.json
.github/config/.release-please-manifest.json
.github/config/commitlint.config.js

# Modulare Actions
.github/actions/               # Alle security, compliance und automation actions
.gitleaks.toml                 # Gitleaks Konfiguration
.gitguardian.yml              # GitGuardian Konfiguration
```

### 2. Konfiguration anpassen

Passe die Konfigurationsdateien an dein Projekt an:

- **release-please-config.json**: Projekt-Name, Release-Type, Changelog-Sections
- **commitlint.config.js**: Commit-Regeln (optional anpassbar)
- **.gitleaks.toml**: Security-Patterns (optional)
- **.gitguardian.yml**: Security-Regeln (optional)

### 3. Repository Secrets (optional)

Für erweiterte Features konfiguriere optional:

- `GITLEAKS_LICENSE_KEY`: Für Gitleaks Pro Features
- `GITGUARDIAN_API_KEY`: Für GitGuardian Enterprise
- `NPM_TOKEN`: Für NPM Package Publishing
- `DOCKER_REGISTRY_TOKEN`: Für Docker Image Publishing

**Hinweis:** Der Workflow funktioniert vollständig mit nur `GITHUB_TOKEN` (automatisch verfügbar)

### 4. Erste Verwendung

1. Erstelle einen Commit mit Conventional Commit Format (z.B. `feat: add new feature`)
2. Push auf den main Branch
3. Der Enhanced Release Workflow wird automatisch ausgeführt

## 📊 Feature Matrix

| Kategorie | Features | Status |
|-----------|----------|--------|
| **Release Management** | googleapis/release-please, Conventional Commits, Intelligent Versioning | ✅ Vollständig |
| **Security Scanning** | Gitleaks + GitGuardian Dual-Engine, Secret Detection | ✅ Vollständig |
| **Compliance** | SPDX License Compliance, SBOM Generation, Audit Trails | ✅ Vollständig |
| **Artifact Management** | Multi-Format Builds, Docker Images, NPM Packages | ✅ Vollständig |
| **Automation** | Auto-Merge, Branch Cleanup, PR Management | ✅ Vollständig |
| **Monitoring** | Detailed Reports, Performance Metrics, Error Tracking | ✅ Vollständig |
| **Documentation** | Auto-README Updates, Changelog Generation | ✅ Vollständig |
| **CI/CD Integration** | GitHub Actions, Workflow Orchestration | ✅ Vollständig |

## 🎯 Quick Start Commands

### Enhanced Release Setup

```bash
# Repository klonen/vorbereiten
mkdir my-project && cd my-project
git init

# Enhanced Release Workflow kopieren
mkdir -p .github/workflows .github/config .github/actions
cp path/to/examples/enhanced-release-example.md .github/workflows/enhanced-release.yml

# Modulare Actions kopieren
cp -r path/to/.github/actions/* .github/actions/

# Basis-Konfiguration erstellen
echo '{"packages": {".": {"release-type": "simple", "package-name": "my-project"}}}' > .github/config/release-please-config.json
echo '{".": "0.1.0"}' > .github/config/.release-please-manifest.json

# Erstes Release vorbereiten
git add .
git commit -m "feat: initial release setup"
git push origin main
```

### Konfiguration für spezifische Projekttypen

```bash
# Node.js Projekt
echo '{"packages": {".": {"release-type": "node", "package-name": "my-node-app"}}}' > .github/config/release-please-config.json

# Python Projekt  
echo '{"packages": {".": {"release-type": "python", "package-name": "my-python-app"}}}' > .github/config/release-please-config.json

# Go Projekt
echo '{"packages": {".": {"release-type": "go", "package-name": "my-go-app"}}}' > .github/config/release-please-config.json

# Simple/Generic Projekt
echo '{"packages": {".": {"release-type": "simple", "package-name": "my-project"}}}' > .github/config/release-please-config.json
```

## 🔄 Migration Path

### Von anderen Release-Tools

1. **Backup erstellen**: Exportiere bestehende Release-Historie
2. **Release-Please konfigurieren**: Setze korrekte Startversion in `.release-please-manifest.json`
3. **Conventional Commits**: Migriere zu Conventional Commit Format falls nötig
4. **Test-Release**: Teste mit einem Dummy-Release

### Von Standard GitHub Releases

```bash
# Letzte Version ermitteln
LAST_VERSION=$(gh release list --limit 1 --json tagName --jq '.[0].tagName')

# Release-Please Manifest erstellen
echo "{\".\": \"$LAST_VERSION\"}" > .github/config/.release-please-manifest.json

# Enhanced Workflow aktivieren
cp examples/enhanced-release-example.md .github/workflows/enhanced-release.yml
```

### Von manuellen Releases

1. **Commit-Historie analysieren**: Prüfe bestehende Commit-Nachrichten
2. **Conventional Commits einführen**: Schrittweise Migration der Commit-Patterns
3. **Enhanced Workflow testen**: Parallel zum manuellen Prozess
4. **Vollständige Migration**: Nach erfolgreichen Tests

## 📚 Weitere Ressourcen

- **[googleapis/release-please](https://github.com/googleapis/release-please)**: Offizielle Release-Please Dokumentation
- **[Conventional Commits](https://www.conventionalcommits.org/)**: Conventional Commit Specification
- **[SPDX License List](https://spdx.org/licenses/)**: Standardisierte Lizenz-Identifier
- **[Security Scanning Best Practices](https://docs.github.com/en/code-security)**: GitHub Security Features

## 🆘 Troubleshooting

### Häufige Probleme

**Release wird nicht erstellt:**

- Prüfe Conventional Commit Format
- Vergewissere dich, dass releasable Commits seit letztem Release vorhanden sind
- Überprüfe .release-please-manifest.json

**Security Scan fehlgeschlagen:**

- Prüfe Repository Secrets (GITLEAKS_LICENSE_KEY, GITGUARDIAN_API_KEY)
- Überprüfe .gitleaks.toml und .gitguardian.yml Konfiguration
- Teste Security Scan lokal

**Artifact Generation fehlgeschlagen:**

- Prüfe Build-Commands in artifact-generator Action
- Vergewissere dich, dass Upload-Permissions korrekt sind
- Überprüfe Docker Registry Credentials

### Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
- **Enhanced Release Documentation**: [Enhanced Release README](../README.MD)

## 🎉 Fazit

Der Enhanced Release Workflow bietet eine vollständige, produktionsreife Lösung für moderne DevOps-Workflows mit:

- **Zero-Configuration Start**: Funktioniert sofort mit minimaler Konfiguration
- **Skalierbare Features**: Von einfachen Projekten bis hin zu Enterprise-Anforderungen
- **Security-First Approach**: Integrierte Security- und Compliance-Features
- **Intelligent Automation**: Automatisierte Entscheidungen basierend auf Projektkontext
- **Comprehensive Monitoring**: Detaillierte Einblicke in alle Workflow-Aspekte

**Ready to use, built for scale!** 🚀
