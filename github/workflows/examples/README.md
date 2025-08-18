# 🚀 Workflow Examples

Diese Sammlung enthält vollständige Beispiele für die Verwendung der Automation Templates Workflows mit **googleapis/release-please** Integration.

## 📦 Verfügbare Beispiele

### [Standard Release Example](standard-release-example.md)

Einfacher Release-Workflow für kleine bis mittlere Projekte mit googleapis/release-please.

**Features:**

- ✅ Conventional Commit Validation
- ✅ Automatische Releases mit googleapis/release-please
- ✅ README Auto-Update
- ✅ Basic Post-Release Actions

**Geeignet für:**

- Kleine bis mittlere Projekte
- Einfache Release-Anforderungen
- Grundlegende Conventional Commit Validation

### [Enhanced Release Example](enhanced-release-example.md)

Enterprise-Workflow mit vollständigen Security-, Compliance- und Artifact-Features.

**Features:**

- ✅ Dual-Engine Security Scanning (Gitleaks + GitGuardian)
- ✅ SPDX License Compliance
- ✅ Umfassende Artifact-Generierung
- ✅ Automatisches PR-Management
- ✅ Branch Cleanup
- ✅ Detaillierte Reports

**Geeignet für:**

- Enterprise-Projekte
- Security & Compliance kritische Anwendungen
- Projekte mit umfassenden Artifact-Anforderungen

## 🔧 Setup Instructions

### 1. Workflow auswählen

Wähle den passenden Workflow basierend auf deinen Anforderungen:

- **Standard**: Für einfache Projekte ohne komplexe Security-Anforderungen
- **Enhanced**: Für Enterprise-Projekte mit umfassenden Security & Compliance Features

### 2. Dateien kopieren

Kopiere die entsprechenden Workflow-Dateien in dein Repository:

```bash
# Standard Release
.github/workflows/release.yml
.github/config/release-please-config.json
.github/config/.release-please-manifest.json
.github/config/commitlint.config.js

# Enhanced Release (zusätzlich)
.github/actions/               # Alle modularen Actions
.gitleaks.toml                 # Gitleaks Konfiguration
.gitguardian.yml              # GitGuardian Konfiguration
```

### 3. Konfiguration anpassen

Passe die Konfigurationsdateien an dein Projekt an:

- **release-please-config.json**: Projekt-Name, Release-Type
- **commitlint.config.js**: Commit-Regeln (optional)
- **.gitleaks.toml**: Security-Patterns (optional)

### 4. Repository Secrets

Konfiguriere die erforderlichen Secrets:

**Standard (automatisch verfügbar):**

- `GITHUB_TOKEN`: Für GitHub API Zugriff

**Enhanced (optional):**

- `GITLEAKS_LICENSE_KEY`: Für Gitleaks Pro Features
- `GITGUARDIAN_API_KEY`: Für GitGuardian Enterprise

### 5. Erste Verwendung

1. Erstelle einen Commit mit Conventional Commit Format
2. Push auf den main Branch
3. Der Workflow wird automatisch ausgeführt

## 📊 Workflow Comparison

| Feature | Standard | Enhanced |
|---------|----------|----------|
| **Release-Please** | ✅ googleapis/release-please | ✅ googleapis/release-please |
| **Conventional Commits** | ✅ | ✅ |
| **Security Scanning** | ❌ | ✅ (Dual-Engine) |
| **License Compliance** | ❌ | ✅ (SPDX + SBOM) |
| **Artifact Generation** | ❌ | ✅ (Multi-Format) |
| **Auto-Merge** | ❌ | ✅ (Intelligent) |
| **Branch Cleanup** | ❌ | ✅ |
| **Detailed Reports** | ❌ | ✅ |
| **Setup Complexity** | 🟢 Low | 🟡 Medium |
| **Enterprise Ready** | 🟡 Basic | ✅ Full |

## 🎯 Quick Start Commands

### Standard Release Setup

```bash
# Kopiere Standard Release Beispiel
cp examples/standard-release-example.md .github/workflows/release.yml

# Erstelle Konfiguration
mkdir -p .github/config
echo '{"packages": {".": {"release-type": "simple", "package-name": "my-project"}}}' > .github/config/release-please-config.json
echo '{".": "0.1.0"}' > .github/config/.release-please-manifest.json
```

### Enhanced Release Setup

```bash
# Kopiere Enhanced Release Beispiel
cp examples/enhanced-release-example.md .github/workflows/enhanced-release.yml

# Kopiere alle Actions
cp -r ../../.github/actions .github/

# Erstelle erweiterte Konfiguration
cp examples/configs/.gitleaks.toml .
cp examples/configs/.gitguardian.yml .
```

## 🔄 Migration Path

### Von Standard zu Enhanced

1. Behalte den bestehenden Standard-Workflow
2. Füge den Enhanced-Workflow parallel hinzu
3. Teste den Enhanced-Workflow mit Test-Releases
4. Deaktiviere den Standard-Workflow wenn Enhanced stabil läuft

### Von anderen Release-Tools

1. Exportiere bestehende Release-Historie
2. Konfiguriere Release-Please mit korrekter Startversion
3. Migriere Conventional Commit Format falls nötig
4. Teste mit einem Dummy-Release

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
