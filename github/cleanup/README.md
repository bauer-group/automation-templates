# GitHub Repository Cleanup Tool

Ein plattformunabhängiges Tool zur vollständigen Bereinigung von GitHub Repositories.

## Features

- 🧹 **Bereinigt Workflow Runs**: Löscht alle GitHub Actions Workflow-Läufe
- 🏷️ **Entfernt Tags**: Löscht alle Git-Tags und deren GitHub-Releases
- 🌿 **Löscht Branches**: Entfernt alle Branches außer `main` und `master`
- 🔐 **Automatische Authentifizierung**: Device Flow für sichere Browser-basierte Anmeldung
- 🎯 **Dry-Run Modus**: Sicherer Test-Modus ohne tatsächliche Änderungen
- 💻 **Cross-Platform**: Wrapper-Skripte für Windows, Linux und macOS

## Schnellstart

### Option 1: Python direkt
```bash
# Installation der Dependencies
pip install -r requirements.txt

# Mit Dry-Run (empfohlen für ersten Test)
python github_cleanup.py --owner bauer-group --repo automation-templates --dry-run

# Echte Bereinigung
python github_cleanup.py --owner bauer-group --repo automation-templates
```

### Option 2: Platform-spezifische Scripts

**Windows PowerShell:**
```powershell
.\github-cleanup.ps1 --owner bauer-group --repo automation-templates --dry-run
```

**Linux/macOS Bash:**
```bash
./github-cleanup.sh --owner bauer-group --repo automation-templates --dry-run
```

**Windows Batch:**
```batch
github-cleanup.bat --owner bauer-group --repo automation-templates --dry-run
```

## Authentifizierung

Das Tool verwendet automatisch den GitHub Device Flow:
1. Startet Browser-basierte Authentifizierung
2. Sie loggen sich in GitHub ein
3. Tool erhält temporären Zugriff
4. Token wird automatisch für die Session gespeichert

Alternativ können Sie einen Personal Access Token setzen:
```bash
# Als Umgebungsvariable
export GITHUB_TOKEN=ghp_your_token_here

# Oder direkt als Parameter
python github_cleanup.py --token ghp_your_token_here --owner myorg --repo myrepo
```

## Sicherheit

- ⚠️ **Achtung**: Dieses Tool löscht dauerhaft Daten aus Ihrem Repository
- 🧪 **Immer zuerst `--dry-run` verwenden** um zu sehen, was gelöscht würde
- 🔒 Tokens werden nur in-memory gespeichert, nie auf der Festplatte
- 🛡️ Device Flow bietet sicherere Authentifizierung als Personal Access Tokens

## Beispiele

```bash
# Trockenlauf - zeigt was gelöscht würde, ohne zu löschen
python github_cleanup.py --owner microsoft --repo typescript --dry-run

# Bereinigung mit eigenem Token
python github_cleanup.py --owner myorg --repo myrepo --token ghp_xxxxxxxxxxxx

# Verwendung mit Umgebungsvariable
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
python github_cleanup.py --owner myorg --repo myrepo
```

## Requirements

- Python 3.6+
- PyGithub >= 1.59.0
- requests >= 2.28.0
- pyperclip >= 1.8.0
