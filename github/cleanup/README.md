# GitHub Repository Cleanup Tool

Ein plattformunabhängiges Python-Tool zur umfassenden Bereinigung von GitHub-Repositories mit komfortabler OAuth-Authentifizierung.

## Features

Das Tool entfernt automatisch:
- ✅ Alle Workflow-Runs (GitHub Actions)
- ✅ Alle Releases
- ✅ Alle Tags
- ✅ Alle Branches (außer `main` und `master`)

## Authentifizierungs-Methoden

### 🔐 OAuth Browser-Login (Empfohlen)
- Keine manuelle Token-Erstellung erforderlich
- Sichere Browser-basierte Anmeldung
- Automatische Berechtigung aller erforderlichen Scopes

### 🔑 Personal Access Token
- Traditionelle Token-basierte Authentifizierung
- Manuell erstellter Token erforderlich
- Für Automatisierung und CI/CD geeignet

## Voraussetzungen

- Python 3.6 oder höher
- Internetverbindung für OAuth oder GitHub Token

### Für Personal Access Token:
GitHub Personal Access Token mit folgenden Berechtigungen:
- `repo` (Full control of private repositories)
- `actions` (Access to GitHub Actions)
- `admin:repo_hook` (Admin access to repository hooks)

## Installation

1. **Python-Abhängigkeiten installieren:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Optional: GitHub Token erstellen (nur für Token-basierte Auth):**
   - Gehen Sie zu [GitHub Settings > Personal Access Tokens](https://github.com/settings/tokens)
   - Erstellen Sie einen neuen Token mit den oben genannten Berechtigungen
   - Kopieren Sie den Token für die spätere Verwendung

## Verwendung

### OAuth-Authentifizierung (Empfohlen)

```bash
python github_cleanup.py --owner <owner> --repo <repo> --oauth [--dry-run]
```

### Token-basierte Authentifizierung

```bash
python github_cleanup.py --owner <owner> --repo <repo> --token <token> [--dry-run]
```

### Beispiele

1. **OAuth Dry-Run (Simulation ohne Löschung):**
   ```bash
   python github_cleanup.py --owner bauer-group --repo automation-templates --oauth --dry-run
   ```

2. **OAuth echte Bereinigung:**
   ```bash
   python github_cleanup.py --owner bauer-group --repo automation-templates --oauth
   ```

3. **Token-basierte Bereinigung:**
   ```bash
   python github_cleanup.py --owner bauer-group --repo automation-templates --token ghp_xxxxxxxxxxxx
   ```

3. **Mit Environment Variable:**
   ```bash
   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
   python github_cleanup.py --owner bauer-group --repo automation-templates
   ```

### Parameter

| Parameter | Beschreibung | Erforderlich |
|-----------|--------------|--------------|
| `--owner` | Repository-Besitzer/Organisation | ✅ |
| `--repo` | Repository-Name | ✅ |
| `--token` | GitHub Personal Access Token | ⚠️ (oder GITHUB_TOKEN env var) |
| `--dry-run` | Simulation ohne echte Löschung | ❌ |
| `--verbose` | Detaillierte Ausgabe | ❌ |

## Sicherheitshinweise

⚠️ **WICHTIG**: Dieses Tool führt **dauerhafte Löschungen** durch!

- **Führen Sie immer zuerst einen Dry-Run aus**: `--dry-run`
- **Erstellen Sie Backups** wichtiger Daten vor der Verwendung
- **Überprüfen Sie die Repository-Angaben** sorgfältig
- Das Tool fragt vor der echten Löschung um Bestätigung

## Beispiel-Ausgabe

```
🔧 [2025-08-18 14:30:15] INFO: 🚀 Starting GitHub repository cleanup...
🔧 [2025-08-18 14:30:15] INFO: Repository: bauer-group/automation-templates
🔧 [2025-08-18 14:30:15] INFO: Dry run mode: Disabled
🔧 [2025-08-18 14:30:16] INFO: Repository: bauer-group/automation-templates
🔧 [2025-08-18 14:30:16] INFO: Description: Centralized automation templates
🔧 [2025-08-18 14:30:16] INFO: Default branch: main
🔧 [2025-08-18 14:30:16] INFO: 🏃 Starting workflow runs cleanup...
🔧 [2025-08-18 14:30:17] INFO: Found 42 workflow runs
🔧 [2025-08-18 14:30:18] INFO: ✅ Deleted workflow run: Release Management (ID: 123456)
...
🔧 [2025-08-18 14:32:45] INFO: ✨ Cleanup completed successfully!
```

## Troubleshooting

### Häufige Probleme

1. **401 Unauthorized**
   - Überprüfen Sie Ihr GitHub Token
   - Stellen Sie sicher, dass das Token die erforderlichen Berechtigungen hat

2. **404 Not Found**
   - Überprüfen Sie Owner- und Repository-Namen
   - Stellen Sie sicher, dass Sie Zugriff auf das Repository haben

3. **403 Rate Limit**
   - Das Tool wartet automatisch bei Rate-Limiting
   - Bei großen Repositories kann der Prozess länger dauern

4. **Network Errors**
   - Überprüfen Sie Ihre Internetverbindung
   - Das Tool wiederholt fehlgeschlagene Anfragen automatisch

### Logs und Debugging

- Das Tool gibt detaillierte Logs aus
- Verwenden Sie `--verbose` für noch mehr Details
- Bei Problemen führen Sie zuerst einen `--dry-run` aus

## Lizenz

MIT License - Siehe [LICENSE](../../LICENSE) für Details.

## Support

Bei Problemen oder Fragen:
- Öffnen Sie ein Issue im Repository
- Kontaktieren Sie das BAUER GROUP Automation Team
