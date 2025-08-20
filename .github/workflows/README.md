# Repository Workflows

Diese Workflows sind speziell für das `automation-templates` Repository entwickelt und demonstrieren die Verwendung der modularen Workflow-Komponenten.

## 📁 Workflow-Dateien

### 🔄 [automatic-release.yml](./automatic-release.yml) - Automatische Releases
**Zweck:** Automatische Release-Erstellung bei Push auf Main Branch  
**Module verwendet:** semantic-release

**Features:**
- Automatische Versionierung basierend auf Conventional Commits
- CHANGELOG.MD Generierung
- GitHub Release Erstellung
- Semantic Versioning

### 📄 [documentation.yml](./documentation.yml) - Dokumentations-Management
**Zweck:** README-Generierung und Dokumentationsvalidierung  
**Module verwendet:** readme-generate action (direkt)

**Features:**
- Template-basierte README-Generierung
- Automatische Updates bei Template-Änderungen
- Git-basierte Änderungserkennung

### 📦 [manual-release.yml](./manual-release.yml) - Manuelle Release-Erstellung
**Zweck:** Kontrollierte, manuelle Release-Erstellung  
**Module verwendet:** security-scan, license-compliance, artifact-generation, generate-changelog

**Features:**
- Flexible Versionierung (major, minor, patch, custom)
- Optionale Security- und Compliance-Checks
- Konfigurierbare Artefakt-Generierung
- Changelog-Generierung mit generate-changelog Action

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
      scan-engine: 'both'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  semantic-release:
    needs: security-scan
    uses: ./.github/workflows/modules-semantic-release.yml
    with:
      dry-run: false
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📊 Workflow-Matrix

| Workflow | Trigger | Module/Actions | Primärer Zweck |
|----------|---------|----------------|----------------|
| **automatic-release.yml** | Push (main) | semantic-release | Automatische Releases |
| **documentation.yml** | Docs-Änderungen | readme-generate | Dokumentations-Management |
| **manual-release.yml** | Workflow Dispatch | 4 Module | Kontrollierte Releases |

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
- **[GitHub Actions](../actions/README.MD)** - Verfügbare Action-Komponenten

---

*Diese Workflows demonstrieren die Transformation von monolithischen zu modularen, wiederverwendbaren CI/CD-Pipelines.* 🧩
