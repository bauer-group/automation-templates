# Repository Workflows

Diese Workflows sind speziell für das `automation-templates` Repository entwickelt und demonstrieren die Verwendung der modularen Workflow-Komponenten.

## 📁 Workflow-Dateien

### 🔄 [ci-cd.yml](./ci-cd.yml) - Haupt CI/CD Pipeline
**Zweck:** Hauptpipeline für Pull Requests und Main Branch  
**Zeilen:** 147 (vs. 870 im ursprünglichen automatic-release.yml)  
**Module verwendet:** pr-validation, security-scan, license-compliance, release-management, artifact-generation

**Features:**
- PR-Validierung mit Quality Gates
- Umfassende Security-Analysen für Main Branch
- Automatische Release-Erstellung
- Modulare Artefakt-Generierung

### 📄 [documentation.yml](./documentation.yml) - Dokumentations-Management
**Zweck:** README-Generierung und Dokumentationsvalidierung  
**Zeilen:** 141 (vs. 309 im ursprünglichen readme.yml)  
**Module verwendet:** readme-generate action (direkt)

**Features:**
- Template-basierte README-Generierung
- Dokumentations-Struktur-Validierung
- Link-Checking für interne Verweise
- Automatische Updates bei Template-Änderungen

### 📦 [manual-release.yml](./manual-release.yml) - Manuelle Release-Erstellung
**Zweck:** Kontrollierte, manuelle Release-Erstellung  
**Zeilen:** 346 (vs. 313 im ursprünglichen manual-release.yml)  
**Module verwendet:** security-scan, license-compliance, artifact-generation

**Features:**
- Flexible Versionierung (major, minor, patch, custom)
- Optionale Security- und Compliance-Checks
- Konfigurierbare Artefakt-Generierung
- Detaillierte Release-Dokumentation

## 🧩 Modulare Architektur

### Vorher (Legacy-Workflows)
- `automatic-release.yml`: **870 Zeilen** - Monolithisch
- `manual-release.yml`: **313 Zeilen** - Eigenständig
- `readme.yml`: **309 Zeilen** - Isoliert

**Gesamt:** 1.492 Zeilen in 3 separaten, nicht wiederverwendbaren Workflows

### Nachher (Modulare Workflows)
- `ci-cd.yml`: **147 Zeilen** - Komponiert aus 5 Modulen
- `documentation.yml`: **141 Zeilen** - Nutzt wiederverwendbare Komponenten
- `manual-release.yml`: **346 Zeilen** - Komponiert aus 3 Modulen

**Gesamt:** 634 Zeilen in 3 komponierten Workflows + 5 wiederverwendbare Module

### 💡 Verbesserungen

**Reduzierte Komplexität:**
- ✅ **57% weniger Code** in Repository-Workflows (634 vs. 1.492 Zeilen)
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
# Beispiel: CI/CD Pipeline mit modularen Komponenten
jobs:
  security-scan:
    uses: ./.github/workflows/modules-security-scan.yml
    with:
      scan-engine: 'both'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  release-management:
    needs: security-scan
    uses: ./.github/workflows/modules-release-management.yml
    with:
      release-type: 'simple'
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📊 Workflow-Matrix

| Workflow | Trigger | Module-Anzahl | Primärer Zweck |
|----------|---------|---------------|----------------|
| **ci-cd.yml** | Push (main), PR | 5 Module | Kontinuierliche Integration |
| **documentation.yml** | Docs-Änderungen | 1 Workflow | Dokumentations-Management |
| **manual-release.yml** | Workflow Dispatch | 3 Module | Kontrollierte Releases |

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

- **[Modulare Komponenten](./modules/README.md)** - Detaillierte Modul-Dokumentation
- **[Workflow-Beispiele](./examples/README.MD)** - Verwendungsbeispiele für externe Repositories
- **[GitHub Actions](../actions/README.MD)** - Verfügbare Action-Komponenten

---

*Diese Workflows demonstrieren die Transformation von monolithischen zu modularen, wiederverwendbaren CI/CD-Pipelines.* 🧩
