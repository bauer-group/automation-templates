# Repository Workflows

Diese Workflows sind speziell für das `automation-templates` Repository entwickelt und demonstrieren die Verwendung der modularen Workflow-Komponenten.

## 📁 Workflow-Dateien

### Repository-spezifische Workflows

#### 🔄 [automatic-release.yml](./automatic-release.yml) - Automatische Releases
**Zweck:** Automatische Release-Erstellung bei Push auf Main Branch  
**Module verwendet:** semantic-release

**Features:**
- Automatische Versionierung basierend auf Conventional Commits
- CHANGELOG.MD Generierung
- GitHub Release Erstellung
- Semantic Versioning

#### 📄 [documentation.yml](./documentation.yml) - Dokumentations-Management
**Zweck:** README-Generierung und Dokumentationsvalidierung  
**Module verwendet:** readme-generate action (direkt)

**Features:**
- Template-basierte README-Generierung
- Automatische Updates bei Template-Änderungen
- Git-basierte Änderungserkennung

#### 📦 [manual-release.yml](./manual-release.yml) - Manuelle Release-Erstellung
**Zweck:** Kontrollierte, manuelle Release-Erstellung  
**Module verwendet:** security-scan, license-compliance, artifact-generation, generate-changelog

**Features:**
- Flexible Versionierung (major, minor, patch, custom)
- Optionale Security- und Compliance-Checks
- Konfigurierbare Artefakt-Generierung
- Changelog-Generierung mit generate-changelog Action

