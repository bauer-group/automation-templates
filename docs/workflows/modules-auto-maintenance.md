# Auto Maintenance - Benutzeranleitung

Vollautomatische Repository-Wartung: Base Image Monitoring, Dependency Updates, Validierung mit Rollback und automatisches Release-Triggering - gesteuert durch eine einzige JSON-Konfigurationsdatei.

## Inhaltsverzeichnis

- [Problemstellung](#problemstellung)
- [Funktionsweise](#funktionsweise)
  - [Was committet wird](#was-committet-wird)
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
                               + Digests speichern
```

**Wenn nichts zu tun ist:** Workflow endet in ~30 Sekunden. Kein Commit, kein Release.

**Unterschied zum Base Image Monitor:** Hier zählt ein Digest als erledigt, sobald der Release-Workflow gestartet wurde. Muss ein Release-Gate (z. B. der Backup-Round-Trip) erst bestehen und soll ein fehlgeschlagener Release automatisch wiederholt werden, ist [`modules-docker-base-image-monitor.yml`](./modules-docker-base-image-monitor.md#release-confirmation) das passende Modul.

**Digest-Variablen werden zuletzt gespeichert:** erst nachdem der Commit gepusht und der Release-Workflow gestartet wurde. Schlägt einer dieser Schritte fehl oder wird der Commit übersprungen (z. B. fehlgeschlagene Validierung), bleibt der alte Digest stehen und der nächste Lauf erkennt das Update erneut. Der leere Commit für reine Base-Image-Updates endet auf `[skip ci]`, wenn `release.trigger-workflow` gesetzt ist; der per `workflow_dispatch` gestartete Release läuft trotzdem. `docker manifest inspect` wird bei vorübergehenden Registry-Fehlern (z. B. `429`) bis zu 3-mal versucht.

### Was committet wird

Der Schritt „Commit and push“ committet nur Dependency-Manifeste und Lock-Dateien. Ausgangspunkt sind die Dateien, die der Lauf geändert oder neu angelegt hat; jede wird einzeln geprüft und mit einem eigenen `git add` aufgenommen. Für versionierte und neue Dateien gelten unterschiedliche Regeln:

| Datei | Wird committet, wenn … |
|-------|------------------------|
| **Versioniert und geändert** (laut `git diff`, auch gelöscht) | ihr Dateiname in der Tabelle unten steht — an jeder Stelle im Repository, also auch unterhalb eines `working-directory` |
| **Neu** (nicht versioniert, nicht ignoriert) | sie eine Lock-Datei ist **und** ihr Manifest im selben Verzeichnis versioniert ist: `go.sum` neben `go.mod`, `package-lock.json`/`npm-shrinkwrap.json`/`yarn.lock`/`pnpm-lock.yaml` neben `package.json`, `packages.lock.json` neben einem `*.csproj`/`*.fsproj`/`*.vbproj`, `poetry.lock` neben `pyproject.toml`, `Pipfile.lock` neben `Pipfile`. Ein **neues Manifest** wird nie committet — die Update-Schritte ändern nur vorhandene. |

| Ecosystem | Manifeste und Lock-Dateien |
|-----------|----------------------------|
| Node.js (npm, yarn, pnpm) | `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `pnpm-lock.yaml` |
| Python | `requirements*.txt`, die konfigurierte `requirements-file` unter jedem Namen (z. B. `requirements/prod.txt`), `Pipfile.lock`, `poetry.lock` |
| .NET | `*.csproj`, `*.fsproj`, `*.vbproj`, `Directory.Build.props`, `Directory.Packages.props`, `packages.lock.json` (entsteht nur mit `RestorePackagesWithLockFile`) |
| Go | `go.mod`, `go.sum` |
| Base Images | Keine Datei: Der Digest liegt in einer Repository-Variable. Ändert sich sonst nichts, entsteht ein leerer Commit `<commit-prefix>: update base image <namen>` (mit `[skip ci]`, wenn `release.trigger-workflow` gesetzt ist). |

Dabei gilt:

- **Nicht versionierte Build- und Tool-Verzeichnisse bleiben draußen**, auch ohne `.gitignore` und auch dann, wenn darin Dateien wie `package.json`, `yarn.lock` oder `requirements.txt` liegen — z. B. `dist/`, `build/`, `.venv/`, `.tox/`, `.next/`, `.output/`, `obj/`. Ihre Dateien sind neu, und neben ihnen ist kein Manifest versioniert.
- **Versionierte Build-Ausgabe wird committet, wenn sie wie ein Manifest heißt** und der Lauf sie ändert — z. B. das eingecheckte `dist/package.json` einer JavaScript Action nach `npm run build`. Die übrigen Dateien daneben (`dist/index.js`) bleiben draußen, siehe [Build-Ausgabe im Commit](#build-ausgabe-im-commit).
- **`.gitignore` wirkt nur auf neue Dateien.** Eine neue, ignorierte Lock-Datei bleibt draußen; eine bereits versionierte wird auch dann committet, wenn sie zusätzlich in `.gitignore` steht.
- **`node_modules/` wird nie committet**, auch wenn das Verzeichnis nicht ignoriert ist.
- **Alles andere bleibt im Checkout des Runners** und verfällt mit ihm: Quellcode, den ein Validierungsbefehl geändert hat, und neue Dateien, die keine der Regeln oben erfüllen. Das Log von „Commit and push“ listet sie unter `Not committed` (die ersten 20).
- **Keine committbare Datei geändert:** kein Dependency-Commit, Log `No dependency files to commit`, die Job Summary meldet „Files changed, but none of them is a dependency file to commit“. Base-Image-Updates desselben Laufs bekommen trotzdem ihren leeren Commit.
- **Base Images und Dependencies im selben Lauf:** ein gemeinsamer Commit `<commit-prefix>: automated maintenance update`, dessen Body die Images nennt. Er läuft ohne `[skip ci]`, die Push-CI prüft die neuen Versionen also mit.

> **Bis zu dieser Korrektur** nahm der Schritt jedes Ecosystem mit **einem** `git add` fester Pfade im Repository-Root auf, z. B. `git add package.json package-lock.json yarn.lock pnpm-lock.yaml`. Fehlte einer davon, nahm Git keinen auf (`fatal: pathspec ... did not match any files`, im Workflow unterdrückt). npm-, pip- und .NET-Updates wurden deshalb aktualisiert, validiert und dann verworfen, während der Lauf grün blieb. Wer `ecosystems` deshalb nicht eingesetzt hat, kann es jetzt aktivieren — zusammen mit [`validation`](#validation---validierung-nach-updates). **Ein Caller, der `ecosystems` bereits ohne `validation` konfiguriert hat, pusht ab jetzt ungebaute und ungetestete Updates direkt auf den Ziel-Branch** — dort `validation` ergänzen. Getestet wird das Verhalten von [`auto-maintenance-commit.test.sh`](../../.github/workflows/tests/auto-maintenance-commit.test.sh) in der Workflow-Validierung.

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
| `requirements-file` | string | `"requirements.txt"` | Pfad zur Requirements-Datei, relativ zu `working-directory` |
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

**Ohne `validation`** werden die Updates aus `ecosystems` ungebaut und ungetestet committet und direkt auf `release.target-branch` gepusht. Wer `ecosystems` nutzt, sollte `validation` deshalb immer setzen.

### `release` - Release-Konfiguration

| Feld | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `commit-prefix` | string | `"fix(deps)"` | Conventional Commit Prefix |
| `target-branch` | string | `"main"` | Ziel-Branch fuer Push |
| `trigger-workflow` | string | - | Workflow-Datei fuer Dispatch |
| `trigger-inputs` | object | `{}` | Inputs fuer den Dispatch |

---

## Beispiele

> Kopierfertiger Caller und Konfigurationen: [`github/workflows/examples/auto-maintenance/`](../../github/workflows/examples/auto-maintenance/README.md) — Base Images (`maintenance-config.json`) und ein npm-Projekt mit Validierung (`maintenance-config-npm.json`). Welche Dateien je Ecosystem committet werden, steht unter [Was committet wird](#was-committet-wird).

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
      "requirements-file": "requirements.txt",
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
      "requirements-file": "requirements.txt",
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

### "No dependency files to commit"

Der Lauf hat Dateien geändert oder angelegt, aber keine davon wird nach [Was committet wird](#was-committet-wird) committet. Die Zeilen unter `Not committed` direkt davor im Log nennen die Dateien; die Job Summary meldet „Files changed, but none of them is a dependency file to commit“. Base-Image-Updates desselben Laufs werden trotzdem committet und released.

| Ursache | Lösung |
|---------|--------|
| Nur ein Validierungsbefehl hat Dateien geändert oder angelegt (Quellcode, Build-Ausgabe, `.venv/`) | Erwartet, nichts zu tun. Build- und Tool-Verzeichnisse in `.gitignore` aufnehmen, dann bleibt das Log ruhig. |
| Die Requirements-Datei heißt nicht `requirements*.txt` und `requirements-file` zeigt nicht auf sie | `requirements-file` relativ zu `working-directory` angeben, z. B. `"working-directory": "backend", "requirements-file": "requirements/prod.txt"` |
| Die Datei ist neu: ein Manifest oder eine Lock-Datei ohne versioniertes Manifest im selben Verzeichnis | Die Datei einmal selbst committen. Ab dann ist sie versioniert, und der Lauf committet ihre Änderungen. |

### Ein Update fehlt im Commit

Der Commit enthält nur einen Teil der erwarteten Dateien, oder eine Lock-Datei fehlt:

- **Lock-Datei ignoriert?** `git check-ignore -v package-lock.json` zeigt die Regel. Eine neue, ignorierte Datei wird nie committet — Regel entfernen und die Datei einchecken.
- **Neue Lock-Datei ohne Manifest daneben?** Eine neue Lock-Datei wird nur committet, wenn ihr Manifest im **selben** Verzeichnis versioniert ist (`go.sum` neben `go.mod`). Liegt das Manifest woanders oder ist es nicht eingecheckt, die Lock-Datei einmal selbst committen.
- **Datei unter `node_modules/`?** Wird nie committet, auch ohne `.gitignore`.
- **Validierung fehlgeschlagen?** Dann wurde alles zurückgerollt und nichts committet, siehe [Validation fehlgeschlagen](#validation-fehlgeschlagen).
- **Welche Dateien hat der Lauf geändert?** Der Schritt „Detect changes“ listet geänderte und neue Dateien, „Commit and push“ unter `Staged files` die committeten und unter `Not committed` die übrigen.

### Build-Ausgabe im Commit

Eine versionierte Datei, die wie ein Manifest heißt, wird committet, sobald der Lauf sie ändert — auch wenn sie Build-Ausgabe ist, z. B. ein eingechecktes `dist/package.json`, das `npm run build` neu schreibt. Soll sie nicht mehr mitlaufen: `git rm --cached dist/package.json` und `dist/` in `.gitignore` aufnehmen. Nicht versionierte Build-Ausgabe wird nie committet.

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
