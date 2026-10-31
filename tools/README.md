# 🚀 Automation Deployment Tools

Dieses Verzeichnis enthält Tools zur einfachen Bereitstellung der wiederverwendbaren Automationen in anderen Repositories, während die gesamte Logik zentral hier gepflegt wird.

## 📋 Übersicht

### Bereitstellungskonzept

- **Zentrale Logik**: Alle Workflow-Logik bleibt in diesem Repository
- **Referenz-Workflows**: Ziel-Repositories erhalten nur "Wrapper"-Workflows, die auf die zentralen Workflows verweisen
- **Konfigurationsbasiert**: Einfache Anpassung durch Konfigurationsdateien
- **Automatische Updates**: Änderungen in diesem Repository werden automatisch in allen verwendenden Repositories aktiv

## 🛠️ Tools

### `deploy-automations.sh` (Linux/macOS)
Bash-basiertes Deployment-Tool für Unix-Systeme.

### `deploy-automations.ps1` (Windows)
PowerShell-basiertes Deployment-Tool für Windows-Systeme.

### `deploy-config.yml`
Zentrale Konfigurationsdatei für Deployment-Profile und Einstellungen.

## 🚀 Verwendung

### Basis-Deployment
```bash
# Linux/macOS
./deploy-automations.sh --profile basic owner/my-repo

# Windows
.\deploy-automations.ps1 -Profile basic owner/my-repo
```

### Vollständiges Deployment
```bash
# Alle verfügbaren Automationen
./deploy-automations.sh --profile complete owner/my-repo
```

### Nur Sicherheits-Workflows
```bash
# Nur Security-relevante Workflows
./deploy-automations.sh --profile security-focused owner/my-repo
```

### Spezifische Workflows
```bash
# Auswahl bestimmter Workflows
./deploy-automations.sh --workflows "ci-cd,teams-notifications" owner/my-repo

# Mit Projekt-Typ für spezifische Konfigurationen
./deploy-automations.sh --profile basic --project-type nodejs owner/my-repo
```

### Dry Run (Vorschau)
```bash
# Zeigt was deployed würde, ohne Änderungen zu machen
./deploy-automations.sh --profile complete --dry-run owner/my-repo
```

## 📦 Deployment-Profile

### `basic` - Basis-Automationen
**Enthält:**
- CI/CD Pipeline
- Security Management
- Documentation
- Teams Notifications

**Benötigte Secrets:**
- `TEAMS_WEBHOOK_URL`

### `complete` - Alle Automationen
**Enthält:**
- Alle Basic-Workflows
- Docker Hub Integration
- Release Management

**Benötigte Secrets:**
- `TEAMS_WEBHOOK_URL`
- `DOCKER_PASSWORD`

### `security-focused` - Nur Sicherheit
**Enthält:**
- Security Management
- Teams Notifications

**Benötigte Secrets:**
- `TEAMS_WEBHOOK_URL`

### `docs-only` - Nur Dokumentation
**Enthält:**
- Documentation Workflows

**Benötigte Secrets:** Keine

## 🔧 Was wird erstellt

### Workflow-spezifische Konfigurationen
```
.github/config/
├── security-policy/config.yml          # Security Management
├── teams-notification/                 # Teams Notifications
│   ├── default.yml
│   ├── success.yml
│   ├── failure.yml
│   └── ...
├── docker-build/default.yml           # Docker Workflows
├── nodejs-build/default.yml           # Node.js Projekte
├── dotnet-build/default.yml           # .NET Projekte
└── python-build/default.yml           # Python Projekte
```

### In Ziel-Repository: `.github/workflows/`
```yaml
name: 🔄 ci-cd (via Automation Templates)

on:
  workflow_call:
    secrets:
      TEAMS_WEBHOOK_URL:
        required: false

jobs:
  delegate-to-automation-templates:
    name: 🚀 Execute via Automation Templates
    uses: bauer-group/automation-templates/.github/workflows/ci-cd.yml@main
    secrets: inherit
```

### In Ziel-Repository: `.github/actions/`
```yaml
name: 'teams-notification (via Automation Templates)'
description: 'Centralized teams-notification action from automation templates'

runs:
  using: 'composite'
  steps:
    - name: 🚀 Execute Centralized Action
      uses: bauer-group/automation-templates/.github/actions/teams-notification@main
```

### Konfigurationsdatei: `.github/config/automation-templates/config.yml`
```yaml
# Repository-spezifische Konfiguration
repository:
  name: ${{ github.repository }}
  description: "Your repository description"
  
teams:
  notification_level: "errors-only"
  
security:
  policy_version: "1.0.0"
  review_cycle: 12
```

