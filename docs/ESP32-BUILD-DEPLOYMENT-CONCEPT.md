# ESP32 Build & Deployment Konzept

## Übersicht

Dieses Dokument beschreibt das CI/CD-Konzept für ESP32-Mikrocontroller-Projekte unter Verwendung der offiziellen Espressif Docker-Images und GitHub Actions.

## Architektur

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ESP32 CI/CD Pipeline                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐ │
│  │   Commit    │──►│   Build     │──►│    Test     │──►│    Release      │ │
│  │   Push/PR   │   │   Matrix    │   │   Quality   │   │   Deployment    │ │
│  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────────┘ │
│        │                 │                 │                   │            │
│        ▼                 ▼                 ▼                   ▼            │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐ │
│  │ Security    │   │ ESP32       │   │ Unit Tests  │   │ GitHub Release  │ │
│  │ Scan        │   │ ESP32-S3    │   │ Analysis    │   │ OTA Server      │ │
│  │ (Gitleaks)  │   │ ESP32-C3    │   │ Size Check  │   │ Factory Image   │ │
│  └─────────────┘   └─────────────┘   └─────────────┘   └─────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Komponenten

### 1. Reusable Workflow

**Datei:** `.github/workflows/esp32-build.yml`

Der Hauptworkflow, der von allen ESP32-Projekten verwendet wird:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      target: esp32s3
      idf-version: v5.2
      create-release: true
```

### 2. Composite Action

**Datei:** `.github/actions/esp32-build/`

Wiederverwendbare Action für Build-Operationen:

```yaml
- uses: bauer-group/automation-templates/.github/actions/esp32-build@main
  with:
    target: esp32
    run-tests: true
```

### 3. Configuration Templates

**Verzeichnis:** `.github/config/esp32-build/`

| Template | Anwendungsfall |
|----------|---------------|
| `default.yml` | Standard-Projekte |
| `iot-device.yml` | IoT-Geräte mit OTA |
| `industrial.yml` | Industrielle Anwendungen |
| `prototype.yml` | Schnelle Prototypen |

## Freigabe-Prozess (Release Workflow)

### Versionierung

Firmware-Versionen folgen Semantic Versioning:

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

**Beispiele:**
- `1.0.0` - Produktions-Release
- `1.1.0-beta.1` - Beta-Release
- `1.0.1+build.123` - Patch mit Build-Metadata

### Release-Trigger

| Trigger | Aktion |
|---------|--------|
| Push auf `main` | Vollständiger Build, keine Release |
| Pull Request | Schnelle Validierung |
| Tag `v*` | Release mit Artefakten |

### Release-Artefakte

Jedes Release enthält:

```
firmware-v1.2.3/
├── firmware-esp32-v1.2.3.bin      # Haupt-Applikation
├── firmware-esp32s3-v1.2.3.bin    # ESP32-S3 Variante
├── firmware-esp32c3-v1.2.3.bin    # ESP32-C3 Variante
├── bootloader-*.bin                # Bootloader
├── partition-table.bin             # Partitionstabelle
├── ota-*.bin                       # OTA-Pakete
├── checksums.sha256                # Prüfsummen
├── version.json                    # Build-Metadaten
└── RELEASE_NOTES.md               # Changelog
```

## Deployment-Strategien

### 1. GitHub Release (Standard)

Automatische Release-Erstellung bei Tags:

```yaml
on:
  push:
    tags: ['v*']

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      create-release: true
```

### 2. OTA-Deployment

Automatisches Upload zu OTA-Server:

```
┌──────────────────────────────────────────────────────────────┐
│                      OTA Update Flow                          │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  GitHub Actions        OTA Server            ESP32 Device     │
│       │                      │                      │         │
│       │  1. Build & Sign     │                      │         │
│       ├───────────────────►  │                      │         │
│       │                      │                      │         │
│       │  2. Upload Binary    │                      │         │
│       ├───────────────────►  │                      │         │
│       │                      │                      │         │
│       │                      │  3. Version Check    │         │
│       │                      │◄─────────────────────┤         │
│       │                      │                      │         │
│       │                      │  4. Download OTA     │         │
│       │                      ├─────────────────────►│         │
│       │                      │                      │         │
│       │                      │  5. Verify & Apply   │         │
│       │                      │                      ├──┐      │
│       │                      │                      │  │      │
│       │                      │                      │◄─┘      │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

