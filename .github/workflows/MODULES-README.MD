# 🧩 Modulare Workflow-Komponenten

Diese Sammlung von wiederverwendbaren Workflows ermöglicht es, CI/CD-Pipelines durch Komposition kleinerer, spezialisierter Module aufzubauen.

## 🎯 Philosophie

**Modular statt Monolithisch:** Anstatt eines großen 870-Zeilen Workflows bieten wir spezialisierte, komponierbare Module, die flexibel kombiniert werden können.

## 📦 Verfügbare Module

### 🛡️ [Security Scan](./modules-security-scan.yml)
**Zweck:** Trivy Vulnerability Scan + Secrets-Erkennung mit Gitleaks (opt-in)

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
with:
  scan-engine: 'none'       # Default: Gitleaks aus; 'gitleaks' schaltet es ein (siehe unten)
  scan-type: 'all'
  fail-on-findings: true
secrets: inherit           # GITLEAKS_LICENSE, nur mit scan-engine: 'gitleaks' nötig
```

> **Gitleaks ist opt-in (seit 2026-10).** Ohne `scan-engine: 'gitleaks'` läuft nur Trivy;
> die Zusammenfassung zeigt dann „disabled - Gitleaks is opt-in“ statt eines sauberen
> Secret-Scans, und der Lauf scheitert nicht daran. Einschalten in Repositories **ohne**
> GitHub Secret Scanning und Push Protection - typisch private Repositories in
> Organisationen ohne GitHub Secret Protection (Advanced Security); öffentliche
> Repositories können beides kostenlos einschalten. In Organisations-Repositories braucht Gitleaks das
> Secret `GITLEAKS_LICENSE`, für Dependabot-Läufe zusätzlich als **Dependabot**-Secret.
> Details und Prüfbefehl:
> [Gitleaks ist opt-in](../../docs/security/native-secret-scanning.md#gitleaks-is-opt-in).

> GitGuardian wurde entfernt (2026-10): Im CI scannte es nur den letzten Commit und konnte
> Funde gar nicht melden. `scan-engine: 'both'` läuft weiter und nutzt Gitleaks,
> `'gitguardian'` scannt keine Secrets mehr (mit Warnung im Lauf). `minimum-severity` und
> das Secret `GITGUARDIAN_API_KEY` werden noch angenommen, aber ignoriert.

**Python ohne Lock-Datei:** Trivy liest bei Python nur `requirements.txt`, `poetry.lock`,
`uv.lock`, `Pipfile.lock` und `pylock.toml`, nie `pyproject.toml`. Für jedes `pyproject.toml`
ohne solche Datei (auch nicht in einem übergeordneten Workspace) löst der Scan die
Laufzeit-Abhängigkeiten vorher mit `uv pip compile` auf und legt sie unter
`security-reports/python-deps/` ab, wo Trivy sie scannt. Gescannt werden die neuesten
Versionen, die die Versionsbereiche erlauben; eine committete Lock-Datei (`uv lock`) hat
immer Vorrang und ist genauer.

**Nichts gescannt ist nicht sauber:** Findet Trivy keine Datei, die es lesen kann, meldet
der Scan `vulnerabilities-found: unknown` statt `false`, und die Zusammenfassung zeigt
„NOT scanned“ statt „Excellent“. Das lässt den Lauf nicht scheitern.

**Ausgaben:**
- `secrets-found`: Ob Secrets gefunden wurden (`skipped` = kein Secret-Scan, z. B. weil Gitleaks nicht eingeschaltet ist; nur `false` heißt gescannt und sauber)
- `vulnerabilities-found`: Ob Schwachstellen entdeckt wurden (via Trivy; `unknown` = nichts gescannt)
- `security-score`: Sicherheitsbewertung (0-100)
- `scan-results`: Zusammenfassung der Ergebnisse

### 🛡️ [Vulnerability Scan](./modules-vulnerability-scan.yml)
**Zweck:** Professionelles Dependency-Vulnerability-Scanning mit Trivy + OSV-Scanner + Anchore/Grype

Kombiniert drei offizielle GitHub Actions für maximale Abdeckung:
- **Trivy** (Filesystem): Dependencies, Secrets, Misconfigs
- **OSV-Scanner** (Google): Dependency-Scan via OSV.dev (20+ Vulnerability-Quellen)
- **Anchore/Grype** (Container): Container-Image-Scanning (optional, Multi-Image)

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-vulnerability-scan.yml@main
with:
  scan-engine: 'both'           # osv-scanner, trivy, both
  trivy-severity: 'CRITICAL,HIGH'
  fail-on-findings: true
  container-images: |            # Optional: eins pro Zeile
    ghcr.io/org/api:latest
    ghcr.io/org/frontend:latest
```

