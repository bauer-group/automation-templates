# Auto Maintenance - Benutzeranleitung

Vollautomatische Repository-Wartung: Base Image Monitoring, Dependency Updates, Validierung mit Rollback und automatisches Release-Triggering - gesteuert durch eine einzige JSON-Konfigurationsdatei.

## Inhaltsverzeichnis

- [Problemstellung](#problemstellung)
- [Funktionsweise](#funktionsweise)
- [Schnellstart](#schnellstart)
- [Vollstaendige Einrichtung](#vollstaendige-einrichtung)
- [JSON-Konfigurationsreferenz](#json-konfigurationsreferenz)
- [Beispiele](#beispiele)
- [Migration](#migration)
- [Troubleshooting](#troubleshooting)

---

## Problemstellung

**Bisher:** Bis zu 3 separate Workflows pro Repository fuer Wartungsaufgaben:

| Workflow | Aufgabe |
|----------|---------|
| `check-base-images.yml` | Docker Base Image Digest-Monitoring |
| `scheduled-dependency-update.yml` | npm/Python Dependency Updates |
| `docker-maintenance.yml` | Dependabot PR Auto-Merge |

**Probleme:**
- Inkonsistenz: Jedes Repo hat eigenen Ansatz
- Dependency-Updates manuell: PRs muessen von Hand gemergt werden
- Keine Python/Go/.NET-Automatisierung
- Floating Docker Tags nur in wenigen Repos ueberwacht

**Neu:** Ein Shared Workflow + Eine JSON-Config = Vollautomatische Wartung.

```
VORHER (pro Repo, bis zu 3 Workflows):        NACHHER (pro Repo):
  check-base-images.yml         ──┐             maintenance.yml (15 Zeilen)
  scheduled-dependency-update.yml ├──>          config.json (Gesamte Konfiguration)
  + base-images.json            ──┘
```

---

## Funktionsweise

```
                   Schedule / workflow_dispatch
                            |
                            v
                   maintenance.yml (Caller)
                            |
                            v
               modules-auto-maintenance.yml (Shared)
                            |
                            v
                  config.json einlesen
                            |
              +-------------+-------------+
              |                           |
              v                           v
     [base-images Block]         [ecosystems Block]
              |                           |
              v                           v
   Fuer jedes Image:              Fuer jedes Ecosystem:
   Registry-Digest pruefen       Updates pruefen + anwenden
   Mit Variable vergleichen       (npm/pip/dotnet/go)
              |                           |
              +-------------+-------------+
                            |
                            v
                   Aenderungen?
                    /        \
                  Nein       Ja
                  |           |
                  v           v
              Exit(0)    Validierung
              Kein        (build/test/typecheck)
              Release       |
                         Bestanden?
                          /      \
                        Nein     Ja
                        |         |
                        v         v
                  Verwerfen    Commit & Push
                  (Rollback)   + Release-Trigger
```

**Wenn nichts zu tun ist:** Workflow endet in ~30 Sekunden. Kein Commit, kein Release.

---

## Schnellstart

### Minimale Einrichtung (5 Minuten)

**1. Token als Secret hinterlegen**

Repository > Settings > Secrets and variables > Actions > New repository secret

- Name: `MAINTENANCE_TOKEN` (oder vorhandenes `PAT_READWRITE_ORGANISATION`)
- Value: Personal Access Token mit `repo` Scope

**2. Konfigurationsdatei erstellen**

Erstelle `.github/config/maintenance/config.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/maintenance/auto-maintenance.schema.json",

  "ecosystems": {
    "node": {
      "version": "22",
      "package-manager": "npm"
    }
  },

  "validation": {
    "build-command": "npm run build",
    "test-command": "npm test"
  },

  "release": {
    "commit-prefix": "fix(deps)",
    "trigger-workflow": "release.yml",
    "trigger-inputs": { "force-release": "true" }
  }
}
```

**3. Caller-Workflow erstellen**

Erstelle `.github/workflows/maintenance.yml`:

```yaml
name: "Auto-Maintenance"

on:
  schedule:
    - cron: "0 6 * * 1"  # Woechentlich Montag 06:00 UTC
  workflow_dispatch:
    inputs:
      dry-run:
        description: "Nur pruefen, keine Commits"
        type: boolean
        default: false

concurrency:
  group: maintenance-${{ github.repository }}
  cancel-in-progress: false

permissions:
  contents: write

jobs:
  maintenance:
    uses: bauer-group/automation-templates/.github/workflows/modules-auto-maintenance.yml@main
    with:
      config-file: ".github/config/maintenance/config.json"
      dry-run: ${{ inputs.dry-run || false }}
    secrets: inherit
```

**Fertig!** Der Workflow laeuft woechentlich und aktualisiert automatisch Abhingigkeiten.

---

## Vollstaendige Einrichtung

### Schritt 1: Personal Access Token (PAT)

#### Option A: Fine-grained Token (empfohlen)

1. [GitHub Settings > Developer settings > Fine-grained tokens](https://github.com/settings/tokens?type=beta)
2. "Generate new token"
3. Konfiguriere:
   - **Token name:** `maintenance-bot`
   - **Repository access:** Only select repositories
   - **Permissions:**
     - `Contents`: Read and Write (Checkout, Commit, Push)
     - `Variables`: Read and Write (Digest-Speicherung)
     - `Actions`: Read and Write (workflow_dispatch, nur wenn `trigger-workflow` genutzt)

#### Option B: Classic Token

1. [GitHub Settings > Developer settings > Personal access tokens (classic)](https://github.com/settings/tokens)
2. Scope: `repo` (Full control)

### Schritt 2: Token als Secret speichern

Repository > Settings > Secrets and variables > Actions > New repository secret

| Name | Wann verwenden |
|------|---------------|
| `MAINTENANCE_TOKEN` | Neuer empfohlener Name |
| `PAT_READWRITE_ORGANISATION` | Wenn bereits in anderen Workflows verwendet |

Der Workflow unterstuetzt beide Namen mit automatischem Fallback:
`MAINTENANCE_TOKEN` > `PAT_READWRITE_ORGANISATION` > `GITHUB_TOKEN`

> **Hinweis:** `GITHUB_TOKEN` reicht fuer reine Dependency-Updates ohne Base-Image-Monitoring und ohne Workflow-Dispatch.

### Schritt 3: Konfigurationsdatei

Erstelle `.github/config/maintenance/config.json` mit den gewuenschten Bloecken.
Durch die `$schema`-Referenz erhaelt die IDE Autocomplete und Validierung.

### Schritt 4: Caller-Workflow

Erstelle `.github/workflows/maintenance.yml` (siehe Schnellstart).

Optionale Anpassungen:

| Parameter | Default | Wann aendern |
|-----------|---------|--------------|
| `cron` | `0 6 * * 1` (Mo 06:00 UTC) | Anderer Schedule |
| `config-file` | `.github/config/maintenance/config.json` | Abweichender Pfad |
| `runs-on` | `ubuntu-latest` | Self-hosted Runner |
| `dry-run` | `false` | Zum Testen |

---

## JSON-Konfigurationsreferenz

Jeder Block ist **optional**. Man konfiguriert nur was man braucht.

### `base-images` - Docker Base Image Monitoring

| Feld | Typ | Pflicht | Beschreibung |
|------|-----|---------|--------------|
| `name` | string | Ja | Anzeigename (Logs, Commits) |
| `image` | string | Ja | Docker Image ohne Tag (z.B. `n8nio/n8n`) |
| `tag` | string | Ja | Docker Tag zum Ueberwachen (z.B. `stable`) |
| `variable` | string | Ja | GitHub Variable Name (z.B. `N8N_STABLE_DIGEST`) |
| `description` | string | Nein | Beschreibung fuer Dokumentation |

### `ecosystems` - Dependency Updates

#### `ecosystems.node`

| Feld | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `version` | string | `"22"` | Node.js Version |
| `package-manager` | string | `"npm"` | `npm`, `yarn` oder `pnpm` |
| `working-directory` | string | `"."` | Arbeitsverzeichnis |
| `update-strategy` | string | `"safe"` | `safe`: npm update + audit fix |

**Ablauf:** `npm ci --ignore-scripts` > `npm update` > `npm audit fix`

#### `ecosystems.python`

| Feld | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `version` | string | `"3.13"` | Python Version |
| `requirements-file` | string | `"requirements.txt"` | Pfad zur Requirements-Datei |
| `working-directory` | string | `"."` | Arbeitsverzeichnis |
| `update-strategy` | string | `"compatible"` | `compatible`: Upgrade innerhalb Constraints |

**Ablauf:** `pip install -r requirements.txt` > `pip install --upgrade --upgrade-strategy only-if-needed`

#### `ecosystems.dotnet`

| Feld | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `version` | string | `"8.0.x"` | .NET SDK Version |
| `project-path` | string | `"."` | Pfad zu .sln oder .csproj |
| `working-directory` | string | `"."` | Arbeitsverzeichnis |
| `update-strategy` | string | `"minor"` | `minor` oder `patch` |

**Ablauf:** `dotnet-outdated --upgrade --version-lock Minor` > `dotnet restore`

#### `ecosystems.go`

| Feld | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `version` | string | `"stable"` | Go Version |
| `working-directory` | string | `"."` | Arbeitsverzeichnis |
| `update-strategy` | string | `"compatible"` | `compatible`: SemVer Minor/Patch |

**Ablauf:** `go get -u ./...` > `go mod tidy`

### `validation` - Validierung nach Updates

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `build-command` | string | Build-Befehl (z.B. `npm run build`) |
| `test-command` | string | Test-Befehl (z.B. `npm test`) |
| `typecheck-command` | string | Typecheck (z.B. `npm run typecheck`) |

**Bei Fehler:** Alle Aenderungen werden mit `git checkout -- . && git clean -fd` revertiert. Der Workflow schlaegt NICHT fehl, sondern reportet den Fehler in der Job Summary.

### `release` - Release-Konfiguration

| Feld | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `commit-prefix` | string | `"fix(deps)"` | Conventional Commit Prefix |
| `target-branch` | string | `"main"` | Ziel-Branch fuer Push |
| `trigger-workflow` | string | - | Workflow-Datei fuer Dispatch |
| `trigger-inputs` | object | `{}` | Inputs fuer den Dispatch |

---

## Beispiele

### Node.js Projekt (z.B. Ghost BunnyCDN Connector)

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/maintenance/auto-maintenance.schema.json",

  "ecosystems": {
    "node": {
      "version": "22",
      "package-manager": "npm",
      "update-strategy": "safe"
    }
  },

  "validation": {
    "build-command": "npm run build",
    "test-command": "npm test",
    "typecheck-command": "npm run typecheck"
  },

  "release": {
    "commit-prefix": "fix(deps)",
    "trigger-workflow": "docker-release-build.yml",
    "trigger-inputs": { "force-release": "true" }
  }
}
```

### Multi-Ecosystem mit Base Images (z.B. n8n)

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/maintenance/auto-maintenance.schema.json",

  "base-images": [
    {
      "name": "n8n",
      "image": "n8nio/n8n",
      "tag": "stable",
      "variable": "N8N_STABLE_DIGEST",
      "description": "n8n workflow automation platform"
    },
    {
      "name": "n8n-runner",
      "image": "n8nio/runners",
      "tag": "stable",
      "variable": "N8N_RUNNER_STABLE_DIGEST"
    },
    {
      "name": "python-alpine",
      "image": "python",
      "tag": "3.13-alpine",
      "variable": "PYTHON_ALPINE_DIGEST"
    }
  ],

  "ecosystems": {
    "node": {
      "version": "22",
      "package-manager": "npm"
    },
    "python": {
      "version": "3.13",
      "requirements-file": "src/n8n-backup/requirements.txt",
      "working-directory": "src/n8n-backup"
    }
  },

  "validation": {
    "build-command": "npm run build",
    "test-command": "npm test -- --passWithNoTests",
    "typecheck-command": "npm run typecheck"
  },

  "release": {
    "commit-prefix": "fix(deps)",
    "trigger-workflow": "docker-release.yml",
    "trigger-inputs": { "force-release": "true" }
  }
}
```

### Python + Base Image (z.B. MTA-STS)

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/maintenance/auto-maintenance.schema.json",

  "base-images": [
    {
      "name": "python3-light",
      "image": "bauergroup/python3-light",
      "tag": "latest",
      "variable": "PYTHON3_LIGHT_DIGEST"
    }
  ],

  "ecosystems": {
    "python": {
      "version": "3.13",
      "requirements-file": "src/requirements.txt",
      "working-directory": "src"
    }
  },

  "release": {
    "commit-prefix": "fix(deps)",
    "trigger-workflow": "docker-release.yml",
    "trigger-inputs": { "force-release": "true" }
  }
}
```

### Nur Base Images (z.B. NocoDB, ApplicationErrorObservability)

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/maintenance/auto-maintenance.schema.json",

  "base-images": [
    {
      "name": "nocodb",
      "image": "nocodb/nocodb",
      "tag": "latest",
      "variable": "NOCODB_LATEST_DIGEST"
    }
  ],

  "release": {
    "commit-prefix": "fix(deps)",
    "trigger-workflow": "docker-release.yml",
    "trigger-inputs": { "force-release": "true" }
  }
}
```

### Go-Projekt (z.B. SimpleHTTPRedirector)

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/maintenance/auto-maintenance.schema.json",

  "ecosystems": {
    "go": {
      "version": "1.25",
      "working-directory": "src"
    }
  },

  "validation": {
    "build-command": "go build -o /dev/null ./...",
    "test-command": "go test ./..."
  },

  "release": {
    "commit-prefix": "fix(deps)",
    "trigger-workflow": "docker-release.yml",
    "trigger-inputs": { "force-release": "true" }
  }
}
```

### Self-hosted Runner

```yaml
jobs:
  maintenance:
    uses: bauer-group/automation-templates/.github/workflows/modules-auto-maintenance.yml@main
    with:
      runs-on: '["self-hosted", "linux"]'
      config-file: ".github/config/maintenance/config.json"
      dry-run: ${{ inputs.dry-run || false }}
    secrets: inherit
```

---

## Migration

### Von separaten Workflows zum Unified Workflow

**Schritt 1:** `config.json` erstellen mit den bestehenden Konfigurationen

Wenn `base-images.json` existiert, die Eintraege in den `base-images` Block uebernehmen:

```
base-images.json → config.json "base-images" Block
```

**Schritt 2:** `maintenance.yml` Caller erstellen (siehe Schnellstart)

**Schritt 3:** Testen mit Dry-Run

```yaml
# Manuell triggern mit dry-run: true
gh workflow run maintenance.yml -f dry-run=true
```

**Schritt 4:** Alte Workflows deaktivieren

Wenn der neue Workflow korrekt laeuft:
- `check-base-images.yml` entfernen oder deaktivieren
- `scheduled-dependency-update.yml` entfernen
- `base-images.json` kann bleiben (wird nicht mehr genutzt)

### Kompatibilitaet mit Dependabot

Der Workflow ergaenzt Dependabot - er ersetzt es nicht:

| Was | Werkzeug | Warum |
|-----|----------|-------|
| Pinned Docker Tags (`node:22-alpine`) | Dependabot + Auto-Merge | Nativ unterstuetzt |
| Floating Docker Tags (`nocodb:latest`) | auto-maintenance (base-images) | Dependabot kann keine Digests |
| GitHub Actions Versionen | Dependabot | Nativ unterstuetzt |
| npm/Python/Go/.NET Packages | auto-maintenance (ecosystems) | Vollautomatisch, kein PR |

---

## Troubleshooting

### "Config file not found"

Die Konfigurationsdatei existiert nicht am angegebenen Pfad. Default: `.github/config/maintenance/config.json`

### "Invalid JSON in config file"

Die JSON-Datei hat Syntaxfehler. Tipp: `$schema`-Referenz in der Datei nutzen fuer IDE-Validierung.

### "Could not fetch manifest"

Docker Hub Rate Limits oder das Image existiert nicht. Pruefen:
```bash
docker manifest inspect IMAGE:TAG
```

### Validation fehlgeschlagen

Der Workflow revertiert automatisch alle Aenderungen bei fehlgeschlagener Validierung. Pruefen:
- Build-Command korrekt?
- Test-Command laeuft ohne aktive Aenderungen?
- Working-Directory stimmt?

### Token-Berechtigungen

| Fehler | Loesung |
|--------|---------|
| `gh variable set` schlaegt fehl | PAT braucht `Variables: Write` |
| `git push` schlaegt fehl | PAT braucht `Contents: Write` |
| `gh workflow run` schlaegt fehl | PAT braucht `Actions: Write` |
| Workflow wird nicht getriggert | Push mit `GITHUB_TOKEN` triggert keine Workflows |

### Endlosschleifen vermeiden

Der Workflow laeuft nur auf `schedule` und `workflow_dispatch`, nicht auf `push`. Dadurch kann ein Commit des Workflows keinen erneuten Run ausloesen.

Zusaetzlich: `concurrency` Group im Caller verhindert parallele Ausfuehrung:
```yaml
concurrency:
  group: maintenance-${{ github.repository }}
  cancel-in-progress: false
```
