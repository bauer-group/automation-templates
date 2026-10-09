# 🐳 Docker Base Image Monitor - Benutzeranleitung

Überwacht Docker Base Images auf Digest-Änderungen und triggert automatische Rebuilds mit Semantic Release. Löst das Problem, dass Dependabot keine "floating tags" wie `stable` oder `latest` tracken kann.

## 📋 Inhaltsverzeichnis

- [Problemstellung](#-problemstellung)
- [Funktionsweise](#-funktionsweise)
- [Schnellstart](#-schnellstart)
- [Vollständige Einrichtung](#-vollständige-einrichtung)
- [Konfigurationsoptionen](#-konfigurationsoptionen)
- [Beispiele](#-beispiele)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Problemstellung

**Das Problem:** Dependabot und Renovate können nur **fixierte Tags** wie `1.2.3` überwachen, aber keine **floating Tags** wie:

- `stable` - Wechselt bei jedem stabilen Release
- `latest` - Immer die neueste Version
- `lts` - Long Term Support Version
- `alpine` - Leichtgewichtige Variante

**Die Lösung:** Dieser Workflow überwacht die **Digests** (SHA256-Hashes) der Images und erkennt Änderungen, auch wenn der Tag gleich bleibt.

```
n8nio/n8n:stable
├── Gestern: sha256:abc123...
└── Heute:   sha256:def456... ← Update erkannt!
```

---

## ⚙️ Funktionsweise

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  1. Scheduled Trigger (z.B. täglich 07:00 UTC)                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  2. Für jedes konfigurierte Image:                                           │
│     docker manifest inspect n8nio/n8n:stable → sha256:neu123...              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  3. Vergleich mit gespeichertem Digest (GitHub Variable)                     │
│     ${{ vars.N8N_STABLE_DIGEST }} → sha256:alt456...                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
          ┌─────────────────┐                 ┌─────────────────────────┐
          │  Gleich:        │                 │  Unterschiedlich:       │
          │  ✅ Nichts tun  │                 │  1. Commit erstellen    │
          └─────────────────┘                 │  2. Semantic Release    │
                                              │     triggern            │
                                              │  3. Variable updaten    │
                                              │     (nur wenn 1+2 ok;   │
                                              │     mit target-workflow │
                                              │     erst nach Erfolg    │
                                              │     des Release-Runs)   │
                                              └─────────────────────────┘
```

Mit `target-workflow` zählt ein neuer Digest erst als erledigt, wenn der dispatchte
Release-Run **erfolgreich** war. Bis dahin steht der Run in einer zweiten Variable
`<variable>_PENDING`. Jeder folgende Check liest dessen Ergebnis: erfolgreich → Digest
speichern; fehlgeschlagen (z.B. rotes Backup-Round-Trip-Gate) → Release erneut
dispatchen; läuft noch → abwarten. Details: [Release confirmation](../../../docs/workflows/modules-docker-base-image-monitor.md#release-confirmation).

---

## 🚀 Schnellstart

### Minimale Einrichtung (5 Minuten)

**1. PAT Secret erstellen**

Repository → Settings → Secrets and variables → Actions → New repository secret

- Name: `PAT_READWRITE_ORGANISATION`
- Value: [Personal Access Token erstellen](https://github.com/settings/tokens/new) mit `repo` Scope

**2. Workflow-Datei erstellen**

Erstelle `.github/workflows/check-base-images.yml`:

```yaml
name: 🔄 Check Base Image Updates

on:
  schedule:
    - cron: '0 7 * * *'  # Täglich 07:00 UTC
  workflow_dispatch:     # Manueller Trigger

jobs:
  check:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      images: |
        [
          {
            "name": "n8n",
            "image": "n8nio/n8n",
            "tag": "stable",
            "variable": "N8N_STABLE_DIGEST"
          }
        ]
    secrets: inherit
```

**Fertig!** Der Workflow prüft jetzt täglich, ob ein neues n8n Base Image verfügbar ist.

### Interne oder private GHCR-Images überwachen

Das Beispiel oben nutzt ein öffentliches Image. Für **interne oder private** GHCR-Packages
muss der **aufrufende** Workflow zusätzlich `packages: read` gewähren — ein Reusable
Workflow kann Caller-Permissions nur einschränken, niemals erweitern:

```yaml
jobs:
  check:
    permissions:
      packages: read          # <-- ohne dies: "denied" beim Lesen der Manifeste
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    secrets: inherit
```

Der Registry-Login nutzt dafür `github.token`. Dieser greift auch **org-übergreifend**
auf intern sichtbare Packages innerhalb derselben Enterprise zu — ein PAT ist dafür
nicht nötig. `PAT_READWRITE_ORGANISATION` braucht daher **keinen** Packages-Scope.

Nur für Registries **außerhalb** der Enterprise wird ein optionales Secret
`REGISTRY_READ_TOKEN` benötigt.

> Fehlt `packages: read`, meldet der Login trotzdem `Login Succeeded!` — die Manifeste
> schlagen erst danach mit `denied` fehl. Siehe [docs/ghcr-internal-visibility.md](../../../docs/ghcr-internal-visibility.md).

---

## 📚 Vollständige Einrichtung

### Schritt 1: Personal Access Token (PAT) erstellen

#### Option A: Fine-grained Token (empfohlen)

1. Gehe zu [GitHub Settings → Developer settings → Fine-grained tokens](https://github.com/settings/tokens?type=beta)
2. Klicke "Generate new token"
3. Konfiguriere:
   - **Token name:** `docker-base-image-monitor`
   - **Expiration:** 90 days (oder länger)
   - **Repository access:** Only select repositories → Dein Repository wählen
   - **Permissions:**
     - `Actions`: Read and Write
     - `Contents`: Read and Write
     - `Variables`: Read and Write

4. Klicke "Generate token" und kopiere den Token

#### Option B: Classic Token

1. Gehe zu [GitHub Settings → Developer settings → Personal access tokens (classic)](https://github.com/settings/tokens)
2. Klicke "Generate new token (classic)"
3. Wähle Scope: `repo` (Full control)
4. Klicke "Generate token" und kopiere den Token

### Schritt 2: Token als Secret speichern

1. Gehe zu deinem Repository → Settings → Secrets and variables → Actions
2. Klicke "New repository secret"
3. Name: `PAT_READWRITE_ORGANISATION`
4. Value: Dein kopierter Token
5. Klicke "Add secret"

### Schritt 3: Konfigurationsdatei erstellen (empfohlen)

Erstelle `.github/config/docker-base-image-monitor/base-images.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/docker-base-image-monitor/docker-base-images.schema.json",
  "images": [
    {
      "name": "n8n",
      "image": "n8nio/n8n",
      "tag": "stable",
      "variable": "N8N_STABLE_DIGEST",
      "description": "n8n workflow automation platform"
    }
  ],
  "settings": {
    "commit-prefix": "chore(deps)",
    "auto-create-variables": true
  }
}
```

### Schritt 4: Workflow-Datei erstellen

Erstelle `.github/workflows/check-base-images.yml`:

```yaml
name: 🔄 Check Base Image Updates

on:
  schedule:
    # Täglich um 07:00 UTC (08:00 MEZ / 09:00 MESZ)
    - cron: '0 7 * * *'

  workflow_dispatch:
    inputs:
      dry-run:
        description: 'Nur prüfen, keine Änderungen vornehmen'
        type: boolean
        default: false

jobs:
  check-updates:
    name: Check for Base Image Updates
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
      dry-run: ${{ inputs.dry-run || false }}
    secrets: inherit

  # Optional: Benachrichtigung bei Updates
  notify:
    name: Notify on Updates
    needs: check-updates
    if: needs.check-updates.outputs.updates-found == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: 📢 Summary
        run: |
          echo "Base image updates found!"
          echo "Updated: ${{ needs.check-updates.outputs.updated-images }}"
          echo "Commit: ${{ needs.check-updates.outputs.commit-sha }}"
```

### Schritt 5: Semantic Release konfigurieren

Die Standard-Konfiguration in `.github/config/release/semantic-release.json` enthält bereits die Regel für `chore(deps):` → PATCH-Release.

**Falls du `modules-semantic-release.yml` verwendest:** Keine weitere Konfiguration nötig.

**Falls du eine eigene `.releaserc.json` nutzt:** Stelle sicher, dass diese Regel vorhanden ist:

```json
{
  "releaseRules": [
    { "type": "chore", "scope": "deps", "release": "patch" }
  ]
}
```

---

## 🔧 Konfigurationsoptionen

### Workflow Inputs

| Input | Typ | Default | Beschreibung |
|-------|-----|---------|--------------|
| `images` | string (JSON) | - | Inline JSON-Array mit Images |
| `config-file` | string | - | Pfad zur JSON-Konfigurationsdatei |
| `commit-prefix` | string | `chore(deps)` | Prefix für Commit-Messages |
| `commit-and-release` | boolean | `true` | Commit erstellen für Semantic Release |
| `target-workflow` | string | - | Alternativer Workflow zum Triggern |
| `target-workflow-ref` | string | `main` | Branch für workflow_dispatch |
| `max-release-attempts` | number | `3` | Release-Runs pro Digest, danach gibt der Monitor auf und schlägt fehl (`0` = unbegrenzt) |
| `dry-run` | boolean | `false` | Nur prüfen, keine Änderungen |
| `runs-on` | string | `ubuntu-latest` | Runner-Konfiguration |

### Workflow Outputs

| Output | Typ | Beschreibung |
|--------|-----|--------------|
| `updates-found` | boolean | `true` wenn ein Image ein Release braucht (neuer Digest oder fehlgeschlagenes Release) |
| `updated-images` | JSON array | Image-Namen, die ein Release brauchen (neue und wiederholte) |
| `retried-images` | JSON array | Image-Namen, deren Release fehlschlug und erneut dispatcht wurde |
| `pending-images` | JSON array | Image-Namen, deren dispatchter Release-Run noch läuft |
| `exhausted-images` | JSON array | Image-Namen, deren Release `max-release-attempts`-mal fehlschlug; nicht mehr dispatcht, Job rot |
| `triggered` | boolean | `true` wenn Commit/Workflow getriggert |
| `commit-sha` | string | SHA des erstellten Commits |
| `new-digests` | JSON object | Neue Digests pro Image |
| `dispatched-run-id` | string | Id des dispatchten Runs |
| `dispatched-run-url` | string | URL des dispatchten Runs |

### JSON-Konfiguration

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/docker-base-image-monitor/docker-base-images.schema.json",
  "images": [
    {
      "name": "string",        // Anzeigename (required)
      "image": "string",       // Docker Image ohne Tag (required)
      "tag": "string",         // Tag zum Überwachen (required)
      "variable": "string",    // GitHub Variable Name (required)
      "description": "string"  // Optionale Beschreibung
    }
  ],
  "settings": {
    "commit-prefix": "chore(deps)",  // Commit-Prefix
    "auto-create-variables": true    // Variables automatisch anlegen
  }
}
```

---

## 📝 Beispiele

### Beispiel 1: n8n mit Runner (Multi-Image)

**Konfiguration:** `.github/config/docker-base-image-monitor/base-images.json`

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/docker-base-image-monitor/docker-base-images.schema.json",
  "images": [
    {
      "name": "n8n",
      "image": "n8nio/n8n",
      "tag": "stable",
      "variable": "N8N_STABLE_DIGEST",
      "description": "n8n workflow automation platform"
    },
    {
      "name": "runner",
      "image": "n8nio/runners",
      "tag": "stable",
      "variable": "N8N_RUNNER_STABLE_DIGEST",
      "description": "n8n task runner for code execution"
    }
  ],
  "settings": {
    "commit-prefix": "chore(deps)",
    "auto-create-variables": true
  }
}
```

**Workflow:** `.github/workflows/check-base-images.yml`

```yaml
name: 🔄 Check Base Image Updates

on:
  schedule:
    - cron: '0 7 * * *'
  workflow_dispatch:
    inputs:
      dry-run:
        description: 'Dry run mode'
        type: boolean
        default: false

jobs:
  check-updates:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
      dry-run: ${{ inputs.dry-run || false }}
    secrets: inherit
```

### Beispiel 2: PostgreSQL + Redis (Datenbank-Stack)

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/docker-base-image-monitor/docker-base-images.schema.json",
  "images": [
    {
      "name": "postgres",
      "image": "library/postgres",
      "tag": "16-alpine",
      "variable": "POSTGRES_16_ALPINE_DIGEST",
      "description": "PostgreSQL 16 Alpine"
    },
    {
      "name": "redis",
      "image": "library/redis",
      "tag": "7-alpine",
      "variable": "REDIS_7_ALPINE_DIGEST",
      "description": "Redis 7 Alpine"
    }
  ],
  "settings": {
    "commit-prefix": "chore(deps)"
  }
}
```

### Beispiel 3: Node.js Multi-Version Monitoring

```json
{
  "$schema": "https://raw.githubusercontent.com/bauer-group/automation-templates/main/.github/config/docker-base-image-monitor/docker-base-images.schema.json",
  "images": [
    {
      "name": "node-lts",
      "image": "library/node",
      "tag": "lts-alpine",
      "variable": "NODE_LTS_ALPINE_DIGEST",
      "description": "Node.js LTS Alpine"
    },
    {
      "name": "node-current",
      "image": "library/node",
      "tag": "current-alpine",
      "variable": "NODE_CURRENT_ALPINE_DIGEST",
      "description": "Node.js Current Alpine"
    }
  ],
  "settings": {
    "commit-prefix": "build(deps)"
  }
}
```

### Beispiel 4: Inline-Konfiguration (ohne JSON-Datei)

Für einfache Setups kann die Konfiguration direkt im Workflow erfolgen:

```yaml
name: 🔄 Check Base Image Updates

on:
  schedule:
    - cron: '0 7 * * *'
  workflow_dispatch:

jobs:
  check-updates:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      images: |
        [
          {
            "name": "n8n",
            "image": "n8nio/n8n",
            "tag": "stable",
            "variable": "N8N_STABLE_DIGEST"
          },
          {
            "name": "runner",
            "image": "n8nio/runners",
            "tag": "stable",
            "variable": "N8N_RUNNER_STABLE_DIGEST"
          }
        ]
      commit-prefix: 'chore(deps)'
    secrets: inherit
```

### Beispiel 5: Mit Workflow-Dispatch statt Commit

Wenn du einen anderen Workflow triggern möchtest statt einen Commit zu erstellen:

```yaml
name: 🔄 Check Base Image Updates

on:
  schedule:
    - cron: '0 7 * * *'

jobs:
  check-updates:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
      commit-and-release: false
      target-workflow: 'docker-build.yml'
      target-workflow-ref: 'main'
    secrets: inherit
```

### Beispiel 6: Mit Self-Hosted Runner

```yaml
jobs:
  check-updates:
    uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
    with:
      config-file: '.github/config/docker-base-image-monitor/base-images.json'
      runs-on: '["self-hosted", "linux", "docker"]'
    secrets: inherit
```

---

## 🔄 Kompletter Release-Flow

So sieht der vollständige automatische Release-Flow aus:

```
07:00 UTC - Scheduled Trigger
       │
       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  docker-base-image-monitor prüft alle konfigurierten Images                   │
│                                                                               │
│  n8nio/n8n:stable                                                             │
│  ├── Aktueller Digest: sha256:newdigest123                                    │
│  └── Gespeicherter:    sha256:olddigest456                                    │
│  → Update gefunden!                                                           │
└──────────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  1. Commit erstellen:                                                         │
│     "chore(deps): update base image n8n                                       │
│                                                                               │
│      Base image digest changed:                                               │
│      - n8n (n8nio/n8n:stable)                                                 │
│        Old: sha256:olddigest456                                               │
│        New: sha256:newdigest123                                               │
│                                                                               │
│      Triggered by: Docker Base Image Monitor"                                 │
│     (mit target-workflow endet der Betreff auf [skip ci])                     │
│                                                                               │
│  2. Push to main (+ workflow_dispatch des target-workflow)                    │
│                                                                               │
│  3. GitHub Variable updaten - erst wenn 1 und 2 erfolgreich waren:            │
│     N8N_STABLE_DIGEST = sha256:newdigest123                                   │
│     Mit target-workflow erst, wenn der dispatchte Run erfolgreich war -       │
│     bis dahin steht der Run in N8N_STABLE_DIGEST_PENDING                      │
└──────────────────────────────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  dein-release-workflow.yml wird getriggert (on: push)                         │
│                                                                               │
│  1. Semantic Release analysiert Commits                                       │
│     → "chore(deps):" = PATCH Release                                          │
│     → Version: 1.2.3 → 1.2.4                                                  │
│                                                                               │
│  2. Release erstellt                                                          │
│     → Git Tag: v1.2.4                                                         │
│     → GitHub Release mit Changelog                                            │
│                                                                               │
│  3. Docker Build                                                              │
│     → FROM n8nio/n8n:stable (jetzt mit neuem Digest!)                         │
│     → Push: ghcr.io/your-org/your-image:1.2.4                                 │
│     → Push: ghcr.io/your-org/your-image:stable                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Troubleshooting

### Fehler: "Resource not accessible by integration"

**Ursache:** Der Token hat keine Berechtigung für Repository Variables.

**Lösung:**
- Classic PAT: Stelle sicher, dass `repo` Scope aktiviert ist
- Fine-grained PAT: Prüfe, dass "Variables" auf "Read and Write" steht

### Fehler: "Config file not found"

**Ursache:** Der Pfad zur Konfigurationsdatei ist falsch.

**Lösung:**
- Pfad muss relativ zum Repository-Root sein
- Beispiel: `.github/config/docker-base-image-monitor/base-images.json`

### Fehler: "Could not fetch digest"

**Ursache:** Das Image existiert nicht oder Docker Hub Rate Limit erreicht.

**Lösung:**
- Image-Namen und Tag prüfen: `docker manifest inspect n8nio/n8n:stable`
- Bei Rate Limit: Docker Hub Login oder später erneut versuchen

### Semantic Release erstellt kein Release

**Ursache:** Der Commit-Prefix ist nicht in den releaseRules konfiguriert.

**Lösung:** Verwende `modules-semantic-release.yml` - dort ist `chore(deps)` bereits konfiguriert. Bei eigener `.releaserc.json` prüfe, ob die Regel vorhanden ist:
```json
{ "type": "chore", "scope": "deps", "release": "patch" }
```

### Variable wird nicht angelegt

**Ursache:** Der Token hat keine Berechtigung, neue Variables anzulegen.

**Lösung:**
- Fine-grained PAT: "Variables" Permission auf "Read and Write"
- Classic PAT: `repo` Scope ist ausreichend

### Summary meldet "❌ Release failed"

**Ursache:** Der für den neuen Digest dispatchte Release-Run ist fehlgeschlagen (z.B.
rotes Backup-Round-Trip-Gate oder Build-Fehler). Das Image basiert noch auf dem alten
Base Image.

**Verhalten:** Der Digest wird nicht gespeichert, der Release wird bei jedem Check erneut
dispatcht, bis ein Run erfolgreich ist oder `max-release-attempts` Runs (Standard 3)
fehlgeschlagen sind. Den Fehler im verlinkten Run beheben — solange das Limit nicht
erreicht ist, kein manueller Eingriff am Monitor nötig.

Hatte der fehlgeschlagene Run sein Release schon getaggt (Release-Job grün, danach Build,
Scan oder Push rot), pusht der Retry vorher einen neuen leeren Release-Commit
(`<commit-prefix>: update base image …`, im Body der fehlgeschlagene Run). Ohne ihn fände
semantic-release nichts zu releasen, der Run übersprünge alle Builds und endete trotzdem
grün. Ist der Base-Image-Commit noch unreleased (z.B. rotes Gate vor dem Release), wird
ohne neuen Commit erneut dispatcht. Details: [Retry commit](../../../docs/workflows/modules-docker-base-image-monitor.md#retry-commit).

### Summary meldet "🛑 Release retries exhausted", Job ist rot

**Ursache:** Der Release für diesen Digest ist `max-release-attempts`-mal (Standard 3)
fehlgeschlagen. Der Monitor dispatcht ihn nicht mehr — jeder Retry nach einem getaggten
Release würde sonst ein weiteres Patch-Release erzeugen — und lässt den Job bei jedem
Check fehlschlagen.

**Lösung:** Ursache im verlinkten Run beheben, dann die Variable `<NAME>_PENDING` löschen
(*Settings → Secrets and variables → Actions → Variables*). Der nächste Check dispatcht
den Release dann wie für einen neuen Digest. Ein neuerer Digest des Images beginnt
ohnehin von vorn.

### Variable `<NAME>_PENDING` im Repository

**Ursache:** Kein Fehler. Sie hält den Release-Run, der für einen neuen Digest dispatcht
wurde (`{"digest", "run_id", "run_url", "attempt"}`), und wird entfernt, sobald der Run
erfolgreich war. Nur nach "Release retries exhausted" von Hand löschen, sonst nicht ändern.

### Workflow läuft, aber findet nie Updates

**Ursache:** Das überwachte Image ändert sich tatsächlich nicht.

**Lösung:**
- Prüfe manuell: `docker manifest inspect <image>:<tag>`
- Teste mit `dry-run: false` und manuellem Trigger
- Prüfe die GitHub Variable im Repository (Settings → Secrets and variables → Variables)

---

## 📚 Weiterführende Links

- [GitHub Actions: Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [Semantic Release](https://semantic-release.gitbook.io/)
- [Docker Manifest](https://docs.docker.com/engine/reference/commandline/manifest/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

*Erstellt für bauer-group/automation-templates*