**Ausgaben:**
- `vulnerabilities-found`: Ob irgendeine Engine Schwachstellen gefunden hat
- `trivy-result`: Trivy Ergebnis (pass/fail/skipped)
- `osv-result`: OSV-Scanner Ergebnis (pass/fail/skipped)
- `container-result`: Container-Scan Ergebnis (pass/fail/skipped)
- `security-score`: Kombinierte Sicherheitsbewertung (0-100)
- `scan-results`: Zusammenfassung der Ergebnisse

### 🐷 [TruffleHog Secret Scan](./modules-trufflehog-scan.yml)
**Zweck:** Verified-first Secret-Scanning mit TruffleHog (800+ Detektoren mit Live-Verifizierung)

Ergänzt Gitleaks um **Verifizierung**: TruffleHog prüft per Provider-API, ob ein gefundenes Secret tatsächlich *live* ist. Standalone-Modul (nicht im Meta-Orchestrator), aber output-kompatibel.

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-trufflehog-scan.yml@main
with:
  scan-mode: 'filesystem'        # oder 'git-history'
  only-verified: true
  fail-on-findings: true
```

**Ausgaben:**
- `secrets-found`: Ob Secrets gefunden wurden
- `secrets-count`: Gesamtzahl gefundener Secrets
- `verified-count`: Anzahl **verifizierter (live)** Secrets
- `security-score`: Sicherheitsbewertung (0-100)
- `scan-status`: pass/warning/fail

### 🛡️ [CodeQL Analysis](./modules-codeql.yml)
**Zweck:** Statische Code-Analyse (SAST) mit GitHub CodeQL — für Downstream-Produkt-Repos

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-codeql.yml@main
with:
  languages: 'javascript-typescript,python'
  queries: 'security-extended'
  # build-mode: 'autobuild'   # für kompilierte Sprachen
```

**Ausgaben:**
- `analysis-complete`: Ob die Analyse für alle Sprachen abgeschlossen wurde

> Ergebnisse erscheinen im **Security-Tab → Code Scanning**.

### 🛡️ [Dependency Review](./modules-dependency-review.yml)
**Zweck:** Pre-Merge-Gate — blockiert PRs mit neuen verwundbaren oder lizenzwidrigen Dependencies

> **Trigger:** Caller-Workflow muss von `pull_request` ausgelöst werden.

```yaml
on: pull_request
jobs:
  dependency-review:
    uses: bauer-group/automation-templates/.github/workflows/modules-dependency-review.yml@main
    with:
      fail-on-severity: 'high'
      deny-licenses: 'GPL-3.0, AGPL-3.0'
```

**Ausgaben:**
- `review-result`: success/failure

### 📋 [License Compliance](./modules-license-compliance.yml)
**Zweck:** Lizenz-Compliance-Prüfung und SBOM-Generierung

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-license-compliance.yml@main
with:
  fail-on-forbidden: true
  scan-dependencies: true
  generate-sbom: true
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  FOSSA_API_KEY: ${{ secrets.FOSSA_API_KEY }}
```

**Ausgaben:**
- `compliance-status`: Compliance-Status (pass/fail)
- `forbidden-count`: Anzahl verbotener Lizenzen
- `unknown-count`: Anzahl unbekannter Lizenzen
- `sbom-generated`: Ob SBOM erstellt wurde

### 🧪 [Code Quality (SonarQube)](./modules-code-quality.yml)
**Zweck:** Statische Code-Analyse mit self-hosted SonarQube Server (opt-in, tolerant)

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-code-quality.yml@main
with:
  enable-sonar: true
  # fail-on-quality-gate: true   # optional: Quality Gate erzwingen
secrets: inherit   # liefert SONARQUBE_TOKEN + SONARQUBE_HOST_URL (Org-Secrets)
```

**Ausgaben:**
- `executed`: Ob der Scan tatsächlich lief (true/false)
- `quality-gate`: Quality-Gate-Status (PASSED/FAILED/unknown)

> Auch direkt in `dotnet/nodejs/python/php-build.yml` via `enable-sonar: true` verfügbar. Fehlen Token/URL, gibt der Job nur eine Warnung aus statt zu scheitern. Projekt-Config (projectKey, Coverage-Pfade) gehört in `sonar-project.properties` im Consumer-Repo.