### 3. Factory Provisioning

Für Massenproduktion:

```yaml
jobs:
  factory:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: industrial
      secure-boot: true
      flash-encryption: true
```

## Sicherheits-Features

### Secure Boot

```yaml
security:
  secure-boot:
    enabled: true
    version: v2  # Für ESP32-S2/S3/C3
```

**Key-Generierung:**
```bash
espsecure.py generate_signing_key --version 2 secure_boot_key.pem
```

### Flash Encryption

```yaml
security:
  flash-encryption:
    enabled: true
    mode: release  # oder 'development'
```

### Erforderliche Secrets

| Secret | Beschreibung | Verwendung |
|--------|--------------|------------|
| `SECURE_BOOT_SIGNING_KEY` | RSA-3072/ECDSA Key (PEM) | Secure Boot |
| `OTA_SERVER_URL` | OTA Server Endpoint | OTA Deployment |
| `OTA_API_KEY` | OTA Server Auth | OTA Deployment |

## Qualitätssicherung

### Quality Gates

| Check | Beschreibung | Pflicht |
|-------|--------------|---------|
| Security Scan | Gitleaks für Secrets | Ja |
| Build Success | Alle Targets kompilieren | Ja |
| Unit Tests | pytest/Unity Tests | Konfigurierbar |
| Static Analysis | cppcheck, clang-tidy | Konfigurierbar |
| Size Check | Max. Binary-Größe | Konfigurierbar |

### Beispiel Quality Gate

```yaml
quality-gates:
  no-warnings: true
  tests-pass: true
  analysis-pass: true
  min-coverage: 80
  max-binary-size: 2097152  # 2MB
```

## Anwendungsbeispiele

### IoT-Gerät (Standard)

```yaml
name: IoT Device CI

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: iot-device
      targets: '["esp32", "esp32s3", "esp32c3"]'
      create-release: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

### Industrielle Anwendung (Sicher)

```yaml
name: Industrial Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      config-file: industrial
      target: esp32s3
      secure-boot: true
      flash-encryption: true
      create-release: true
    secrets:
      SECURE_BOOT_SIGNING_KEY: ${{ secrets.SECURE_BOOT_SIGNING_KEY }}
```

## Dateistruktur

```
automation-templates/
├── .github/
│   ├── workflows/
│   │   └── esp32-build.yml           # Reusable Workflow
│   ├── actions/
│   │   └── esp32-build/              # Composite Action
│   │       ├── action.yml
│   │       └── README.md
│   └── config/
│       └── esp32-build/              # Configuration Templates
│           ├── default.yml
│           ├── iot-device.yml
│           ├── industrial.yml
│           └── prototype.yml
├── github/
│   └── workflows/
│       └── examples/
│           └── esp32-build/          # Example Workflows
│               ├── README.md
│               ├── basic-build.yml
│               ├── multi-target-matrix.yml
│               ├── iot-device-ci.yml
│               └── industrial-release.yml
└── docs/
    └── workflows/
        └── esp32-build.md            # Dokumentation
```

## Referenzen

- [ESP-IDF Programming Guide](https://docs.espressif.com/projects/esp-idf/en/latest/)
- [ESP-IDF Docker Image](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/tools/idf-docker-image.html)
- [esp-idf-ci-action](https://github.com/espressif/esp-idf-ci-action)
- [ESP-IDF Security Features](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/)
- [Espressif IDF Docker Hub](https://hub.docker.com/r/espressif/idf)
