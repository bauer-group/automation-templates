# 📚 Workflow-Beispiele

Diese Beispiele zeigen verschiedene Anwendungsszenarien für die Automation-Templates.

## 🔄 Vollständige Pipeline (full-pipeline-example.yml)

Das umfassendste Beispiel mit allen Features:

- **📄 README-Management**: Automatische Dokumentation mit Validierung
- **🚀 Release-Management**: Intelligente Releases mit Conventional Commits  
- **🧪 Test-Integration**: Automatisierte Tests vor Deployments
- **� Monitoring**: Umfassende Summaries und Metriken
- **⏰ Scheduling**: Regelmäßige Updates via Cron
- **🎯 Deployment**: Umgebungsbasierte Deployments

### Hauptfeatures

```yaml
# Täglich um 02:00 UTC für README-Updates
schedule:
  - cron: '0 2 * * *'

# Bedingte Job-Ausführung
readme-management:
  if: |
    github.event_name == 'schedule' ||
    contains(github.event.head_commit.modified, 'docs/README.template.MD')

# Professionelle Summaries
notification:
  run: |
    echo "### 🔄 Pipeline Execution Summary" >> $GITHUB_STEP_SUMMARY
```

## 📄 README-Beispiel (readme-example.yml)

Zeigt spezifische README-Funktionen:

- **Template-Validierung**: Syntax- und Placeholder-Checks
- **Flexible Konfiguration**: Anpassbare Parameter
- **Auto-Commit**: Automatische Commits bei Änderungen
- **PR-Integration**: Previews in Pull Requests

```yaml
uses: bauer-group/automation-templates/github/workflows/readme.yml@main
with:
  template-path: "docs/README.template.MD"
  project-name: "Mein Projekt"
  validate-output: true
  auto-commit: true
```

## 🚀 Release-Beispiel (release-example.yml)

Demonstriert Release-Management:

- **Conventional Commits**: Automatische Versionierung
- **Validierung**: Eligibility-Checks vor Release
- **Post-Processing**: Aktionen nach Release-Erstellung
- **Metriken**: Detaillierte Release-Statistiken

```yaml
release-management:
  uses: bauer-group/automation-templates/.github/workflows/release.yml@main
  with:
    release-type: "simple"
    package-name: "mein-projekt"
```

## 📋 Verwendung der Beispiele

### 1. Kopieren und Anpassen

```bash
# Beispiel in Ihr Repository kopieren
cp github/workflows/examples/full-pipeline-example.yml .github/workflows/
```

### 2. Parameter anpassen

```yaml
# Ihre spezifischen Werte einsetzen
project-name: "Ihr Projektname"
company-name: "Ihre Firma"
contact-email: "ihre@email.com"
```

### 3. Permissions konfigurieren

```yaml
permissions:
  contents: write      # Für Commits und Releases
  pull-requests: write # Für PR-Comments
  issues: write        # Für Issue-Updates
```

## 🎯 Best Practices

### Job-Dependencies

```yaml
# Korrekte Reihenfolge sicherstellen
release-management:
  needs: readme-management

deployment:
  needs: [release-management, test-suite]
```

### Bedingte Ausführung

```yaml
# Nur bei relevanten Änderungen ausführen
if: |
  contains(github.event.head_commit.modified, 'docs/') ||
  github.event_name == 'workflow_dispatch'
```

### Environment-Protection

```yaml
# Produktions-Deployments schützen
deployment:
  environment: production
  needs: [release-management, test-suite]
```

## 🔧 Erweiterte Konfiguration

### Custom Actions verwenden

```yaml
# Direkte Action-Nutzung für maximale Kontrolle
- uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    template-path: "custom/template.MD"
    fallback-generator: true
```

### Multi-Environment Setup

```yaml
# Verschiedene Umgebungen
deploy-staging:
  environment: staging
  if: github.ref == 'refs/heads/develop'

deploy-production:
  environment: production
  if: needs.release.outputs.release_created == 'true'
```

## 📊 Monitoring und Debugging

### Workflow-Summaries

Alle Beispiele generieren detaillierte Summaries im Actions-Tab:

- 📋 Job-Status-Übersicht
- 📊 Performance-Metriken
- 🔍 Validation-Ergebnisse
- 🎯 Release-Details

### Debugging-Tipps

```yaml
# Debug-Modus aktivieren
- name: Debug Information
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "Modified files: ${{ toJson(github.event.head_commit.modified) }}"
```

## 🚀 Nächste Schritte

1. **Beispiel auswählen**: Passend zu Ihren Anforderungen
2. **Parameter anpassen**: Projektspezifische Werte einsetzen
3. **Testen**: Mit `workflow_dispatch` manuell auslösen
4. **Monitoring**: Summaries und Logs überwachen
5. **Optimieren**: Basierend auf Erfahrungen anpassen

Die Beispiele sind production-ready und können direkt verwendet werden! 🎉