#### 🤖 AI Issue Zusammenfassungen (pausiert)
**Zweck:** AI-gestützte Issue-Zusammenfassungen  
**Status:** Der Caller `ai-issue-summary.yml` wurde am 2026-09-28 aus diesem Repository und org-weit entfernt, weil kein Lauf mehr eine echte AI-Zusammenfassung lieferte. Das Modul [modules-ai-issue-summary.yml](./modules-ai-issue-summary.yml) bleibt für die Überarbeitung bestehen; Re-Rollout in [#105](https://github.com/bauer-group/automation-templates/issues/105)  
**Module verwendet:** modules-ai-issue-summary  
**Benötigt:** `copilot-requests: write` — im Caller **und** im Modul, da der
`permissions:`-Block eines `workflow_call`-Workflows eine Obergrenze ist, keine
Vergabe. Kein Secret nötig: der Copilot-Provider authentifiziert sich mit
`github.token`. Voraussetzung ist die Org-Einstellung „Allow use of Copilot CLI
billed to the organization".  
**Doku:** [docs/workflows/ai-issue-summary.md](../../docs/workflows/ai-issue-summary.md)

#### 🏷️ [pr-labeler.yml](./pr-labeler.yml) - PR Labeling
**Zweck:** Automatisches PR Labeling  
**Module verwendet:** modules-pr-labeler

#### 🔧 [issue-automation.yml](./issue-automation.yml) - Issue Automatisierung
**Zweck:** Issue Management Automatisierung  
**Module verwendet:** modules-issue-automation

#### 🧪 [backup-roundtrip-selftest.yml](./backup-roundtrip-selftest.yml) - Backup Round-Trip Self-Test
**Zweck:** Führt das Modul `modules-backup-roundtrip-test.yml` gegen einen Fixture-Stack aus ([tests/backup-roundtrip/](./tests/backup-roundtrip/): PostgreSQL, Datei-Volume als uid 1000, Meta-Image auf der öffentlichen BackupHelper-Engine) — Backup, Löschen, Restore und Datenprüfung laufen echt durch, einmal mit allen Services, einmal nur mit ausgewählten (neben einem Service, dessen Image nicht gepullt werden kann) und als Matrix pro Compose-Variante (die Proxy-Variante braucht ein externes Netzwerk, das das Modul anlegt); zwei Läufe sichern zusätzlich in einen Wegwerf-MinIO und stellen nach dem Löschen der lokalen Sidecar-Daten aus S3 wieder her; drei Läufe starten mit einem älteren Engine-Release und stellen dessen Snapshot nach dem Upgrade wieder her. Dazu Step-Tests für *Validate Inputs*, *Prepare Environment*, *Create External Networks*, die S3- und Upgrade-Schritte, *Build Images Under Test*, *Create Backup* (Exit-Code 1 bei fehlgeschlagener Komponente) und *Pull Images* ([tests/backup-roundtrip-module.test.sh](./tests/backup-roundtrip-module.test.sh)) sowie ein Test der beiden Upgrade-Prüfungen gegen das echte Docker Compose: `pull_policy: always` und `build` ersetzen beim `up` das vom Modul getaggte Image, und beide Prüfungen müssen daran scheitern ([tests/backup-roundtrip-pull-policy.test.sh](./tests/backup-roundtrip-pull-policy.test.sh))  
**Module verwendet:** modules-backup-roundtrip-test  
**Trigger:** Nur Änderungen am Modul, am Self-Test, an der Fixture oder am Step-Test (pfadgefiltert)  
**Doku:** [docs/workflows/modules-backup-roundtrip-test.md](../../docs/workflows/modules-backup-roundtrip-test.md)

#### ✅ [workflow-validation.yml](./workflow-validation.yml) - Workflow Validation
**Zweck:** Prüft jede Änderung an Workflows, Actions und den ausgelieferten Beispielen, bevor sie Consumer erreicht  
**Module verwendet:** modules-validate-workflows (actionlint + shellcheck über `.github/workflows/` und `github/workflows/examples/`, Permission-Ceiling)  
**Step-Tests:** führen die echten Step-Bodies aus, u. a. docker-build (Plattformen, Token-Secret, Dockerfile-Write-back, Primary Tag), docker-maintenance-dependabot (Merge nach grüner CI), security-scan, docker-base-image-monitor (Digest erst nach erfolgreichem Release) und semantic-release; dazu der workflow-audit (Script-Injection, nicht deklarierte Variablen)  
**Trigger:** PR/Push mit Änderungen unter `.github/workflows/`, `.github/actions/` oder `github/workflows/examples/`

### Reusable Workflows (Neu)

#### 🔷 [dotnet-build.yml](./dotnet-build.yml) - .NET Build & Test
**Zweck:** Wiederverwendbarer .NET Core/5+ Build Workflow  
**Features:** Docker, NuGet Publishing, Cross-Platform

#### 🖥️ [dotnet-desktop-build.yml](./dotnet-desktop-build.yml) - .NET Desktop Build
**Zweck:** Wiederverwendbarer .NET Desktop (WPF/WinForms/MAUI) Build Workflow  
**Features:** Code Signing, MSIX Packaging, Multi-Platform

#### 📚 [dotnet-publish-library.yml](./dotnet-publish-library.yml) - .NET Library / Tool Publish
**Zweck:** Build, Test, Pack und Push von NuGet-Paketen (Libraries und `PackAsTool`-Tools)  
**Features:** Trusted Publishing (OIDC), GitHub Packages, Multi-Package Support, optionales Strong-Name Signing

#### 🚢 [dotnet-publish-binaries.yml](./dotnet-publish-binaries.yml) - .NET Binary Publish
**Zweck:** Self-contained Single-File Binaries pro RID bauen und als Release-Assets hochladen  
**Features:** Konfigurierbare RID-Matrix (Default: `linux-x64`, `linux-arm64`, `win-x64`; opt-in für macOS/win-arm64), SHA-256 Checksums, optionale Pre-Build-Artefakte (Kiota/Codegen), tar.gz + zip

#### 📦 [nodejs-build.yml](./nodejs-build.yml) - Node.js Build & Publish
**Zweck:** Wiederverwendbarer Node.js Build und Publish Workflow  
**Features:** npm/yarn/pnpm/bun Support, Package Publishing, Docker

#### 🐳 [docker-build.yml](./docker-build.yml) - Docker Build & Publish
**Zweck:** Multi-Platform Docker Build mit Security-Scan, SBOM und Push nach GHCR und/oder Docker Hub (Composite Action [`docker-build`](../actions/docker-build/action.yml))  
**Features:** Trivy/Grype-Gate vor dem Push, Cosign, SBOM-Attestation, Dockerfile-Version-Write-back mit Retry, `free-disk-space` für große Images (nur GitHub-hosted Runner)  
**Docs:** [docs/workflows/docker-build.md](../../docs/workflows/docker-build.md) · **Beispiele:** [examples/docker/](../../github/workflows/examples/docker/README.md)

### Container-Wartung & Release-Gate

Reusable Workflows, mit denen sich Container-Repositories selbst aktuell halten, und das Gate, das jedes Release davor bestehen muss — jeweils mit eigener Doku und kopierfertigen Beispielen:

#### 🐳 [docker-maintenance-dependabot.yml](./docker-maintenance-dependabot.yml) - Docker Maintenance (Dependabot)
**Zweck:** Merged Dependabot-PRs erst, nachdem die in `required-workflows` genannte PR-CI auf dem Head-Commit grün ist (ohne Ruleset/Branch Protection)  
**Features:** Entscheidungstabelle mit Annotation pro Fall, nur Patch-Updates per Default, CI-Änderungen (`.github/`, GitHub Actions) bleiben offen, gepinnter Merge (`--match-head-commit`)  
**Trigger-Umfang:** Die `pull_request.paths` des Callers entscheiden, welche Dependabot-PRs das Modul erreichen  
**Docs:** [docs/workflows/docker-maintenance.md](../../docs/workflows/docker-maintenance.md) · **Beispiele:** [examples/docker-maintenance-dependabot/](../../github/workflows/examples/docker-maintenance-dependabot/README.md)

#### 🔍 [modules-docker-base-image-monitor.yml](./modules-docker-base-image-monitor.yml) - Docker Base Image Monitor
**Zweck:** Erkennt neu gebaute Base Images hinter Floating Tags und stößt Release + Rebuild an  
**Features:** Digest-Speicherung erst nach erfolgreichem Release (`<VAR>_PENDING`), fehlgeschlagene Releases erneut dispatcht (bis zu 3 Läufe pro Digest, `max-release-attempts`), Coverage-Report, Dry Run  
**Docs:** [docs/workflows/modules-docker-base-image-monitor.md](../../docs/workflows/modules-docker-base-image-monitor.md) ([Operator recovery](../../docs/workflows/modules-docker-base-image-monitor.md#operator-recovery)) · **Beispiele:** [examples/docker-base-image-monitor/](../../github/workflows/examples/docker-base-image-monitor/README.md)

#### 🔧 [modules-auto-maintenance.yml](./modules-auto-maintenance.yml) - Auto Maintenance
**Zweck:** Base-Image-Digests und Dependency-Updates (npm, pip, .NET, Go) in einem Lauf, validiert mit Build/Test und bei Fehlern zurückgerollt  
**Features:** Eine JSON-Konfiguration, Commit + Release-Dispatch, Digests erst nach Push und Dispatch gespeichert, Dry Run  
**Bekannte Einschränkung:** npm-, pip- und .NET-Updates werden derzeit nicht committet ([Details](../../docs/workflows/modules-auto-maintenance.md#bekannte-einschraenkung-dependency-updates-werden-nicht-committet))  
**Docs:** [docs/workflows/modules-auto-maintenance.md](../../docs/workflows/modules-auto-maintenance.md) · **Beispiele:** [examples/auto-maintenance/](../../github/workflows/examples/auto-maintenance/README.md)

#### 🧪 [modules-backup-roundtrip-test.yml](./modules-backup-roundtrip-test.yml) - Backup Round-Trip Test
**Zweck:** Release-Gate: Startet den Compose-Stack mit den Images aus dem Commit, sichert echte Daten mit dem BackupHelper-Sidecar, löscht sie und stellt sie wieder her  
**Features:** Opt-in Upgrade vom vorigen Release, Off-Site-S3 mit "neuem Host", Matrix pro Compose-Variante (Traefik, Coolify); Self-Test: [backup-roundtrip-selftest.yml](./backup-roundtrip-selftest.yml)  
**Docs:** [docs/workflows/modules-backup-roundtrip-test.md](../../docs/workflows/modules-backup-roundtrip-test.md) · **Beispiele:** [examples/backup-roundtrip/](../../github/workflows/examples/backup-roundtrip/README.md)

### Fork-Automation

Für geforkte Repositories, die sich selbst warten (Mirror → Workspace → Build):

#### 🐳 [fork-docker-build.yml](./fork-docker-build.yml) - Fork Docker Build
**Zweck:** Schlanker Multi-Image-Builder für Forks (Build auf jedem `workspace`-Push)  
**Features:** Image-Matrix, Trivy-Scan mit Push-Block bei CRITICAL, Workspace-Tags, GHCR  
**Docs:** [docs/workflows/fork-docker-build.md](../../docs/workflows/fork-docker-build.md)

#### 🔄 [sync-upstream.yml](./sync-upstream.yml) - Sync Upstream
**Zweck:** Fork-Sync via nativer `merge-upstream`-API + optionaler `main → workspace`-Merge  
**Features:** "Sync fork"-Button als API, konfigurierbare Branches, Konflikt-Warnung + Issue, PAT-getriggerter Folge-Build  
**Docs:** [docs/workflows/sync-upstream.md](../../docs/workflows/sync-upstream.md)

## 🧩 Modulare Architektur

Die Workflows nutzen modulare Komponenten für bessere Wiederverwendbarkeit:

### 💡 Vorteile

**Reduzierte Komplexität:**
- ✅ **Wiederverwendbare Module** für externe Repositories
- ✅ **Bessere Wartbarkeit** durch Modularisierung
- ✅ **Parallel ausführbar** für bessere Performance

**Erweiterte Funktionalität:**
- ✅ **Flexiblere Konfiguration** durch modulare Parameter
- ✅ **Bessere Fehlerbehandlung** in einzelnen Modulen
- ✅ **Detailliertere Berichte** und Monitoring
- ✅ **Konsistente Interfaces** zwischen Modulen

## 🔗 Integration mit Modularen Komponenten

Diese Repository-Workflows demonstrieren die optimale Nutzung der modularen Komponenten:

```yaml
# Beispiel: Modulare Komponenten-Nutzung
jobs:
  security-scan:
    uses: ./.github/workflows/modules-security-scan.yml
    with:
      # Gitleaks ist opt-in (Default 'none' = nur Trivy). Dieses Repository schaltet
      # es ein; für Repositories ohne GitHub Secret Scanning gedacht, siehe
      # docs/security/native-secret-scanning.md#gitleaks-is-opt-in
      scan-engine: 'gitleaks'
    secrets: inherit   # GITLEAKS_LICENSE

  semantic-release:
    needs: security-scan
    uses: ./.github/workflows/modules-semantic-release.yml
    with:
      dry-run: false
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📊 Workflow-Matrix

### Repository Workflows
| Workflow | Trigger | Module/Actions | Primärer Zweck |
|----------|---------|----------------|----------------|
| **automatic-release.yml** | Push (main) | semantic-release | Automatische Releases |
| **documentation.yml** | Docs-Änderungen | readme-generate | Dokumentations-Management |
| **manual-release.yml** | Workflow Dispatch | 4 Module | Kontrollierte Releases |
| **pr-labeler.yml** | Pull Request | modules-pr-labeler | PR Labeling |
| **issue-automation.yml** | Issue/PR Events | modules-issue-automation | Issue Management |
| **backup-roundtrip-selftest.yml** | PR/Push (Modul + Fixture) | modules-backup-roundtrip-test | Self-Test des Backup-Round-Trip-Moduls |
| **workflow-validation.yml** | PR/Push (Workflows, Actions, Beispiele) | modules-validate-workflows | actionlint, Step-Tests, workflow-audit |

### Reusable Workflows
| Workflow | Type | Hauptfunktionen | Plattformen |
|----------|------|-----------------|-------------|
| **dotnet-build.yml** | workflow_call | Build, Test, Package, Docker | Linux, Windows, macOS |
| **dotnet-desktop-build.yml** | workflow_call | Desktop Build, Sign, MSIX | Windows |
| **dotnet-publish-library.yml** | workflow_call | Pack & Push NuGet (Libs + Tools) | Linux, Windows, macOS |
| **dotnet-publish-binaries.yml** | workflow_call | Self-contained Binaries pro RID + Release-Upload | Linux (x64+arm64), Windows (x64); macOS/win-arm64 opt-in |
| **nodejs-build.yml** | workflow_call | Build, Test, Publish, Docker | Linux, Windows, macOS |
| **docker-build.yml** | workflow_call | Build, Scan, SBOM, Sign, Push (GHCR/Docker Hub) | Linux (GitHub-hosted oder self-hosted) |
| **fork-docker-build.yml** | workflow_call | Multi-Image Build, Trivy-Scan, GHCR (Fork-CI) | Linux |
| **modules-auto-maintenance.yml** | workflow_call (Caller: `schedule`) | Base Images + Dependency-Updates mit Validierung und Rollback | Linux |
| **modules-backup-roundtrip-test.yml** | workflow_call (Caller: `pull_request`, `push`, `workflow_dispatch`) | Backup → Löschen → Restore → Prüfen eines Compose-Stacks als Release-Gate | Linux |
| **docker-maintenance-dependabot.yml** | workflow_call (Caller: `pull_request`) | Dependabot-PRs nach grüner PR-CI mergen | Linux |
| **modules-docker-base-image-monitor.yml** | workflow_call (Caller: `schedule`) | Digest-Überwachung, Release-Dispatch mit Bestätigung und Retries | Linux |
| **sync-upstream.yml** | workflow_call | Fork-Sync (merge-upstream API) + Workspace-Merge | Linux |

## 🚀 Verwendung für externe Repositories

Externe Repositories können diese Workflows als Vorlage verwenden:

1. **Kopiere die Workflow-Dateien** in dein Repository
2. **Ändere die Module-Referenzen** von `./` zu `bauer-group/automation-templates/`
3. **Passe die Parameter** an deine Projektanforderungen an
4. **Konfiguriere Repository-Secrets** falls erforderlich

**Beispiel-Anpassung:**
```yaml
# Von (intern):
uses: ./.github/workflows/modules-security-scan.yml

# Zu (extern):
uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
```

## 📚 Weitere Dokumentation

- **[Modulare Komponenten](./MODULES-README.MD)** - Detaillierte Modul-Dokumentation
- **[GitHub Actions](../actions/README.md)** - Verfügbare Action-Komponenten

---

*Diese Workflows demonstrieren die Transformation von monolithischen zu modularen, wiederverwendbaren CI/CD-Pipelines.* 🧩