### 🧪 [Backup Round-Trip Test](./modules-backup-roundtrip-test.yml)
**Zweck:** Beweist vor dem Release, dass der BackupHelper-Sidecar eines Compose-Stacks echte Daten sichern **und** wiederherstellen kann

Startet den Stack des Consumers mit den Images aus dem Commit, legt Testdaten an, erstellt ein Backup, löscht die Daten, stellt den Snapshot wieder her und prüft, dass die Daten zurück sind. Läuft im Consumer-Repository, Logs privater Stacks bleiben dort.

```yaml
backup-roundtrip:
  permissions:
    contents: read
    packages: read
  uses: bauer-group/automation-templates/.github/workflows/modules-backup-roundtrip-test.yml@main
  with:
    compose-file: 'docker-compose.local.yml'
    profiles: 'backup'
    generated-secrets: 'DATABASE_PASSWORD'
    build-images: '[{"service": "app-backup", "context": "src/app-backup"}]'
    backup-service: 'app-backup'
    require-components: 'app files'
    seed-script: 'tests/backup-roundtrip/seed.sh'
    mutate-script: 'tests/backup-roundtrip/mutate.sh'
    check-script: 'tests/backup-roundtrip/check.sh'
  secrets: inherit   # kein Secret nötig: Passwörter werden pro Lauf generiert
```

**Ausgaben:**
- `snapshot-id`: Id des erstellten und wiederhergestellten Snapshots
- `components`: Komponenten des Snapshots als JSON (`name`, `kind`, `size`, `error`)
- `result`: Ergebnis des Jobs (`success`/`failure`/`cancelled`)

> Das Check-Skript muss die Daten vor dem Backup sehen, nach dem Löschen **nicht** sehen und nach dem Restore wieder sehen — ein Restore, der nichts schreibt, kann so nicht bestehen. Doku und Skript-Vertrag: [docs/workflows/modules-backup-roundtrip-test.md](../../docs/workflows/modules-backup-roundtrip-test.md). Sechs kopierfertige Caller (minimal, Release-Pipeline, Plugin-Quellen, Upgrade, Off-Site S3, Compose-Varianten): [github/workflows/examples/backup-roundtrip/](../../github/workflows/examples/backup-roundtrip/README.md).

