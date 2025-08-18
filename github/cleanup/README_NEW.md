# GitHub Repository Cleanup Tool

Ein plattformunabhängiges Python-Tool zur umfassenden Bereinigung von GitHub-Repositories mit komfortabler Device Flow Authentifizierung.

## Features

Das Tool entfernt automatisch:
- ✅ Alle Workflow-Runs (GitHub Actions)
- ✅ Alle Releases
- ✅ Alle Tags
- ✅ Alle Branches (außer `main` und `master`)

## Authentifizierung

### 🔐 GitHub Device Flow (Empfohlen)
- Keine manuelle Token-Erstellung erforderlich
- Sichere Browser-basierte Anmeldung
- Automatische Berechtigung aller erforderlichen Scopes
- Code wird automatisch in die Zwischenablage kopiert

### 🔑 Personal Access Token
- Traditionelle Token-basierte Authentifizierung
- Für Automatisierung und CI/CD geeignet

## Voraussetzungen

- Python 3.6 oder höher
- Internetverbindung für Device Flow oder GitHub Token

### Für Personal Access Token
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

### Device Flow Authentifizierung (Empfohlen)
```bash
python github_cleanup.py --owner <owner> --repo <repo> --device-auth [--dry-run]
```

### Token-basierte Authentifizierung
```bash
python github_cleanup.py --owner <owner> --repo <repo> --token <token> [--dry-run]
```

### PowerShell Schnellstart
```powershell
.\quick_cleanup.ps1 -Repository "owner/repo" -DryRun
```

### Beispiele

1. **Device Flow Dry-Run (Simulation ohne Löschung):**
   ```bash
   python github_cleanup.py --owner bauer-group --repo automation-templates --device-auth --dry-run
   ```

2. **Device Flow echte Bereinigung:**
   ```bash
   python github_cleanup.py --owner bauer-group --repo automation-templates --device-auth
   ```

3. **Token-basierte Bereinigung:**
   ```bash
   python github_cleanup.py --owner bauer-group --repo automation-templates --token ghp_xxxxxxxxxxxx
   ```

4. **Mit Environment Variable:**
   ```bash
   export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
   python github_cleanup.py --owner bauer-group --repo automation-templates --dry-run
   ```

## Sicherheitshinweise

⚠️ **WARNUNG**: Dieses Tool löscht dauerhaft alle Workflow-Runs, Releases, Tags und Branches (außer main/master).

- Verwenden Sie immer zuerst `--dry-run` um zu sehen, was gelöscht werden würde
- Erstellen Sie Backups wichtiger Daten vor der Ausführung
- Das Tool fragt vor destructiven Operationen nach Bestätigung

## Troubleshooting

### Device Flow Probleme
- Stellen Sie sicher, dass alle Dependencies installiert sind
- Überprüfen Sie Ihre Internetverbindung
- Bei Firewall-Problemen: verwenden Sie Personal Access Token

### Rate Limiting
- Das Tool hat eingebaute Rate-Limit-Behandlung
- Bei Überschreitung werden automatische Wartezeiten eingelegt

### API-Fehler
- Stellen Sie sicher, dass Sie die erforderlichen Berechtigungen haben
- Überprüfen Sie Repository-Name und Owner

## Logs und Debugging

Das Tool gibt detaillierte Informationen über alle Aktionen aus:
```
🔐 Starte GitHub Device Flow Authentifizierung...
📱 Bitte besuchen Sie: https://github.com/login/device
🔢 Und geben Sie diesen Code ein: XXXX-XXXX
⏳ Warte auf Autorisierung...
✅ Authentifizierung erfolgreich!
✅ Erfolgreich angemeldet als: username (Name)
🔍 [DRY-RUN] Starting workflow runs cleanup...
```

## Unterstützung

Bei Problemen:
- Überprüfen Sie die Logs auf Fehlermeldungen
- Stellen Sie sicher, dass alle Abhängigkeiten installiert sind
- Testen Sie mit `--dry-run` Parameter
- Öffnen Sie ein Issue im Repository

## Lizenz

MIT License - siehe LICENSE Datei für Details.
