# GitHub Repository Cleanup Tool - Dateiübersicht

## 📁 Struktur des Cleanup-Tools

```
github/cleanup/
├── 🐍 github_cleanup.py      # Haupt-Python-Skript (Kernlogik)
├── 📋 requirements.txt       # Python-Abhängigkeiten
├── 📖 README.md             # Hauptdokumentation
├── 📚 EXAMPLES.md           # Verwendungsbeispiele
├── ⚙️ config.example.py     # Beispiel-Konfiguration
├── 🪟 cleanup.bat           # Windows Batch Wrapper
├── 💙 cleanup.ps1           # PowerShell Wrapper
└── 🐧 cleanup.sh            # Bash/Linux Wrapper
```

## 🚀 Schnellstart

### 1. Abhängigkeiten installieren
```bash
pip install -r requirements.txt
```

### 2. Dry-Run ausführen
```bash
python github_cleanup.py --owner bauer-group --repo automation-templates --dry-run
```

### 3. Echte Bereinigung (nach Bestätigung)
```bash
python github_cleanup.py --owner bauer-group --repo automation-templates --token YOUR_TOKEN
```

## 🔧 Was wird bereinigt?

- ✅ **Workflow Runs**: Alle GitHub Actions Ausführungen
- ✅ **Releases**: Alle veröffentlichten Versionen
- ✅ **Tags**: Alle Git-Tags
- ✅ **Branches**: Alle außer `main` und `master`

## 🛡️ Sicherheitsfeatures

- 🔍 **Dry-Run Modus**: Zeigt nur an, was gelöschts würde
- ⚠️ **Bestätigungsabfrage**: Fragt vor echter Löschung nach
- 🔄 **Rate Limiting**: Automatische Behandlung von API-Limits
- 📝 **Detailliertes Logging**: Vollständige Nachverfolgung aller Aktionen

## 📱 Plattformunterstützung

| Plattform | Wrapper-Skript | Kommando |
|-----------|---------------|----------|
| 🪟 Windows | `cleanup.ps1` oder `cleanup.bat` | `.\cleanup.ps1 -Owner "bauer-group" -Repo "repo"` |
| 🐧 Linux | `cleanup.sh` | `./cleanup.sh --owner bauer-group --repo repo` |
| 🍎 macOS | `cleanup.sh` | `./cleanup.sh --owner bauer-group --repo repo` |
| 🐍 Universal | `github_cleanup.py` | `python github_cleanup.py --owner bauer-group --repo repo` |

## 🔑 GitHub Token Berechtigungen

Erforderliche Scopes für Ihr Personal Access Token:
- `repo` (Full control of private repositories)
- `actions` (Access to GitHub Actions)
- `admin:repo_hook` (Admin access to repository hooks)

Token erstellen: https://github.com/settings/tokens

## ⚡ Tipps für beste Ergebnisse

1. **Immer zuerst Dry-Run**: `--dry-run` verwenden
2. **Token sicher speichern**: Environment Variable `GITHUB_TOKEN`
3. **Bei großen Repos**: Geduld haben, kann länger dauern
4. **Backups erstellen**: Wichtige Daten vor Bereinigung sichern
5. **Berechtigungen prüfen**: Sicherstellen, dass Sie Admin-Rechte haben
