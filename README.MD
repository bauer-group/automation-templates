<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.md instead. -->

# BAUER GROUP – Automation Templates

Status: Version 0.0.0 (2025-08-08)

Dieses Repository enthält zentralisierte, wiederverwendbare Automations-Templates für GitHub Actions (CI/CD) mit Fokus auf Skalierbarkeit, Wartbarkeit und Konsistenz.

[![Create Release](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml)

## Features
- Einheitliche Release-Strategie via Conventional Commits
- Automatische Generierung von CHANGELOG.md
- Automatisch erzeugtes README aus Template
- Vorlagen für wiederverwendbare Workflows

## Verwendung
1. README anpassen: docs/README.template.md ändern, nicht die generierte README.md.
2. Commits nach Conventional-Commits-Schema verfassen (feat:, fix:, chore:, docs:, etc.).
3. Merge nach main triggert die Release-Pipeline.

## Releasing
- semantic-release analysiert Commits und bestimmt automatisch die nächste Version.
- CHANGELOG.md und README.md werden aktualisiert und zurück ins Repo committed.
- Ein GitHub-Release mit Notes wird erstellt.

## Entwicklung
- Python-Skript zum Bauen der README: scripts/generate_readme.py
- Release-Konfigurationen liegen unter .github/release/