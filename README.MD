<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-17 00:19:35 UTC -->

# {{COMPANY_NAME}} – Automation Templates

**Status:** Version 0.2.0 (2025-08-17)  
**Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)  
**Branch:** {{CURRENT_BRANCH}}

{{PROJECT_DESCRIPTION}}

[![Create Release](https://github.com/bauer-group/automation-templates/actions/workflows/release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release.yml)
[![README Update](https://github.com/bauer-group/automation-templates/actions/workflows/readme.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/readme.yml)

## 🎯 Features

- **🔧 Composite Actions**: Wiederverwendbare GitHub Actions für zentrale Logik
- **🔄 Wiederverwendbare Workflows**: Komplexe Workflow-Orchestrierung
- **📄 README-Generator**: Automatische Generierung aus Templates mit 40+ Platzhaltern  
- **🚀 Release-Management**: Automatische Releases mit Release-Please und Conventional Commits
- **📋 Kopierbare Beispiele**: Sofort einsetzbare Workflow-Templates

## 🏗️ Architektur

```text
├── .github/
│   ├── actions/                    # 🔧 Composite Actions (Single Source of Truth)
│   │   ├── readme-generate/       # 📄 README-Generator
│   │   │   └── action.yml
│   │   └── release-please/        # 🚀 Release-Management  
│   │       └── action.yml
│   │
│   └── workflows/                  # 🎯 Lokale Workflows (für dieses Repository)
│       ├── readme.yml             # → nutzt lokale Action
│       └── release.yml            # → nutzt lokale Action
│
├── github/workflows/              # 📚 Für externe Repositories
│   ├── readme.yml                 # 🔄 Wiederverwendbarer README-Workflow
│   ├── release-please.yml         # 🔄 Wiederverwendbarer Release-Workflow
│   ├── examples/                  # 📋 Kopierbare Beispiele
│   │   ├── readme-example.yml
│   │   ├── release-example.yml
│   │   └── full-pipeline-example.yml
│   └── README.md                  # 📖 Detaillierte Dokumentation
│
├── docs/                          # 📄 Templates und Dokumentation
│   └── README.template.md         # README-Template mit Platzhaltern
│
└── scripts/                       # 🛠️ Automatisierungs-Skripte
    └── generate_readme.py         # Erweiterter README-Generator
```

## 🚀 Schnellstart

### 🔧 Composite Actions (Empfohlen)

Für maximale Flexibilität und Performance:

```yaml
# README-Generierung hinzufügen
- name: Generate README  
  uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    project-name: "Mein Projekt"
    company-name: "Meine Firma"
    project-description: "Projektbeschreibung"

# Release-Management hinzufügen
- name: Release Please
  uses: bauer-group/automation-templates/.github/actions/release-please@main  
  with:
    release-type: "simple"
    token: ${{ secrets.GITHUB_TOKEN }}
```

### 🔄 Wiederverwendbare Workflows

Für komplette Workflow-Orchestrierung:

```yaml
# .github/workflows/readme.yml
jobs:
  readme:
    uses: bauer-group/automation-templates/github/workflows/readme.yml@main
    with:
      project-name: "Mein Projekt"
      company-name: "Meine Firma"

# .github/workflows/release.yml  
jobs:
  release:
    uses: bauer-group/automation-templates/github/workflows/release-please.yml@main
    with:
      release-type: "simple"
```

### 📋 Kopierbare Beispiele

1. **Beispiel-Workflow kopieren**: `github/workflows/examples/`
2. **Parameter anpassen**: Projektspezifische Werte eintragen
3. **Committen**: Workflow wird automatisch aktiviert

## 📄 README-Generator

### Unterstützte Platzhalter:

#### Basis-Informationen:
- `{{VERSION}}` - Git Tag oder 0.1.0
- `{{DATE}}` - 2025-08-17  
- `{{DATETIME}}` - 2025-08-17 00:19:35 UTC
- `{{YEAR}}` - 2025

#### Repository-Informationen:
- `{{REPOSITORY}}` - bauer-group/automation-templates
- `{{REPOSITORY_URL}}` - https://github.com/bauer-group/automation-templates
- `{{REPOSITORY_OWNER}}` - bauer-group
- `{{REPOSITORY_NAME}}` - automation-templates
- `{{CURRENT_BRANCH}}` - {{CURRENT_BRANCH}}

#### Projekt-Informationen:
- `{{PROJECT_NAME}}` - Projektname (konfigurierbar)
- `{{PROJECT_DESCRIPTION}}` - Projektbeschreibung (konfigurierbar)
- `{{COMPANY_NAME}}` - Firmenname (konfigurierbar)
- `{{CONTACT_EMAIL}}` - Kontakt E-Mail (konfigurierbar)

### Template erstellen:

```markdown
<!-- docs/README.template.md -->
# {{PROJECT_NAME}}

**{{PROJECT_DESCRIPTION}}**

Version: {{VERSION}} | Stand: {{DATE}}  
Repository: [{{REPOSITORY}}]({{REPOSITORY_URL}})
Firma: {{COMPANY_NAME}}
```

## 🚀 Release-Management

### Workflow-Prozess:

1. **Conventional Commits** verwenden:
   - `feat:` → Minor Version (0.1.0 → 0.2.0)
   - `fix:` → Patch Version (0.1.0 → 0.1.1)  
   - `feat!:` → Major Version (0.1.0 → 1.0.0)

2. **Push nach main** → Release-Please erstellt Release-PR

3. **Release-PR mergen** → GitHub Release wird erstellt

### Beispiel Commits:

```bash
git commit -m "feat: neue README-Template-Engine"
git commit -m "fix: korrigiere Platzhalter-Ersetzung"  
git commit -m "feat!: neue API für Composite Actions"
git commit -m "docs: aktualisiere Dokumentation"
```

## 🛠️ Lokale Entwicklung

```bash
# Repository klonen
git clone https://github.com/bauer-group/automation-templates.git
cd automation-templates

# README lokal generieren
python scripts/generate_readme.py

# Mit Custom-Variablen
PROJECT_NAME="Test" COMPANY_NAME="Test Corp" python scripts/generate_readme.py
```

## 💡 Warum Composite Actions?

### ✅ Vorteile:
- **Single Source of Truth**: Logik nur einmal definiert
- **Automatische Updates**: Alle Nutzer erhalten Updates ohne Änderungen
- **Bessere Performance**: Weniger Netzwerk-Overhead
- **Flexibilität**: Einfache Integration in bestehende Workflows

### 📊 Vergleich:

| Feature | Composite Actions | Wiederverwendbare Workflows |
|---------|-------------------|------------------------------|
| Performance | ⚡ Schnell | 🐌 Langsamer |
| Updates | 🔄 Automatisch | 📝 Manuell |
| Flexibilität | 🎯 Hoch | 📋 Medium |
| Komplexität | 🎨 Einfach | 🔧 Komplex |

## 📞 Support

- **Dokumentation**: [github/workflows/README.md](github/workflows/README.md)
- **Beispiele**: [github/workflows/examples/](github/workflows/examples/)
- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Wiki**: [Detaillierte Anleitungen](https://github.com/bauer-group/automation-templates/wiki)

## 🔄 Migration Guide

### Von v0.1.x auf v0.2.x:

**Bestehende Workflows funktionieren weiterhin!** Für neue Projekte empfehlen wir Composite Actions:

```yaml
# Alt (funktioniert weiterhin):
uses: bauer-group/automation-templates/github/workflows/readme.yml@main

# Neu (empfohlen):  
uses: bauer-group/automation-templates/.github/actions/readme-generate@main
```

---

*Dieses README wurde automatisch generiert am 2025-08-17 00:19:35 UTC aus [docs/README.template.MD](docs/README.template.MD)*

**🌟 Production-Ready GitHub Actions Templates - Folgt Best Practices! 🌟**
