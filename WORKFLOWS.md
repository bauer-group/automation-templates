# GitHub Workflows Übersicht

## 📋 Professionelle Architektur

```
├── .github/
│   ├── actions/                    # Wiederverwendbare Composite Actions
│   │   ├── readme-generate/       # README-Generator Logic
│   │   │   └── action.yml
│   │   └── release-please/        # Release-Please Logic  
│   │       └── action.yml
│   │
│   └── workflows/                  # Lokale Workflows (für dieses Repository)
│       ├── readme.yml             # README-Update (nutzt Composite Action)
│       └── release-please.yml     # Release-Management (nutzt Composite Action)
│
└── github/workflows/               # Wiederverwendbare Workflows (für externe Verwendung)
    ├── readme.yml                 # Erweiterte README-Generierung
    ├── release-please.yml         # Release-Please mit automatischen PRs
    ├── README.md                  # Detaillierte Dokumentation
    └── README-CONFIGURATION.md   # Konfigurationsleitfaden
```

## 🏗️ **DRY-Prinzip (Don't Repeat Yourself)**

**Problem gelöst:** Keine Code-Duplikation mehr!

### **Composite Actions (Single Source of Truth):**
- 📄 **`.github/actions/readme-generate/`** - Zentrale README-Generator Logik
- 🚀 **`.github/actions/release-please/`** - Zentrale Release-Please Logik

### **Workflow-Layer:**
- **Lokal** (`.github/workflows/`) - Nutzt lokale Composite Actions
- **Wiederverwendbar** (`github/workflows/`) - Nutzt externe Composite Actions via `@main`

## 🎯 Verfügbare Workflows

### 📄 README Generation
**Composite Action:** `.github/actions/readme-generate/action.yml`  
**Lokaler Workflow:** `.github/workflows/readme.yml`  
**Wiederverwendbarer Workflow:** `github/workflows/readme.yml`

**Features:**
- 40+ Template-Platzhalter
- Automatische Git-Repository-Information
- Script-Download-Mechanismus
- Conditional Template-Blöcke
- PR-Validierung und Auto-Commit

### 🚀 Release Management
**Composite Action:** `.github/actions/release-please/action.yml`  
**Lokaler Workflow:** `.github/workflows/release-please.yml`  
**Wiederverwendbarer Workflow:** `github/workflows/release-please.yml`

**Features:**
- Conventional Commits Support
- Automatische Changelog-Generierung
- GitHub Release-Erstellung
- PR-basierte oder direkte Releases

## 🔄 Architektur-Vorteile

### **✅ Keine Code-Duplikation:**
- Composite Actions als Single Source of Truth
- Workflows rufen nur Actions auf
- Zentrale Wartung und Updates

### **✅ Flexible Verwendung:**
- **Intern:** Lokale Actions ohne Versionsprobleme
- **Extern:** Actions via `@main` oder `@v1.0.0`

### **✅ Professionelle Struktur:**
- Klare Trennung von Logik und Interface
- Wartungsfreundliche Architektur
- Skalierbare Lösung

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
