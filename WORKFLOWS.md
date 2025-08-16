# GitHub Workflows Übersicht

## 📋 Struktur

```
├── .github/workflows/          # Caller Workflows (mit Punkt)
│   ├── build.yml              # → ruft github/workflows/build.yml auf
│   ├── deploy.yml             # → ruft github/workflows/deploy.yml auf
│   ├── readme.yml             # → ruft github/workflows/readme.yml auf
│   ├── release.yml            # → ruft github/workflows/release.yml auf
│   ├── release-please.yml     # → ruft github/workflows/release-please.yml auf
│   └── security-scan.yml      # → ruft github/workflows/security-scan.yml auf
│
└── github/workflows/           # Wiederverwendbare Workflows (ohne Punkt)
    ├── build.yml              # Build-Prozess für Node.js
    ├── deploy.yml             # Deployment-Workflow
    ├── readme.yml             # README-Generierung
    ├── release.yml            # Release-Management
    ├── release-please.yml     # Release-Please mit automatischen PRs
    ├── security-scan.yml      # Sicherheitsscans
    └── README.md              # Detaillierte Dokumentation
```

## 🎯 Konzept

**Zweistufiges System:**
1. **Wiederverwendbare Workflows** (`github/workflows/`) - Die eigentlichen Workflow-Logiken
2. **Caller Workflows** (`.github/workflows/`) - Rufen die wiederverwendbaren Workflows auf

**Vorteile:**
- ✅ Zentrale Wartung der Workflow-Logik
- ✅ Einfache Wiederverwendung in anderen Projekten
- ✅ Klare Trennung zwischen Interface und Implementierung
- ✅ Versionierung und Stabilität

## 🔄 Verwendung

### Intern (in diesem Repository):
```yaml
uses: ./github/workflows/build.yml
```

### Extern (in anderen Repositories):
```yaml
uses: bauer-group/automation-templates/github/workflows/build.yml@main
```

## 📚 Weitere Informationen

Siehe `github/workflows/README.md` für detaillierte Dokumentation aller verfügbaren Workflows, Parameter und Beispiele.
