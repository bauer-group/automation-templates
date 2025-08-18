# Beispiele für die Verwendung des GitHub Cleanup Tools

## 1. Einfacher Dry-Run

```bash
# Mit Python direkt
python github_cleanup.py --owner bauer-group --repo automation-templates --dry-run

# Mit PowerShell Wrapper (Windows)
.\cleanup.ps1 -Owner "bauer-group" -Repo "automation-templates" -DryRun

# Mit Bash Wrapper (Linux/macOS)
./cleanup.sh --owner bauer-group --repo automation-templates --dry-run
```

## 2. Vollständige Bereinigung

```bash
# Mit Token als Parameter
python github_cleanup.py --owner bauer-group --repo automation-templates --token ghp_xxxxxxxxxxxx

# Mit Environment Variable
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
python github_cleanup.py --owner bauer-group --repo automation-templates

# PowerShell mit Token
.\cleanup.ps1 -Owner "bauer-group" -Repo "automation-templates" -Token "ghp_xxxxxxxxxxxx"
```

## 3. Verschiedene Repositories

```bash
# Anderes Repository bereinigen
python github_cleanup.py --owner myorg --repo myproject --dry-run

# Privates Repository
python github_cleanup.py --owner myusername --repo private-repo --token ghp_xxxxxxxxxxxx
```

## 4. Erweiterte Verwendung

```bash
# Mit detaillierter Ausgabe
python github_cleanup.py --owner bauer-group --repo automation-templates --verbose --dry-run

# Nur Workflow-Runs bereinigen (Code-Modifikation erforderlich)
# Kommentieren Sie andere Cleanup-Methoden im Python-Code aus
```

## 5. Batch-Bereinigung mehrerer Repositories

Erstellen Sie ein Skript für mehrere Repositories:

### PowerShell Beispiel:
```powershell
$repositories = @(
    @{Owner="bauer-group"; Repo="automation-templates"},
    @{Owner="bauer-group"; Repo="another-repo"},
    @{Owner="myorg"; Repo="project1"}
)

foreach ($repo in $repositories) {
    Write-Host "Bereinige $($repo.Owner)/$($repo.Repo)..." -ForegroundColor Yellow
    .\cleanup.ps1 -Owner $repo.Owner -Repo $repo.Repo -DryRun
}
```

### Bash Beispiel:
```bash
#!/bin/bash
repositories=(
    "bauer-group/automation-templates"
    "bauer-group/another-repo"
    "myorg/project1"
)

for repo in "${repositories[@]}"; do
    IFS='/' read -r owner name <<< "$repo"
    echo "Bereinige $owner/$name..."
    ./cleanup.sh --owner "$owner" --repo "$name" --dry-run
done
```

## 6. Fehlerbehandlung und Logging

```bash
# Ausgabe in Datei umleiten
python github_cleanup.py --owner bauer-group --repo automation-templates --verbose 2>&1 | tee cleanup.log

# Nur Fehler anzeigen
python github_cleanup.py --owner bauer-group --repo automation-templates 2> errors.log
```

## 7. Token-Verwaltung

### Umgebungsvariablen setzen:

**Windows (PowerShell):**
```powershell
$env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxx"
```

**Windows (CMD):**
```cmd
set GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

**Linux/macOS:**
```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

### Token in .env Datei (für Entwicklung):
```bash
# .env Datei erstellen
echo "GITHUB_TOKEN=ghp_xxxxxxxxxxxx" > .env

# In PowerShell laden
Get-Content .env | ForEach-Object {
    $name, $value = $_.split('=', 2)
    Set-Item -Path "env:$name" -Value $value
}
```

## 8. Sicherheitstipps

```bash
# Immer erst Dry-Run ausführen
python github_cleanup.py --owner bauer-group --repo automation-templates --dry-run

# Repository-Info überprüfen
gh repo view bauer-group/automation-templates

# Backup wichtiger Branches erstellen
git clone --mirror https://github.com/bauer-group/automation-templates.git backup/

# Mit minimalen Berechtigungen arbeiten
# Erstellen Sie einen Token nur mit den erforderlichen Permissions
```
