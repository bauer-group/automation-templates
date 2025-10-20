## [3.1.0](https://github.com/bauer-group/automation-templates/compare/v3.0.0...v3.1.0) (2025-10-20)

### 🚀 Features

* add skip-ci option to commit message for CI workflow control ([7d8749a](https://github.com/bauer-group/automation-templates/commit/7d8749af020a34894e2d67b20772e54b292bc3c2))

### 🐛 Bug Fixes

* add skip-ci option to prevent CI workflows during routine syncs ([e663c64](https://github.com/bauer-group/automation-templates/commit/e663c643709b8d837f38b2ef5a9c72bb5204d4f3))
* configure git credentials for submodule operations with private repos ([b81b285](https://github.com/bauer-group/automation-templates/commit/b81b28512c8b524d49dc4bfedf7338d551875c1d))
* optimize submodule update command to fetch only the tracked branch ([9215d37](https://github.com/bauer-group/automation-templates/commit/9215d3799cb6803f6cc9eee48004fb1e10cd29a1))
* prevent submodule loading during initial checkout to avoid access issues ([ef5d9ee](https://github.com/bauer-group/automation-templates/commit/ef5d9ee2300be7ca5b3d19b0abfd15bcfb2c9408))
* properly configure git credentials for submodule operations ([58e8461](https://github.com/bauer-group/automation-templates/commit/58e84617822b0e8563376e09ef29b00bca3452e0))
* reset git credentials to github.token after submodule sync for push operations ([23323df](https://github.com/bauer-group/automation-templates/commit/23323df1d663c1b6bba8c8cd43c579dbe1006208))
* set GH_TOKEN at job level to fix branch detection and repository access ([41655e9](https://github.com/bauer-group/automation-templates/commit/41655e90cc648f17750027f5468c54550d4c7867))
* use --local instead of --global for git credentials in submodule sync ([68df0d1](https://github.com/bauer-group/automation-templates/commit/68df0d1541c5782607c9abb81c0c0856370a4597))
* use global git config for submodule credentials, local for push ([cf2be92](https://github.com/bauer-group/automation-templates/commit/cf2be92e435c55c0220eecfbee2b9078544eb913))

## [3.0.0](https://github.com/bauer-group/automation-templates/compare/v2.0.0...v3.0.0) (2025-10-18)

### ⚠ BREAKING CHANGES

* Secret name changed from GH_PAT to GITHUB_PAT

Security improvements:
- GITHUB_PAT is now only used for reading private repos from organization
- All write operations (checkout, commit, push) use default github.token
- Implements principle of least privilege
- Added warning when include-private=true but GITHUB_PAT not provided

Changes:
- Rename secret from GH_PAT to GITHUB_PAT
- GITHUB_PAT only set in GH_TOKEN env var when include-private=true
- Add security comment in checkout step
- Update all example workflows (shopware5-plugins.yml, multi-topic-portfolio.yml)
- Extend documentation with security best practices
- Add recommended token scopes (repo only, no workflow/admin/delete)
- Document read-only behavior of GITHUB_PAT

Why this matters:
- Reduces attack surface: PAT cannot modify meta repository
- Clear separation: github.token for writes, GITHUB_PAT for reads
- Better security posture for organizations

Co-Authored-By: Claude <noreply@anthropic.com>

### ♻️ Code Refactoring

* rename GH_PAT to GITHUB_PAT and implement read-only security model ([d49c5d2](https://github.com/bauer-group/automation-templates/commit/d49c5d2f2c7d336e254caa1aa5a570aaf5a4ca0b))

## [2.0.0](https://github.com/bauer-group/automation-templates/compare/v1.11.0...v2.0.0) (2025-10-18)

### ⚠ BREAKING CHANGES

* To access private repositories, users must now provide a GH_PAT secret with 'repo' scope.

Changes:
- Add optional GH_PAT secret parameter to workflow_call
- Implement fallback logic: GH_PAT || github.token
- Add debug output showing which token is being used
- Update all example workflows with secrets.GH_PAT parameter
- Extend PARAMETERS.md with detailed GH_PAT setup instructions
- Add "Private Repository Access" section to README.md

Why this change:
The default github.token has limited permissions and may not access all private repositories
in an organization. A Personal Access Token with 'repo' scope ensures full access to both
public and private repositories.

Co-Authored-By: Claude <noreply@anthropic.com>

### 🚀 Features

* add GH_PAT secret support for private repository access in meta-repository-sync ([6753a6e](https://github.com/bauer-group/automation-templates/commit/6753a6eb6a312a480363b03991eac6401efdf884))
* verbessere Unterstützung für private Repositories durch erweiterte Eingabeverarbeitung und detaillierte Protokollierung ([5faebaa](https://github.com/bauer-group/automation-templates/commit/5faebaa063c80600804a5f37e2e8a5e79cf417b7))

## [1.11.0](https://github.com/bauer-group/automation-templates/compare/v1.10.1...v1.11.0) (2025-10-17)

### 🚀 Features

* füge automatisiertes Meta-Repository-Synchronisierungssystem hinzu ([068562a](https://github.com/bauer-group/automation-templates/commit/068562a84f5a7e02bbe588ee5cdf4af372f21006))
* füge Unterstützung für private Repositories hinzu und aktualisiere README-Vorlage ([ed8e513](https://github.com/bauer-group/automation-templates/commit/ed8e5135baadeb2d73a054e7c50ffb1836d5d8d1))
* füge Unterstützung für private Repositories in Workflow-Konfigurationen hinzu ([83b2e26](https://github.com/bauer-group/automation-templates/commit/83b2e2613eb2bc6c4fde15e44a1ac0466dec894c))

### ♻️ Code Refactoring

* benenne Ausgabedateien um, um Präfixe zu entfernen und die Konsistenz zu verbessern ([9029c58](https://github.com/bauer-group/automation-templates/commit/9029c58e4956c0975acc28b6b34772269e985931))
* entferne geheime Token-Referenzen aus Workflow- und README-Vorlage ([5cb9adb](https://github.com/bauer-group/automation-templates/commit/5cb9adb842833bff73b4ce04bbc31983bd56bd71))
* verbessere Fetch-Logik durch Caching aller Repositories für effizientere Verarbeitung ([ef24564](https://github.com/bauer-group/automation-templates/commit/ef24564ccd3e504d3664bc65dc568aa7926be589))
* verbessere Fetch-Logik für Repositories nach Themen ([c949e17](https://github.com/bauer-group/automation-templates/commit/c949e17a3c8ee383810d8f9b84153477718653a0))
* verbessere README-Generierung durch Hinzufügen von Template-Variablen und Platzhalter-Unterstützung ([57b2736](https://github.com/bauer-group/automation-templates/commit/57b27368e06075df2805452d46ab70ebfd931259))
* verbessere README-Generierung durch Verwendung von jq für sichere Template-Variablenersetzung ([ca8e537](https://github.com/bauer-group/automation-templates/commit/ca8e537118957b3dd39cd4e18cf03e9265ea1987))
* verbessere README-Generierung durch Verwendung von Python für sichere Platzhalterersetzung ([cc66bd1](https://github.com/bauer-group/automation-templates/commit/cc66bd17a71469b527aa88b7b5c3402262b42864))
* verbessere README.md Generierung durch Verwendung von printf und Platzhaltern ([a1f7603](https://github.com/bauer-group/automation-templates/commit/a1f76034065e744e6412fc6704580091af3121d2))

## [1.10.1](https://github.com/bauer-group/automation-templates/compare/v1.10.0...v1.10.1) (2025-10-17)

### 🐛 Bug Fixes

* erweitere die README-Dokumentation um Konfigurationsoptionen und verbessere die Beschreibung der automatischen Synchronisierungsfunktionen ([0e62788](https://github.com/bauer-group/automation-templates/commit/0e6278829a0647f0dbb97dda478a932e0a2cb7ca))

## [1.10.0](https://github.com/bauer-group/automation-templates/compare/v1.9.0...v1.10.0) (2025-10-17)

### 🚀 Features

* add meta repository sync workflow documentation and examples ([dc3fc40](https://github.com/bauer-group/automation-templates/commit/dc3fc40944ad78caae5aac340c751ecbef3dafe0))

### 🐛 Bug Fixes

* behebe Version-Extraktion aus plugin.json und plugin.xml ([4d0a0b3](https://github.com/bauer-group/automation-templates/commit/4d0a0b34cb3e53b5067a0bad2975be09df8f5789))
* erhöhe maxdepth für find-Befehle von 3 auf 5 für tief verschachtelte Plugin-Strukturen ([3889a0b](https://github.com/bauer-group/automation-templates/commit/3889a0bdd02b737ae51f1f3f212c0587bd0a37c2))
* erweitere die Erkennung der Plugin-Struktur für Legacy-Plugins und füge Unterstützung für Core-Plugins hinzu ([1e4a7b8](https://github.com/bauer-group/automation-templates/commit/1e4a7b8c2a87f9fb1cf6209b76c13cf3d8744d55))
* erweitere die Erkennung und Validierung von Plugin-Systemen im Build-Prozess ([6a17d52](https://github.com/bauer-group/automation-templates/commit/6a17d52acee56b1d988be1d28a97b453c84fe5fb))
* extrahiere Plugin-Namen aus Verzeichnisstruktur statt aus label ([749e8b0](https://github.com/bauer-group/automation-templates/commit/749e8b0a015cfb6f1df0614f1b0397212ba895fc))
* generiere sauberen ZIP-Dateinamen mit Version ([9177355](https://github.com/bauer-group/automation-templates/commit/9177355c64ccbd3f3e07d321a9964d1e10a189e8))
* verbessere die Bestimmung des Plugin-Stammverzeichnisses und passe die ZIP-Dateinamensgenerierung an das Repository an ([4958c3d](https://github.com/bauer-group/automation-templates/commit/4958c3db1cc709fa49f5185d6743741cf05601bd))
* verbessere die Erkennung von BAUERGROUP-Plugins und optimiere die ZIP-Struktur für verschiedene Plugin-Typen ([0230acc](https://github.com/bauer-group/automation-templates/commit/0230accefe3dcea1f21248dc6e471015276e31ba))
* verbessere die Handhabung der Composer-Abhängigkeiten und optimiere die ZIP-Struktur für Plugins ([72d6097](https://github.com/bauer-group/automation-templates/commit/72d6097f4d0c522cd2ca8efe434fb20fdb60815c))
* verbessere die Handhabung der Composer-Authentifizierung im Build-Prozess ([54dd8af](https://github.com/bauer-group/automation-templates/commit/54dd8afc21da9fefc2a5e8aea3125aa6e9ee162a))
* verbessere die Plugin-Namens- und Versionsextraktion aus plugin.json, plugin.xml und composer.json ([c4bbae7](https://github.com/bauer-group/automation-templates/commit/c4bbae7aebd21f6dd83a2b701c1b5f22336b4442))

## [1.9.0](https://github.com/bauer-group/automation-templates/compare/v1.8.1...v1.9.0) (2025-10-16)

### 🚀 Features

* füge Konfigurationsdateien für das Python-Paket und den Semantic Release-Workflow hinzu ([29dc08e](https://github.com/bauer-group/automation-templates/commit/29dc08eaf55149f351e6c01a4a5f556f6b02b037))
* Shopware 5 Build System added ([b0d5962](https://github.com/bauer-group/automation-templates/commit/b0d59627b95ad172d3965e6c3d6407771855b2a5))

### 🐛 Bug Fixes

* behebe die Einrückung in der Workflow-Konfiguration für die AI-Zusammenfassung ([71f3e4a](https://github.com/bauer-group/automation-templates/commit/71f3e4ab52244d84d544779cba614e9c5fbeff06))
* füge Synchronisation mit dem Remote-Branch hinzu, um Push-Konflikte zu vermeiden ([46876f3](https://github.com/bauer-group/automation-templates/commit/46876f3bdc19b1811a7648a01980d80a1fcc637e))
* verbessere die Handhabung von Eingaben und Ausgaben im AI-Zusammenfassungsworkflow ([ae4afa3](https://github.com/bauer-group/automation-templates/commit/ae4afa3af7cda0795349e271d79a6fa6bc714e98))

## [1.8.1](https://github.com/bauer-group/automation-templates/compare/v1.8.0...v1.8.1) (2025-09-01)

### 🐛 Bug Fixes

* aktualisiere Berechtigungen im CI/CD-Workflow für Aktionen ([8b6da4d](https://github.com/bauer-group/automation-templates/commit/8b6da4d527d247cb0929a6d1378613743f2668e0))
* aktualisiere den Befehl für die semantische Veröffentlichung auf verbose Ausgabe ([c81d10c](https://github.com/bauer-group/automation-templates/commit/c81d10cd020e8e1847744d24b14d4b57fe75468b))
* aktualisiere den Namen des CI/CD-Pipelines für Klarheit ([7a28423](https://github.com/bauer-group/automation-templates/commit/7a284235c9e17a50eb9cefd0ea863d51399e28fb))
* aktualisiere Kommentare zu Berechtigungen im CI/CD-Workflow ([cfd8e5f](https://github.com/bauer-group/automation-templates/commit/cfd8e5fbaf5be2ebe74cd45d9e62d417da1afdaa))
* aktualisiere Umgebungsnamen für die Veröffentlichung auf Produktion und verbessere die Beispielkonfiguration in pyproject.toml ([28109c0](https://github.com/bauer-group/automation-templates/commit/28109c0ed68fbb7048d60cf6f7d9feb3a60717f5))
* entferne überflüssige Leerzeile am Anfang der CI/CD-Pipeline ([f87a341](https://github.com/bauer-group/automation-templates/commit/f87a341d3cc18c00be696efc0f6b603c25a87060))
* ersetze 'safety' durch 'pip-audit' in Sicherheitskonfigurationen und -prüfungen ([514423b](https://github.com/bauer-group/automation-templates/commit/514423bfae7d14e8ef75a31ae07a7c51f2b6e327))
* erweitere Test- und Qualitätsjob um Ausgaben für Testergebnisse, Abdeckungsquote und Sicherheits-/Linting-Probleme ([355460e](https://github.com/bauer-group/automation-templates/commit/355460e708b41bd51c015d70db9b9bd2a1e6c80d))
* füge Bedingung hinzu, um bei fehlenden Dateien im Sicherheitsbericht zu ignorieren ([2da5a85](https://github.com/bauer-group/automation-templates/commit/2da5a85f8bbf9a5f3386b95e7a32cbfa2232825a))
* füge Schritt hinzu, um sicherzustellen, dass CHANGELOG.MD für die semantische Veröffentlichung existiert ([0acb166](https://github.com/bauer-group/automation-templates/commit/0acb166ba9b5d8251574bba2557e98ddd085bb2e))
* füge Statusausgabe für PyPI-Publikation im Pipeline-Zusammenfassung hinzu ([98c5e27](https://github.com/bauer-group/automation-templates/commit/98c5e2784f780e17965d6d36ee317a7ab861abd8))
* integriere den Build- und Testprozess für Wheel-Pakete in den Semantic Release Workflow ([f2b81af](https://github.com/bauer-group/automation-templates/commit/f2b81af656749d631596a1264a55927e0905f2fd))
* verbessere die Erstellung von CHANGELOG.MD für die semantische Veröffentlichung ([31d4a0f](https://github.com/bauer-group/automation-templates/commit/31d4a0fb0746e84153446741e2309b47d063db4b))
* verbessere die PyPI Veröffentlichungsdetails und füge übersichtliche Statusausgaben hinzu ([7e50a53](https://github.com/bauer-group/automation-templates/commit/7e50a53e19edef47fa6df82c879f68a259e0c2f0))
* verbessere Fehlerbehandlung und Ausgaben in der CI/CD-Pipeline für Tests, Sicherheitsanalysen und Linting ([ce86d6e](https://github.com/bauer-group/automation-templates/commit/ce86d6e072389aa0e55c3ddb5d8d5a9507f91670))
* verschiebe und aktualisiere den Semantic Release Job im CI/CD-Workflow ([d3785b6](https://github.com/bauer-group/automation-templates/commit/d3785b64999e477df159abefa8e2cad9131a967d))

## [1.8.0](https://github.com/bauer-group/automation-templates/compare/v1.7.0...v1.8.0) (2025-09-01)

### 🚀 Features

* erweitere Berechtigungen für CI/CD-Workflow um Prüf- und Sicherheitsereignisse ([bdb11f2](https://github.com/bauer-group/automation-templates/commit/bdb11f2e08e7e0ad2a2ec003359e9da1f4ac9f02))

### 🐛 Bug Fixes

* Remove Python Testing Action and CI/CD Workflows ([3d36c22](https://github.com/bauer-group/automation-templates/commit/3d36c226d35d981e0378b98a727fc94cdf4e0ec0))

### ♻️ Code Refactoring

* move commit_parser_options to a dedicated section in pyproject.toml ([23d84ee](https://github.com/bauer-group/automation-templates/commit/23d84ee8bad6b3a10ebdd6f9bcca5903b141ed34))

## [1.7.0](https://github.com/bauer-group/automation-templates/compare/v1.6.1...v1.7.0) (2025-09-01)

### 🚀 Features

* Add comprehensive Zephyr RTOS build examples and workflows ([2cb962d](https://github.com/bauer-group/automation-templates/commit/2cb962db18ce340656bd2e43cb7645a973ac4bdb))
* enhance Python package installation logic for modern and legacy projects ([63de420](https://github.com/bauer-group/automation-templates/commit/63de42038957f0cb1c93da0f4920b5d664fd1951))

### 🐛 Bug Fixes

* use eval for executing test commands in python-build.yml ([8603cf6](https://github.com/bauer-group/automation-templates/commit/8603cf608085c522360d1a921f6e841f6928a06c))
* use eval for install command execution in python-build.yml ([b10853b](https://github.com/bauer-group/automation-templates/commit/b10853b5f51f4af9ca6a608b0dd54ee85deb1de6))

## [1.6.1](https://github.com/bauer-group/automation-templates/compare/v1.6.0...v1.6.1) (2025-08-31)

### 🐛 Bug Fixes

* improve unresolved placeholders check in README generator ([139e4b2](https://github.com/bauer-group/automation-templates/commit/139e4b28476325a404bc5351fec2433e856cb456))
* rename unresolved placeholders output for clarity ([cb82fa5](https://github.com/bauer-group/automation-templates/commit/cb82fa59429574f5f5c6eb19e9b449eaea188b1e))
* rename unresolved placeholders output for consistency ([0629fe2](https://github.com/bauer-group/automation-templates/commit/0629fe266687fd48f712e5c28d3cc6d03843f420))

## [1.6.0](https://github.com/bauer-group/automation-templates/compare/v1.5.0...v1.6.0) (2025-08-31)

### 🚀 Features

* enhance unittest integration with XML output and report checks ([725069e](https://github.com/bauer-group/automation-templates/commit/725069e988ea37ca7fda3785effd70f74f5d2fa0))
* update working directory input for Python build and publish jobs ([525b950](https://github.com/bauer-group/automation-templates/commit/525b950a62daa8470ad6903925bbc388dfd438f7))

### 🐛 Bug Fixes

* ensure newline at end of file in deploy-automations.sh ([9023b08](https://github.com/bauer-group/automation-templates/commit/9023b084b63a18449b68cfd44f3196bffd0ea60e))
* handle unset variable for unresolved placeholders count in README generation ([211cfdb](https://github.com/bauer-group/automation-templates/commit/211cfdbd97ba689480d97145b8f71d071ac442ab))
* improve unresolved placeholders counting in README generation ([e2d30a9](https://github.com/bauer-group/automation-templates/commit/e2d30a9b5324a5eb8493889c7025eddf476e8f87))
* remove branch check from workflow conditions to simplify execution ([388e295](https://github.com/bauer-group/automation-templates/commit/388e29507fb1a149d4973b10b76ef903722d956e))
* simplify dependencies for PyPI publishing and clarify artifact generation summary ([1bdade8](https://github.com/bauer-group/automation-templates/commit/1bdade8835561c993bcee15df06b58ef0758ff7e))
* streamline unittest execution in Python build workflow ([fc6d27c](https://github.com/bauer-group/automation-templates/commit/fc6d27cfb44eb27cfda1287cdd5ed7b64d877a40))
* update artifact generation summary to include wheel type ([db00856](https://github.com/bauer-group/automation-templates/commit/db0085666d76e0062c97da394f5acf7aaf75d963))

### ♻️ Code Refactoring

* simplify unittest execution in Python build workflow ([30abb72](https://github.com/bauer-group/automation-templates/commit/30abb7284b936d837be4d9911f26ad36a34ce08b))

## [1.5.0](https://github.com/bauer-group/automation-templates/compare/v1.4.1...v1.5.0) (2025-08-30)

### 🚀 Features

* add force-release option to release management job ([90923d1](https://github.com/bauer-group/automation-templates/commit/90923d10715945161a9d696290b42477f1912b83))
* add force-release option to semantic release configuration ([9b45f07](https://github.com/bauer-group/automation-templates/commit/9b45f070f530dafb7155122ec6fc11c1e70723d1))
* add force-release option to semantic release workflows ([f915d13](https://github.com/bauer-group/automation-templates/commit/f915d13a0d2b2de7809b4247f2657b14db1f8007))

### ♻️ Code Refactoring

* remove build-package option from publish-pypi job ([e32a5c7](https://github.com/bauer-group/automation-templates/commit/e32a5c77f4eb1532d987606457090e74a87ef143))
* remove format and type check options from Python CI/CD pipeline ([661d765](https://github.com/bauer-group/automation-templates/commit/661d76558e58e73f796e3235b1adad9fc0a4b9d2))

## [1.4.1](https://github.com/bauer-group/automation-templates/compare/v1.4.0...v1.4.1) (2025-08-30)

### ♻️ Code Refactoring

* update security scan engine input type and description in CI/CD pipeline ([3473f2a](https://github.com/bauer-group/automation-templates/commit/3473f2a361bb7de60123c5e21ceb746bd3acfe1c))

### 🔧 Maintenance

* update default Python version to 3.12 in build and publish workflows ([11fa942](https://github.com/bauer-group/automation-templates/commit/11fa942b07848ed132190dda396a81f8616eeb8e))
* update pipeline name for clarity in python-example.yml ([d785880](https://github.com/bauer-group/automation-templates/commit/d785880d85dc64b8238469e65d2fa361e5aca27b))

## [1.4.0](https://github.com/bauer-group/automation-templates/compare/v1.3.8...v1.4.0) (2025-08-30)

### 🚀 Features

* enhance Python automatic release workflow with reusable inputs and improved security scan options ([7710d02](https://github.com/bauer-group/automation-templates/commit/7710d02e79b048a180e0ff2d24f9a22659497452))

### 🐛 Bug Fixes

* update default security scan engine to 'both' in PR validation workflow ([02d5bd0](https://github.com/bauer-group/automation-templates/commit/02d5bd06acef8fffbaa98be30b5dcdc979b1873b))

### ♻️ Code Refactoring

* remove artifact-types input from Python release workflows for simplification ([4685c3b](https://github.com/bauer-group/automation-templates/commit/4685c3b560c2598a457d05a5f25b9a9e83717278))
* update Python CI/CD pipeline names and improve example workflow configuration ([2dc9671](https://github.com/bauer-group/automation-templates/commit/2dc96714a939151e8b3136b8598d6dfaebecfc57))

## [1.3.8](https://github.com/bauer-group/automation-templates/compare/v1.3.7...v1.3.8) (2025-08-30)

### 🐛 Bug Fixes

* update example value for minimum coverage in deployment config ([09e90e6](https://github.com/bauer-group/automation-templates/commit/09e90e6f3c752b6d2e068a1df9f4dec3237c3ecf))
* update security policy job dependencies to include documentation update ([257c823](https://github.com/bauer-group/automation-templates/commit/257c8232aec2c912509567f857882820fa827953))

## [1.3.7](https://github.com/bauer-group/automation-templates/compare/v1.3.6...v1.3.7) (2025-08-30)

### 🐛 Bug Fixes

* add missing newline at end of deploy-config.yml ([7e0464f](https://github.com/bauer-group/automation-templates/commit/7e0464fd56f1c0d0302ca3faf68ce990b1929d31))
* include all files in TAR.GZ archive creation ([1beff99](https://github.com/bauer-group/automation-templates/commit/1beff993db5d6353912a1b13c1f9692e61bc4a49))

## [1.3.6](https://github.com/bauer-group/automation-templates/compare/v1.3.5...v1.3.6) (2025-08-30)

### 🐛 Bug Fixes

* add missing newline at end of deploy-config.yml ([1a0ab69](https://github.com/bauer-group/automation-templates/commit/1a0ab69b8036853f8e21a79a7d992e5908157779))
* correct tar command to include all files in source archive ([fad4a78](https://github.com/bauer-group/automation-templates/commit/fad4a780dbf63b2541ca53934712a4346413e202))

## [1.3.5](https://github.com/bauer-group/automation-templates/compare/v1.3.4...v1.3.5) (2025-08-30)

### 🐛 Bug Fixes

* add missing newline at end of deploy-config.yml ([52853c9](https://github.com/bauer-group/automation-templates/commit/52853c9642636c6c73bb3c8021fd93f7d5a08f4b))
* exclude artifacts directory from generated zip and tar.gz archives ([360bb4b](https://github.com/bauer-group/automation-templates/commit/360bb4b54453cbee720ce72bb3cdbc137cdaff72))

## [1.3.4](https://github.com/bauer-group/automation-templates/compare/v1.3.3...v1.3.4) (2025-08-30)

### 🐛 Bug Fixes

* add newline at end of python-example.yml ([83ae0b9](https://github.com/bauer-group/automation-templates/commit/83ae0b914dd7574d5c29594a9f61cede7a54c490))
* prevent nested project directories in release artifacts ([04430df](https://github.com/bauer-group/automation-templates/commit/04430dfb3eb6b9a287d10d1888ae429648e1ccde))
* remove temp- prefix from release artifact directory structure ([37b6074](https://github.com/bauer-group/automation-templates/commit/37b60748e0572bc2f973af18bb8d00be7fe98545))

## [1.3.3](https://github.com/bauer-group/automation-templates/compare/v1.3.2...v1.3.3) (2025-08-30)

### 🐛 Bug Fixes

* update PyYAML version to 6.0.2 in requirements.txt ([f95a912](https://github.com/bauer-group/automation-templates/commit/f95a9129f589472ddf69c2cae9b3a7aee4ee6382))

## [1.3.2](https://github.com/bauer-group/automation-templates/compare/v1.3.1...v1.3.2) (2025-08-30)

### 🐛 Bug Fixes

* add retry logic to documentation workflow for concurrent push conflicts ([b05652d](https://github.com/bauer-group/automation-templates/commit/b05652d9c0a74a20c5104ed74b781009b9d0f1fd))

## [1.3.1](https://github.com/bauer-group/automation-templates/compare/v1.3.0...v1.3.1) (2025-08-30)

### 🐛 Bug Fixes

* ensure newline at end of file in deploy-automations.sh ([ba18ab3](https://github.com/bauer-group/automation-templates/commit/ba18ab3056a4b3d4672bf3b93d752abbaa8391d6))
* improve version detection and clean workflow path filters ([724e1bf](https://github.com/bauer-group/automation-templates/commit/724e1bf02a99245449ee9ba12a9a9e0d697428aa))

## [1.3.0](https://github.com/bauer-group/automation-templates/compare/v1.2.0...v1.3.0) (2025-08-29)

### 🚀 Features

* remove obsolete Python script for README generation ([fac3d4b](https://github.com/bauer-group/automation-templates/commit/fac3d4bf809464d2ce8924c00101cd2c9a5eb4e5))

### 🐛 Bug Fixes

* update comment for consistency in deploy-automations.sh ([e379015](https://github.com/bauer-group/automation-templates/commit/e3790153cc169c6b8bc6c6071584ec3fe05fc67a))

## [1.2.0](https://github.com/bauer-group/automation-templates/compare/v1.1.13...v1.2.0) (2025-08-29)

### 🚀 Features

* refactor README generator action to work inline without external scripts ([0a866ca](https://github.com/bauer-group/automation-templates/commit/0a866caa74f2bd03a7cb2d92aedac81bb9039a21))

### 🐛 Bug Fixes

* resolve sed temporary file issues in README generator action ([521b555](https://github.com/bauer-group/automation-templates/commit/521b5559d722aa3e6c2e6c9ca061256a7e8050d4))

## [1.1.13](https://github.com/bauer-group/automation-templates/compare/v1.1.12...v1.1.13) (2025-08-29)

### 🐛 Bug Fixes

* preserve generated content during git merge operations ([baadd38](https://github.com/bauer-group/automation-templates/commit/baadd383a8d4760b1c14e54cc8529184677c7b24))

## [1.1.12](https://github.com/bauer-group/automation-templates/compare/v1.1.11...v1.1.12) (2025-08-29)

### 🐛 Bug Fixes

* handle clean git merge without changes gracefully ([e2b056e](https://github.com/bauer-group/automation-templates/commit/e2b056ef20205ff37c369ba2e6e47fa080f46e70))

## [1.1.11](https://github.com/bauer-group/automation-templates/compare/v1.1.10...v1.1.11) (2025-08-29)

### 🐛 Bug Fixes

* correct workflow order to preserve generated content ([70e7d11](https://github.com/bauer-group/automation-templates/commit/70e7d11b0882ffda7e7522db6cafb2c14a08b83d))

## [1.1.10](https://github.com/bauer-group/automation-templates/compare/v1.1.9...v1.1.10) (2025-08-29)

### 🐛 Bug Fixes

* restructure workflow steps to prevent sync conflicts ([b17d401](https://github.com/bauer-group/automation-templates/commit/b17d40196ad80b667b2f96c842331e2bcfcafcbd))

## [1.1.9](https://github.com/bauer-group/automation-templates/compare/v1.1.8...v1.1.9) (2025-08-29)

### 🐛 Bug Fixes

* resolve git rebase conflicts in documentation workflows ([23666e3](https://github.com/bauer-group/automation-templates/commit/23666e30da310b90118c889abf917e9ce1737e47))

## [1.1.8](https://github.com/bauer-group/automation-templates/compare/v1.1.7...v1.1.8) (2025-08-29)

### 🐛 Bug Fixes

* improve git sync in documentation and security workflows ([fae9e9c](https://github.com/bauer-group/automation-templates/commit/fae9e9c4b180441f5b30a583d1730d1578984186))

## [1.1.7](https://github.com/bauer-group/automation-templates/compare/v1.1.6...v1.1.7) (2025-08-29)

### 🐛 Bug Fixes

* add missing custom-version input to workflow_call sections ([6ca65ae](https://github.com/bauer-group/automation-templates/commit/6ca65aef696a7b48a14bc3d27dd4774fa74a87b2))
* ensure documentation and security workflows run after releases ([4c9dc65](https://github.com/bauer-group/automation-templates/commit/4c9dc656052da01c94c7563441904fb3c83ea2f3))

## [1.1.6](https://github.com/bauer-group/automation-templates/compare/v1.1.5...v1.1.6) (2025-08-29)

### 🐛 Bug Fixes

* correct GitHub Actions syntax for tag and branch triggers ([297c2a2](https://github.com/bauer-group/automation-templates/commit/297c2a298a2dfcc47cbb11e747cee2308be87d83))
* use correct GitHub Actions syntax for tag creation triggers ([87e2078](https://github.com/bauer-group/automation-templates/commit/87e20784d6071ec7bf5171ee879b2a7b2f7e8d7a))

## [1.1.5](https://github.com/bauer-group/automation-templates/compare/v1.1.4...v1.1.5) (2025-08-29)

### 🐛 Bug Fixes

* disable automatic [skip ci] in semantic-release action ([b44abe8](https://github.com/bauer-group/automation-templates/commit/b44abe821c8c61a7a79d3ed44a112180879e89e9))
* remove [skip ci] from repository semantic-release configuration ([99481f9](https://github.com/bauer-group/automation-templates/commit/99481f9180627fa6e74953c559c4166e51708236))
* remove unnecessary blank line before main execution block ([3cfdaf3](https://github.com/bauer-group/automation-templates/commit/3cfdaf3bae46ad2a622b05080eb9fa6065818bd7))

### 🔧 Maintenance

* remove unnecessary ci: false parameter from semantic-release action ([adab4f4](https://github.com/bauer-group/automation-templates/commit/adab4f4599f53dbfa52750a9c392f99b3ac92375))

## [1.1.4](https://github.com/bauer-group/automation-templates/compare/v1.1.3...v1.1.4) (2025-08-29)

### 🐛 Bug Fixes

* add a blank line before the main execution block for better readability ([ab19582](https://github.com/bauer-group/automation-templates/commit/ab19582bd0592a22d20ccc4ceb489a12a0d7cca9))
* update paths in workflows to include documentation and security templates ([300838d](https://github.com/bauer-group/automation-templates/commit/300838d9696a9bab6e37ae695abaeaee66c15c5b))

## [1.1.3](https://github.com/bauer-group/automation-templates/compare/v1.1.2...v1.1.3) (2025-08-29)

### 🐛 Bug Fixes

* ensure paths are ignored for pull requests in automatic release workflow ([5c9f414](https://github.com/bauer-group/automation-templates/commit/5c9f4146406d82eb5cab7f15009eba188ae50537))
* finalize workflow validation and ensure [skip ci] removal is active ([e99caeb](https://github.com/bauer-group/automation-templates/commit/e99caebf9aae911a5a9e69b3246558a51730dff4))

### 🔧 Maintenance

* remove outdated comment about workflow validation ([85304c3](https://github.com/bauer-group/automation-templates/commit/85304c311710885a6bbdea8aac2bf3be0b6c6203))

## [1.1.2](https://github.com/bauer-group/automation-templates/compare/v1.1.1...v1.1.2) (2025-08-29)

### 🐛 Bug Fixes

* make semantic-release robust against parallel workflow conflicts ([4e7f6cf](https://github.com/bauer-group/automation-templates/commit/4e7f6cf02e895a2ed9f78932a141d12a945d2230))

## [1.1.1](https://github.com/bauer-group/automation-templates/compare/v1.1.0...v1.1.1) (2025-08-29)

### 🐛 Bug Fixes

* improve git pull robustness in parallel workflows ([8f1ddc7](https://github.com/bauer-group/automation-templates/commit/8f1ddc785f556b781fe7d3b6b4e751ae29225770))
* prevent parallel workflow conflicts with semantic-release ([8046b59](https://github.com/bauer-group/automation-templates/commit/8046b59b1740baf28685512188b973b908f33e91))

### 🔧 Maintenance

* remove workflow testing comment from generate_readme.py ([edf2c61](https://github.com/bauer-group/automation-templates/commit/edf2c61a7458142116c7b889c473a341898e2d3b))

## [1.1.0](https://github.com/bauer-group/automation-templates/compare/v1.0.6...v1.1.0) (2025-08-29)

### 🚀 Features

* restore tag-triggered documentation and security workflows ([f7e6ad6](https://github.com/bauer-group/automation-templates/commit/f7e6ad6488b75fd6baa5c22a4699bad67184c22a))

### ♻️ Code Refactoring

* simplify documentation and security workflows to main-branch triggers only ([724d98f](https://github.com/bauer-group/automation-templates/commit/724d98fb2bb9f1939753321b3ce1fd4aa3456be6))

## [1.0.6](https://github.com/bauer-group/automation-templates/compare/v1.0.5...v1.0.6) (2025-08-29)

### 🐛 Bug Fixes

* resolve detached HEAD issue in tag-triggered documentation and security workflows ([9a8c5e1](https://github.com/bauer-group/automation-templates/commit/9a8c5e1da307ecdc581b15ac67719f5a044a5bed))

## [1.0.5](https://github.com/bauer-group/automation-templates/compare/v1.0.4...v1.0.5) (2025-08-29)

### 🐛 Bug Fixes

* add workflow validation comment for testing release workflow ([2336518](https://github.com/bauer-group/automation-templates/commit/2336518ce7154b086ebdb04706344280071dba74))
* remove unnecessary newline before main execution block in generate_readme.py ([31553bf](https://github.com/bauer-group/automation-templates/commit/31553bf7670a30a3e6d00fd8207b924df6c2a2c2))
* resolve tag conflict and ensure semantic-release workflow consistency ([98e4dff](https://github.com/bauer-group/automation-templates/commit/98e4dfff26c7708e780524affe6e12319e6cb87a))
* restore v0.23.0 workflow functionality with git merge strategy and semantic-release output fixes ([bb51862](https://github.com/bauer-group/automation-templates/commit/bb518625f368f0ea101609a96aa576a006fad921))
* test workflow decoupling and validation ([f25b9ce](https://github.com/bauer-group/automation-templates/commit/f25b9ce76eba2b19a59f44e663895f02f90ac223))

### ♻️ Code Refactoring

* decouple documentation and security workflows - now independent tag-triggered only ([7ea649a](https://github.com/bauer-group/automation-templates/commit/7ea649aa800a870890b4d49bb0cca2ee80a0d0af))
* decouple workflows - documentation and security now independent tag-triggered, automatic-release simplified ([20b9ce1](https://github.com/bauer-group/automation-templates/commit/20b9ce16058436c92a7eeb5f0b9a3f853388a8c8))

### 🔧 Maintenance

* **release:** 1.0.5 [skip ci] ([f94807f](https://github.com/bauer-group/automation-templates/commit/f94807fba2309f3d609079d387d1019c4b5f2814))

## [1.0.5](https://github.com/bauer-group/automation-templates/compare/v1.0.4...v1.0.5) (2025-08-29)

### 🐛 Bug Fixes

* add workflow validation comment for testing release workflow ([2336518](https://github.com/bauer-group/automation-templates/commit/2336518ce7154b086ebdb04706344280071dba74))
* remove unnecessary newline before main execution block in generate_readme.py ([31553bf](https://github.com/bauer-group/automation-templates/commit/31553bf7670a30a3e6d00fd8207b924df6c2a2c2))
* resolve tag conflict and ensure semantic-release workflow consistency ([98e4dff](https://github.com/bauer-group/automation-templates/commit/98e4dfff26c7708e780524affe6e12319e6cb87a))
* restore v0.23.0 workflow functionality with git merge strategy and semantic-release output fixes ([bb51862](https://github.com/bauer-group/automation-templates/commit/bb518625f368f0ea101609a96aa576a006fad921))
* test workflow decoupling and validation ([f25b9ce](https://github.com/bauer-group/automation-templates/commit/f25b9ce76eba2b19a59f44e663895f02f90ac223))

### ♻️ Code Refactoring

* decouple documentation and security workflows - now independent tag-triggered only ([7ea649a](https://github.com/bauer-group/automation-templates/commit/7ea649aa800a870890b4d49bb0cca2ee80a0d0af))
* decouple workflows - documentation and security now independent tag-triggered, automatic-release simplified ([20b9ce1](https://github.com/bauer-group/automation-templates/commit/20b9ce16058436c92a7eeb5f0b9a3f853388a8c8))

## [1.0.4](https://github.com/bauer-group/automation-templates/compare/v1.0.3...v1.0.4) (2025-08-29)

### 🐛 Bug Fixes

* add a newline before the main execution block in generate_readme.py ([e875975](https://github.com/bauer-group/automation-templates/commit/e87597539419007d85a05299789fed517992f57e))
* add merge strategy to git pull to resolve divergent branches error ([87f648d](https://github.com/bauer-group/automation-templates/commit/87f648d84128823f8f52ffa1f9e1470087cf5351))
* correct workflow dependencies and external references - remove circular deps, use relative paths ([44fc8e0](https://github.com/bauer-group/automation-templates/commit/44fc8e0c213a0950dbd72d08fd8df415f78d8977))
* remove unnecessary newline before main execution block in generate_readme.py ([68a2f42](https://github.com/bauer-group/automation-templates/commit/68a2f4278dd7d206f1fa5b4542c039740495bbc3))
* use correct semantic-release action output names (release-created, version, tag) ([564f6d2](https://github.com/bauer-group/automation-templates/commit/564f6d28e2f770bd33ad54008a33d6cf03175b52))
* use recursive merge strategy instead of invalid merge strategy ([ea9ed5f](https://github.com/bauer-group/automation-templates/commit/ea9ed5fcf3d9615bc36a495f96c96943c1efcb9a))

### ⏪ Reverts

* restore [@main](https://github.com/main) references in python-automatic-release for external repository usage ([462b0e9](https://github.com/bauer-group/automation-templates/commit/462b0e9199275d8c4006225171fe0c81b9c385ae))

## [1.0.3](https://github.com/bauer-group/automation-templates/compare/v1.0.2...v1.0.3) (2025-08-29)

### 🐛 Bug Fixes

* implement hard reset strategy in security management to prevent conflicts ([f354443](https://github.com/bauer-group/automation-templates/commit/f3544439050956ea6f9d274866650f04d05231d8))
* improve error handling in README generation script ([a3eb933](https://github.com/bauer-group/automation-templates/commit/a3eb93340b4bd5444301695500518f45c8b9c46c))
* remove unnecessary blank line before main execution ([d0f970b](https://github.com/bauer-group/automation-templates/commit/d0f970b14b3a64405d21d42629dd230278d1b72d))
* remove unnecessary blank line before the main function ([02dd4c9](https://github.com/bauer-group/automation-templates/commit/02dd4c946b96971618693e482a6bfe5f83c013dc))
* resolve all workflow issues - correct semantic-release outputs, remove rebase conflicts, add retry logic ([e6e2e91](https://github.com/bauer-group/automation-templates/commit/e6e2e9113382bcd5b1ab2424fd0d8d5a9e29a20e))
* update documentation versions to correct v1.0.2 ([07914bd](https://github.com/bauer-group/automation-templates/commit/07914bd70f25e20cc8d9bae630b83cceb20f7f81))

## [1.0.2](https://github.com/bauer-group/automation-templates/compare/v1.0.1...v1.0.2) (2025-08-29)

### 🐛 Bug Fixes

* correct semantic-release output mapping for proper version/tag display ([96fa89d](https://github.com/bauer-group/automation-templates/commit/96fa89d94aed8845e0a4274b6a44d55aca952664))
* remove unnecessary blank line before main execution ([eac7ed8](https://github.com/bauer-group/automation-templates/commit/eac7ed85cd44dc341acf69ed3800170e5b69f7c4))
* remove unnecessary blank line before main function ([34819b9](https://github.com/bauer-group/automation-templates/commit/34819b95ff55bfc3cebc8c5c302577a8f2a675ff))
* replace rebase with merge in security management to avoid conflicts ([5dfddb3](https://github.com/bauer-group/automation-templates/commit/5dfddb3cf4d6e3da137f05f567efa2c186097f40))
* use correct action output references for version and tag mapping ([01e4de8](https://github.com/bauer-group/automation-templates/commit/01e4de8c19cfc9cbc92f7138136d844647815c2b))

## [1.0.1](https://github.com/bauer-group/automation-templates/compare/v1.0.0...v1.0.1) (2025-08-29)

### 🐛 Bug Fixes

* add newline at end of file in CONFIG.YML and generate_readme.py ([7074bf1](https://github.com/bauer-group/automation-templates/commit/7074bf1c892a9999e86e1b950ed663ab5f71cfa1))
* correct tag output mapping in semantic-release workflow ([9465d92](https://github.com/bauer-group/automation-templates/commit/9465d924e91d74f125822650c87b9e1826407250))

## [1.0.0](https://github.com/bauer-group/automation-templates/compare/v0.25.0...v1.0.0) (2025-08-29)

### ⚠ BREAKING CHANGES

* test major version bump for workflow validation

### 🚀 Features

* add CHANGELOG sync from release tags to main branch ([e423d85](https://github.com/bauer-group/automation-templates/commit/e423d855f5a92402ece98245bd5dccf8ed7348b4))
* Add custom version parameter to documentation and security workflows ([f2866be](https://github.com/bauer-group/automation-templates/commit/f2866be3be03545f8a31c0247a319559ae8df8b2))
* Add example workflow for NocoDB SimpleClient library release process ([d2eb43f](https://github.com/bauer-group/automation-templates/commit/d2eb43f1f0a51ac098835aed264051dd64cc46a6))
* Add tag verification and update documentation/security policies in release tags ([85a7194](https://github.com/bauer-group/automation-templates/commit/85a7194f24859d808b522b5c6a23a2dd67bda486))
* add validation test feature for workflow testing ([4a77a53](https://github.com/bauer-group/automation-templates/commit/4a77a532807576738093830d7d3efc6e4d3fddc9))
* trigger new major release for testing ([e4f9a92](https://github.com/bauer-group/automation-templates/commit/e4f9a927770b805fd866b79f32977c70850e0632))
* Update deployment profiles and workflows for enhanced automation and security ([71abb43](https://github.com/bauer-group/automation-templates/commit/71abb43689380bfeae0e86639753b884f62c4a22))

### 🐛 Bug Fixes

* correct version propagation in semantic-release and CHANGELOG sync ([bac5c9b](https://github.com/bauer-group/automation-templates/commit/bac5c9b3c375fece47fec876068e947103b16d24))
* ensure newline at end of file in deploy_automations.py ([b5ba11b](https://github.com/bauer-group/automation-templates/commit/b5ba11bc943591a4f8418b8dd6d23cedef3a199e))
* improve documentation structure for better readability ([a837d30](https://github.com/bauer-group/automation-templates/commit/a837d3064773f7e5d2153572638927f58679169f))
* remove duplicate v0.26.0 entry from CHANGELOG ([2de0cbf](https://github.com/bauer-group/automation-templates/commit/2de0cbf4ece5ab636e62f5dc085f84482705690a))
* remove outdated CHANGELOG entries to streamline documentation ([4148fea](https://github.com/bauer-group/automation-templates/commit/4148feaf8377187038bd8e06f127d04c211994ff))
* remove test files and update CHANGELOG with proper v1.0.0 entry ([1cdb648](https://github.com/bauer-group/automation-templates/commit/1cdb6483082777c07863318711639bc8f8360d76))
* update validation test for proper workflow testing ([d705e94](https://github.com/bauer-group/automation-templates/commit/d705e94524ec58caf66aa16ea6069bcc411016a2))

### ♻️ Code Refactoring

* Remove custom version parameter from documentation and security updates in release workflows ([4320a34](https://github.com/bauer-group/automation-templates/commit/4320a3446d89992d041d4703f07cdebf8ddf7440))

### 🔧 Maintenance

* **release:** 0.26.0 [skip ci] ([f2ca698](https://github.com/bauer-group/automation-templates/commit/f2ca6984dc3febe5aa67c7184660be905ca9ea55))
* **release:** 1.0.0 [skip ci] ([dba28ec](https://github.com/bauer-group/automation-templates/commit/dba28eca40dc354b2bef3ccd785e92a2bb8ccf07))
