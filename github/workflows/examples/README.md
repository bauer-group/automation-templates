# 📄 Beispiel-Workflows für externe Repositories

Diese Workflows können von anderen Repositories als zentrale Vorlagen verwendet werden.

## 📄 README Generator Workflow

### Verwendung in externen Repositories

Erstelle eine Datei `.github/workflows/documentation.yml` in deinem Repository:

```yaml
name: 📄 Documentation Management

on:
  push:
    branches: [main]
    paths: ['docs/**', '*.md', '*.MD']
  workflow_dispatch:

jobs:
  generate-readme:
    name: Generate README
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bauer-group/automation-templates/.github/actions/readme-generate@main
        with:
          template-path: 'docs/README.template.MD'
          output-path: 'README.MD'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Template-Datei erstellen

Erstelle eine Datei `docs/README.template.MD` mit Platzhaltern:

```markdown
# {{PROJECT_NAME}}

**{{PROJECT_DESCRIPTION}}**

- Version: {{VERSION}}
- Repository: {{REPOSITORY_URL}}
- Company: {{COMPANY_NAME}}
- Contact: {{CONTACT_EMAIL}}

Generated on: {{GENERATION_DATE}}
```

### Verfügbare Platzhalter

| Platzhalter | Beschreibung | Automatisch erkannt |
|-------------|-------------|-------------------|
| `{{PROJECT_NAME}}` | Projektname | ✅ Aus Repository-Name |
| `{{PROJECT_DESCRIPTION}}` | Projektbeschreibung | ✅ Aus Repository-Description |
| `{{VERSION}}` | Version | ✅ Aus Git-Tags |
| `{{COMPANY_NAME}}` | Firmenname | ❌ Parameter erforderlich |
| `{{CONTACT_EMAIL}}` | Kontakt-Email | ❌ Parameter erforderlich |
| `{{REPOSITORY_URL}}` | Repository-URL | ✅ Automatisch |
| `{{GENERATION_DATE}}` | Generierungsdatum | ✅ Automatisch |
| `{{BRANCH}}` | Aktueller Branch | ✅ Automatisch |

## Konfigurationsoptionen

### Workflow-Inputs

- `template-path`: Pfad zur Template-Datei (Standard: `docs/README.template.MD`)
- `output-path`: Ausgabedatei (Standard: `README.MD`)
- `project-name`: Projektname (automatisch erkannt wenn leer)
- `company-name`: Firmenname (erforderlich für saubere Ausgabe)
- `project-description`: Projektbeschreibung (automatisch erkannt)
- `auto-commit`: Automatisches Committen der Änderungen (Standard: `true`)
- `force-update`: Update erzwingen auch ohne Änderungen (Standard: `false`)

### Workflow-Outputs

- `readme_updated`: Ob README aktualisiert wurde
- `changes_detected`: Ob Änderungen erkannt wurden
- `validation_passed`: Ob Validierung erfolgreich war
- `file_size`: Größe der generierten Datei
- `unresolved_placeholders`: Anzahl unaufgelöster Platzhalter

### Beispiel für verschiedene Trigger

```yaml
name: 📄 README Management

on:
  # Bei Änderungen am Template
  push:
    branches: [main]
    paths: ['docs/README.template.MD', 'docs/**']
  
  # Bei neuen Releases
  release:
    types: [published]
  
  # Manueller Trigger
  workflow_dispatch:
    inputs:
      force-update:
        description: 'README auch ohne Änderungen aktualisieren'
        type: boolean
        default: false

jobs:
  update-readme:
    uses: bauer-group/automation-templates/.github/workflows/readme.yml@main
    with:
      force-update: ${{ inputs.force-update || false }}
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 🧩 Modulare Workflow-Beispiele

Die folgenden Beispiele zeigen, wie die **modularen Workflow-Komponenten** für verschiedene Projekttypen und Anwendungsfälle verwendet werden können.

### 📋 Verfügbare Beispiele

| Beispiel | Beschreibung | Zielgruppe |
|----------|-------------|-----------|
| **[documentation.yml](../../.github/workflows/documentation.yml)** | Documentation Management | Alle Projekttypen |
| **[simple-release.yml](./simple-release.yml)** | Einfacher Release-Workflow | Kleine Projekte, Prototypen |
| **[comprehensive-ci-cd.yml](./comprehensive-ci-cd.yml)** | Vollständige CI/CD-Pipeline | Enterprise-Projekte |
| **[security-focused.yml](./security-focused.yml)** | Security-zentrierte Pipeline | Sicherheitskritische Anwendungen |
| **[nodejs-project.yml](./nodejs-project.yml)** | Node.js-spezifischer Workflow | JavaScript/TypeScript-Projekte |

### 🎯 Modulare Architektur

Anstatt monolithischer Workflows (wie der ursprüngliche 870-Zeilen automatic-release.yml) verwenden wir **komponierbare Module**:

```
🧩 Modulare Komponenten (.github/workflows/):
├── 🛡️ modules-security-scan.yml      → Sicherheitsanalyse
├── 📋 modules-license-compliance.yml → Lizenz-Compliance
├── 🚀 modules-semantic-release.yml  → Release-Automatisierung
├── 🔨 modules-artifact-generation.yml → Artefakt-Erstellung
└── 🔍 modules-pr-validation.yml      → Pull Request-Validierung
```

### 🚀 Quick Start

**1. Einfacher Release-Workflow:**
```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    with:
      release-type: 'simple'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**2. Mit Security-Scan:**
```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
  
  release:
    needs: security
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
```

**3. PR-Validierung:**
```yaml
jobs:
  pr-check:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/modules-pr-validation.yml@main
    with:
      enable-security-scan: true
      enable-license-check: true
```

### 💡 Vorteile der modularen Architektur

- ✅ **Wiederverwendbarkeit:** Ein Modul, viele Projekte
- ✅ **Flexibilität:** Nur die benötigten Komponenten verwenden
- ✅ **Wartbarkeit:** Einzelne Module unabhängig aktualisieren
- ✅ **Testbarkeit:** Jedes Modul isoliert testbar
- ✅ **Performance:** Parallel ausführbare Module

### 🔗 Weiterführende Dokumentation

- **[Modulare Komponenten](..//modules-README.MD)** - Detaillierte Dokumentation der einzelnen Module
- **[Migration Guide](../modules-README.MD#migration-von-monolithen)** - Von monolithischen zu modularen Workflows
- **[Best Practices](../modules-README.MD#best-practices)** - Empfehlungen für die Workflow-Komposition
- **[Actions Documentation](../../.github/actions/README.MD)** - Übersicht über verfügbare GitHub Actions
- **[Repository Workflows](../../.github/workflows/README.md)** - Interne Workflow-Dokumentation

---

## 🔧 Setup für Semantic Release

### 1. Konfiguration erstellen

Erstelle `.github/config/.releaserc.json`:

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", {
      "changelogFile": "CHANGELOG.MD"
    }],
    "@semantic-release/github",
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.MD"]
    }]
  ]
}
```

### 2. Workflow einrichten

```yaml
name: 🚀 Automatic Release

on:
  push:
    branches: [main]

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-semantic-release.yml@main
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📚 Weitere Ressourcen

- **[Semantic Release](https://semantic-release.gitbook.io/)**: Offizielle Dokumentation
- **[Conventional Commits](https://www.conventionalcommits.org/)**: Commit-Format Spezifikation
- **[SPDX License List](https://spdx.org/licenses/)**: Standardisierte Lizenz-Identifier

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)

**Ready to use, built for scale!** 🚀
