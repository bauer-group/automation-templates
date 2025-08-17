# GitHub Actions Templates - Übersicht

## 🏗️ **Finale professionelle Architektur**

```
├── .github/
│   ├── actions/                    # 🔧 Wiederverwendbare Composite Actions
│   │   ├── readme-generate/       # 📄 README-Generator (Single Source of Truth)
│   │   │   └── action.yml
│   │   └── release-please/        # 🚀 Release-Management (Single Source of Truth)
│   │       └── action.yml
│   │
│   └── workflows/                  # 🎯 Lokale Workflows (für dieses Repository)
│       ├── readme.yml             # → nutzt lokale Action
│       └── release-please.yml     # → nutzt lokale Action
│
└── github/
    ├── branch-protect/            # 🛡️ Branch-Protection Tools
    ├── runner/                    # 🏃 Self-Hosted Runner Setup  
    └── workflows/                 # 📚 Beispiele für externe Repositories
        ├── examples/              # 📋 Kopierbare Workflow-Beispiele
        │   ├── readme-example.yml
        │   ├── release-example.yml
        │   └── full-pipeline-example.yml
        ├── README.md              # 📖 Detaillierte Nutzungsdokumentation
        └── README-CONFIGURATION.md # ⚙️ Konfigurationsleitfaden
```

## ✅ **Problem-Lösung: DRY-Prinzip umgesetzt**

### **Vorher (❌ Code-Duplikation):**
- Wiederverwendbare Workflows mit dupliziertem Code
- Wartung an mehreren Stellen erforderlich
- Inkonsistenzen zwischen Implementierungen

### **Nachher (✅ Single Source of Truth):**
- **Composite Actions** als zentrale Logik
- **Workflows** als dünne Interface-Layer
- **Beispiele** für externe Verwendung

## 🎯 **Verwendung**

### **Für externe Repositories:**

#### README-Generierung hinzufügen:
```yaml
- uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    project-name: "Mein Projekt"
    company-name: "Meine Firma"
```

#### Release-Management hinzufügen:
```yaml
- uses: bauer-group/automation-templates/.github/actions/release-please@main
  with:
    release-type: "simple"
```

### **Schnellstart:**
1. Kopieren Sie `examples/readme-example.yml` oder `examples/release-example.yml`
2. Passen Sie die Parameter an
3. Committen und fertig!

## 🚀 **Architektur-Vorteile**

### **✅ Wartungsfreundlichkeit:**
- Änderungen nur in einer Datei (Composite Action)
- Automatische Propagierung zu allen Nutzern
- Keine Versionskonflikte bei lokaler Verwendung

### **✅ Skalierbarkeit:**
- Neue Actions einfach hinzufügbar
- Beispiele für verschiedene Use Cases
- Modulare, erweiterbare Struktur

### **✅ Professionalität:**
- GitHub Actions Best Practices
- Klare Separation of Concerns
- Dokumentierte API-Interfaces

## 📋 **Features**

### 📄 **README-Generator:**
- 40+ Template-Platzhalter
- Git-Repository Auto-Detection  
- Conditional Template-Blöcke
- PR-Validierung
- Script-Download-Mechanismus

### 🚀 **Release-Please:**
- Conventional Commits Support
- Semantic Versioning
- GitHub Releases
- Flexible Modi (PR/Direct)

Das System ist jetzt **production-ready** und folgt **GitHub Actions Best Practices**! 🌟

## 🔄 Verwendung

### Intern (in diesem Repository):
```yaml
uses: ./github/workflows/readme.yml
```

### Extern (in anderen Repositories):
```yaml
uses: bauer-group/automation-templates/github/workflows/readme.yml@main
```

## 🛠️ Script-Download-Mechanismus

Der README-Workflow verwendet einen innovativen Ansatz:
1. **Primär:** Download des aktuellen `generate_readme.py` Scripts vom Repository
2. **Fallback:** Minimale Script-Version falls Download fehlschlägt
3. **Vorteil:** Immer die neueste Script-Version ohne Code-Duplikation

```bash
# Download-URL für externe Verwendung:
https://raw.githubusercontent.com/bauer-group/automation-templates/main/scripts/generate_readme.py
```

## 📚 Weitere Informationen

Siehe `github/workflows/README.md` für detaillierte Dokumentation aller verfügbaren Workflows, Parameter und Beispiele.
