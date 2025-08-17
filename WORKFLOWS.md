# GitHub Workflows Übersicht

## 📋 Aktuelle Struktur

```
├── .github/workflows/          # Caller Workflows (mit Punkt)
│   ├── readme.yml             # → ruft github/workflows/readme.yml auf
│   └── release-please.yml     # → ruft github/workflows/release-please.yml auf
│
└── github/workflows/           # Wiederverwendbare Workflows (ohne Punkt)
    ├── readme.yml             # Erweiterte README-Generierung mit Templates
    ├── release-please.yml     # Release-Please mit automatischen PRs
    ├── README.md              # Detaillierte Dokumentation
    └── README-CONFIGURATION.md # Konfigurationsleitfaden für README-Workflow
```

## 🎯 Verfügbare Workflows

### 📄 README Generation (`readme.yml`)
**Zweck:** Automatische README-Generierung aus Templates mit umfangreichen Platzhaltern  
**Features:**
- 40+ Template-Platzhalter
- Automatische Git-Repository-Information
- Package.json Integration
- Workflow-Badge-Generierung
- Conditional Template-Blöcke
- Automatisches Commit bei manueller Ausführung
- PR-Validierung (fails wenn README veraltet)

### 🚀 Release Management (`release-please.yml`)
**Zweck:** Automatisches Release-Management mit semantic versioning  
**Features:**
- Conventional Commits Support
- Automatische Changelog-Generierung
- GitHub Release-Erstellung
- PR-basierte oder direkte Releases
- Konfigurierbare Release-Typen
- Multi-Package Support

## 🔄 Konzept

**Zweistufiges System:**
1. **Wiederverwendbare Workflows** (`github/workflows/`) - Die eigentlichen Workflow-Logiken
2. **Caller Workflows** (`.github/workflows/`) - Rufen die wiederverwendbaren Workflows auf

**Vorteile:**
- ✅ Zentrale Wartung der Workflow-Logik
- ✅ Einfache Wiederverwendung in anderen Projekten
- ✅ Klare Trennung zwischen Interface und Implementierung
- ✅ Versionierung und Stabilität
- ✅ Keine Code-Duplikation durch dynamischen Script-Download

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
