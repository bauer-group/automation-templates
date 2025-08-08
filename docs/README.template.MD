# BAUER GROUP – Automation Templates

Status: Version {{VERSION}} ({{DATE}})

Dieses Repository enthält zentralisierte, wiederverwendbare Automations-Templates für GitHub Actions (CI/CD) mit Fokus auf Skalierbarkeit, Wartbarkeit und Konsistenz.

[![README Auto-Update](https://github.com/bauer-group/automation-templates/actions/workflows/readme.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/readme.yml)
[![Release Automation](https://github.com/bauer-group/automation-templates/actions/workflows/release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release.yml)

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