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

#### 🤖 [ai-issue-summary.yml](./ai-issue-summary.yml) - AI Issue Zusammenfassungen
**Zweck:** AI-gestützte Issue-Zusammenfassungen  
**Module verwendet:** modules-ai-issue-summary

#### 🏷️ [pr-labeler.yml](./pr-labeler.yml) - PR Labeling
**Zweck:** Automatisches PR Labeling  
**Module verwendet:** modules-pr-labeler

#### 🔧 [issue-automation.yml](./issue-automation.yml) - Issue Automatisierung
**Zweck:** Issue Management Automatisierung  
**Module verwendet:** modules-issue-automation

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

### Repository Workflows
| Workflow | Trigger | Module/Actions | Primärer Zweck |
|----------|---------|----------------|----------------|
| **automatic-release.yml** | Push (main) | semantic-release | Automatische Releases |
| **documentation.yml** | Docs-Änderungen | readme-generate | Dokumentations-Management |
| **manual-release.yml** | Workflow Dispatch | 4 Module | Kontrollierte Releases |
| **ai-issue-summary.yml** | Issue Events | modules-ai-issue-summary | AI Zusammenfassungen |
| **pr-labeler.yml** | Pull Request | modules-pr-labeler | PR Labeling |
| **issue-automation.yml** | Issue/PR Events | modules-issue-automation | Issue Management |

### Reusable Workflows
| Workflow | Type | Hauptfunktionen | Plattformen |
|----------|------|-----------------|-------------|
| **dotnet-build.yml** | workflow_call | Build, Test, Package, Docker | Linux, Windows, macOS |
| **dotnet-desktop-build.yml** | workflow_call | Desktop Build, Sign, MSIX | Windows |
| **dotnet-publish-library.yml** | workflow_call | Pack & Push NuGet (Libs + Tools) | Linux, Windows, macOS |
| **dotnet-publish-binaries.yml** | workflow_call | Self-contained Binaries pro RID + Release-Upload | Linux (x64+arm64), Windows (x64); macOS/win-arm64 opt-in |
| **nodejs-build.yml** | workflow_call | Build, Test, Publish, Docker | Linux, Windows, macOS |

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
