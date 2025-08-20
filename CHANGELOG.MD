## [0.4.1](https://github.com/bauer-group/automation-templates/compare/v0.4.0...v0.4.1) (2025-08-20)

### 🐛 Bug Fixes

* korrigiere Ausgabenamen in den Workflow-Dateien für Artefakterstellung, Lizenzprüfung und Sicherheitsprüfung ([5b6d0e9](https://github.com/bauer-group/automation-templates/commit/5b6d0e96cc35db3662e3c161ea7458e6920884ad))

## [0.4.0](https://github.com/bauer-group/automation-templates/compare/v0.3.0...v0.4.0) (2025-08-20)

### 🚀 Features

* Add modular workflows for license compliance, security scanning, PR validation, and release management ([e24c90b](https://github.com/bauer-group/automation-templates/commit/e24c90b6c51168cb621d395bde5057b63bde47e0))
* füge Beispiel-README-Generator-Workflow hinzu ([0015eeb](https://github.com/bauer-group/automation-templates/commit/0015eeb17e2f23c9c43bbbe4e09b2101e7de851e))
* füge CI/CD-Pipeline mit modularen Workflow-Komponenten hinzu ([0123e5f](https://github.com/bauer-group/automation-templates/commit/0123e5fb411b8d505870e2c29bea54035465a977))
* implement semantic release and changelog generation actions ([3b222ea](https://github.com/bauer-group/automation-templates/commit/3b222ea1fb7fa007148dc18829975579a85fb730))
* update README and workflow files for enhanced README generation ([5a7223a](https://github.com/bauer-group/automation-templates/commit/5a7223a3b430479ca5e4bfa50f6c143a47ff6f82))

### 🐛 Bug Fixes

* aktualisiere Beschreibung des GitHub Actions Runners ([40cf074](https://github.com/bauer-group/automation-templates/commit/40cf074aa4f5ef0510c2a415aaa17141038d878a))
* Aktualisiere den Action-Pfad für die Release-Management-Workflow und passe die Badge-Links im README an ([1cfa265](https://github.com/bauer-group/automation-templates/commit/1cfa265e31c8867add00af50a49dd14eca678c3d))
* aktualisiere den CI/CD-Pipeline-Link im README-Template ([d8aefcf](https://github.com/bauer-group/automation-templates/commit/d8aefcfa7b574e8eda61398db11f518703e31560))
* aktualisiere den Namen des manuellen Release-Workflows ([c573ebe](https://github.com/bauer-group/automation-templates/commit/c573ebe8af1e4b42a990f5540a53c63426b9603e))
* aktualisiere den Release-Management-Workflow zur Verbesserung der PR-Erstellung und -Zusammenführung ([7f5e028](https://github.com/bauer-group/automation-templates/commit/7f5e028e02ca419dad44d2a15618685e550760ec))
* aktualisiere den Release-Management-Workflow zur Verwendung von Semantic Release ([35f576e](https://github.com/bauer-group/automation-templates/commit/35f576efdf261372dd11e80fd8a530f108c18e28))
* aktualisiere den Release-Prozess zur Vermeidung von PR-Konflikten durch eindeutige Branch-Namen ([58c0396](https://github.com/bauer-group/automation-templates/commit/58c0396224da2875ff6f26d4ffe784d0156475be))
* aktualisiere die Konfiguration für die Release-Management-Workflow ([6e37b3b](https://github.com/bauer-group/automation-templates/commit/6e37b3b3be9fe96d3e2482da6ec89fe4bc6f16c6))
* Aktualisiere die Namen der Workflow-Dateien für eine einheitliche Modulbenennung ([dac936b](https://github.com/bauer-group/automation-templates/commit/dac936b95deb93541a6733685d71dc69a9234ca3))
* aktualisiere Module in CI/CD- und manuellen Release-Workflows auf den Hauptbranch ([4ce2c61](https://github.com/bauer-group/automation-templates/commit/4ce2c613fb02c5bdc20ee96afa01555973e9ccaf))
* enable GitHub release creation in manual fallback script ([4b5a9f4](https://github.com/bauer-group/automation-templates/commit/4b5a9f43b7c06312280e484da08ce7be6251f9bf))
* entferne den Schritt zur Aktualisierung der Dokumentation im Release-Management-Workflow ([212d5a8](https://github.com/bauer-group/automation-templates/commit/212d5a8ab35aee6143053d2b7a598629c0af4e81))
* Entferne GITHUB_TOKEN-Referenzen aus den Workflow-Modulen ([e559f69](https://github.com/bauer-group/automation-templates/commit/e559f69b97cf4a965709b6ffb09829a0316b6958))
* Entferne spezifische Branch-Referenzen aus den Workflow-Modulen in CI/CD- und manuellen Release-Workflows ([d154469](https://github.com/bauer-group/automation-templates/commit/d154469ff4fa1f9399464def4a72cece8fd79132))
* Entferne überflüssige Umgebungsvariable in der Artefakterzeugung ([1a2a9fa](https://github.com/bauer-group/automation-templates/commit/1a2a9facaf3d4e63b36d62ae2fc3e80d76ab8771))
* Entferne überflüssige Zeile in der Release-Zusammenfassung ([d8262d7](https://github.com/bauer-group/automation-templates/commit/d8262d79af018fac92ff5269704b4752db2674e7))
* entferne veraltete README-Pfade aus der Dokumentations-Workflow-Datei ([f589be1](https://github.com/bauer-group/automation-templates/commit/f589be104a8e045a7c9fe3407d690fd9360e0e84))
* Erhöhe die Suchtiefe für Releases und Commits in der Release-Management-Konfiguration ([5eb2902](https://github.com/bauer-group/automation-templates/commit/5eb29026b6039fbfd8101ded622549396ba36dce))
* Ersetze spezifische Geheimnisse durch Vererbung in CI/CD-Workflows ([adf627f](https://github.com/bauer-group/automation-templates/commit/adf627f1f6ba600d3de2e377fa4d2d4a5788960d))
* füge Abschlussmeldung zum Manage-Skript hinzu ([e8cc697](https://github.com/bauer-group/automation-templates/commit/e8cc69700ce7ed50c37f4c95381deeac4b5f8435))
* füge Unterstützung für Ziel-Branch-Parameter im Release-Management-Workflow hinzu ([97b02f4](https://github.com/bauer-group/automation-templates/commit/97b02f453f04f4cc04a2d04c611becf309a59e5e))
* korrigiere Pfad zur README.md in der Dokumentations-Workflow-Datei ([35eec3c](https://github.com/bauer-group/automation-templates/commit/35eec3c9a5facab5801ef516a9ca10c30def9b4a))
* reduziere die Suchtiefe für Releases und Commits in der Release-Management-Konfiguration ([7796a71](https://github.com/bauer-group/automation-templates/commit/7796a71e90e757dff8ac1f9aace4032cac811904))
* verbessere den Release-Management-Workflow durch Schließen veralteter PRs ([2160d0c](https://github.com/bauer-group/automation-templates/commit/2160d0c395c5e04f6b94fdefa0afd800a80cb6f4))
* verbessere Release-Management-Workflow mit erweiterten PR-Prüfungen und Fehlerbehandlung ([1cf1220](https://github.com/bauer-group/automation-templates/commit/1cf1220e9efebfde830f38884524f6dce57899c3))
* verbessere Release-Management-Workflow mit Retry-Logik und Git-Konfiguration ([463cd64](https://github.com/bauer-group/automation-templates/commit/463cd64b33a7c0c030994de776779dfe5962c05e))

### ♻️ Refactoring

* migrate from Release Please to Semantic Release ([2e69499](https://github.com/bauer-group/automation-templates/commit/2e69499e870938b9ce58b497482bf2f14e70aa3e))

## 🚀 What's Changed in v0.3.0

### 📋 Changes since v0.2.0

- fix: update permissions in automatic-release workflow to include repository-projects and checks
- fix: enhance error handling and recovery in release process; add missing release creation logic
- fix: update README workflow and template for consistency in naming
- docs: update README.MD [automated]
- fix: standardize uninstall completion message in uninstall script
- Merge branch 'main' of https://github.com/bauer-group/automation-templates
- feat: add reusable workflows for README generation and release process
- docs: update README.MD [automated]
- chore: release v0.2.0
- fix: update release-please manifest to v0.2.0
- Merge branch 'main' of https://github.com/bauer-group/automation-templates
- fix: correct manual fallback release outputs and dashboard logic
- docs: update README.MD [automated]

### 🔗 Full Changelog

**Full Changelog**: https://github.com/bauer-group/automation-templates/compare/v0.2.0...v0.3.0

---

*This release was created using the Universal Release Script.*

---

## 🚀 What's Changed in v0.2.0

### 📋 Changes since v0.1.6

- fix: update permissions in automatic-release workflow to include repository-projects and checks
- fix: enhance error handling and recovery in release process; add missing release creation logic
- fix: update README workflow and template for consistency in naming
- docs: update README.MD [automated]
- fix: standardize uninstall completion message in uninstall script
- Merge branch 'main' of https://github.com/bauer-group/automation-templates
- docs: update README.MD [automated]

### 🔗 Full Changelog

**Full Changelog**: https://github.com/bauer-group/automation-templates/compare/v0.1.6...v0.2.0

---

*This release was created using the Universal Release Script.*

---
