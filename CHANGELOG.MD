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
