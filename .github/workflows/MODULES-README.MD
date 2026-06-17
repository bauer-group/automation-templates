# 🧩 Modulare Workflow-Komponenten

Diese Sammlung von wiederverwendbaren Workflows ermöglicht es, CI/CD-Pipelines durch Komposition kleinerer, spezialisierter Module aufzubauen.

## 🎯 Philosophie

**Modular statt Monolithisch:** Anstatt eines großen 870-Zeilen Workflows bieten wir spezialisierte, komponierbare Module, die flexibel kombiniert werden können.

## 📦 Verfügbare Module

### 🛡️ [Security Scan](./modules-security-scan.yml)
**Zweck:** Secrets-Erkennung mit Gitleaks und GitGuardian + Trivy Vulnerability Scan

```yaml
uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
with:
  scan-engine: 'both'
  scan-type: 'all'
  fail-on-findings: true
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }}
```

**Ausgaben:**
- `secrets-found`: Ob Secrets gefunden wurden
- `vulnerabilities-found`: Ob Schwachstellen entdeckt wurden (via Trivy)
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
  enable-license-check: true
  enable-commit-lint: true
  fail-on-security-issues: true
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

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
      scan-engine: 'both'

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