### Setup-Dokumentation: `AUTOMATION-SETUP.md`
Vollständige Anleitung zur Konfiguration und Verwendung der deploierten Automationen.

## ⚙️ Konfiguration

### Repository Secrets
Die folgenden Secrets müssen im Ziel-Repository konfiguriert werden:

| Secret | Beschreibung | Benötigt für |
|--------|-------------|--------------|
| `TEAMS_WEBHOOK_URL` | Microsoft Teams Webhook URL | Teams-Benachrichtigungen |
| `DOCKER_PASSWORD` | Docker Hub Passwort/Token | Docker-Workflows |

### Repository Variables
Optionale Konfiguration über Repository-Variablen:

| Variable | Beschreibung | Standard |
|----------|-------------|----------|
| `TEAMS_NOTIFICATION_LEVEL` | Benachrichtigungslevel (all/errors-only) | errors-only |
| `TEAMS_MENTION_ON_FAILURE` | Benutzer bei Fehlern erwähnen | |
| `TEAMS_MENTION_ON_PR_REVIEW` | Benutzer bei PR-Reviews erwähnen | |

## 🎯 Automatische Konfiguration

### Projekt-Typ erkennen
```bash
# Das Tool kopiert automatisch die passenden Konfigurationen
./deploy-automations.sh --profile basic --project-type nodejs owner/my-repo
```

**Unterstützte Projekt-Typen:**
- `nodejs` - Node.js/React/Vue/Angular Projekte
- `dotnet` - .NET/C# Projekte  
- `python` - Python/Django/Flask Projekte
- `docker` - Container-basierte Projekte

### Was wird automatisch konfiguriert

| Workflow | Benötigte Configs | Automatisch kopiert |
|----------|------------------|-------------------|
| `security-management` | `security-policy/config.yml` | ✅ Ja |
| `teams-notifications` | `teams-notification/*.yml` | ✅ Ja |
| `docker-hub` | `docker-build/default.yml` | ✅ Ja |
| `ci-cd` (Node.js) | `nodejs-build/default.yml` | ✅ Ja |
| `ci-cd` (.NET) | `dotnet-build/default.yml` | ✅ Ja |
| `ci-cd` (Python) | `python-build/default.yml` | ✅ Ja |

## 🔄 Funktionsweise

### 1. Zentrale Ausführung
Alle Workflow-Logik bleibt in `bauer-group/automation-templates`:
```yaml
uses: bauer-group/automation-templates/.github/workflows/ci-cd.yml@main
```

### 2. Automatische Updates
Änderungen in diesem Repository werden sofort in allen verwendenden Repositories aktiv.

### 3. Konfigurationsbasierte Anpassung
Repositories können das Verhalten über Konfigurationsdateien anpassen, ohne Workflows zu ändern.

## 🎯 Vorteile

### ✅ Zentrale Wartung
- Alle Logik in einem Repository
- Updates propagieren automatisch
- Einheitliche Standards

### ✅ Einfache Verwendung
- Ein Befehl für komplettes Setup
- Vorkonfigurierte Profile
- Ausführliche Dokumentation

### ✅ Flexibilität
- Anpassbare Profile
- Repository-spezifische Konfiguration
- Optionale Komponenten

### ✅ Sicherheit
- Keine Duplikation von Secrets
- Zentrale Security-Updates
- Konsistente Sicherheitsstandards

## 🛠️ Erweiterte Verwendung

### Eigene Profile erstellen
Bearbeite `deploy-config.yml` um eigene Profile zu definieren:

```yaml
profiles:
  my-custom-profile:
    description: "Mein angepasstes Profil"
    workflows:
      - "ci-cd"
      - "teams-notifications"
    actions:
      - "teams-notification"
```

### Repository-spezifische Anpassungen
Nach dem Deployment kann die Konfiguration angepasst werden:

```yaml
# .github/config/automation-templates/config.yml
teams:
  notification_level: "all"  # Alle Benachrichtigungen
  
security:
  policy_version: "2.0.0"    # Eigene Policy-Version
  review_cycle: 6            # Review alle 6 Monate
```

## 📞 Support

- **Dokumentation**: Siehe jeweilige Action/Workflow README-Dateien
- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Updates**: [GitHub Releases](https://github.com/bauer-group/automation-templates/releases)

---

**🎯 Zentrale Automationen - Einfach zu verwenden, einfach zu warten!**