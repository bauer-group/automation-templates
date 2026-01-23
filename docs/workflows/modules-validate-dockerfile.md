# 🐳 Dockerfile Validator Workflow

Professionelle Dockerfile-Validierung mit [Hadolint](https://github.com/hadolint/hadolint) - dem führenden Dockerfile-Linter, der Best Practices und Sicherheitsrichtlinien überprüft.

## Übersicht

Der `modules-validate-dockerfile` Workflow bietet:

- **Umfassende Linting-Analyse** - Überprüft Dockerfiles auf Best Practices
- **Sicherheits-Checks** - Erkennt potenzielle Sicherheitsprobleme
- **Flexible Konfiguration** - Anpassbare Regeln und Schwellenwerte
- **Multi-Dockerfile-Support** - Scannt mehrere Dockerfiles parallel
- **Detaillierte Reports** - GitHub Summary mit allen Findings

## Schnellstart

### Minimale Konfiguration

```yaml
name: 🐳 Validate Dockerfiles

on: [push, pull_request]

jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
```

### Empfohlene Konfiguration

```yaml
name: 🐳 Dockerfile Validation

on:
  push:
    paths:
      - '**/Dockerfile*'
      - '**/*.Dockerfile'
  pull_request:
    paths:
      - '**/Dockerfile*'
      - '**/*.Dockerfile'

jobs:
  hadolint:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      failure-threshold: 'warning'
      trusted-registries: '["docker.io", "ghcr.io"]'
      ignore-rules: '["DL3008"]'
```

## Inputs

| Input | Typ | Default | Beschreibung |
|-------|-----|---------|--------------|
| `scan-directory` | string | `.` | Verzeichnis zum Scannen |
| `scan-paths` | string (JSON) | `''` | Spezifische Pfade `["docker/", "services/"]` |
| `dockerfile-patterns` | string (JSON) | `["Dockerfile", "Dockerfile.*", "*.Dockerfile"]` | Dateinamenmuster |
| `recursive` | boolean | `true` | Rekursive Suche |
| `failure-threshold` | string | `warning` | Schwellenwert: `error`, `warning`, `info`, `style`, `ignore` |
| `ignore-rules` | string (JSON) | `''` | Zu ignorierende Regeln `["DL3008", "DL3013"]` |
| `trusted-registries` | string (JSON) | `''` | Vertrauenswürdige Registries `["docker.io", "ghcr.io"]` |
| `config-file` | string | `''` | Pfad zur `.hadolint.yaml` |
| `format` | string | `tty` | Ausgabeformat |
| `fail-on-findings` | boolean | `true` | Bei Findings fehlschlagen |
| `override-error` | string (JSON) | `''` | Regeln als Error behandeln |
| `override-warning` | string (JSON) | `''` | Regeln als Warning behandeln |
| `override-info` | string (JSON) | `''` | Regeln als Info behandeln |
| `override-style` | string (JSON) | `''` | Regeln als Style behandeln |
| `runs-on` | string | `ubuntu-latest` | Runner-Konfiguration |

## Outputs

| Output | Beschreibung |
|--------|--------------|
| `passed` | `true` wenn alle Dockerfiles die Validierung bestanden |
| `files-checked` | Anzahl der geprüften Dockerfiles |
| `issues-found` | Gesamtanzahl der gefundenen Issues |
| `error-count` | Anzahl der Errors |
| `warning-count` | Anzahl der Warnings |
| `info-count` | Anzahl der Info-Meldungen |
| `style-count` | Anzahl der Style-Issues |

## Failure Threshold

Der `failure-threshold` bestimmt, ab welcher Severity der Workflow fehlschlägt:

| Threshold | Fehler bei | Use Case |
|-----------|------------|----------|
| `error` | Nur bei Errors | Produktions-Builds, nur kritische Issues |
| `warning` | Errors + Warnings | **Empfohlen** - Standardmäßige Qualitätsprüfung |
| `info` | Errors + Warnings + Info | Strenge Qualitätskontrolle |
| `style` | Alle Issues | Maximale Codequalität |
| `ignore` | Nie | Nur für Reports, kein Fail |

## Beispiele

### Multi-Service Docker-Projekt

```yaml
name: 🐳 Docker Lint

on:
  push:
    paths:
      - 'services/**/Dockerfile*'
      - 'docker/**'

jobs:
  lint:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      scan-paths: '["services/", "docker/"]'
      failure-threshold: 'warning'
      trusted-registries: '["ghcr.io", "docker.io", "mcr.microsoft.com"]'
```

### Mit Konfigurationsdatei

```yaml
name: 🐳 Hadolint Check

on: [push, pull_request]

jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      config-file: '.hadolint.yaml'
      fail-on-findings: true
```

**.hadolint.yaml:**

```yaml
ignored:
  - DL3008  # Pin versions in apt-get
  - DL3013  # Pin versions in pip

trustedRegistries:
  - docker.io
  - ghcr.io
  - mcr.microsoft.com

override:
  error:
    - DL3001  # WORKDIR statt cd
    - DL3002  # Nicht zu root wechseln
  warning:
    - DL3042  # Cache verwenden
```

### Strenge Production Pipeline

```yaml
name: 🐳 Production Dockerfile Validation

on:
  pull_request:
    branches: [main]
    paths:
      - '**/Dockerfile*'

jobs:
  strict-lint:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      failure-threshold: 'info'
      ignore-rules: '[]'  # Keine Ausnahmen
      override-error: '["DL3007", "DL3006"]'  # latest Tag als Error
      trusted-registries: '["ghcr.io/company"]'  # Nur Company Registry
```

### Self-Hosted Runner

```yaml
jobs:
  validate:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      runs-on: '["self-hosted", "linux", "docker"]'
      failure-threshold: 'warning'
```

### Nur Reporting (kein Fail)

```yaml
jobs:
  report:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      failure-threshold: 'ignore'
      fail-on-findings: false
```

## Wichtige Hadolint-Regeln

### Sicherheit

| Regel | Beschreibung | Empfehlung |
|-------|--------------|------------|
| DL3002 | Wechsel zu root USER | Vermeiden - Security Risk |
| DL3004 | sudo in RUN | Vermeiden - nicht notwendig in Docker |
| DL3006 | Image ohne Tag | Immer Version taggen |
| DL3007 | `latest` Tag verwendet | Spezifische Version nutzen |

### Best Practices

| Regel | Beschreibung | Empfehlung |
|-------|--------------|------------|
| DL3000 | Absoluter WORKDIR-Pfad | `/app` statt `app` |
| DL3001 | `cd` in RUN | WORKDIR verwenden |
| DL3003 | `cd` und Befehl trennen | WORKDIR + RUN |
| DL3025 | CMD Format | JSON-Array: `["cmd", "arg"]` |

### Paket-Management

| Regel | Beschreibung | Empfehlung |
|-------|--------------|------------|
| DL3008 | apt-get ohne Version | `package=version` pinnen |
| DL3013 | pip ohne Version | `package==version` pinnen |
| DL3018 | apk ohne Version | `package=version` pinnen |
| DL3028 | gem ohne Version | `gem install pkg -v version` |

## Workflow mit anderen Validatoren kombinieren

```yaml
name: 🔍 Full Docker Validation

on: [push, pull_request]

jobs:
  # Dockerfile Linting
  hadolint:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-dockerfile.yml@main
    with:
      failure-threshold: 'warning'

  # Docker Compose Validation
  compose:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-compose.yml@main
    with:
      compose-file: 'docker-compose.yml'

  # Shell Script Validation (für Entrypoints)
  shellcheck:
    uses: bauer-group/automation-templates/.github/workflows/modules-validate-shellscript.yml@main
    with:
      scan-paths: '["scripts/", "docker/"]'

  # Abschließender Check
  summary:
    needs: [hadolint, compose, shellcheck]
    runs-on: ubuntu-latest
    steps:
      - name: 📊 Validation Summary
        run: |
          echo "### Docker Validation Summary" >> $GITHUB_STEP_SUMMARY
          echo "- Hadolint: ${{ needs.hadolint.outputs.passed && '✅' || '❌' }}" >> $GITHUB_STEP_SUMMARY
          echo "- Compose: ${{ needs.compose.outputs.valid && '✅' || '❌' }}" >> $GITHUB_STEP_SUMMARY
          echo "- ShellCheck: ${{ needs.shellcheck.outputs.passed && '✅' || '❌' }}" >> $GITHUB_STEP_SUMMARY
```

## Empfohlene .hadolint.yaml

```yaml
# .hadolint.yaml - Empfohlene Konfiguration
---
# Regeln ignorieren (mit Begründung)
ignored:
  # Version-Pinning oft nicht praktikabel für Base-Images
  # - DL3008

# Vertrauenswürdige Registries
trustedRegistries:
  - docker.io
  - ghcr.io
  - mcr.microsoft.com
  - gcr.io
  - quay.io

# Severity-Overrides
override:
  # Kritische Sicherheitsregeln als Error
  error:
    - DL3002  # Nicht zu root wechseln
    - DL3004  # Kein sudo verwenden

  # Wichtige Best Practices als Warning
  warning:
    - DL3007  # latest Tag vermeiden
    - DL3025  # JSON CMD Format

# Labels die in Dockerfiles sein sollten (optional)
label-schema:
  author: text
  version: semver
```

## Ressourcen

- [Hadolint GitHub](https://github.com/hadolint/hadolint)
- [Hadolint Rules Reference](https://github.com/hadolint/hadolint#rules)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Security Best Practices](https://snyk.io/blog/10-docker-image-security-best-practices/)
