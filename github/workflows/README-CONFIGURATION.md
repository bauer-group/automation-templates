# README-Workflow Konfiguration

Diese Datei zeigt, wie der erweiterte README-Workflow konfiguriert werden kann.

## Minimale Konfiguration

```yaml
# .github/workflows/readme.yml
name: README Update

on:
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  readme:
    uses: bauer-group/automation-templates/github/workflows/readme.yml@main
    with:
      template-path: "docs/README.template.md"
      output-path: "README.md"
```

## Vollständige Konfiguration

```yaml
# .github/workflows/readme.yml
name: README Update

on:
  pull_request:
    branches: [ main ]
  push:
    branches: [ main ]
    paths: [ 'docs/README.template.md', 'package.json' ]
  workflow_dispatch:
    inputs:
      auto-commit:
        description: "Auto-commit changes"
        type: boolean
        default: true

permissions:
  contents: write

jobs:
  readme:
    uses: bauer-group/automation-templates/github/workflows/readme.yml@main
    with:
      # Pfade
      template-path: "docs/README.template.md"
      output-path: "README.md"
      
      # Python Konfiguration  
      python-version: "3.12"
      
      # Verhalten
      commit-message: "docs: auto-generate README [skip ci]"
      fail-on-pr: true
      auto-commit: ${{ inputs.auto-commit != false }}
      
      # Projekt-Informationen
      project-name: "Mein Awesome Projekt"
      project-description: "Eine ausführliche Beschreibung meines Projekts"
      company-name: "Meine Firma GmbH"
      contact-email: "support@example.com"
      documentation-url: "https://docs.example.com"
      support-url: "https://support.example.com"
```

## Verfügbare Umgebungsvariablen

Diese können als `with`-Parameter oder als Repository-/Organization-Secrets gesetzt werden:

- `PROJECT_NAME` - Projektname
- `PROJECT_DESCRIPTION` - Projektbeschreibung  
- `COMPANY_NAME` - Firmenname
- `CONTACT_EMAIL` - Kontakt E-Mail
- `DOCUMENTATION_URL` - Dokumentations-URL
- `SUPPORT_URL` - Support-URL

## Template-Beispiele

### Basis-Template

```markdown
# {{PROJECT_NAME}}

**Version:** {{VERSION}} ({{DATE}})  
**Repository:** [{{REPO_FULL_NAME}}]({{REPO_URL}})

{{PROJECT_DESCRIPTION}}

## Installation

\`\`\`bash
git clone {{REPO_URL}}
\`\`\`

## Support

{{#IF CONTACT_EMAIL}}
Kontakt: [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}})
{{/IF}}

---
*README generiert am {{DATETIME}}*
```

### Erweiterte Template mit Badges

```markdown
# {{COMPANY_NAME}} - {{PROJECT_NAME}}

{{BADGE_BUILD}} {{BADGE_RELEASE}} {{BADGE_SECURITY}}

**Status:** Version {{VERSION}} ({{DATE}})  
**Repository:** [{{REPO_FULL_NAME}}]({{REPO_URL}})  

{{PROJECT_DESCRIPTION}}

{{#IF PACKAGE_LICENSE}}
**Lizenz:** {{PACKAGE_LICENSE}}
{{/IF}}

{{#IF PACKAGE_AUTHOR}}
**Autor:** {{PACKAGE_AUTHOR}}
{{/IF}}

## Verwendung

Siehe [Dokumentation]({{DOCUMENTATION_URL}}) für Details.

## Support

{{#IF CONTACT_EMAIL}}
- **E-Mail:** [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}})
{{/IF}}
{{#IF SUPPORT_URL}}
- **Support Portal:** [{{SUPPORT_URL}}]({{SUPPORT_URL}})
{{/IF}}
- **Issues:** [GitHub Issues]({{REPO_URL}}/issues)

---
*Auto-generiert am {{DATETIME}} | Branch: {{CURRENT_BRANCH}}*
```

## Bedingte Blöcke

Das Template-System unterstützt bedingte Blöcke:

```markdown
{{#IF VARIABLE_NAME}}
Dieser Inhalt wird nur angezeigt, wenn VARIABLE_NAME existiert und nicht leer ist.
{{/IF}}
```

Beispiele:

```markdown
{{#IF CONTACT_EMAIL}}
**Kontakt:** [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}})
{{/IF}}

{{#IF DOCUMENTATION_URL}}
## Dokumentation
Siehe [Dokumentation]({{DOCUMENTATION_URL}}) für weitere Informationen.
{{/IF}}

{{#IF PACKAGE_LICENSE}}
**Lizenz:** {{PACKAGE_LICENSE}}
{{/IF}}
```

## Automatische Erkennung

Der Workflow erkennt automatisch:

- **Git-Informationen:** Repository-URL, Branch, Owner, etc.
- **Package-Informationen:** Aus `package.json`, `setup.py`, etc.
- **Version:** Aus Git Tags oder Umgebungsvariablen
- **Workflow-Badges:** Basierend auf Repository-Informationen

## Fehlerbehebung

### Template nicht gefunden
```
Error: Template file docs/README.template.md not found
```
→ Stellen Sie sicher, dass der `template-path` korrekt ist

### Python-Fehler
```
ModuleNotFoundError: No module named 'xyz'
```
→ Der Workflow hat eine Fallback-Implementierung für fehlende Abhängigkeiten

### Git-Informationen fehlen
```
Warning: Could not get git info
```
→ Repository-Informationen werden mit Fallback-Werten ersetzt

### README nicht aktualisiert
```
README ist nicht aktuell
```
→ Führen Sie den Workflow manuell aus oder aktualisieren Sie das Template