**Optional (Standard: aus):**
- `upgrade-from: 'latest-release'` testet das Upgrade einer bestehenden Installation: Das vorige Release sichert, der Stack wird wie von einem Operator auf die Images aus dem Commit aktualisiert (Daten und Healthcheck geprüft), und der neue Sidecar stellt den alten Snapshot wieder her ([Upgrade](../../docs/workflows/modules-backup-roundtrip-test.md#upgrade-from-a-previous-release))
- `s3-destination: true` + `s3-env` startet einen Wegwerf-S3-Server (MinIO) als S3-Ziel des Sidecars: Der Snapshot muss im Bucket liegen, danach werden die lokalen Daten des Sidecars wie auf einem neuen Host gelöscht, und der Restore muss ihn aus S3 zurückholen ([Off-Site S3](../../docs/workflows/modules-backup-roundtrip-test.md#off-site-s3-and-a-new-host))
- `external-networks: 'auto'` legt die externen Proxy-Netzwerke an, die eine Traefik- oder Coolify-Variante erwartet — so läuft der Round Trip per Matrix einmal pro Compose-Variante ([Compose-Varianten](../../docs/workflows/modules-backup-roundtrip-test.md#compose-variants-traefik-coolify))

### 🔍 [Docker Base Image Monitor](./modules-docker-base-image-monitor.yml)
**Zweck:** Erkennt, wenn ein Base Image unter demselben Tag neu gebaut wurde (`stable`, `latest`, `7`), und stößt den Rebuild an — der neue Digest zählt erst als erledigt, wenn der Release erfolgreich war

Liest den Digest hinter jedem Tag der Konfiguration (`docker manifest inspect`, multi-arch, 3 Versuche bei Registry-Fehlern). Hat er sich bewegt: leerer Release-Commit und/oder `workflow_dispatch` des Release-Workflows. Mit `target-workflow` wird der Digest erst gespeichert, wenn der dispatchte Run erfolgreich war; bis dahin steht der Run in `<VAR>_PENDING`, ein fehlgeschlagener Release (z.B. rotes Backup-Round-Trip-Gate) wird beim nächsten Check erneut dispatcht, bis `max-release-attempts` (Standard 3) Läufe fehlgeschlagen sind; danach schlägt der Job fehl.

```yaml
check:
  permissions:
    contents: read
    packages: read        # interne/private GHCR-Images
  uses: bauer-group/automation-templates/.github/workflows/modules-docker-base-image-monitor.yml@main
  with:
    config-file: '.github/config/docker-base-image-monitor/base-images.json'
    target-workflow: 'docker-release.yml'
    target-workflow-inputs: '{"force-release": "true"}'
  secrets: inherit        # PAT_READWRITE_ORGANISATION (Pflicht)
```

**Ausgaben:**
- `updates-found`: Ob ein Image ein Release braucht (neuer Digest oder fehlgeschlagener Release)
- `updated-images` / `retried-images` / `pending-images` / `exhausted-images`: Image-Namen je Zustand (JSON)
- `new-digests`: Neue Digests pro Image (JSON)
- `dispatched-run-id` / `dispatched-run-url`: Der in diesem Check dispatchte Release-Run
- `images-configured` / `images-checked` / `unreachable-images`: Abdeckung des Checks

> Release fehlgeschlagen oder „Release retries exhausted“? Lebenszyklus der Variablen und alle Recovery-Schritte mit `gh`-Befehlen: [State variables and lifecycle](../../docs/workflows/modules-docker-base-image-monitor.md#state-variables-and-lifecycle) · [Operator recovery](../../docs/workflows/modules-docker-base-image-monitor.md#operator-recovery). Beispiele: [github/workflows/examples/docker-base-image-monitor/](../../github/workflows/examples/docker-base-image-monitor/README.md).

### 🐳 [Docker Maintenance (Dependabot)](./docker-maintenance-dependabot.yml)
**Zweck:** Merged Dependabot-PRs erst, nachdem die genannte PR-CI auf dem Head-Commit gelaufen und grün ist — ohne Ruleset, Branch Protection oder „Allow auto-merge“

Wartet, bis die CI des PRs vollständig und 3 Minuten unverändert ist, und merged nur, wenn jeder Workflow aus `required-workflows` per `pull_request` auf dem Head-Commit erfolgreich lief und kein Check fehlschlug (`gh pr merge --match-head-commit`). Standardmäßig nur Patch-Updates. GitHub-Actions-Updates und PRs, die `.github/` ändern, bleiben immer offen. Ohne `required-workflows` wird nichts gemerged.

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
    paths: ['src/app/Dockerfile']   # entscheidet, welche Dependabot-PRs das Modul erreichen
permissions:
  contents: write
  pull-requests: write
  checks: read            # private Repositories
  statuses: read          # private Repositories
  actions: read           # private Repositories
jobs:
  maintenance:
    uses: bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main
    with:
      required-workflows: .github/workflows/docker-release.yml
      merge-update-types: 'patch'
    secrets: inherit      # kein Secret nötig
```

> **Trigger-Umfang:** Die `paths:` des Callers bestimmen, welche Dependabot-PRs das Modul überhaupt erreichen. Mit reinen Dockerfile-Pfaden bleiben npm-, pip- und Composer-Updates manuelle Merges — ohne Annotation. Entscheidungstabelle, Trigger-Umfang und Beispiele (Backup-Round-Trip-Gate, eigener Build-/Test-Workflow, mehrere Workflows, bewusst ohne PR-CI): [docs/workflows/docker-maintenance.md](../../docs/workflows/docker-maintenance.md#option-1-dependabot-simple) · [github/workflows/examples/docker-maintenance-dependabot/](../../github/workflows/examples/docker-maintenance-dependabot/README.md).

### 🔧 [Auto Maintenance](./modules-auto-maintenance.yml)
**Zweck:** Base-Image-Digests und Dependency-Updates (npm, pip, .NET, Go) in einem geplanten Lauf — validiert mit Build/Test/Typecheck des Repositories, bei Fehlern zurückgerollt

Eine JSON-Konfiguration pro Repository. Ein Lauf mit Änderungen committet nach `main` und dispatcht den Release-Workflow; die neuen Digests werden erst danach gespeichert, ein fehlgeschlagener Push oder Dispatch speichert nichts. Anders als beim Base Image Monitor wartet der Digest nicht auf den Erfolg des Releases.

```yaml
maintenance:
  uses: bauer-group/automation-templates/.github/workflows/modules-auto-maintenance.yml@main
  with:
    config-file: '.github/config/maintenance/config.json'
  secrets: inherit        # MAINTENANCE_TOKEN oder PAT_READWRITE_ORGANISATION
```

**Ausgaben:**
- `updates-found`: Ob Updates gefunden wurden
- `summary`: Zusammenfassung der Änderungen

> **Bekannte Einschränkung:** npm-, pip- und .NET-Updates werden derzeit validiert, aber nicht committet; Base Images und Go-Module im Root sind nicht betroffen ([Details](../../docs/workflows/modules-auto-maintenance.md#bekannte-einschraenkung-dependency-updates-werden-nicht-committet)).
>
> Doku: [docs/workflows/modules-auto-maintenance.md](../../docs/workflows/modules-auto-maintenance.md) · Beispiele: [github/workflows/examples/auto-maintenance/](../../github/workflows/examples/auto-maintenance/README.md)

### 🚀 [Semantic Release](./modules-semantic-release.yml)
**Zweck:** Automatisierte Release-Erstellung mit Semantic Release

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
with:
  target-branch: 'main'
  dry-run: false
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Ausgaben:**
- `release-created`: Ob Release erstellt wurde
- `version`: Release-Version
- `tag-name`: Git-Tag des Releases

### 🔨 [Artifact Generation](./modules-artifact-generation.yml)
**Zweck:** Erstellung und Upload von Release-Artefakten

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-artifact-generation.yml@main
with:
  artifact-types: 'all'
  tag-name: ${{ needs.release.outputs.tag-name }}
  version: ${{ needs.release.outputs.version }}
  release-url: ${{ needs.release.outputs.release-url }}
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Ausgaben:**
- `artifacts-generated`: Ob Artefakte erfolgreich erstellt wurden
- `source-archive-created`: Ob Quellcode-Archiv erstellt wurde
- `binaries-created`: Ob Binärdateien erstellt wurden
- `docker-image-pushed`: Ob Docker-Image gepusht wurde

### 🔍 [PR Validation](./modules-pr-validation.yml)
**Zweck:** Umfassende Pull Request Validierung

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-pr-validation.yml@main
with:
  enable-security-scan: true
  security-scan-engine: 'none'   # Default; 'gitleaks' für Repos ohne GitHub Secret Scanning
  enable-license-check: true
  enable-commit-lint: true
  fail-on-security-issues: true
secrets: inherit
```

> Der Secret-Scan der PR-Validierung ist Gitleaks und damit opt-in: Mit
> `security-scan-engine: 'none'` (Default) wird der Schritt übersprungen und in der
> Zusammenfassung als „Gitleaks disabled (opt-in)“ ausgewiesen.

### 🏷️ [PR Labeler & Triage](./modules-pr-labeler.yml)
**Zweck:** Automatisches Labeling und Triage von Pull Requests

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-pr-labeler.yml@main
with:
  config-path: '.github/config/pr-labeler/path-labels.yml'
  size-labels: true
  priority-labels: true
  type-labels: true
  auto-assign: false
secrets: inherit
```

**Ausgaben:**
- `labels-added`: Hinzugefügte Labels
- `size-label`: Größen-Label (XS/S/M/L/XL/XXL)
- `priority-label`: Prioritäts-Label
- `all-labels`: Alle aktuellen PR-Labels

**Ausgaben:**
- `validation-passed`: Ob alle Validierungen bestanden wurden
- `security-score`: Sicherheitsbewertung
- `license-compliance`: Lizenz-Compliance-Status

## 🔄 Kompositions-Patterns

### 1. Einfacher Release-Workflow
```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      target-branch: 'main'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  artifacts:
    if: needs.release.outputs.release-created == 'true'
    needs: release
    uses: bauer-group/automation-templates/.github/workflows/modules-artifact-generation.yml@main
    with:
      artifact-types: 'source'
      tag-name: ${{ needs.release.outputs.tag-name }}
      version: ${{ needs.release.outputs.version }}
```

### 2. Security-First Pipeline
```yaml
jobs:
  secrets:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    with:
      scan-engine: 'gitleaks'   # opt-in: Repo ohne GitHub Secret Scanning / Push Protection
    secrets: inherit            # GITLEAKS_LICENSE

  vulnerabilities:
    uses: bauer-group/automation-templates/.github/workflows/modules-vulnerability-scan.yml@main
    with:
      scan-engine: 'both'
      trivy-severity: 'CRITICAL,HIGH'

  compliance:
    uses: bauer-group/automation-templates/.github/workflows/modules-license-compliance.yml@main

  release:
    needs: [secrets, vulnerabilities, compliance]
    if: needs.vulnerabilities.outputs.security-score >= 80
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
```

### 3. PR-Validierung mit Gates
```yaml
jobs:
  pr-check:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/modules-pr-validation.yml@main
    with:
      fail-on-security-issues: true
      fail-on-license-issues: false
```

### 4. Release erst nach erfolgreichem Backup-Round-Trip
```yaml
jobs:
  backup-roundtrip:
    permissions:
      contents: read
      packages: read
    uses: bauer-group/automation-templates/.github/workflows/modules-backup-roundtrip-test.yml@main
    with:
      backup-service: 'app-backup'
      # ... siehe Modul-Doku
    secrets: inherit

  release:
    needs: backup-roundtrip
    if: needs.backup-roundtrip.result == 'success' && github.event_name != 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets: inherit
```

### 5. Wartungskreislauf eines Container-Stacks
Drei Caller, ein Gate: Der Base Image Monitor dispatcht `docker-release.yml`, wenn ein Floating Tag sich bewegt; Dependabot-PRs für fixierte Tags werden erst gemerged, wenn der PR-Lauf desselben `docker-release.yml` grün ist. In beiden Fällen entscheidet der Backup-Round-Trip, ob ein Release entsteht.

- `check-base-images.yml` → [daily-release-dispatch.yml](../../github/workflows/examples/docker-base-image-monitor/daily-release-dispatch.yml)
- `docker-maintenance.yml` → [with-backup-roundtrip-gate.yml](../../github/workflows/examples/docker-maintenance-dependabot/with-backup-roundtrip-gate.yml)
- `docker-release.yml` → [gated-release-pipeline.yml](../../github/workflows/examples/backup-roundtrip/gated-release-pipeline.yml)

## 🛠️ Anpassung und Konfiguration

### Umgebungsvariablen
Jedes Modul unterstützt verschiedene Konfigurationsoptionen über `inputs` und `secrets`. Siehe die jeweilige Workflow-Datei für alle verfügbaren Parameter.

### Conditional Execution
Module können basierend auf verschiedenen Bedingungen ausgeführt werden:

```yaml
jobs:
  security-scan:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    
  pr-validation:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/modules-pr-validation.yml@main
```

### Error Handling
Module verwenden `continue-on-error` und Output-Parameter für flexibles Error-Handling:

```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    with:
      fail-on-findings: false  # Informative Scans

  release:
    needs: security
    if: needs.security.outputs.security-score >= 80  # Conditional based on results
```

## 📚 Best Practices

### 1. Dependency Management
- Verwende `needs:` um Abhängigkeiten zwischen Modulen zu definieren
- Nutze Outputs für Datenfluss zwischen Modulen
- Implementiere sinnvolle Fallback-Strategien

### 2. Secret Management
- Definiere nur die tatsächlich benötigten Secrets
- Verwende optionale Secrets für erweiterte Features
- Dokumentiere alle erforderlichen Repository-Secrets

### 3. Performance Optimization
- Lasse Module parallel laufen wo möglich
- Nutze `if:` Conditions um unnötige Ausführungen zu vermeiden
- Cache-Strategien in modulspezifischen Steps implementieren

### 4. Monitoring & Observability
- Nutze die Summary-Reports der Module
- Implementiere eigene Monitoring-Jobs wenn nötig
- Tracke wichtige Metriken über mehrere Workflows hinweg

## 🔧 Migration von Monolithen

### Von automatic-release.yml
Der ursprüngliche monolithische Workflow kann schrittweise durch modulare Komponenten ersetzt werden:

1. **Phase 1:** PR-Validation extrahieren
2. **Phase 2:** Security-Scanning auslagern  
3. **Phase 3:** Release-Management modularisieren
4. **Phase 4:** Artifact-Generation trennen

### Kompatibilität
Die Module sind darauf ausgelegt, dieselben Outputs und Verhalten wie die ursprünglichen Workflows zu bieten, um eine nahtlose Migration zu ermöglichen.

## 🚀 Nächste Schritte

1. **Testen Sie ein einzelnes Modul** in Ihrem Repository
2. **Komponieren Sie eine einfache Pipeline** aus 2-3 Modulen
3. **Erweitern Sie schrittweise** um weitere Module
4. **Optimieren Sie die Konfiguration** für Ihre Anforderungen

Die modulare Architektur ermöglicht es Ihnen, mit einfachen Workflows zu beginnen und diese nach Bedarf zu erweitern, anstatt mit einem komplexen monolithischen System zu starten.
