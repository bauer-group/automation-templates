# 🔐 OAuth-Authentifizierung für GitHub Cleanup Tool

## Übersicht

Das GitHub Cleanup Tool wurde mit **komfortabler OAuth-Authentifizierung** erweitert, die eine sichere Browser-basierte Anmeldung ohne manuelle Token-Erstellung ermöglicht.

## 🚀 Schnellstart

### Mit dem vereinfachten PowerShell-Skript:
```powershell
.\quick_cleanup.ps1 -Repository "bauer-group/automation-templates" -DryRun
```

### Mit dem Haupttool:
```bash
python github_cleanup.py --owner bauer-group --repo automation-templates --oauth --dry-run
```

## 🔐 Authentifizierungsmethoden

### 1. GitHub Device Flow (Empfohlen)
- ✅ **Keine OAuth-App erforderlich**
- ✅ **Browser öffnet sich automatisch**
- ✅ **Code wird in Zwischenablage kopiert**
- ✅ **Sichere, zeitlich begrenzte Tokens**
- ✅ **Automatische Berechtigung aller erforderlichen Scopes**

**Ablauf:**
1. Tool startet Device Flow
2. Browser öffnet sich zu `https://github.com/login/device`
3. Code wird automatisch in Zwischenablage kopiert
4. Nach Eingabe des Codes: sofortige Authentifizierung
5. Tool läuft mit temporärem Token

### 2. OAuth App (Optional)
- Erfordert eigene GitHub OAuth App
- Für Unternehmen mit eigenen OAuth-Konfigurationen
- Konfiguration über Umgebungsvariablen:
  - `GITHUB_CLIENT_ID`
  - `GITHUB_CLIENT_SECRET`

### 3. Personal Access Token (Fallback)
- Traditionelle Token-basierte Authentifizierung
- Für CI/CD und Automatisierung geeignet

## 📁 Neue Dateien

| Datei | Beschreibung |
|-------|--------------|
| `github_auth.py` | OAuth-Authentifizierungsmodul |
| `cleanup_oauth.ps1` | PowerShell-Wrapper mit OAuth-Support |
| `quick_cleanup.ps1` | Vereinfachtes Schnellstart-Skript |
| `test_oauth.py` | Test-Skript für OAuth-Funktionalität |

## 🧪 OAuth-Funktionalität testen

```bash
python test_oauth.py
```

**Erwartete Ausgabe:**
```
🔐 GitHub OAuth Authentication Test
==================================================
🔐 Starte GitHub Device Flow Authentifizierung...
📱 Bitte besuchen Sie: https://github.com/login/device
🔢 Und geben Sie diesen Code ein: XXXX-XXXX
⏳ Warte auf Autorisierung...
✅ Authentifizierung erfolgreich!
✅ Erfolgreich angemeldet als: [username] ([Name])
```

## 🛠️ Verwendungsbeispiele

### 1. Erste Überprüfung (Dry Run)
```powershell
.\quick_cleanup.ps1 -Repository "owner/repo" -DryRun
```

### 2. Echte Bereinigung
```powershell
.\quick_cleanup.ps1 -Repository "owner/repo"
```

### 3. Mit expliziten Parametern
```bash
python github_cleanup.py --owner owner --repo repo --oauth --dry-run
```

### 4. PowerShell mit OAuth-Support
```powershell
.\cleanup_oauth.ps1 -Owner owner -Repo repo -OAuth -DryRun
```

## 🔒 Sicherheitsfeatures

- **Zeitlich begrenzte Tokens**: OAuth-Tokens haben automatische Ablaufzeiten
- **Minimal erforderliche Scopes**: Nur notwendige Berechtigungen werden angefordert
- **Browser-basierte Authentifizierung**: Keine Speicherung von Credentials im Code
- **Secure Token Handling**: Tokens werden nur im Arbeitsspeicher gehalten

## 📋 Erforderliche Berechtigungen

Das Tool fordert automatisch folgende GitHub-Scopes an:
- `repo`: Vollzugriff auf Repository-Inhalte
- `workflow`: Zugriff auf GitHub Actions
- `delete_repo`: Berechtigung zum Löschen von Repository-Elementen

## 🔧 Installation der Abhängigkeiten

```bash
pip install -r requirements.txt
```

**Neue Dependencies:**
- `PyGithub>=1.59.0`: GitHub API Python-Bibliothek
- `flask>=2.3.0`: Web-Framework für OAuth-Callback
- `pyperclip>=1.8.0`: Zwischenablage-Funktionalität
- `urllib3>=1.26.0`: HTTP-Bibliothek
- `requests>=2.28.0`: HTTP-Requests (bereits vorhanden)

## 🎯 Vorteile der OAuth-Implementierung

1. **Benutzerfreundlichkeit**: Keine manuelle Token-Erstellung erforderlich
2. **Sicherheit**: Automatischer Token-Ablauf und sichere Übertragung
3. **Kompatibilität**: Funktioniert mit allen GitHub-Konten ohne Setup
4. **Automatisierung**: Einmaliger Login für mehrere Operationen
5. **Plattformunabhängigkeit**: Funktioniert auf Windows, macOS und Linux

## 🚨 Troubleshooting

### Browser öffnet sich nicht
- Kopieren Sie die angezeigte URL manuell in den Browser
- Überprüfen Sie Firewall-Einstellungen

### OAuth-Fehler
- Stellen Sie sicher, dass alle Dependencies installiert sind
- Überprüfen Sie Ihre Internetverbindung
- Bei wiederholten Fehlern: verwenden Sie Personal Access Token

### Rate Limits
- Das Tool hat eingebaute Rate-Limit-Behandlung
- Bei Überschreitung: automatische Wartezeiten

## 🎉 Fazit

Die OAuth-Integration macht das GitHub Cleanup Tool erheblich benutzerfreundlicher und sicherer. Anstatt manuell GitHub-Tokens zu erstellen und zu verwalten, ermöglicht die Browser-basierte Authentifizierung eine nahtlose und sichere Nutzung.
