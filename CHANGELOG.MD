## [4.13.1](https://github.com/bauer-group/automation-templates/compare/v4.13.0...v4.13.1) (2026-01-18)

### 🐛 Bug Fixes

* Add note for CODECOV_TOKEN handling in Windows validation build step ([a5d5446](https://github.com/bauer-group/automation-templates/commit/a5d544691d3156ef26988d176ab84a3fb657b259))
* Enhance conditions for publishing to NuGet and GitHub based on test results ([3ee8567](https://github.com/bauer-group/automation-templates/commit/3ee8567faa9df686df70b68132871ab20807b0e2))
* Enhance job failure handling for test results and artifact uploads ([1fcd503](https://github.com/bauer-group/automation-templates/commit/1fcd5036990ed4e05f4fcc7be10cb153d8840baf))
* Ensure successful execution before validating and pushing NuGet packages ([3dfd487](https://github.com/bauer-group/automation-templates/commit/3dfd487ab3ffd8c7d6069dfaaf7ca44907e73a46))
* Improve test result handling and coverage reporting in .NET NuGet action ([b501c44](https://github.com/bauer-group/automation-templates/commit/b501c448a48f051629c0d843bf4e0ae82424d4b7))
* Update coverage upload condition to include test execution check ([630894e](https://github.com/bauer-group/automation-templates/commit/630894e5167e67bbe8eb695bfaacee1b8364af27))

## [4.13.0](https://github.com/bauer-group/automation-templates/compare/v4.12.1...v4.13.0) (2026-01-17)

### 🚀 Features

* Add comprehensive documentation for .NET NuGet and semantic-release actions with examples ([755f3a8](https://github.com/bauer-group/automation-templates/commit/755f3a8a30e977dd0e256acb47955d4bd2a4c8e5))

### 🐛 Bug Fixes

* Add assembly signing support with SNK key configuration in dotnet-build workflow ([e4cd23c](https://github.com/bauer-group/automation-templates/commit/e4cd23cef173d8a36b838c16f6a156a419765e8e))
* Add cache support for NuGet lockfile and update semantic-release rules for breaking changes ([6f2913a](https://github.com/bauer-group/automation-templates/commit/6f2913abb16f777c41c269ba21094487a531617b))
* Add cache support for NuGet lockfile in dotnet workflows ([635d81e](https://github.com/bauer-group/automation-templates/commit/635d81e9f6ed0325e37055314e6c2b04addeccfa))
* Add package count and names outputs to .NET NuGet action and workflow ([ffff9c1](https://github.com/bauer-group/automation-templates/commit/ffff9c19ff5e57c485932e351bb49c4e1eb2d2bd))
* Enable Windows targeting for non-Windows platforms in dotnet workflows ([35b999f](https://github.com/bauer-group/automation-templates/commit/35b999f1a3df7bb657d5d1088bfa4599588aca35))
* Enhance .NET NuGet action outputs with package count and names for multi-package solutions ([f791959](https://github.com/bauer-group/automation-templates/commit/f791959ed331c3524c8cdffd3407e54b3bcb34d4))
* Enhance .NET NuGet action with package count output and summary generation options ([4ec108f](https://github.com/bauer-group/automation-templates/commit/4ec108fc26bd47e19b2b3fb996293f7ef6239282))
* Enhance package push process with detailed success/failure counts and summary output ([9e6e15e](https://github.com/bauer-group/automation-templates/commit/9e6e15e985e0d46bb754f7960bbf4614cbfb642e))
* Improve semantic-release configuration by adding support for custom release rules, changelog paths, and extra plugins ([a426ea8](https://github.com/bauer-group/automation-templates/commit/a426ea8d146b72c08414a329e1baf32cbb4ab2f2))
* Preserve JSON string format for git message in semantic-release configuration ([cfd8eae](https://github.com/bauer-group/automation-templates/commit/cfd8eae370f7484b99cf0ec4648f4f2dfd6d4f88))
* Refactor test results handling in dotnet-build workflow for improved clarity and cross-platform compatibility ([aa9bd4a](https://github.com/bauer-group/automation-templates/commit/aa9bd4a9f0876e2e94e6dcb528e2bc15a0a82bbd))
* Simplify release rules by removing redundant breaking change types in semantic-release configuration ([0562caa](https://github.com/bauer-group/automation-templates/commit/0562caa2f1985488b355b0ce0203eebbf75ae664))
* Update dotnet-build workflow to use global-json-file and improve test result handling ([aa77835](https://github.com/bauer-group/automation-templates/commit/aa778355d19fcb9ed3b665362ea6290148b663e3))
* Update matrix strategy to use formatted inputs for OS and .NET version ([d75efab](https://github.com/bauer-group/automation-templates/commit/d75efab0309a744e7ebe4d5a9f29f767ad841d0b))
* Upgrade to actions/setup-dotnet@v5 and add cache support for improved performance ([b6cc9e7](https://github.com/bauer-group/automation-templates/commit/b6cc9e7a80e941b87d42fdb4c5944c60d3da8ff1))

## [4.12.1](https://github.com/bauer-group/automation-templates/compare/v4.12.0...v4.12.1) (2026-01-16)

### 🐛 Bug Fixes

* Resolve output path early in SNK generator script ([652d089](https://github.com/bauer-group/automation-templates/commit/652d0899984a7410fcd1d78f4fd15fdeb0debb57))

## [4.12.0](https://github.com/bauer-group/automation-templates/compare/v4.11.0...v4.12.0) (2026-01-16)

### 🚀 Features

* Update .NET SDK version to 10.0.x and enhance platform matrix support ([f21dbfd](https://github.com/bauer-group/automation-templates/commit/f21dbfde289730da981bb8eef3d343030998a1d5))

## [4.11.0](https://github.com/bauer-group/automation-templates/compare/v4.10.1...v4.11.0) (2026-01-16)

### 🚀 Features

* Add .NET Library Publishing Workflow and related scripts ([9225bbc](https://github.com/bauer-group/automation-templates/commit/9225bbc2bb613d15bfb4f621eb7a6153691c5408))

### 🐛 Bug Fixes

* update AI model description and default value in workflow to gpt-4.1-mini ([5a40148](https://github.com/bauer-group/automation-templates/commit/5a40148c02c6d0c675fcd531ce47c081fce13502))

### 💄 UI/UX Improvements

* Update workflow names to include emojis for better visibility ([daecaf2](https://github.com/bauer-group/automation-templates/commit/daecaf2ccdef3538ac68ff6f2994db9678e1337a))

## [4.10.1](https://github.com/bauer-group/automation-templates/compare/v4.10.0...v4.10.1) (2026-01-13)

### 🐛 Bug Fixes

* Add cache settings for Docker build process ([0480ed9](https://github.com/bauer-group/automation-templates/commit/0480ed9688b63f51f8b06a22203ad6f1d64dd951))

## [4.10.0](https://github.com/bauer-group/automation-templates/compare/v4.9.0...v4.10.0) (2026-01-13)

### 🚀 Features

* Enhance self-hosted GitHub Actions runner documentation and scripts ([a01a687](https://github.com/bauer-group/automation-templates/commit/a01a687bdc267b454f2ab4cebf26db7a4c42e44f))

## [4.9.0](https://github.com/bauer-group/automation-templates/compare/v4.8.0...v4.9.0) (2026-01-13)

### 🚀 Features

* add labels for Dependabot updates in configuration ([bd1bf89](https://github.com/bauer-group/automation-templates/commit/bd1bf89e937a2ee8672ad65580561e8e6f93d503))
* Enhance self-hosted runner support across workflows ([4367389](https://github.com/bauer-group/automation-templates/commit/4367389c0aa77defcb5dec9b9b869105bb8aa0de))

### 🐛 Bug Fixes

* ensure newline before delimiter in AI response output ([9c9ef3e](https://github.com/bauer-group/automation-templates/commit/9c9ef3ed38e1b6000a0f226469bec3c78e97786a))
* improve prompt formatting for AI summary generation ([2988466](https://github.com/bauer-group/automation-templates/commit/2988466e0243a9d886238afa1835f8cf375f1454))
* update branch reference condition for auto-tagging in Docker action ([cec01e4](https://github.com/bauer-group/automation-templates/commit/cec01e4acd6ff7121d65c60ca56833d14f02a88b))

### 🔧 Maintenance

* **ci:** bump actions/checkout from 4 to 6 ([a021f33](https://github.com/bauer-group/automation-templates/commit/a021f33d41d148acf68ef5bf5f29e7c08252cfbf))
* **ci:** bump lewagon/wait-on-check-action from 1.3.4 to 1.4.1 ([25ce20e](https://github.com/bauer-group/automation-templates/commit/25ce20efd47c99e35c3e2aa811bcb087a080d94f))

## [4.8.0](https://github.com/bauer-group/automation-templates/compare/v4.7.0...v4.8.0) (2026-01-06)

### 🚀 Features

* implement automated Docker maintenance workflows with Dependabot and Renovate ([c86ef76](https://github.com/bauer-group/automation-templates/commit/c86ef760485e157720bc3ec09741ea67544a836e))

### 🐛 Bug Fixes

* remove GITHUB_TOKEN input from Claude workflow ([37cb6be](https://github.com/bauer-group/automation-templates/commit/37cb6be6f24ab5e13b11eaf13e99de22f7e65ad5))

## [4.7.0](https://github.com/bauer-group/automation-templates/compare/v4.6.0...v4.7.0) (2026-01-05)

### 🚀 Features

* add Claude Code Assistant workflow and examples ([de53b5c](https://github.com/bauer-group/automation-templates/commit/de53b5cca045552be416018c13fdf8130efd7609))
* add human-readable image size output to Docker build action ([fb527a1](https://github.com/bauer-group/automation-templates/commit/fb527a103c3a53df4146eb01405dd3af58ea9e20))
* add human-readable image size output to pipeline summary ([adef136](https://github.com/bauer-group/automation-templates/commit/adef136e481e92222ac7b659fb5bbe77dfaedc93))
* improve Docker Compose validation by supporting multiple files and enhancing variable extraction ([b37967d](https://github.com/bauer-group/automation-templates/commit/b37967d3c8d1968da591cf759f57a00ce1de7fdf))

### 🐛 Bug Fixes

* clear additional extraheader configs to prevent duplicate header errors in git credentials ([8979574](https://github.com/bauer-group/automation-templates/commit/89795748ede8ecf0df035d19735256fa030a7588))
* clear all extraheader configs to prevent duplicate headers in git credentials ([6787220](https://github.com/bauer-group/automation-templates/commit/6787220223902c62f793650e6c5d9e391db25061))
* implement secure delimiter generation to handle special characters in issue/PR details ([bb780f6](https://github.com/bauer-group/automation-templates/commit/bb780f623b0c635a2b715a74627456570015768c))
* optimize AI prompt preparation and response handling for improved safety and efficiency ([3d80bba](https://github.com/bauer-group/automation-templates/commit/3d80bba108b94d8a5dd89d34fc1018c7e318b2b5))
* update git credentials handling to prevent duplicate header errors in actions/checkout ([fa58449](https://github.com/bauer-group/automation-templates/commit/fa5844958222610c2d9924ff031599d3cbcc50a6))
* update git remote URL to use GitHub token for authentication during fetch ([8abed01](https://github.com/bauer-group/automation-templates/commit/8abed01011fa8bf878aaa07abad7889eee087661))
* use unique delimiters to handle special characters in issue/PR details and fallback summary ([1c7818d](https://github.com/bauer-group/automation-templates/commit/1c7818df1c81f83502192bdcff48acb975053938))

## [4.6.0](https://github.com/bauer-group/automation-templates/compare/v4.5.1...v4.6.0) (2025-12-25)

### 🚀 Features

* Coolify deployment workflow documentation and examples ([1a7d35d](https://github.com/bauer-group/automation-templates/commit/1a7d35df23f3ee9ee00ef7537bf6d3033b3848f3))

### 🐛 Bug Fixes

* enhance security analysis and deployment steps in Docker workflow ([459b4f0](https://github.com/bauer-group/automation-templates/commit/459b4f02092f5c19b68685719cee6b611ddc18d0))
* simplify image size retrieval in Docker build action ([b67aa98](https://github.com/bauer-group/automation-templates/commit/b67aa98b3ce33142f1789d4a28b9c05562bf6a49))

## [4.5.1](https://github.com/bauer-group/automation-templates/compare/v4.5.0...v4.5.1) (2025-12-25)

### 🐛 Bug Fixes

* enhance Docker image build process with improved security scanning and output handling ([05d798c](https://github.com/bauer-group/automation-templates/commit/05d798c480b8b547252ca2a3d7e067d026230701))
* enhance Docker workflows with improved security scanning and output handling ([9338714](https://github.com/bauer-group/automation-templates/commit/93387140417364279333cbfeca41ab5e64a8cdb1))
* improve handling of warnings in Docker Compose validation output ([ab5e08a](https://github.com/bauer-group/automation-templates/commit/ab5e08a4841b5b78dcc6309c53a01007da425cc1))
* improve shell script detection and output handling in validation workflow ([3bfa9f5](https://github.com/bauer-group/automation-templates/commit/3bfa9f5c57785a9c4fc4bde155b92cf45fe4ed10))
* improve warning detection in Docker Compose validation output ([ff184e0](https://github.com/bauer-group/automation-templates/commit/ff184e02795d23c723832e18c24864d2cd577244))

### ♻️ Code Refactoring

* optimize shell script validation logic and improve output formatting ([c1eae8b](https://github.com/bauer-group/automation-templates/commit/c1eae8bc0ae4b4e0ec688e9164d08dfd00328bb4))

## [4.5.0](https://github.com/bauer-group/automation-templates/compare/v4.4.0...v4.5.0) (2025-12-24)

### 🚀 Features

* Add Docker Compose and Shell Script validation modules with examples ([3708514](https://github.com/bauer-group/automation-templates/commit/370851478a38ac54df04bf67c835954d7bca9560))
* add support for additional semantic-release plugins in workflow ([4648c8c](https://github.com/bauer-group/automation-templates/commit/4648c8c0f60f1df531c7fba64303ac46b53e7ada))
* enhance Dockerfile version update logic to support release version input ([0050a98](https://github.com/bauer-group/automation-templates/commit/0050a98cb765da1af6e0588efd1f182247a79de2))
* refine Dockerfile version update conditions to prevent conflicts with version-from-dockerfile ([805ca9f](https://github.com/bauer-group/automation-templates/commit/805ca9fe3a60c47ce25374e0a9093f0fac026ddc))

### 🐛 Bug Fixes

* ensure boolean checks for Docker Hub README sync conditions ([10ef042](https://github.com/bauer-group/automation-templates/commit/10ef0420537e25e0f068be4f0fc73587f6f4f314))
* ensure Dockerfile content is saved before git operations to prevent data loss ([7afdb83](https://github.com/bauer-group/automation-templates/commit/7afdb831874c31b27d0047de607778872830d71d))

### ♻️ Code Refactoring

* improve AI response processing and cleanup logic ([9befbce](https://github.com/bauer-group/automation-templates/commit/9befbce951d4141895a080ee730f459a361a2a67))
* streamline AI response processing and improve variable handling ([df4bdf7](https://github.com/bauer-group/automation-templates/commit/df4bdf7dfeaa987a76604f0789363beef5ae1604))

### 🔧 Maintenance

* **deps:** bump actions/cache from 4 to 5 ([ecb52b5](https://github.com/bauer-group/automation-templates/commit/ecb52b545708c57b99a69af4cc0f7917fba6a731))
* **deps:** bump actions/checkout from 4 to 6 ([77fc57e](https://github.com/bauer-group/automation-templates/commit/77fc57e925c777142719ab82d0965c25d0b3b2a2))
* **deps:** bump actions/download-artifact from 6 to 7 ([c1ab329](https://github.com/bauer-group/automation-templates/commit/c1ab32941870e4128af569b487c587eb658b4d9b))
* **deps:** bump actions/upload-artifact from 5 to 6 ([3cafdfd](https://github.com/bauer-group/automation-templates/commit/3cafdfdd1f396e9ae3314003c99b1bc51ff3a172))
* **deps:** bump mukunku/tag-exists-action from 1.6.0 to 1.7.0 ([c83545d](https://github.com/bauer-group/automation-templates/commit/c83545db48ac20a88d2e2c13e0ff62d1e4727820))

## [4.4.0](https://github.com/bauer-group/automation-templates/compare/v4.3.0...v4.4.0) (2025-12-09)

### 🚀 Features

* add release version input and tagging logic to Docker build workflows ([4e06054](https://github.com/bauer-group/automation-templates/commit/4e0605468367896c4774fba5d05db8accac9e40e))

### 🐛 Bug Fixes

* add permissions section for reusable Docker build workflow ([57ee672](https://github.com/bauer-group/automation-templates/commit/57ee6726f3e67f04b0f79186bf60a0482f82d338))
* ensure secondary tags are filtered and handle empty lines in Docker build workflow ([0c650cd](https://github.com/bauer-group/automation-templates/commit/0c650cd9999a0c5b8e1f47af9caca5009ec06fb0))
* remove unnecessary permissions for actions in Docker build workflow ([5cc233c](https://github.com/bauer-group/automation-templates/commit/5cc233c981fd7457879b2749b3f53ecb519d89b1))

## [4.3.0](https://github.com/bauer-group/automation-templates/compare/v4.2.1...v4.3.0) (2025-12-09)

### 🚀 Features

* add Docker Build & Push workflow for GitHub Container Registry and Docker Hub ([3360d95](https://github.com/bauer-group/automation-templates/commit/3360d95f0da82b2c896753f693ea482109a71e4b))
* add semver tag generation from Dockerfile version in docker-build action and workflow ([3334cba](https://github.com/bauer-group/automation-templates/commit/3334cbaf194984278467834e2b616fb02003365c))

## [4.2.1](https://github.com/bauer-group/automation-templates/compare/v4.2.0...v4.2.1) (2025-12-09)

### 🐛 Bug Fixes

* simplify auto-tagging logic in docker-build action ([5875c1d](https://github.com/bauer-group/automation-templates/commit/5875c1d48784f8347915d93681e68909c59595f9))
* update CodeQL SARIF upload action to v4 in multiple workflows ([7c36060](https://github.com/bauer-group/automation-templates/commit/7c3606074fc02728803f5c1a0a9e95a361c2dd33))

## [4.2.0](https://github.com/bauer-group/automation-templates/compare/v4.1.0...v4.2.0) (2025-12-09)

### 🚀 Features

* add functionality to commit Dockerfile version updates automatically on tag push ([978c1e8](https://github.com/bauer-group/automation-templates/commit/978c1e88dd739932e4dae7d27882ae04f74a0027))
* add support for extracting metadata from secondary Docker registry and combining tags for multi-registry push ([574d2a9](https://github.com/bauer-group/automation-templates/commit/574d2a9a8df484ffa66e4784d6fa6ab3c726516d))
* improve Docker Hub image name determination based on publish target settings ([9a819b4](https://github.com/bauer-group/automation-templates/commit/9a819b49225735502b72e8981df2f84587913031))
* update image name inputs for Docker Hub and GitHub Container Registry in workflow ([6ca71f8](https://github.com/bauer-group/automation-templates/commit/6ca71f847001fb1cb196de8daba744e50f089713))

## [4.1.0](https://github.com/bauer-group/automation-templates/compare/v4.0.0...v4.1.0) (2025-12-08)

### 🚀 Features

* add support for secondary Docker registry configuration in build workflow ([361b29f](https://github.com/bauer-group/automation-templates/commit/361b29f0844a6a6ba10472ab4fd2939998c8df61))
* add version extraction and update options for Dockerfile in build workflow ([d90a3e6](https://github.com/bauer-group/automation-templates/commit/d90a3e6bdcd84a46a5f7dc1d523e4f0c5d5134a8))
* enhance Docker registry configuration to support publish target options ([e445211](https://github.com/bauer-group/automation-templates/commit/e4452115a21ae6b0377ef899c39a251ddd09ae1b))

### 🐛 Bug Fixes

* improve handling of issue and PR details in AI summary workflow ([481e25e](https://github.com/bauer-group/automation-templates/commit/481e25e1fa7153b3de5131ac59345dd0783e912d))
* Refactor Docker workflows for improved security, multi-platform support, and README synchronization ([a7b5ffe](https://github.com/bauer-group/automation-templates/commit/a7b5ffeaa0e4b2e5fa6f8fac7b11a76eef66b749))
* update label formatting for Docker image metadata to include repository URL and SHA ([b344c83](https://github.com/bauer-group/automation-templates/commit/b344c83de159a38829ebc2360d17074d93092b99))
* update registry username handling to use secrets for sensitive values ([5a0bbc4](https://github.com/bauer-group/automation-templates/commit/5a0bbc462253aaacfe3ea13f6b2eef744ddb5d25))
* update tag handling logic for Docker image based on branch type ([4b00b4b](https://github.com/bauer-group/automation-templates/commit/4b00b4bbc2718fb5d3bd859a6dc7bfed3cd0f160))
* use heredoc for safer variable handling in PR title, body, and comment template ([e813343](https://github.com/bauer-group/automation-templates/commit/e81334366676008cbc3091296c4d9c9322c64374))

### 🔧 Maintenance

* **deps:** bump actions/download-artifact from 4 to 6 ([1edd3b7](https://github.com/bauer-group/automation-templates/commit/1edd3b76a8a669d9a8f94d331e321621c773a304))
* **deps:** bump actions/github-script from 7 to 8 ([8a65680](https://github.com/bauer-group/automation-templates/commit/8a656805be6f301e5397a3561a7a40c80aacf5f7))
* **deps:** bump FriendsOfShopware/shopware-cli-action from 2 to 3 ([e76fedb](https://github.com/bauer-group/automation-templates/commit/e76fedb138d0c7717c802a11b738a2b8358929d6))

## [4.0.0](https://github.com/bauer-group/automation-templates/compare/v3.2.0...v4.0.0) (2025-10-30)

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
* test major version bump for workflow validation
* All previous release history has been reset

### 🚀 Features

* add .claude/ to .gitignore ([dcaf764](https://github.com/bauer-group/automation-templates/commit/dcaf7642f6348458bb8bd6789d565f30de966eda))
* add .gitignore for Python project and remove obsolete test scripts ([57da1c6](https://github.com/bauer-group/automation-templates/commit/57da1c691261d379b9b932a658912b78d7a33c4f))
* add automatic release management workflow with enhanced features and artifact generation ([55b6c42](https://github.com/bauer-group/automation-templates/commit/55b6c42e2370fe2227465f8703e0958477e572d4))
* Add bug report template for improved issue tracking ([ae86590](https://github.com/bauer-group/automation-templates/commit/ae865908a9ff9f1d49e4cf6211c1fa1610db3079))
* add CHANGELOG sync from release tags to main branch ([da701ac](https://github.com/bauer-group/automation-templates/commit/da701ac96957769ddbe02ca2c501fab6c27fbc08))
* Add Code of Conduct to promote a welcoming and inclusive community ([cb5300f](https://github.com/bauer-group/automation-templates/commit/cb5300fa09e8ad973ea758d46d087a228d43fdce))
* Add comprehensive .NET Build & Test workflow documentation ([9e9c9c7](https://github.com/bauer-group/automation-templates/commit/9e9c9c70128c091850cc51cc0e0f53668e2aa2d0))
* Add comprehensive CI/CD workflows for Makefile projects ([52af7e4](https://github.com/bauer-group/automation-templates/commit/52af7e4d92555b27fcda440ebfea27ce30efb0c3))
* Add comprehensive Node.js Build & Publish workflow documentation ([c9371f0](https://github.com/bauer-group/automation-templates/commit/c9371f0d45d10b1069183ba0daad2494e5ffe949))
* Add comprehensive secrets naming convention documentation ([eb38b0d](https://github.com/bauer-group/automation-templates/commit/eb38b0ddd7a04d48543649c89550664d04b700ea))
* Add comprehensive Teams notifications workflows ([16aa722](https://github.com/bauer-group/automation-templates/commit/16aa722af4be0e596cc3a0e0fe1733f37a23512d))
* Add comprehensive Zephyr RTOS build examples and workflows ([3f7f0c8](https://github.com/bauer-group/automation-templates/commit/3f7f0c82e0771ff752031939ef6da58fd1197c1e))
* Add conservative repository cleanup workflow ([aa613fc](https://github.com/bauer-group/automation-templates/commit/aa613fc17ac64ad34a498f6e38f8087d7710fcc0))
* Add contributing and security policy documentation ([68805ca](https://github.com/bauer-group/automation-templates/commit/68805ca614f580c88b32d4ea83eb09f4e73ea9b3))
* Add custom version parameter to documentation and security workflows ([184a2a7](https://github.com/bauer-group/automation-templates/commit/184a2a7d4a86f30873233cf1b0ac7a6ec63c094e))
* add deployment scripts and configuration for automation templates ([f0f3dfd](https://github.com/bauer-group/automation-templates/commit/f0f3dfdb7c3a0a881dd73749ee271dd62c1da368))
* Add Docker Hub README synchronization workflow example ([bbb9969](https://github.com/bauer-group/automation-templates/commit/bbb9969619cc09753da369d38be9396a3c014469))
* Add dual security scan meta package and enhance release management workflow ([4da9ce3](https://github.com/bauer-group/automation-templates/commit/4da9ce37fd3c5eb3419f92db0ff4b60779ca795c))
* add enterprise profile with advanced workflows and actions to deployment configuration ([89e1949](https://github.com/bauer-group/automation-templates/commit/89e1949f2086d359e5ea3828c104b53940fecf21))
* Add example workflow for NocoDB SimpleClient library release process ([5d92ac2](https://github.com/bauer-group/automation-templates/commit/5d92ac2f53762478489072af9b8441ea92a60246))
* Add feature request template to enhance issue tracking ([748310d](https://github.com/bauer-group/automation-templates/commit/748310dd12030e5dd31a924b8c97a061cf58b93a))
* Add feature request template to streamline enhancement suggestions ([69d4003](https://github.com/bauer-group/automation-templates/commit/69d4003317856fd1a8c54f534dc954d67b6d2a4f))
* add force-release option to release management job ([9d16917](https://github.com/bauer-group/automation-templates/commit/9d16917b58e1ef76cb121a4dad839f164f3f8db8))
* add force-release option to semantic release configuration ([11870ec](https://github.com/bauer-group/automation-templates/commit/11870ec11e2c893b11f7988a8237bdb3ab2e8957))
* add force-release option to semantic release workflows ([4b98bb1](https://github.com/bauer-group/automation-templates/commit/4b98bb1c365ef642c119669d99b7b8d2375bd586))
* add GH_PAT secret support for private repository access in meta-repository-sync ([6d5dead](https://github.com/bauer-group/automation-templates/commit/6d5dead10eb0736c790088b7d38456ebcd94f3ad))
* Add GitHub token environment variable for release creation step ([42c9285](https://github.com/bauer-group/automation-templates/commit/42c92857304acaefe93e590ec427c003d351752d))
* Add guide for local GitHub workflow testing using nektos/act ([67b5fb2](https://github.com/bauer-group/automation-templates/commit/67b5fb27c6dbf2f38cff627deb73d1232c615afb))
* add initial Dependabot configuration for GitHub Actions updates ([903bc1b](https://github.com/bauer-group/automation-templates/commit/903bc1b6539a837f04e674ae1a6346e610cce6d7))
* add meta repository sync workflow documentation and examples ([c36c39c](https://github.com/bauer-group/automation-templates/commit/c36c39c0222c3149e646f4de1a62b8598d4603c8))
* Add modular workflows for issue summarization, CI/CD, documentation management, and manual release processes ([83c798f](https://github.com/bauer-group/automation-templates/commit/83c798fca8eef977a75e664cc537555ea192e892))
* Add modular workflows for license compliance, security scanning, PR validation, and release management ([bac2927](https://github.com/bauer-group/automation-templates/commit/bac29277bb34b02957fb820f04e8b4b4fb87521a))
* Add modular workflows for Next.js Docker deployment, NPM package publishing, and React app deployment ([c841a3d](https://github.com/bauer-group/automation-templates/commit/c841a3dd70603e922e38ad9f5520ca03534f5b81))
* Add NocoDB SimpleClient release workflow example ([4fbd8f0](https://github.com/bauer-group/automation-templates/commit/4fbd8f06b11679f3259f49d87ab335ffc1afc9b6))
* add notification level configuration for Teams notifications ([2c1d03a](https://github.com/bauer-group/automation-templates/commit/2c1d03a2b93290553b1d2815e18abe5f3613865a))
* add PR Labeler & Triage module with configuration files and workflows ([74947cc](https://github.com/bauer-group/automation-templates/commit/74947cceae798693496b64a7cba9f366d97db75b))
* add project type support and workflow-specific configurations to deployment scripts ([1ac8083](https://github.com/bauer-group/automation-templates/commit/1ac808391636af884a2c899fad924156b4d5da5e))
* Add Python automatic release workflow with security scans and publishing steps ([e18c562](https://github.com/bauer-group/automation-templates/commit/e18c562d5c25291f28b83bceebacc292bfcf4a69))
* Add Python package release examples and documentation ([1a91c34](https://github.com/bauer-group/automation-templates/commit/1a91c34b19d4bf0659a2b5dd5529955a8a1f4fc3))
* Add reusable .NET Desktop build workflow with WPF support ([687c955](https://github.com/bauer-group/automation-templates/commit/687c955ac26a621ce1f28dde6049eafb9149b6c9))
* Add reusable Python package publish workflow with extensive configuration options ([3c7fe22](https://github.com/bauer-group/automation-templates/commit/3c7fe22931000b802209a4975e3bb130e93977e1))
* add reusable workflows for README generation and release process ([c6a695e](https://github.com/bauer-group/automation-templates/commit/c6a695e208752aaf9a6f29d89286043994f25824))
* Add Security Policy Generator Action and Workflow ([5e6339f](https://github.com/bauer-group/automation-templates/commit/5e6339fbdd5b20e49c1614191b9ebf41e3eaea37))
* Add setup.py to installation guide update in release workflow ([f5dbd92](https://github.com/bauer-group/automation-templates/commit/f5dbd92f9ee3a260f0f81384de1d3dda92197721))
* add skip-ci option to commit message for CI workflow control ([d00e9c8](https://github.com/bauer-group/automation-templates/commit/d00e9c85699447730c063895094a959d28de4e8d))
* Add support for Ubuntu 24.04 in nektos/act configuration ([74a5572](https://github.com/bauer-group/automation-templates/commit/74a5572f03b8aea0b5e33680b6bea9aafa406200))
* Add tag verification and update documentation/security policies in release tags ([19992a5](https://github.com/bauer-group/automation-templates/commit/19992a5f8f65b4a4fc68edca0089f12c037b4d9d))
* add validation test feature for workflow testing ([a4dee91](https://github.com/bauer-group/automation-templates/commit/a4dee9138d8bea6bac1861634c9d52107ee01aa3))
* Add workflow logs feature to Microsoft Teams notifications for enhanced visibility ([357c873](https://github.com/bauer-group/automation-templates/commit/357c8736b0aa33ada8a7bda960ac9c7775ef49c8))
* Add workflow validation script to check for issues in GitHub Actions workflows ([eb4188e](https://github.com/bauer-group/automation-templates/commit/eb4188ec9e967f9d59a8f7b9e2daf6f35463bb9f))
* aktualisiere Konfigurationsdateien für PR-Labeler und Triage-Module zur Verbesserung der Struktur und Wartbarkeit ([5b650bd](https://github.com/bauer-group/automation-templates/commit/5b650bd6cb1cc7db289793e206907bb33a0d1b4b))
* aktualisiere Lizenz-Compliance-Workflow mit Zählung verbotener und unbekannter Lizenzen ([4d82809](https://github.com/bauer-group/automation-templates/commit/4d82809755b7ef8d9da05f98e959f7385a86c4eb))
* aktualisiere README und entferne 'delete_repo' Scope; schließe nur offene Pull Requests ([e8a351c](https://github.com/bauer-group/automation-templates/commit/e8a351c3902131b8206681a000b142951fa37da3))
* Aktualisiere README und Workflow-Dokumentation für verbesserte Klarheit und Konsistenz ([a36381b](https://github.com/bauer-group/automation-templates/commit/a36381bc20d26a0cc1838ca50748f86cae306820))
* Aktualisiere README und Workflow-Dokumentation für verbesserte Klarheit und Konsistenz ([0feb331](https://github.com/bauer-group/automation-templates/commit/0feb3312873c03a1c6b06d4fb7689c232a9e6118))
* aktualisiere Workflow-Dokumentation und migriere zu Semantic Release ([e9d7559](https://github.com/bauer-group/automation-templates/commit/e9d75590abe08fdf9e0a1464393e47a502965277))
* aktualisiere Workflow-Trigger für Tags und verbessere die AI Issue Summary Workflow-Konfiguration ([d3a6c66](https://github.com/bauer-group/automation-templates/commit/d3a6c66fb2abe0aa9a853196fd7ad0809eaeeeae))
* aktualisiere Workflow-Trigger für Tags und verbessere Versionserkennung ([76a5cd9](https://github.com/bauer-group/automation-templates/commit/76a5cd91360032589bc54504d45052fcf75ceeff))
* aktualisiere Workflows und entferne veraltete Dateien für verbesserte Release-Management-Funktionalität ([cc333ca](https://github.com/bauer-group/automation-templates/commit/cc333caf674f10a25791933afb9492bd4492a377))
* Allow security scan, license compliance, and release management to run on workflow dispatch ([34a28b4](https://github.com/bauer-group/automation-templates/commit/34a28b467ee2559f48149d38dcc03b0a506b043d))
* Consolidate workflows and enhance README generation ([de84d56](https://github.com/bauer-group/automation-templates/commit/de84d56d4636c3686499665bc3e191f7212b5154))
* Enable explicit documentation and security management updates after successful releases ([a610509](https://github.com/bauer-group/automation-templates/commit/a610509647e44a68a7f4e6c25b0e0596778659d3))
* Enable force update option in documentation and security management workflows ([6ee38d8](https://github.com/bauer-group/automation-templates/commit/6ee38d8034a8bd76fcb8df415131d44cad4698dd))
* Enhance documentation workflow to support triggering from other workflows ([14709bd](https://github.com/bauer-group/automation-templates/commit/14709bd115de844315b7f48f1459e59bfed7b4e2))
* enhance Python automatic release workflow with reusable inputs and improved security scan options ([268f64a](https://github.com/bauer-group/automation-templates/commit/268f64a9d6317bda8c3766b049b0847e420bbd6d))
* enhance Python package installation logic for modern and legacy projects ([07f96b9](https://github.com/bauer-group/automation-templates/commit/07f96b999eeb7be0a0a818d1e182780b4b3585d0))
* Enhance README generation with advanced templating and workflow integration ([da95a79](https://github.com/bauer-group/automation-templates/commit/da95a7940dda8fef9c922fc84c830b0270a2ed01))
* Enhance README management workflow with validation and scheduling ([a7730e8](https://github.com/bauer-group/automation-templates/commit/a7730e869109c4a5d3c8bb9afe1814f307bb7380))
* Enhance README with project resources and support information ([af3ad9a](https://github.com/bauer-group/automation-templates/commit/af3ad9a251bc12d0671d4a60dba4133f46ea4ff1))
* enhance release dashboard with detailed status formatting and improved summaries ([3214051](https://github.com/bauer-group/automation-templates/commit/3214051b5cc4fa872b1a70f917421c39e323c682))
* enhance unittest integration with XML output and report checks ([808031d](https://github.com/bauer-group/automation-templates/commit/808031d216ef8aac651a0ea6d984921aa2023a2c))
* enhance workflows with detailed input descriptions for PR labeler and Teams notifications ([372d59b](https://github.com/bauer-group/automation-templates/commit/372d59b38c078d16ef190d4067d37cfe68773627))
* entferne nicht benötigte Eingaben und Geheimnisse aus dem Artifact-Generierungs-Workflow ([61c8dcf](https://github.com/bauer-group/automation-templates/commit/61c8dcfd5bdfce0734f09d85c6af79ff3e954618))
* Entferne veraltete CHANGELOG.md-Datei zur Konsolidierung der Dokumentation ([e8a68d4](https://github.com/bauer-group/automation-templates/commit/e8a68d4cf9f1108e814c78f2b311afef85efdb95))
* Entferne veraltete Konfigurationsdatei und aktualisiere README für die Enhanced Release Management Workflow ([9bfa9ed](https://github.com/bauer-group/automation-templates/commit/9bfa9ed48a7ad138d477ec23da3ed6bf56f75df1))
* Entferne veraltete Workflow- und Konfigurationsdateien für das Release-Management ([572d7f3](https://github.com/bauer-group/automation-templates/commit/572d7f3e0d9b349d251e3da07ea92cd66ebb19c7))
* erweitere Artefakt-Generator mit neuen Statusausgaben für Quellarchive, Binaries und Docker-Images ([a281686](https://github.com/bauer-group/automation-templates/commit/a2816864ce350e97c3fcb155ece630e81a974b2e))
* erweitere Berechtigungen für CI/CD-Workflow um Prüf- und Sicherheitsereignisse ([de94c7f](https://github.com/bauer-group/automation-templates/commit/de94c7fed9bb402ea4d23aa7141822537cbad06b))
* erweitere README mit Authentifizierungsoptionen und verbessere Token-Berechtigungen; füge Protokollierung für Berechtigungsprobleme hinzu ([7f2cb7b](https://github.com/bauer-group/automation-templates/commit/7f2cb7b15b2ae43eab85809cae610725008a9f27))
* füge AI-Prompt-Vorlagen und Workflow für automatisierte Zusammenfassungen von Issues und PRs hinzu ([a843180](https://github.com/bauer-group/automation-templates/commit/a84318061602f36c669e5709115acb2701b424d7))
* füge automatisiertes Meta-Repository-Synchronisierungssystem hinzu ([c496776](https://github.com/bauer-group/automation-templates/commit/c4967761f4287607adf4475946e50bc70255a505))
* füge automatisiertes Setup-Skript für Windows-Runner hinzu ([7d5f4c4](https://github.com/bauer-group/automation-templates/commit/7d5f4c4b9246ced55faf99f9726e577af02128ca))
* füge Automatisierung für Issues und PRs hinzu, einschließlich Konfiguration und Beispiel-Workflow ([4854420](https://github.com/bauer-group/automation-templates/commit/4854420c704f72f7c19d2ba80f22879ae89be799))
* füge Beispiel-README-Generator-Workflow hinzu ([08e736d](https://github.com/bauer-group/automation-templates/commit/08e736d8bc95d630647fd29c2dd3d37b1f3ccb54))
* füge CI/CD-Pipeline mit modularen Workflow-Komponenten hinzu ([9578da6](https://github.com/bauer-group/automation-templates/commit/9578da657013f0040c0ee7eb48677d4176481314))
* füge Konfigurationsdateien für das Python-Paket und den Semantic Release-Workflow hinzu ([70116b2](https://github.com/bauer-group/automation-templates/commit/70116b2578e58911a75e1b981dd259435c8e6e17))
* Füge neue CHANGELOG.md-Datei hinzu ([5a96b96](https://github.com/bauer-group/automation-templates/commit/5a96b961a46c4b327a4644453db0b915f2f8ac61))
* füge neue Skripte für die Verwaltung von Branch-Protection-Regeln hinzu ([1b06eb8](https://github.com/bauer-group/automation-templates/commit/1b06eb8f896f1822c2a4a45a44b838a4afc83b2f))
* füge plattformunabhängiges Python-Tool zur Verwaltung von Branch-Protection-Regeln hinzu ([7c45c1f](https://github.com/bauer-group/automation-templates/commit/7c45c1f99ba8378905fd54b104fe51600c2fcaa1))
* füge Skript zum Setzen von Branch-Protection-Regeln für GitHub-Repos hinzu ([0fad381](https://github.com/bauer-group/automation-templates/commit/0fad381560af792e5fd2e6d3174941ecd5046c34))
* füge Unterstützung für private Repositories hinzu und aktualisiere README-Vorlage ([d3a39f6](https://github.com/bauer-group/automation-templates/commit/d3a39f6ac4ce907d1b0661d5c2e018d436f1655a))
* füge Unterstützung für private Repositories in Workflow-Konfigurationen hinzu ([28c28f1](https://github.com/bauer-group/automation-templates/commit/28c28f19b5b870333f1f1fa04fec324e38312359))
* füge vollständige Konfiguration für GitHub Actions Runner hinzu ([1dc9aac](https://github.com/bauer-group/automation-templates/commit/1dc9aac415ff9848a28fecc17dd565f732a2b08a))
* implement Action Resolver for dynamic action path resolution in workflows ([585d8c9](https://github.com/bauer-group/automation-templates/commit/585d8c9c41139a382fe1f2a694f94a912c316b0e))
* implement CODEOWNERS file and enhance release workflow documentation ([9146a9a](https://github.com/bauer-group/automation-templates/commit/9146a9a032c8a363120d574daf812bd10f8dfac0))
* implement dynamic configuration for SECURITY.MD generation and add README for security policy management ([d59ba4d](https://github.com/bauer-group/automation-templates/commit/d59ba4d2051869c5a31cae9e9a6a1033ed58d1c1))
* Implement Enhanced Release Management Workflow with Security Scanning and License Compliance ([c1810f4](https://github.com/bauer-group/automation-templates/commit/c1810f4ec0665ccb92eb467aa143a80d356cff05))
* implement GitHub Repository Cleanup Tool with various wrappers and documentation ([3d7fb9a](https://github.com/bauer-group/automation-templates/commit/3d7fb9a77d3846ca9a209afbddc338bd66839671))
* implement OAuth authentication for GitHub Cleanup Tool with browser-based login and PowerShell support ([5bb9ffb](https://github.com/bauer-group/automation-templates/commit/5bb9ffbccac62c7906b49924b30c24e0679e288a))
* Implement Python-based Automation Templates Deployment Tool ([a64679a](https://github.com/bauer-group/automation-templates/commit/a64679adab40ee36d37afca2ed45b0e2d18f9ab9))
* implement semantic release and changelog generation actions ([592126a](https://github.com/bauer-group/automation-templates/commit/592126a0d079705fa8b012120af6bca00f5f5e8d))
* implement universal fallback release logic and enhance dashboard output ([fbd0171](https://github.com/bauer-group/automation-templates/commit/fbd0171b9355142d5e6e92bb78e6a72cdaaa2354))
* implement universal release management system ([f1aac52](https://github.com/bauer-group/automation-templates/commit/f1aac52d813b09292c21bb5e6c17d25d0514a694))
* Implementiere Composite Actions für README-Generierung und Release-Management ([9239006](https://github.com/bauer-group/automation-templates/commit/923900643b662d19cedf0fc63916e0bd86273c61))
* Implementiere Dual Security Scan mit Gitleaks und GitGuardian ggshield Optionen ([2455dae](https://github.com/bauer-group/automation-templates/commit/2455dae8833631237bb61b046ffc5d45701c4bf3))
* initialize enhanced release management system ([38f8f32](https://github.com/bauer-group/automation-templates/commit/38f8f32fa2ce86bef015918dcd6da997e1b72ffb))
* integriere automatische Dokumentationsupdates bei Releases und verbessere Workflow-Konfiguration ([aee42b8](https://github.com/bauer-group/automation-templates/commit/aee42b8896c7ced4291e368863b8e26ebccc4daf))
* optimize README template and workflow system ([3e25614](https://github.com/bauer-group/automation-templates/commit/3e25614d6fe603a4c27aad60c95b04eec3008870))
* Professional refactor to Composite Actions architecture ([eab8ff8](https://github.com/bauer-group/automation-templates/commit/eab8ff8e864291281b97b79b9608cdbdc9a83aa0))
* refactor action path resolution for Teams notifications to use explicit paths for local and external workflows ([4652bdf](https://github.com/bauer-group/automation-templates/commit/4652bdf66b64883704b4f232fd6601acb09683f4))
* Refactor enhanced release management workflow to use GitHub scripts for improved readability and maintainability ([c549dde](https://github.com/bauer-group/automation-templates/commit/c549ddeab45c1bdcbafe040a311f7cfdbc74a776))
* refactor README generator action to work inline without external scripts ([d3a533d](https://github.com/bauer-group/automation-templates/commit/d3a533d7df3753768473d97be203b0d8bf2caa70))
* remove obsolete Python script for README generation ([aa25876](https://github.com/bauer-group/automation-templates/commit/aa2587659225ebd72f34833f59ca842d48e2425e))
* Reset release system - clean slate for new versioning ([effbf8d](https://github.com/bauer-group/automation-templates/commit/effbf8d0acf554ffdeb5426149d901057d982010))
* restore tag-triggered documentation and security workflows ([c571d45](https://github.com/bauer-group/automation-templates/commit/c571d451869ef047b9dceff06e78bfdc5396f6c5))
* Shopware 5 Build System added ([b92be27](https://github.com/bauer-group/automation-templates/commit/b92be27b1ded80dcfc52420aab8482fbe94d9ce7))
* test improved dashboard display without large GitLeaks header ([a298dd3](https://github.com/bauer-group/automation-templates/commit/a298dd3268a950fccef59bc3c2de2ae59860c048))
* trigger new major release for testing ([2d90460](https://github.com/bauer-group/automation-templates/commit/2d90460726519807ca2b90b5838d4e7787705598))
* update action path resolution for local and external workflows in Teams notifications ([bb15acb](https://github.com/bauer-group/automation-templates/commit/bb15acb003f644cf17953f8a1507b91cfdb4c436))
* update action references to use explicit paths for modular components in workflows ([65b8429](https://github.com/bauer-group/automation-templates/commit/65b84291b9319be85d0c5b2b8e4ec2a5d82c83cd))
* update auto-merge action to include 'release-please[bot]' as allowed author and switch to curl for API calls ([4cf4dbd](https://github.com/bauer-group/automation-templates/commit/4cf4dbd2b02c3abb6c761bfcc09d6abef952ed12))
* Update changelog with new features, changes, and bug fixes for improved clarity ([4e45bd6](https://github.com/bauer-group/automation-templates/commit/4e45bd6a343486a29672e56561918105def7b73a))
* Update changelog with new features, changes, and bug fixes for improved clarity and organization ([e5b28f4](https://github.com/bauer-group/automation-templates/commit/e5b28f460140a2a34c3bac4eade36338d457e049))
* Update deployment profiles and workflows for enhanced automation and security ([83db789](https://github.com/bauer-group/automation-templates/commit/83db789bb50acb69590bc2cf9fa4f6c08b46c7da))
* Update enhanced release configuration and remove outdated documentation ([341d3ab](https://github.com/bauer-group/automation-templates/commit/341d3ab17a70f37f87cfac8502edb557f58773ba))
* update enhanced release management workflow with new features and improved configurations ([f5c9d80](https://github.com/bauer-group/automation-templates/commit/f5c9d80a55b07f80273e7444d498c63bf7e55d0a))
* Update issue templates for improved clarity and structure; add new documentation and security vulnerability templates ([32911d2](https://github.com/bauer-group/automation-templates/commit/32911d2221e7b7be5e4edb44be88adec474cd427))
* Update Python automatic release workflow with enhanced versioning and installation guide ([9a3476e](https://github.com/bauer-group/automation-templates/commit/9a3476e24db8be5d786cc9bb29cade022b7cd09d))
* update README and add scripts for GitHub Repository Cleanup with Device Flow authentication ([c242056](https://github.com/bauer-group/automation-templates/commit/c242056c2b45cbc76a2c03b96bebfa274e446f8f))
* update README and workflow files for enhanced README generation ([9953a8d](https://github.com/bauer-group/automation-templates/commit/9953a8d07907319662ae19cb805322cd7604631d))
* Update README generation and release workflows with enhanced features and validation ([1dfc12a](https://github.com/bauer-group/automation-templates/commit/1dfc12ab0f478e820b061ccda9648c8b0a012632))
* Update release workflows to use googleapis/release-please-action and enhance example with force-release input ([3e3efd1](https://github.com/bauer-group/automation-templates/commit/3e3efd1d55f9f1e3b1b0f0f636d42857bfd2cccf))
* Update repository cleanup module name for clarity ([32f5c5c](https://github.com/bauer-group/automation-templates/commit/32f5c5c28851b03d865b5a8a7a8040f371e34d53))
* Update version to 0.2.0 and enable 'include-v-in-tag' in release configuration ([dd656c9](https://github.com/bauer-group/automation-templates/commit/dd656c967e133031d3a97f1d6dceaecec7adae51))
* update working directory input for Python build and publish jobs ([381c6e1](https://github.com/bauer-group/automation-templates/commit/381c6e109aab91d0caa58f014f5172961bf6ebf2))
* verbessere Artefakt-Generator und Upload-Workflow mit zusätzlichen Archivformaten und verbesserten Bedingungen ([c5ed061](https://github.com/bauer-group/automation-templates/commit/c5ed0617cbbf4661abdc306b64285dff838a8b5a))
* verbessere Artefakt-Upload-Namen und aktualisiere Release-URLs in der Zusammenfassung ([668ae29](https://github.com/bauer-group/automation-templates/commit/668ae29aa830df151bcbbd6602d99585dedfdd43))
* verbessere Unterstützung für private Repositories durch erweiterte Eingabeverarbeitung und detaillierte Protokollierung ([96d7e0e](https://github.com/bauer-group/automation-templates/commit/96d7e0e182ea02f493e614d91fcb5ecf9ee58d85))
* vereinheitliche Geheimnisverwaltung in PR-Labeler-Workflows ([71be3c6](https://github.com/bauer-group/automation-templates/commit/71be3c6a6fcf39f4a9b2cfce5a3c3830a4867fcb))

### 🐛 Bug Fixes

* add a blank line before the main execution block for better readability ([377dfdc](https://github.com/bauer-group/automation-templates/commit/377dfdcaf5012944c7492e7ae90c2068dec526cb))
* add a newline before the main execution block in generate_readme.py ([5f38e37](https://github.com/bauer-group/automation-templates/commit/5f38e374cdc4d84e73c0a6aef57af451d8eda796))
* add explicit exit 0 statements to prevent license compliance step failures ([79c6439](https://github.com/bauer-group/automation-templates/commit/79c643984cf7eff237f9f52ac26f2c6ed4c4fad3))
* add git pull --rebase to documentation and security management workflows ([dd3e7ce](https://github.com/bauer-group/automation-templates/commit/dd3e7ce28b2ba1c4e52b0f94aab0ea797a8a5204))
* add id-token permission for improved security management ([b2de857](https://github.com/bauer-group/automation-templates/commit/b2de8573c2271744b35612dcb86fbb2a25a0541d))
* add merge strategy to git pull to resolve divergent branches error ([29a36de](https://github.com/bauer-group/automation-templates/commit/29a36deaa6bc4d381b2d4cff4ee1ab1f2369ed75))
* add missing custom-version input to workflow_call sections ([0f73431](https://github.com/bauer-group/automation-templates/commit/0f734311b61d89b8d1d28722e949cb111e519fd9))
* add missing newline at end of deploy-config.yml ([45dfc24](https://github.com/bauer-group/automation-templates/commit/45dfc241dde6f70e9187f5e65c5bb7b5b8a0c4c7))
* add missing newline at end of deploy-config.yml ([48ad8c8](https://github.com/bauer-group/automation-templates/commit/48ad8c80de92d7e08c4aa4152094ff40e64d1798))
* add missing newline at end of deploy-config.yml ([e74b68d](https://github.com/bauer-group/automation-templates/commit/e74b68d1067acb49b96c1bda55c5abb86ace9b82))
* add missing newline in manage.sh and uninstall.sh for improved readability ([bd888fd](https://github.com/bauer-group/automation-templates/commit/bd888fd3a06091493486b66671dd3b2920602823))
* add newline at end of file in CONFIG.YML and generate_readme.py ([1d0fb22](https://github.com/bauer-group/automation-templates/commit/1d0fb22c8106a2d6a3d3e3044f75ed6018b39bf0))
* add newline at end of python-example.yml ([386422d](https://github.com/bauer-group/automation-templates/commit/386422d740ad24d39480d1d869366f3ae38211c7))
* Add newline at end of validate-workflows.ps1 for proper file termination ([8ee19f6](https://github.com/bauer-group/automation-templates/commit/8ee19f6b2cfac010162e29a9155dee50307fcb52))
* add pre-check for dependencies label like size/priority labels ([9b0edc8](https://github.com/bauer-group/automation-templates/commit/9b0edc869fe067eeef44301169f316e0f7c9837f))
* add pre-check for dependencies label like size/priority labels ([6dd929c](https://github.com/bauer-group/automation-templates/commit/6dd929c815fbb0f7601b8a3f6f5227456b946130))
* add retry logic to documentation workflow for concurrent push conflicts ([1903849](https://github.com/bauer-group/automation-templates/commit/19038493b98283b6bbd5d665eff1eaf0f7b3107d))
* add skip-ci option to prevent CI workflows during routine syncs ([332ad7e](https://github.com/bauer-group/automation-templates/commit/332ad7e276000e4761c6365dc4ca44aa8836e5da))
* add workflow validation comment for testing release workflow ([aa77adf](https://github.com/bauer-group/automation-templates/commit/aa77adfad962922ad4a6b23d1c2590a744dd2894))
* aktualisiere Berechtigungen im CI/CD-Workflow für Aktionen ([26019eb](https://github.com/bauer-group/automation-templates/commit/26019ebf089b4a2a77b2100fb33b979fea91559d))
* aktualisiere Beschreibung des GitHub Actions Runners ([37e831f](https://github.com/bauer-group/automation-templates/commit/37e831fb1740ef9cefed3dfa98c8629d93c8d7d3))
* aktualisiere Branch-Namen auf 'main' und passe Ignorierpfade an ([2c414bb](https://github.com/bauer-group/automation-templates/commit/2c414bbe929d817024e5078c5582dfb02c7913a4))
* Aktualisiere den Action-Pfad für die Release-Management-Workflow und passe die Badge-Links im README an ([73c1454](https://github.com/bauer-group/automation-templates/commit/73c14547d68db438cef9016ed846658906f6fd13))
* aktualisiere den Befehl für die semantische Veröffentlichung auf verbose Ausgabe ([c7a6822](https://github.com/bauer-group/automation-templates/commit/c7a6822f1acc99eecea9195b549480e8d1567a12))
* aktualisiere den CI/CD-Pipeline-Link im README-Template ([30f5d7f](https://github.com/bauer-group/automation-templates/commit/30f5d7fefe2afa0978233c3bf52b173b2794c516))
* aktualisiere den Namen des CI/CD-Pipelines für Klarheit ([0417575](https://github.com/bauer-group/automation-templates/commit/04175759cbff999da54a7e02fc1e0a9249d27cff))
* aktualisiere den Namen des manuellen Release-Workflows ([2c3b679](https://github.com/bauer-group/automation-templates/commit/2c3b67970c86151f1955b11cb98ad0a25da842a1))
* aktualisiere den Release-Management-Workflow zur Verbesserung der PR-Erstellung und -Zusammenführung ([0def5b9](https://github.com/bauer-group/automation-templates/commit/0def5b9eb5d3b769670e32e50a4f33f0cf2b4b42))
* aktualisiere den Release-Management-Workflow zur Verwendung von Semantic Release ([74e3f60](https://github.com/bauer-group/automation-templates/commit/74e3f606f743ecb9ac3b93b0d35967dd5920d23a))
* aktualisiere den Release-Prozess zur Vermeidung von PR-Konflikten durch eindeutige Branch-Namen ([38adbc0](https://github.com/bauer-group/automation-templates/commit/38adbc08b7fd4fb3febec8064ed257870e315182))
* aktualisiere die Konfiguration für die Release-Management-Workflow ([0fbfaef](https://github.com/bauer-group/automation-templates/commit/0fbfaef0ff9ef1e55c093bda0e63a62c7ba63712))
* Aktualisiere die Namen der Workflow-Dateien für eine einheitliche Modulbenennung ([77027b7](https://github.com/bauer-group/automation-templates/commit/77027b7d1c4c7f6460ec5946f7fa837e7dc7a455))
* Aktualisiere die Sicherheitsrichtlinienversion auf 1.0.0 und verbessere die Beschreibung für die semantische Versionierung ([a202105](https://github.com/bauer-group/automation-templates/commit/a202105a957c4c5db6bfa9db01a4591c004d9032))
* aktualisiere Kommentare zu Berechtigungen im CI/CD-Workflow ([cafa59b](https://github.com/bauer-group/automation-templates/commit/cafa59b6bab37179a711ee6cdb3aafe3cf64671d))
* aktualisiere Module in CI/CD- und manuellen Release-Workflows auf den Hauptbranch ([dd4b5d8](https://github.com/bauer-group/automation-templates/commit/dd4b5d8627570d87383a1f52c26b616f9599f341))
* aktualisiere Pfade für GitGuardian-Berichte und verbessere Kopierlogik ([09579b6](https://github.com/bauer-group/automation-templates/commit/09579b61be36acff8da70560b47f4115862fee66))
* aktualisiere Trigger für Tag-Erstellung im Dokumentations-Workflow ([59b4084](https://github.com/bauer-group/automation-templates/commit/59b4084d32810e3213b10e16476e06e3ceda0972))
* aktualisiere Umgebungsnamen für die Veröffentlichung auf Produktion und verbessere die Beispielkonfiguration in pyproject.toml ([4247248](https://github.com/bauer-group/automation-templates/commit/42472488986355305e080f1480cb3d0174e830e6))
* aktualisiere Workflow-Namen für AI Issue Summary und Issue Automation ([1b9a80b](https://github.com/bauer-group/automation-templates/commit/1b9a80b4319326c7591d41930de072d878d99b56))
* behebe die Einrückung in der Workflow-Konfiguration für die AI-Zusammenfassung ([47ff201](https://github.com/bauer-group/automation-templates/commit/47ff201e20d779e0629e7856f784ca93bdbcae08))
* behebe Version-Extraktion aus plugin.json und plugin.xml ([77ba2fb](https://github.com/bauer-group/automation-templates/commit/77ba2fb6770f789fe515f03f83f5ee6da09265f6))
* change pull_request_target to pull_request in automatic-release workflow ([a7904c0](https://github.com/bauer-group/automation-templates/commit/a7904c0660f485a7371da50436ebcbe5b612460d))
* configure git credentials for submodule operations with private repos ([3b53ef7](https://github.com/bauer-group/automation-templates/commit/3b53ef784a4fb63fabeeea0ced6b1b9afcdd679a))
* correct GitHub Actions syntax for tag and branch triggers ([3a2721d](https://github.com/bauer-group/automation-templates/commit/3a2721d0acddeaa5c0720954e2eee416f189f857))
* correct manual fallback release outputs and dashboard logic ([5e5da7c](https://github.com/bauer-group/automation-templates/commit/5e5da7c60b50b8a0e4509147af00ccb90d90fef5))
* correct semantic-release output mapping for proper version/tag display ([edd9917](https://github.com/bauer-group/automation-templates/commit/edd99176cf9efc8ece9e730aa241271c344b90ae))
* correct tag output mapping in semantic-release workflow ([62869fc](https://github.com/bauer-group/automation-templates/commit/62869fc78a919c50bcb77710c30741d9680c3c15))
* correct tar command to include all files in source archive ([3837b5a](https://github.com/bauer-group/automation-templates/commit/3837b5a07ae808c303ffa639ae3c553cd7a58bbf))
* correct version propagation in semantic-release and CHANGELOG sync ([a1b98f7](https://github.com/bauer-group/automation-templates/commit/a1b98f748e5aed44ef232a23d6860db606c68b42))
* correct workflow dependencies and external references - remove circular deps, use relative paths ([40adf31](https://github.com/bauer-group/automation-templates/commit/40adf317e7a8f18d401dafe329b855404f74a4a0))
* correct workflow order to preserve generated content ([a1347bc](https://github.com/bauer-group/automation-templates/commit/a1347bca9dbfcb4bcd411ea2208cac8f863c54e2))
* deaktiviere die Verwendung von 'v' im Tag für die Release-Generierung ([8b22772](https://github.com/bauer-group/automation-templates/commit/8b22772280d02f64f3edbe962e1ca1610bf0d0d5))
* disable automatic [skip ci] in semantic-release action ([81134a6](https://github.com/bauer-group/automation-templates/commit/81134a68be8bc4adb48ab023835a2a35e8c7b332))
* enable fetching tags in documentation and security management workflows ([e07d5b2](https://github.com/bauer-group/automation-templates/commit/e07d5b2be2895f994eb75c54389d63db67744d41))
* enable GitHub release creation in manual fallback script ([5cf2844](https://github.com/bauer-group/automation-templates/commit/5cf284420dabcbb5bea4dbecbb07fa1ed4eed4ea))
* enhance documentation workflow to handle skipped runs and provide summaries ([e93baa7](https://github.com/bauer-group/automation-templates/commit/e93baa76d308cdc9f935ee749a27526d3a205bf8))
* enhance error handling and recovery in release process; add missing release creation logic ([0a1e038](https://github.com/bauer-group/automation-templates/commit/0a1e038a977786f3c7c448451d05ac137c53009f))
* Enhance Microsoft Teams notification formatting for improved clarity and detail ([68c6f5c](https://github.com/bauer-group/automation-templates/commit/68c6f5cbf5ec646a124be2be19ce322365871aba))
* enhance submodule removal process with detailed logging and error handling ([936bc39](https://github.com/bauer-group/automation-templates/commit/936bc3925b7bb5cfd10159f8a5ca5229e1269066))
* Enhance tag detection logic to ensure documentation updates are triggered correctly ([f40d10f](https://github.com/bauer-group/automation-templates/commit/f40d10ff15c541bab1d5f87f6dfa07cbb6e47749))
* ensure all security actions receive required secrets properly ([9eb2f74](https://github.com/bauer-group/automation-templates/commit/9eb2f74057e6aef942cc7c457977786af0cd8cb6))
* ensure auto-merge works with existing release PRs ([d13e33b](https://github.com/bauer-group/automation-templates/commit/d13e33b23b70d46f3dc48dc672d7f7b67bd2dd2a)), closes [#18](https://github.com/bauer-group/automation-templates/issues/18)
* ensure documentation and security workflows run after releases ([4d609e0](https://github.com/bauer-group/automation-templates/commit/4d609e0475760f38c6ae59026d834bcd0672ce91))
* ensure newline at end of file in deploy_automations.py ([32fe4aa](https://github.com/bauer-group/automation-templates/commit/32fe4aafaa3a1b9701b096f75a95c3487a190ded))
* ensure newline at end of file in deploy-automations.sh ([ccc5bfd](https://github.com/bauer-group/automation-templates/commit/ccc5bfd4f042944f311edb76e091576aad19a6b2))
* ensure newline at end of file in deploy-automations.sh ([4c805f6](https://github.com/bauer-group/automation-templates/commit/4c805f6ee128c3816e672a5029fd62d44ae961d1))
* ensure newline at end of file in deployment scripts ([30c014b](https://github.com/bauer-group/automation-templates/commit/30c014be8b960932f1362f717bcc5de3e959a0b9))
* ensure newline at end of file in deployment scripts ([cd05fc7](https://github.com/bauer-group/automation-templates/commit/cd05fc717bc39419f8789d26800f0448e3e697e7))
* ensure newline at end of file in deployment scripts ([730277b](https://github.com/bauer-group/automation-templates/commit/730277b7c9049530f7c545a247b171c6018275b0))
* ensure paths are ignored for pull requests in automatic release workflow ([662aad9](https://github.com/bauer-group/automation-templates/commit/662aad9969a513f3079e0e3f4903178f32da2d9a))
* entferne den Schritt zur Aktualisierung der Dokumentation im Release-Management-Workflow ([d513197](https://github.com/bauer-group/automation-templates/commit/d51319774d14c48e2302b7a7d3dbe92ef7a6b84f))
* entferne doppelte Pfadangabe für .github im Workflow-Trigger ([3c74aa2](https://github.com/bauer-group/automation-templates/commit/3c74aa285c5879bed57f64a12a4bf7c45c5e948f))
* Entferne duplizierte Sicherheitsrichtlinien-Management-Badge im README-Template ([7eadb1e](https://github.com/bauer-group/automation-templates/commit/7eadb1e8e93c438ca0f16d34db7e59faf838ac1c))
* Entferne GITHUB_TOKEN-Referenzen aus den Workflow-Modulen ([7707fbd](https://github.com/bauer-group/automation-templates/commit/7707fbd439313e42080c4628b622d039f13df3e8))
* Entferne spezifische Branch-Referenzen aus den Workflow-Modulen in CI/CD- und manuellen Release-Workflows ([4b0ea13](https://github.com/bauer-group/automation-templates/commit/4b0ea1347b17d66d8cf7580ab3f4d9db8dd57e0b))
* entferne überflüssige Leerzeile am Anfang der CI/CD-Pipeline ([56cbd21](https://github.com/bauer-group/automation-templates/commit/56cbd21c913103b07d7e9eae02d8f9076dc4ba30))
* Entferne überflüssige Umgebungsvariable in der Artefakterzeugung ([dea327b](https://github.com/bauer-group/automation-templates/commit/dea327ba782f32d74c2f39864cf246a3223272c8))
* Entferne überflüssige Zeile in der Release-Zusammenfassung ([98d9b65](https://github.com/bauer-group/automation-templates/commit/98d9b6535ee9c1cf4389e3f733e1fb2a41912895))
* entferne veraltete README-Pfade aus der Dokumentations-Workflow-Datei ([2571f50](https://github.com/bauer-group/automation-templates/commit/2571f50e6e1bf88277c84afa58e1d7d864652981))
* Erhöhe die Suchtiefe für Releases und Commits in der Release-Management-Konfiguration ([f5f6c9e](https://github.com/bauer-group/automation-templates/commit/f5f6c9ef252dd1e44e1014d62b27c64141908f64))
* erhöhe maxdepth für find-Befehle von 3 auf 5 für tief verschachtelte Plugin-Strukturen ([32941ea](https://github.com/bauer-group/automation-templates/commit/32941ea8578c8e7d7fc17378a5f6b9836d3b0a54))
* ersetze 'safety' durch 'pip-audit' in Sicherheitskonfigurationen und -prüfungen ([76d1010](https://github.com/bauer-group/automation-templates/commit/76d1010f8397aa7caa5ef227a447dc7c1b2e41ad))
* Ersetze spezifische Geheimnisse durch Vererbung in CI/CD-Workflows ([270b5a0](https://github.com/bauer-group/automation-templates/commit/270b5a0e53fd058d819d4836af31529e6bfcaab7))
* erweitere die Erkennung der Plugin-Struktur für Legacy-Plugins und füge Unterstützung für Core-Plugins hinzu ([e5348c6](https://github.com/bauer-group/automation-templates/commit/e5348c6ec934405761efb5d0753fcf3fb79c55ca))
* erweitere die Erkennung und Validierung von Plugin-Systemen im Build-Prozess ([c509ad7](https://github.com/bauer-group/automation-templates/commit/c509ad75901a88b8c34ee2784e450ad38cdd55f5))
* erweitere die README-Dokumentation um Konfigurationsoptionen und verbessere die Beschreibung der automatischen Synchronisierungsfunktionen ([af0d835](https://github.com/bauer-group/automation-templates/commit/af0d835824e551d5fea87dda0ed04d820dba78bf))
* erweitere Test- und Qualitätsjob um Ausgaben für Testergebnisse, Abdeckungsquote und Sicherheits-/Linting-Probleme ([6130102](https://github.com/bauer-group/automation-templates/commit/6130102d44a87c10dcffd58a8aedb90491dfc961))
* exclude artifacts directory from generated zip and tar.gz archives ([d477714](https://github.com/bauer-group/automation-templates/commit/d477714822570c8586e18388774eff328b94d926))
* extrahiere Plugin-Namen aus Verzeichnisstruktur statt aus label ([b2782e5](https://github.com/bauer-group/automation-templates/commit/b2782e54d36041fcb3c069d0bcf75caf5a13b618))
* finalize workflow validation and ensure [skip ci] removal is active ([99282af](https://github.com/bauer-group/automation-templates/commit/99282af3a5eae812d8bd59e79a43dab785633f9a))
* Format custom-facts in notifications for better readability ([c90a5a7](https://github.com/bauer-group/automation-templates/commit/c90a5a7221f7a5c26e43acdac10afbcc4d084c57))
* format manage.sh and uninstall.sh for improved readability ([2d1531d](https://github.com/bauer-group/automation-templates/commit/2d1531db7d409b3d9d6cfcf09ac86d8f1ded9541))
* Format timestamp for German locale in Microsoft Teams notifications ([99e1c7f](https://github.com/bauer-group/automation-templates/commit/99e1c7f0f2a50cd59b44097ed3e095a6482d8a29))
* füge Abschlussmeldung zum Manage-Skript hinzu ([23ef366](https://github.com/bauer-group/automation-templates/commit/23ef3669d4827994ec30e540af730671c9c04730))
* füge Bedingung hinzu, um bei fehlenden Dateien im Sicherheitsbericht zu ignorieren ([c9a1178](https://github.com/bauer-group/automation-templates/commit/c9a11789b298257bec69469536fe9530b20f6e57))
* füge Schritt hinzu, um sicherzustellen, dass CHANGELOG.MD für die semantische Veröffentlichung existiert ([dab913c](https://github.com/bauer-group/automation-templates/commit/dab913c0047e6ae03cbd8d1362ad2acaf06a31fd))
* füge Statusausgabe für PyPI-Publikation im Pipeline-Zusammenfassung hinzu ([433cd49](https://github.com/bauer-group/automation-templates/commit/433cd49a1ba0ff37636b71c7ff77daae3a70dde4))
* füge Synchronisation mit dem Remote-Branch hinzu, um Push-Konflikte zu vermeiden ([b31bc38](https://github.com/bauer-group/automation-templates/commit/b31bc3864fd59879b099fc1a06d5223a76df2775))
* füge Unterstützung für Ziel-Branch-Parameter im Release-Management-Workflow hinzu ([d103fb8](https://github.com/bauer-group/automation-templates/commit/d103fb80c3f2ebcc95c6bf1bbdf969145ad98acc))
* generiere sauberen ZIP-Dateinamen mit Version ([678c544](https://github.com/bauer-group/automation-templates/commit/678c54496532b3c9bdca4e696387420ecc73fafd))
* handle clean git merge without changes gracefully ([241f67a](https://github.com/bauer-group/automation-templates/commit/241f67adae4df044442099b840b5e642074c04a7))
* handle unset variable for unresolved placeholders count in README generation ([42bf306](https://github.com/bauer-group/automation-templates/commit/42bf306246f65c1950a503dd620985dfdfd2fd90))
* implement hard reset strategy in security management to prevent conflicts ([4d50802](https://github.com/bauer-group/automation-templates/commit/4d50802f5ad589947849f88300d3c9fc2cc50b44))
* improve auto-merge workflow with separate job and better conditions ([e213591](https://github.com/bauer-group/automation-templates/commit/e213591e071498541df1cb7504bfbd43e09ba21d))
* improve Composer auth configuration and add conditional logging ([a7c91b2](https://github.com/bauer-group/automation-templates/commit/a7c91b2ce34b9f677c50501c52e89219df81aaa8))
* improve documentation structure for better readability ([734a5ce](https://github.com/bauer-group/automation-templates/commit/734a5ce65d7d841e240934d33ceca439d6ea7966))
* improve documentation workflow to trigger on relevant file changes and tags ([ddb0e2a](https://github.com/bauer-group/automation-templates/commit/ddb0e2a139a8d17fef8c3dbab5cd17f40910d90c))
* improve error handling in README generation script ([bad8a0e](https://github.com/bauer-group/automation-templates/commit/bad8a0ea6d7e9f8e6b7f77b9571b2615afe2615e))
* Improve facts JSON construction for Microsoft Teams notifications ([3f5924e](https://github.com/bauer-group/automation-templates/commit/3f5924e54eac07d9e86c1edcc1a53ce1a153b898))
* Improve file change detection logic in documentation workflow ([7f1af8f](https://github.com/bauer-group/automation-templates/commit/7f1af8f7359cad99c5b713049597edc1c904a5cb))
* Improve formatting of custom-facts in notifications for better readability ([b28d063](https://github.com/bauer-group/automation-templates/commit/b28d063168d0cd753fea6df85882cb2aee5f676f))
* improve git pull robustness in parallel workflows ([f1c82b0](https://github.com/bauer-group/automation-templates/commit/f1c82b0429e8077944714d6d9154c529dd42ad3d))
* improve git sync in documentation and security workflows ([383b0eb](https://github.com/bauer-group/automation-templates/commit/383b0eb95dc7bafa418ba9a3fa36fb9d739051ce))
* improve license compliance tool installation with proper permissions ([3c32dc6](https://github.com/bauer-group/automation-templates/commit/3c32dc655fda403aea43a60d88f551484cfdf0e4))
* improve README generation and validation output handling ([d621d82](https://github.com/bauer-group/automation-templates/commit/d621d82f2def0b7c6aa2350553879fbfc0991b13))
* improve submodule processing logic to add new submodules and verify existing ones ([c2ab746](https://github.com/bauer-group/automation-templates/commit/c2ab746e73f8cd24f7be0a346f06496960ca17c3))
* improve unresolved placeholders check in README generator ([15793c1](https://github.com/bauer-group/automation-templates/commit/15793c16ca524cbcb3b664a5dd078baff758b58f))
* improve unresolved placeholders counting in README generation ([c992fc1](https://github.com/bauer-group/automation-templates/commit/c992fc1ccd77cf5426b7f01a01358741b1eba773))
* improve version detection and clean workflow path filters ([88012ea](https://github.com/bauer-group/automation-templates/commit/88012eaca2cba48fb3dcdb115df7ab5475c90804))
* include all files in TAR.GZ archive creation ([d944b6e](https://github.com/bauer-group/automation-templates/commit/d944b6e32ef2284bb21ca89df2f13aa28a457aee))
* integriere den Build- und Testprozess für Wheel-Pakete in den Semantic Release Workflow ([2916030](https://github.com/bauer-group/automation-templates/commit/2916030f3ff5d0e8fbf3cb8537bd62c8c671e64b))
* korrigiere Ausgabemeldung nach dem Start der Runner-Container ([2710737](https://github.com/bauer-group/automation-templates/commit/2710737b108f082a72c82b9d6108c8eecdff4ad5))
* korrigiere Ausgabenamen in den Workflow-Dateien für Artefakterstellung, Lizenzprüfung und Sicherheitsprüfung ([b219eab](https://github.com/bauer-group/automation-templates/commit/b219eab8bf38186d5501c6ffb3de00514b552c94))
* korrigiere den Workflow-Namen für AI Issue Summary ([30482a0](https://github.com/bauer-group/automation-templates/commit/30482a0c884d3925195ed5a15e69d4527c91b772))
* korrigiere Pfad zur Moduldatei und füge Überprüfungen für OpenAI API-Schlüssel hinzu ([7160156](https://github.com/bauer-group/automation-templates/commit/7160156fc91a61dcc86d2c270a775585331ee8c0))
* korrigiere Pfad zur README.md in der Dokumentations-Workflow-Datei ([5ca5ebb](https://github.com/bauer-group/automation-templates/commit/5ca5ebbcce3e13cd1ef846eb6bbe6d56060bfc0d))
* make labeler-triage action error-tolerant for missing labels ([c930912](https://github.com/bauer-group/automation-templates/commit/c930912e720d1962c044d7074bdb560f72fcff58))
* make labeler-triage action error-tolerant for missing labels ([a1d0f05](https://github.com/bauer-group/automation-templates/commit/a1d0f0520cb811bef69ea3055e52986d89f2062c))
* make semantic-release robust against parallel workflow conflicts ([8bd1608](https://github.com/bauer-group/automation-templates/commit/8bd1608627ecec04d01710f68892e52d99723fb5))
* Optimize facts JSON construction for Microsoft Teams notifications ([ee33731](https://github.com/bauer-group/automation-templates/commit/ee337310c49c38e94228cf11c19963b150499fef))
* optimize submodule update command to fetch only the tracked branch ([035a384](https://github.com/bauer-group/automation-templates/commit/035a3843172d7213eb27bcd96631057b671e8ad2))
* preserve generated content during git merge operations ([d749761](https://github.com/bauer-group/automation-templates/commit/d74976138a91d26f284666925a4652602cfb7b2e))
* prevent duplicate Release-Please execution on release PR merge ([5298d07](https://github.com/bauer-group/automation-templates/commit/5298d07e36297ec5959f08ce834416a96ce06ed9))
* prevent nested project directories in release artifacts ([cdb9072](https://github.com/bauer-group/automation-templates/commit/cdb9072095283b59d5d66becc640db361d29c687))
* prevent parallel workflow conflicts with semantic-release ([1b9a99b](https://github.com/bauer-group/automation-templates/commit/1b9a99b7c84f5b231da7eb1b89a75b786396bac1))
* prevent submodule loading during initial checkout to avoid access issues ([eb4b6fb](https://github.com/bauer-group/automation-templates/commit/eb4b6fbb5d5e9c0f9dc49a8f477532151ed1d5ef))
* properly configure git credentials for submodule operations ([2397bdc](https://github.com/bauer-group/automation-templates/commit/2397bdcb2c294fab55aa5ac388d13a9e20c21cff))
* reduziere die Suchtiefe für Releases und Commits in der Release-Management-Konfiguration ([911ed70](https://github.com/bauer-group/automation-templates/commit/911ed702c93abb90807ab75a9ae1b8c1f6a6b046))
* Refactor timestamp and input handling for improved readability in Microsoft Teams notifications ([5c0b862](https://github.com/bauer-group/automation-templates/commit/5c0b862da8f023a058d1965dca6119ef355b5998))
* **release:** correct release-please configuration to resolve parsing errors ([95e9df8](https://github.com/bauer-group/automation-templates/commit/95e9df8b6c46af0e59189519fdd2c92125408c5d))
* **release:** update version in release-please manifest to 0.1.0 ([129fad6](https://github.com/bauer-group/automation-templates/commit/129fad6b0ac4f4791383c288a676c29f91f5533b))
* remove [skip ci] from repository semantic-release configuration ([51d025a](https://github.com/bauer-group/automation-templates/commit/51d025a7657411ba358408e2cb70028118617d15))
* remove branch check from workflow conditions to simplify execution ([5b02c31](https://github.com/bauer-group/automation-templates/commit/5b02c31706b9ce46ec5119a2e507ebde3aff71e2))
* Remove duplicate security policy management badge in README template ([7d95983](https://github.com/bauer-group/automation-templates/commit/7d95983d5446c7023480ef1e4328dd26e7194d15))
* remove duplicate v0.26.0 entry from CHANGELOG ([0e55bec](https://github.com/bauer-group/automation-templates/commit/0e55bec822a883769f7d3b94d1c28e56ce2e38de))
* Remove GITHUB_TOKEN requirement from Python automatic release workflow ([39296a0](https://github.com/bauer-group/automation-templates/commit/39296a094dcba03322b17a4aad9d756562ff6779))
* remove large 'No leaks detected' header from GitLeaks ([ddd7953](https://github.com/bauer-group/automation-templates/commit/ddd7953624db8bdde1f3caeab86f11b1ab430937))
* remove outdated CHANGELOG entries to streamline documentation ([d80d736](https://github.com/bauer-group/automation-templates/commit/d80d736ce39d9bd8bc75f87c121227c0d67bd7d7))
* Remove Python Testing Action and CI/CD Workflows ([e9ece3e](https://github.com/bauer-group/automation-templates/commit/e9ece3eb280befdebe7bf45b5143a19c9f1d7c95))
* remove redundant wording in README.template.MD for clarity ([87914a7](https://github.com/bauer-group/automation-templates/commit/87914a7d5076d448efbbfd96a031811a55b12aa7))
* remove temp- prefix from release artifact directory structure ([413e376](https://github.com/bauer-group/automation-templates/commit/413e376ebaaa3ac75fc030d5072bc2fde93fbfb0))
* remove test files and update CHANGELOG with proper v1.0.0 entry ([5edbcf2](https://github.com/bauer-group/automation-templates/commit/5edbcf2b3e4b3ccb3fe2e8196cdb615d6911f3e3))
* remove unnecessary blank line before main execution ([c5a87e9](https://github.com/bauer-group/automation-templates/commit/c5a87e9fa8680d5ed21993fa971312fd0b473ac3))
* remove unnecessary blank line before main execution ([37592c3](https://github.com/bauer-group/automation-templates/commit/37592c3ca502ab4e6c7d8fb5ccc393c29e6ea24d))
* remove unnecessary blank line before main execution block ([25f8b34](https://github.com/bauer-group/automation-templates/commit/25f8b347aea1d275365de17f33a83a7de971036b))
* remove unnecessary blank line before main function ([14870fa](https://github.com/bauer-group/automation-templates/commit/14870fa844cc67a958bc0b2c412551b050102587))
* remove unnecessary blank line before the main function ([7f794c9](https://github.com/bauer-group/automation-templates/commit/7f794c93c54d47a00c5b9a6d86f8dfe19249ef2e))
* Remove unnecessary formatting in workflow log messages for clarity ([be07382](https://github.com/bauer-group/automation-templates/commit/be07382e11bf472051e42d1f01bdeab680529966))
* remove unnecessary newline before main execution block in generate_readme.py ([734c16f](https://github.com/bauer-group/automation-templates/commit/734c16fb74b98a2a695a88c9adef258b1e2c0b1a))
* remove unnecessary newline before main execution block in generate_readme.py ([f534eda](https://github.com/bauer-group/automation-templates/commit/f534edae7725794bf42f580bbc1f35c754b564b6))
* rename unresolved placeholders output for clarity ([01480dd](https://github.com/bauer-group/automation-templates/commit/01480dd85cf2af0087224ca6ca49dd4c1e875e33))
* rename unresolved placeholders output for consistency ([01d61fa](https://github.com/bauer-group/automation-templates/commit/01d61fac6563e0145383c4f2f38e7c04693f9a6a))
* replace rebase with merge in security management to avoid conflicts ([8a0c487](https://github.com/bauer-group/automation-templates/commit/8a0c487f1bf07d080a6c8375f11e856f9d94b8b5))
* reset git credentials to github.token after submodule sync for push operations ([a919eb5](https://github.com/bauer-group/automation-templates/commit/a919eb580a117154a82ca3f01e6fc845bc1ebf34))
* resolve all workflow issues - correct semantic-release outputs, remove rebase conflicts, add retry logic ([3580080](https://github.com/bauer-group/automation-templates/commit/358008086271a2d55201773ec90e5cce0aef8392))
* resolve detached HEAD issue in tag-triggered documentation and security workflows ([10b2434](https://github.com/bauer-group/automation-templates/commit/10b2434b13647a85c40d068eb8f19346f0d08731))
* resolve git rebase conflicts in documentation workflows ([b405bb0](https://github.com/bauer-group/automation-templates/commit/b405bb014e991bc80df7e2647f72b8f981ce9fdc))
* resolve GitGuardian configuration warnings and vulnerability scan errors ([02b409c](https://github.com/bauer-group/automation-templates/commit/02b409c01a5411110dc6213b05f0a574946b1684))
* resolve GitHub Actions workflow failures caused by DSA addition ([9acc4db](https://github.com/bauer-group/automation-templates/commit/9acc4db22e76deec0cd6bac2494dbfa98e04e81a))
* resolve gitleaks download URL and improve security scan reliability ([c04fb3d](https://github.com/bauer-group/automation-templates/commit/c04fb3d9ac777be29544c5dd98b30848283682ad))
* resolve license compliance exit code 1 by eliminating problematic while loops ([5fa7673](https://github.com/bauer-group/automation-templates/commit/5fa7673666e7078b5a8de315509b3b08fcf01bd4))
* resolve manual release workflow action parameter mismatches ([bcf6d67](https://github.com/bauer-group/automation-templates/commit/bcf6d6767617fa135ca109c58a4499c44a809fa3))
* resolve sed temporary file issues in README generator action ([efab942](https://github.com/bauer-group/automation-templates/commit/efab942257284035788214c14e6cff93ffd5555f))
* resolve tag conflict and ensure semantic-release workflow consistency ([924c28a](https://github.com/bauer-group/automation-templates/commit/924c28a1f29a148a994aaf0b7f0c6789bfccf51f))
* restore v0.23.0 workflow functionality with git merge strategy and semantic-release output fixes ([48e7c1e](https://github.com/bauer-group/automation-templates/commit/48e7c1e2fe00a61ef82584c48963ef8a679ebd61))
* restructure workflow steps to prevent sync conflicts ([e02e7dc](https://github.com/bauer-group/automation-templates/commit/e02e7dc82e518488f55d56f57f1f4c0de5c12559))
* set GH_TOKEN at job level to fix branch detection and repository access ([1211670](https://github.com/bauer-group/automation-templates/commit/12116704e7bb8731e31abcb36d58d72e4b257894))
* set version back to 0.1.0 and remove obsolete CHANGELOG.md ([35a92f3](https://github.com/bauer-group/automation-templates/commit/35a92f325f07175f88f96f63d686326505b4ec18))
* simplify dependencies for PyPI publishing and clarify artifact generation summary ([25cce30](https://github.com/bauer-group/automation-templates/commit/25cce30251b8ffbddcde17dc42a40536a36f0cdf))
* simplify dependencies label handling ([0d44bff](https://github.com/bauer-group/automation-templates/commit/0d44bff9db1d84b830f00d2c02c2a53abfb117fb))
* simplify dependencies label handling ([0215dae](https://github.com/bauer-group/automation-templates/commit/0215daefa07b2f26a7191af49272d775c4cbc3e8))
* standardize uninstall completion message in uninstall script ([cd71654](https://github.com/bauer-group/automation-templates/commit/cd71654b706375cc5e02348b3e4dc6847c605c23))
* streamline unittest execution in Python build workflow ([c90496a](https://github.com/bauer-group/automation-templates/commit/c90496ae120945a7077b571cb38c81d2f27a2360))
* test Release-Please after fixing pending release issue ([27f5923](https://github.com/bauer-group/automation-templates/commit/27f59236a405c95c1ac724aa644074549fcea007))
* test workflow decoupling and validation ([803440d](https://github.com/bauer-group/automation-templates/commit/803440d688e1dd1efd0aaff4279af57b20bc9d2a))
* update artifact generation summary to include wheel type ([988f818](https://github.com/bauer-group/automation-templates/commit/988f81820d13f6e4f26fa01ae3f9b5439c35ea10))
* update comment for consistency in deploy-automations.sh ([e23450f](https://github.com/bauer-group/automation-templates/commit/e23450fa8253cbc09eb52b70e8572784a1bcf7e8))
* update commit messages in workflows to use [automated] for clarity ([4d6167f](https://github.com/bauer-group/automation-templates/commit/4d6167f0f358df2e37fea61626c9416b93e8a78b))
* update coverage upload conditions to use boolean comparison ([be95145](https://github.com/bauer-group/automation-templates/commit/be951455368a560d6f11a2775ec35014a8075d89))
* update default security scan engine to 'both' in PR validation workflow ([af87add](https://github.com/bauer-group/automation-templates/commit/af87addc3efd798791cefbd75248cef81914711a))
* update documentation links for accuracy and completeness ([7f32dda](https://github.com/bauer-group/automation-templates/commit/7f32ddad6e58d38174705a14d7b34bc027e1a9aa))
* update documentation links for accuracy and consistency ([69cfbf7](https://github.com/bauer-group/automation-templates/commit/69cfbf7bf6dc6f24fce06e45199c3ca4d79a98bc))
* update documentation links for consistency and clarity ([69848d5](https://github.com/bauer-group/automation-templates/commit/69848d5c2be0b032f8af98fd9ece27571c507ff6))
* update documentation versions to correct v1.0.2 ([eff4cc2](https://github.com/bauer-group/automation-templates/commit/eff4cc241e837f6312eeb952eaea9cb6d519e2a9))
* update documentation workflow to handle release and tag events correctly ([04c2c7b](https://github.com/bauer-group/automation-templates/commit/04c2c7b00ed1d5dc2d1e94cbe5fa8d5e9ed4a3c6))
* Update email contact for security reporting and streamline supported versions section ([f7569c9](https://github.com/bauer-group/automation-templates/commit/f7569c9894526baa01ee52bbd426deefbad54cda))
* update example value for minimum coverage in deployment config ([5c6dd17](https://github.com/bauer-group/automation-templates/commit/5c6dd171a27331226060206f813d5d5e33cc67e8))
* update GitLeaks installation method ([7c41080](https://github.com/bauer-group/automation-templates/commit/7c41080e230917a63e65d2794044e5e7396ab2c3))
* Update job dependencies for documentation and security management updates ([522b292](https://github.com/bauer-group/automation-templates/commit/522b2924f279108129d4836d927d25c189cf2e5b))
* update paths in workflows to include documentation and security templates ([eb13b5b](https://github.com/bauer-group/automation-templates/commit/eb13b5b4208aa1039387d0907a17f50967107bef))
* update permissions in automatic-release workflow to include repository-projects and checks ([af8fb75](https://github.com/bauer-group/automation-templates/commit/af8fb75dadd0949dca8868cae6e7919fa3cb6235))
* update pull request trigger and permissions in workflows; correct documentation link ([6944ec8](https://github.com/bauer-group/automation-templates/commit/6944ec8fbbd978c7be6f9a412d9b7a6e1761297a))
* update PyYAML version to 6.0.2 in requirements.txt ([35fb65d](https://github.com/bauer-group/automation-templates/commit/35fb65d90343e5482771fd1202fde990e25343c8))
* update README template links for consistency and clarity ([3e01a8b](https://github.com/bauer-group/automation-templates/commit/3e01a8b0c80a23390244de2ee64c87b1a27a6123))
* update README workflow and template for consistency in naming ([7b99d5e](https://github.com/bauer-group/automation-templates/commit/7b99d5ea9784544046e298d5435eff7e2829cf12))
* update release-please manifest to v0.2.0 ([8dfecc9](https://github.com/bauer-group/automation-templates/commit/8dfecc9e29895c486fb7260b2d4bff5b9fbfde8e))
* Update required security policy sections for consistency ([163504b](https://github.com/bauer-group/automation-templates/commit/163504b3aba3d0a3daff480aee079d968237faec))
* Update secret variable names for NuGet and GitHub token in workflows ([c8037e4](https://github.com/bauer-group/automation-templates/commit/c8037e48d73fbc87827489c802aef6a06124abdf))
* Update security engine conditions for Gitleaks and GitGuardian scans ([86bb8c4](https://github.com/bauer-group/automation-templates/commit/86bb8c465349cf39c1601f8b7c44f79dbf63620c))
* update security policy job dependencies to include documentation update ([3a163ae](https://github.com/bauer-group/automation-templates/commit/3a163ae0f2965566fa5039f3339c98cac7bab167))
* update submodule sync command to fetch latest commits and stage updates ([12520f2](https://github.com/bauer-group/automation-templates/commit/12520f28b52219aa1f2b0422c52cda64525135ad))
* Update Teams notification details formatting for clarity ([23960e9](https://github.com/bauer-group/automation-templates/commit/23960e9ee250329a0597f07cf5f95ed1f4ccac99))
* Update Teams notification details formatting for consistency ([fc9acec](https://github.com/bauer-group/automation-templates/commit/fc9acec11ac8a71cee8ff7f0dbeb46d8c06c2788))
* Update text block size in Teams notification for improved layout ([ddce55d](https://github.com/bauer-group/automation-templates/commit/ddce55db8b9737893af808a5c4de1a0a154a234e))
* Update text block sizes in Teams notification for improved readability ([cc7de37](https://github.com/bauer-group/automation-templates/commit/cc7de372c1460645b1dd19e37f30abdea4b367b7))
* update validation test for proper workflow testing ([bc2f3a2](https://github.com/bauer-group/automation-templates/commit/bc2f3a29f8db7cf2677e3993393069f02589aea7))
* use --local instead of --global for git credentials in submodule sync ([0a2f39e](https://github.com/bauer-group/automation-templates/commit/0a2f39e424ea014011acf318e617a59d4285d643))
* use correct action output references for version and tag mapping ([166a0a8](https://github.com/bauer-group/automation-templates/commit/166a0a84dbd478b94eec1b381fff1b1076630ad2))
* use correct GitHub Actions syntax for tag creation triggers ([8b7c8d5](https://github.com/bauer-group/automation-templates/commit/8b7c8d513314ffed3e2ae869d7a99c2b284bd397))
* use correct semantic-release action output names (release-created, version, tag) ([1c54a62](https://github.com/bauer-group/automation-templates/commit/1c54a62e1935bc11ba630e9bc3e611d917e489fb))
* use eval for executing test commands in python-build.yml ([ba021f7](https://github.com/bauer-group/automation-templates/commit/ba021f72c48fed744d85fb80c142a0356153b327))
* use eval for install command execution in python-build.yml ([214c56b](https://github.com/bauer-group/automation-templates/commit/214c56bbe9e0ba0a64d2bae2adc44135bd119732))
* use global git config for submodule credentials, local for push ([62a1b8f](https://github.com/bauer-group/automation-templates/commit/62a1b8f4b519746540bea9391f120982b8d9eac2))
* use heredoc format for multiline outputs in AI Summary workflow ([77d03f3](https://github.com/bauer-group/automation-templates/commit/77d03f312eb99ed19d1d6d0f24659da591dc478e))
* use heredoc format for multiline outputs in AI Summary workflow ([f6224d1](https://github.com/bauer-group/automation-templates/commit/f6224d1145dcadc86712a693a02a4e74ed854845))
* use recursive merge strategy instead of invalid merge strategy ([ddeae43](https://github.com/bauer-group/automation-templates/commit/ddeae43f0a3a42e1875e2035ebc7673823cb928c))
* verbessere den Release-Management-Workflow durch Schließen veralteter PRs ([985bd15](https://github.com/bauer-group/automation-templates/commit/985bd15eccb35be6a3f5373ad9c8dd240764f1f6))
* verbessere die Bestimmung des Plugin-Stammverzeichnisses und passe die ZIP-Dateinamensgenerierung an das Repository an ([04b693c](https://github.com/bauer-group/automation-templates/commit/04b693cb758f216eb4fb8b9bdcab2439b7ed4f30))
* verbessere die Erkennung von BAUERGROUP-Plugins und optimiere die ZIP-Struktur für verschiedene Plugin-Typen ([d5c2f71](https://github.com/bauer-group/automation-templates/commit/d5c2f71643a7bb5d8cf223b6e10bef9d9bf8eff2))
* verbessere die Erstellung von CHANGELOG.MD für die semantische Veröffentlichung ([692b773](https://github.com/bauer-group/automation-templates/commit/692b773475dd1cf2d32e096259c29720957f1d69))
* verbessere die Handhabung der Composer-Abhängigkeiten und optimiere die ZIP-Struktur für Plugins ([d663e31](https://github.com/bauer-group/automation-templates/commit/d663e311eb05ce86db555fb7cb94c6276840e523))
* verbessere die Handhabung der Composer-Authentifizierung im Build-Prozess ([007d0ab](https://github.com/bauer-group/automation-templates/commit/007d0ab57c0f76f3d7f60cae403a4d08cfe5c75b))
* verbessere die Handhabung von Eingaben und Ausgaben im AI-Zusammenfassungsworkflow ([0d2a3c3](https://github.com/bauer-group/automation-templates/commit/0d2a3c354387e3433ee2384f2f46845e3f1dbf20))
* verbessere die Plugin-Namens- und Versionsextraktion aus plugin.json, plugin.xml und composer.json ([bd40951](https://github.com/bauer-group/automation-templates/commit/bd4095164743a34a8fcf3192f2501d2b55b1e068))
* verbessere die PyPI Veröffentlichungsdetails und füge übersichtliche Statusausgaben hinzu ([f68748d](https://github.com/bauer-group/automation-templates/commit/f68748d1c2e81fd7cb572466bada3da15bd47f90))
* verbessere Fehlerbehandlung und Ausgaben in der CI/CD-Pipeline für Tests, Sicherheitsanalysen und Linting ([f8a2739](https://github.com/bauer-group/automation-templates/commit/f8a2739543c1fe6984f8e102f3e86b09417d2fb1))
* verbessere Release-Management-Workflow mit erweiterten PR-Prüfungen und Fehlerbehandlung ([7c7b23e](https://github.com/bauer-group/automation-templates/commit/7c7b23eb529cd757f8bfbba3baffaf07ad7098fb))
* verbessere Release-Management-Workflow mit Retry-Logik und Git-Konfiguration ([8e48f76](https://github.com/bauer-group/automation-templates/commit/8e48f76d9066396b56f5284d5c03fc8775d0b56c))
* verschiebe und aktualisiere den Semantic Release Job im CI/CD-Workflow ([5815c43](https://github.com/bauer-group/automation-templates/commit/5815c436193a340a4acbb1ba4fab7d0187c84386))

### ⏪ Reverts

* restore [@main](https://github.com/main) references in python-automatic-release for external repository usage ([ba0a0e3](https://github.com/bauer-group/automation-templates/commit/ba0a0e31d365bfa53aa9c0bdb4083ed363d9860b))

### ♻️ Code Refactoring

* benenne Ausgabedateien um, um Präfixe zu entfernen und die Konsistenz zu verbessern ([2ec17e0](https://github.com/bauer-group/automation-templates/commit/2ec17e00f0415567917bce889cdc93d231841630))
* decouple documentation and security workflows - now independent tag-triggered only ([ecacb02](https://github.com/bauer-group/automation-templates/commit/ecacb029ae60dbe9cb3870d8bde084ec92e6ef0c))
* decouple workflows - documentation and security now independent tag-triggered, automatic-release simplified ([b7220d9](https://github.com/bauer-group/automation-templates/commit/b7220d9dcbec9dd793715722e0eda92ac6fccbb0))
* Enhance summary reporting in repository cleanup and docker build workflows ([2a46e14](https://github.com/bauer-group/automation-templates/commit/2a46e14b51c69d3fbb102594fc2c1a3415b31c44))
* Enhance workflow condition checks for documentation updates ([d8bd874](https://github.com/bauer-group/automation-templates/commit/d8bd874b25a9b59d437d7f396cd38b8ea9fbdb16))
* entferne geheime Token-Referenzen aus Workflow- und README-Vorlage ([97da42d](https://github.com/bauer-group/automation-templates/commit/97da42d6f405a13ba561636d7f3fa69a99c3ea12))
* entferne veraltete Skripte und aktualisiere README für das Branch-Protection-Tool ([762d9a0](https://github.com/bauer-group/automation-templates/commit/762d9a0ce5c9962fee0e95a5b7e8c12b126169c2))
* Improve input descriptions and validation for repository cleanup workflow ([3b69449](https://github.com/bauer-group/automation-templates/commit/3b694499d7bf3f15806e9db0766d24d3463d9dea))
* migrate from Release Please to Semantic Release ([ca8214b](https://github.com/bauer-group/automation-templates/commit/ca8214bdaf212a3e52c12a90612da7516bcdc165))
* move commit_parser_options to a dedicated section in pyproject.toml ([2295808](https://github.com/bauer-group/automation-templates/commit/22958083491be933621675e38db47ea9feccbb28))
* Optimize cleanup option check in repository cleanup action ([3077dfd](https://github.com/bauer-group/automation-templates/commit/3077dfdecbf27db5bcd7322cc2451e08db72257e))
* remove artifact-types input from Python release workflows for simplification ([ca5753e](https://github.com/bauer-group/automation-templates/commit/ca5753e3ad9076e31562ace23fbe802b13c7bb7b))
* remove build-package option from publish-pypi job ([514fa12](https://github.com/bauer-group/automation-templates/commit/514fa1234c5d4def9065f13ba7511e480527bfc9))
* Remove custom version parameter from documentation and security updates in release workflows ([9b337c3](https://github.com/bauer-group/automation-templates/commit/9b337c37050d45aa3e7d50ee4b3fe2c0a797c5a3))
* remove format and type check options from Python CI/CD pipeline ([a8f3042](https://github.com/bauer-group/automation-templates/commit/a8f30421780d0d5aff75388fa6f5eff2ebc8cd92))
* Remove unnecessary metadata permission from repository cleanup workflow ([4dfe67c](https://github.com/bauer-group/automation-templates/commit/4dfe67c5b190f234d5317b9d69b001c5d0806e12))
* rename GH_PAT to GITHUB_PAT and implement read-only security model ([b64d2b3](https://github.com/bauer-group/automation-templates/commit/b64d2b38d46ba9bbd2dad2dc0c74ead061f9ac87))
* rename universal-release to manual-release for clarity ([8fb3b4e](https://github.com/bauer-group/automation-templates/commit/8fb3b4e065bdba3ee9710868c9132bf9c3cd09b1))
* Rename workflow to focus on .NET Build only ([520dc98](https://github.com/bauer-group/automation-templates/commit/520dc98132d332f1c589e2d49365feacd59d9c40))
* Rewrite branch protection script with enhanced logging and dependency management ([d26f535](https://github.com/bauer-group/automation-templates/commit/d26f535162809355656ad6b0addd2cd772b3ceab))
* Simplify batch size validation and remove unnecessary checks in repository cleanup workflow ([9e2050b](https://github.com/bauer-group/automation-templates/commit/9e2050b39146a9c2ce11e550cf4a27f57284e3a0))
* Simplify cleanup operation check in repository cleanup workflow ([70e5463](https://github.com/bauer-group/automation-templates/commit/70e546340e2b47b85e88152c8a7346257b0bdd7c))
* simplify documentation and security workflows to main-branch triggers only ([ef09357](https://github.com/bauer-group/automation-templates/commit/ef093574b7b54c578f2003866963e4662d4390e9))
* simplify gitleaks integration using official marketplace action ([fb9d9e2](https://github.com/bauer-group/automation-templates/commit/fb9d9e285741f70fbe0d241579c2c04c92b0ccee))
* simplify unittest execution in Python build workflow ([da8932e](https://github.com/bauer-group/automation-templates/commit/da8932e8b498508e8ba39f99c435520761a30a50))
* Update default values for custom operations and batch size in repository cleanup workflow ([40f390f](https://github.com/bauer-group/automation-templates/commit/40f390f0377bf76bce788229a567a6bd9eabc516))
* update Python CI/CD pipeline names and improve example workflow configuration ([09426da](https://github.com/bauer-group/automation-templates/commit/09426daa50a0bb6352b671c023813ae5c2eb60b2))
* Update secret variable names for clarity and consistency across workflows ([334fd90](https://github.com/bauer-group/automation-templates/commit/334fd904a2c2396f15b0cda95273cc16f3010c0f))
* update security scan engine input type and description in CI/CD pipeline ([43fa370](https://github.com/bauer-group/automation-templates/commit/43fa3700c81fed00a98a5653957d147c5daf296d))
* use official GitLeaks action instead of manual installation ([a8dce94](https://github.com/bauer-group/automation-templates/commit/a8dce94ba9a408cc8f4d6360c2463169ddf380f7))
* use process substitution to avoid subshell variable scope issues in repository sync workflow ([6b5fead](https://github.com/bauer-group/automation-templates/commit/6b5feadeeb381961d5cba09e4a3196c9d3f4d88a))
* verbessere Fetch-Logik durch Caching aller Repositories für effizientere Verarbeitung ([9b72079](https://github.com/bauer-group/automation-templates/commit/9b72079eb393cb12244647f1eeb389c49d13410e))
* verbessere Fetch-Logik für Repositories nach Themen ([31750a5](https://github.com/bauer-group/automation-templates/commit/31750a5c5af7ead6a9b78bb98ce3df674b07571e))
* verbessere README-Generierung durch Hinzufügen von Template-Variablen und Platzhalter-Unterstützung ([05928e4](https://github.com/bauer-group/automation-templates/commit/05928e48bb1502647c2fd72253ed492edc286857))
* verbessere README-Generierung durch Verwendung von jq für sichere Template-Variablenersetzung ([1f28bc3](https://github.com/bauer-group/automation-templates/commit/1f28bc3adae48ff7fed7c24c45311d9091f443ab))
* verbessere README-Generierung durch Verwendung von Python für sichere Platzhalterersetzung ([4c81582](https://github.com/bauer-group/automation-templates/commit/4c81582b2dbb8c3aa60c57bad04ead27daf3c847))
* verbessere README.md Generierung durch Verwendung von printf und Platzhaltern ([e6e755f](https://github.com/bauer-group/automation-templates/commit/e6e755fa5ff6ce400068029e2611e57b994a319e))

### 🔧 Maintenance

* aktualisiere Status und Badge-Links in README und README.template ([067da40](https://github.com/bauer-group/automation-templates/commit/067da40539898cf443e6df5facc50491de0b3c1c))
* aktualisiere Workflow für Release-Management und setze Ziel-Branch auf 'main' ([d5392e1](https://github.com/bauer-group/automation-templates/commit/d5392e19b81c01894dbf890f1b02c7fd67b69b2e))
* **deps:** bump actions/setup-dotnet from 4 to 5 ([366b5a8](https://github.com/bauer-group/automation-templates/commit/366b5a85ac88a997fdd79811370b848540d1665b))
* **deps:** bump actions/setup-python from 5 to 6 ([6c445eb](https://github.com/bauer-group/automation-templates/commit/6c445eb6d8a726403652767f946e328bfa17ce5d))
* **deps:** bump actions/upload-artifact from 4 to 5 ([bec5aa7](https://github.com/bauer-group/automation-templates/commit/bec5aa72b283d220e5f76f8f4260401f4a6c2463))
* **deps:** bump dorny/test-reporter from 1 to 2 ([cc31b20](https://github.com/bauer-group/automation-templates/commit/cc31b203e2bd615a180126231465c3c98aadd978))
* **deps:** bump peter-evans/dockerhub-description from 4 to 5 ([ba44010](https://github.com/bauer-group/automation-templates/commit/ba44010d5f2a0680706412292e8944e2bb44bead))
* entferne CHANGELOG.md Datei ([195270f](https://github.com/bauer-group/automation-templates/commit/195270f70e6892c0247cacf92015158b3bda671c))
* entferne nicht verwendete Ausgaben aus dem Release-Workflow ([432706f](https://github.com/bauer-group/automation-templates/commit/432706f4db6fd0ea514667561828473f26fc95b0))
* **main:** release 0.2.0 ([5cab1e7](https://github.com/bauer-group/automation-templates/commit/5cab1e7d8b53f53fd50d4487b7e3bd149508d06b))
* release 0.1.1 ([f348722](https://github.com/bauer-group/automation-templates/commit/f34872288fb9cddf405d9734d121439cd25e72df))
* release 0.1.2 ([d2c25c1](https://github.com/bauer-group/automation-templates/commit/d2c25c1254d423d5be7fbc2d70b9dfd93732d16e))
* release 0.1.2 [skip ci] ([b58ea0c](https://github.com/bauer-group/automation-templates/commit/b58ea0c8992cce2caf9181ce06c4cadf83dfa921))
* release 0.1.3 ([aa02da0](https://github.com/bauer-group/automation-templates/commit/aa02da0594baa21e1fdb84eea0d8262b0f62f56e))
* release 0.1.3 [skip ci] ([2291b20](https://github.com/bauer-group/automation-templates/commit/2291b20b0d5369f6a16f5eaa5000976c22b1c026))
* release 0.1.4 ([c5bcd69](https://github.com/bauer-group/automation-templates/commit/c5bcd69a59b79adb425a6b6694b29951dd0be6c6))
* release 0.1.4 [skip ci] ([dd976be](https://github.com/bauer-group/automation-templates/commit/dd976be5e14c396e40967333847fd94e7347c606))
* release 0.1.5 ([58f9f9c](https://github.com/bauer-group/automation-templates/commit/58f9f9cbd3b0fd439cf917efbf4ee87380ca61ed))
* release 0.1.5 [skip ci] ([7a0b5a9](https://github.com/bauer-group/automation-templates/commit/7a0b5a920d3ac4e35bf180245fd92a88b845cc5f))
* release 0.1.6 ([e284a08](https://github.com/bauer-group/automation-templates/commit/e284a08c3deb959082f38fc7a22a9e16d32d3c0e))
* release 0.1.6 [skip ci] ([b371098](https://github.com/bauer-group/automation-templates/commit/b3710984962c5e5e76ff762e0affbdbedd4b0e37))
* release 0.2.0 [skip ci] ([a4d8924](https://github.com/bauer-group/automation-templates/commit/a4d8924cf72e79d8afe30435d71c7b356f071198))
* release 0.2.1 [skip ci] ([78699da](https://github.com/bauer-group/automation-templates/commit/78699daf5565934ecdc0db203b2eb2d88ef1932b))
* release v0.1.1 ([2d5e58e](https://github.com/bauer-group/automation-templates/commit/2d5e58ee9ea5394c17579bec053d8b61cf22525c))
* release v0.1.2 ([91aa6ac](https://github.com/bauer-group/automation-templates/commit/91aa6ac6d3d08f5e25c39aa5ce4135f73f6452e7))
* release v0.12.2 ([aaf85c6](https://github.com/bauer-group/automation-templates/commit/aaf85c645c6814d6311e9b7ac2d5ac6a36a27b61))
* release v0.12.3 ([ec6f5b7](https://github.com/bauer-group/automation-templates/commit/ec6f5b7ef836b75bebf25fed7073d640c93086e2))
* release v0.12.4 ([c1f0152](https://github.com/bauer-group/automation-templates/commit/c1f01521e0d7fee7c198a0196f7390ea7a88d140))
* release v0.2.0 ([e9342ea](https://github.com/bauer-group/automation-templates/commit/e9342ea09ed9e0b550fd5cf4f765415030b36e26))
* release v0.3.0 ([cd161d5](https://github.com/bauer-group/automation-templates/commit/cd161d522a7fe47aca015845f0b944790ddfe8c6))
* **release:** 0.10.0 [skip ci] ([cd112f8](https://github.com/bauer-group/automation-templates/commit/cd112f8d0ae4e7d00b27352785799e9168e51727))
* **release:** 0.11.0 [skip ci] ([c85f4f1](https://github.com/bauer-group/automation-templates/commit/c85f4f1f9345170d23d9a429978e4c3e9053cec9))
* **release:** 0.12.0 [skip ci] ([8882ab2](https://github.com/bauer-group/automation-templates/commit/8882ab2249348be5ebd681a1b05cd0d20cdbb99b))
* **release:** 0.12.1 [skip ci] ([3e26ca8](https://github.com/bauer-group/automation-templates/commit/3e26ca83a58acfd2c67a7da44e3f4cc3eba0ad9d))
* **release:** 0.12.5 [skip ci] ([14250be](https://github.com/bauer-group/automation-templates/commit/14250be1ae7f6817ed933af7062d33fcb7356fc4))
* **release:** 0.12.6 [skip ci] ([c002079](https://github.com/bauer-group/automation-templates/commit/c002079b4ced76b89a38aea531ddfcc20013a161))
* **release:** 0.13.0 [skip ci] ([e4d7a48](https://github.com/bauer-group/automation-templates/commit/e4d7a481d233b6997aca6e54493f0aabaabc0dfc))
* **release:** 0.14.0 [skip ci] ([9e0ed05](https://github.com/bauer-group/automation-templates/commit/9e0ed05ad854a41e55d61d38c414b128ce8ccb76))
* **release:** 0.15.0 [skip ci] ([a0c11e2](https://github.com/bauer-group/automation-templates/commit/a0c11e26c3b4081c173260a60e05f2157356d46c))
* **release:** 0.16.0 [skip ci] ([dd58880](https://github.com/bauer-group/automation-templates/commit/dd588803e9101dab5024383d8581ca6c213ed69b))
* **release:** 0.17.0 [skip ci] ([3cf2b1e](https://github.com/bauer-group/automation-templates/commit/3cf2b1ed03724837f5ce1f71868949710ad4cd97))
* **release:** 0.18.0 [skip ci] ([8a2aeb0](https://github.com/bauer-group/automation-templates/commit/8a2aeb0550f2198344995c413cab83881620861e))
* **release:** 0.19.0 [skip ci] ([b5b35c1](https://github.com/bauer-group/automation-templates/commit/b5b35c159193340feac01a1528bb36b44d286399))
* **release:** 0.20.0 [skip ci] ([d0e6689](https://github.com/bauer-group/automation-templates/commit/d0e66896bef5f809a10ab11b061f23571e70077e))
* **release:** 0.21.0 [skip ci] ([dbc2aa6](https://github.com/bauer-group/automation-templates/commit/dbc2aa6c1261ad061d3d1b20afd5ff7d07259523))
* **release:** 0.22.0 [skip ci] ([f2b89ba](https://github.com/bauer-group/automation-templates/commit/f2b89ba79a2e5cfc91d8ab6f5ef238eeeffac12b))
* **release:** 0.22.1 [skip ci] ([f72577a](https://github.com/bauer-group/automation-templates/commit/f72577a38dc235f612bcdd72c5594c9957958c06))
* **release:** 0.22.2 [skip ci] ([f6ac805](https://github.com/bauer-group/automation-templates/commit/f6ac8059d6f3b9252710575684542fe7a6721951))
* **release:** 0.23.0 [skip ci] ([7641370](https://github.com/bauer-group/automation-templates/commit/764137011ead2df46b01ebcf0b2aa7b6b94d133f))
* **release:** 0.24.0 [skip ci] ([31537c3](https://github.com/bauer-group/automation-templates/commit/31537c3ed9eea79eba41e2f6dc7075f64deef58b))
* **release:** 0.25.0 [skip ci] ([03b11bc](https://github.com/bauer-group/automation-templates/commit/03b11bc54cf095e951f34fc4e67befe9d0937e19))
* **release:** 0.26.0 [skip ci] ([b81f0b8](https://github.com/bauer-group/automation-templates/commit/b81f0b8fa5af4842d2a7dc6954b7efb7a4accd32))
* **release:** 0.4.0 [skip ci] ([3e12e5a](https://github.com/bauer-group/automation-templates/commit/3e12e5a25de46e56d0e204712095fac21e11001c))
* **release:** 0.4.1 [skip ci] ([c0d6d4f](https://github.com/bauer-group/automation-templates/commit/c0d6d4f322a9219b00087a3acac9799f16ddc8ac))
* **release:** 0.5.0 [skip ci] ([298483c](https://github.com/bauer-group/automation-templates/commit/298483c4b322e010f9801537b6be9423a66ae61c))
* **release:** 0.6.0 [skip ci] ([f90b313](https://github.com/bauer-group/automation-templates/commit/f90b3134424c7c9a52fc2f14b1faf45a4deffd97))
* **release:** 0.7.0 [skip ci] ([9575c0a](https://github.com/bauer-group/automation-templates/commit/9575c0aa4933629aac2bfd5801ba7fea0784a219))
* **release:** 0.8.0 [skip ci] ([5c07bcd](https://github.com/bauer-group/automation-templates/commit/5c07bcd4d95a7c6e902777490b41ad37b6974c0a))
* **release:** 0.9.0 [skip ci] ([bad7ffe](https://github.com/bauer-group/automation-templates/commit/bad7ffe07d16c628e5579c5b0f2368b46d1d48be))
* **release:** 1.0.0 [skip ci] ([725b938](https://github.com/bauer-group/automation-templates/commit/725b938835bcd15f05785772c11251225fda6c9d))
* **release:** 1.0.0 [skip ci] ([9294b13](https://github.com/bauer-group/automation-templates/commit/9294b13d8eaaaf44ab2b7bd8f8c9bc64d9df70bb))
* **release:** 1.0.1 [skip ci] ([86e0ca8](https://github.com/bauer-group/automation-templates/commit/86e0ca8dd4d57602f1249d9ad12de3ba74c83223))
* **release:** 1.0.2 [skip ci] ([b790d22](https://github.com/bauer-group/automation-templates/commit/b790d2285c4e261581298a1cbe18040e7d00503a))
* **release:** 1.0.3 [skip ci] ([758232b](https://github.com/bauer-group/automation-templates/commit/758232b6cc1112a080c359015bb8586cab891015))
* **release:** 1.0.4 [skip ci] ([7c381a6](https://github.com/bauer-group/automation-templates/commit/7c381a6ac5c619600d93cafdedfeb5b9c610c4af))
* **release:** 1.0.5 [skip ci] ([a5bd217](https://github.com/bauer-group/automation-templates/commit/a5bd21778d01b6b2cfefe6df8fe5ac9b5d0355ca))
* **release:** 1.0.5 [skip ci] ([81991b1](https://github.com/bauer-group/automation-templates/commit/81991b1973bd41b2eb492681ab575ad66b305152))
* **release:** 1.0.6 [skip ci] ([0ab5d6b](https://github.com/bauer-group/automation-templates/commit/0ab5d6bdfc8039faa8c8366b4ef9b558a3d4b3b9))
* **release:** 1.1.0 [skip ci] ([0f61ae9](https://github.com/bauer-group/automation-templates/commit/0f61ae9f3f9952090c10fe12b6f0178e5e291bfd))
* **release:** 1.1.1 [skip ci] ([03b166b](https://github.com/bauer-group/automation-templates/commit/03b166b23ae7830a9bf13b41f10ad511d9213d14))
* **release:** 1.1.10 [automated] ([f75155b](https://github.com/bauer-group/automation-templates/commit/f75155bef3332663f27b6981ba6b6de954f8546c))
* **release:** 1.1.11 [automated] ([ee2cd26](https://github.com/bauer-group/automation-templates/commit/ee2cd266896a983a9b8544cf16eb2b95d811ceb6))
* **release:** 1.1.12 [automated] ([a7e799c](https://github.com/bauer-group/automation-templates/commit/a7e799c54ecdb7b9eaad3b4cfebccf72d81fa7d4))
* **release:** 1.1.13 [automated] ([85f9c62](https://github.com/bauer-group/automation-templates/commit/85f9c625e55395a0e48747f3891cfa33e43a658a))
* **release:** 1.1.2 [skip ci] ([a516d4d](https://github.com/bauer-group/automation-templates/commit/a516d4dd4b785d0c7859f43751c5687ce68c902b))
* **release:** 1.1.3 [skip ci] ([4bc9fc7](https://github.com/bauer-group/automation-templates/commit/4bc9fc799386a072e2a3b7ba2276a3ec4a84464e))
* **release:** 1.1.4 [skip ci] ([8db996a](https://github.com/bauer-group/automation-templates/commit/8db996a5150870e99ffad132886b80e8607ec313))
* **release:** 1.1.5 ([c6adb30](https://github.com/bauer-group/automation-templates/commit/c6adb308c899b428bd7ab55fd20a54ac243516d4))
* **release:** 1.1.6 ([6207ba1](https://github.com/bauer-group/automation-templates/commit/6207ba15e2c4638c7a044457edbcb75f65624654))
* **release:** 1.1.7 [automated] ([64f4775](https://github.com/bauer-group/automation-templates/commit/64f4775bdad906b848524dfb147553943ad93a04))
* **release:** 1.1.8 [automated] ([b281cd2](https://github.com/bauer-group/automation-templates/commit/b281cd28bacb5c074d357b08257962bebd28d262))
* **release:** 1.1.9 [automated] ([d1e1a8c](https://github.com/bauer-group/automation-templates/commit/d1e1a8c61f4cd79278a7d7ff9a56d7b05170f064))
* **release:** 1.10.0 [automated] ([cb7df28](https://github.com/bauer-group/automation-templates/commit/cb7df28a5fac4929d76fd3e1b26f1f46973c9a49))
* **release:** 1.10.1 [automated] ([079eaad](https://github.com/bauer-group/automation-templates/commit/079eaade68e5a24a12e9c13fad675d92bebfc20e))
* **release:** 1.11.0 [automated] ([fab068e](https://github.com/bauer-group/automation-templates/commit/fab068e27ebdef6de52aa9f1bc0595ba23c75ba1))
* **release:** 1.2.0 [automated] ([26d75a5](https://github.com/bauer-group/automation-templates/commit/26d75a566e87a5a79a47eb5d7716abdc7f7bee86))
* **release:** 1.3.0 [automated] ([c806e1b](https://github.com/bauer-group/automation-templates/commit/c806e1b737518661601181cb7e3ea873700fb906))
* **release:** 1.3.1 [automated] ([bfefc31](https://github.com/bauer-group/automation-templates/commit/bfefc31c440ead2b3f48649efeac1f5a79108b81))
* **release:** 1.3.2 [automated] ([dcf7a34](https://github.com/bauer-group/automation-templates/commit/dcf7a342b7405698a12176ef155068155f86ac57))
* **release:** 1.3.3 [automated] ([6020d04](https://github.com/bauer-group/automation-templates/commit/6020d04f298a1794c31c5e7a2969e30770448b5f))
* **release:** 1.3.4 [automated] ([932ba78](https://github.com/bauer-group/automation-templates/commit/932ba78a72b146bc5174504cde946836f76ce39a))
* **release:** 1.3.5 [automated] ([effc893](https://github.com/bauer-group/automation-templates/commit/effc893a79cf2367c1a483318a668b05c549b2bb))
* **release:** 1.3.6 [automated] ([f8db32c](https://github.com/bauer-group/automation-templates/commit/f8db32c5f8e9ec458d5daeaf37f0aa5ac1282b93))
* **release:** 1.3.7 [automated] ([d1eb0ce](https://github.com/bauer-group/automation-templates/commit/d1eb0ce8b0dfd90c46dde22cbb55ac7c63237084))
* **release:** 1.3.8 [automated] ([9d85508](https://github.com/bauer-group/automation-templates/commit/9d855082d9271fd169f3e4062880a1f332d8c196))
* **release:** 1.4.0 [automated] ([2a96425](https://github.com/bauer-group/automation-templates/commit/2a96425f5b4ce31af5428aa935081496deed792d))
* **release:** 1.4.1 [automated] ([6e09f0d](https://github.com/bauer-group/automation-templates/commit/6e09f0d1e04a7f1c13c3fe8805c1d6f437e8c384))
* **release:** 1.5.0 [automated] ([95d64b2](https://github.com/bauer-group/automation-templates/commit/95d64b27bf6dffde0111d4a9636d94ec0b3f33d6))
* **release:** 1.6.0 [automated] ([0b68f59](https://github.com/bauer-group/automation-templates/commit/0b68f598d8528da6eba0e526c27b4976342abdca))
* **release:** 1.6.1 [automated] ([5eed191](https://github.com/bauer-group/automation-templates/commit/5eed19193d7d911593e441f805cdc488b1e00e06))
* **release:** 1.7.0 [automated] ([5b7f377](https://github.com/bauer-group/automation-templates/commit/5b7f377619462491577c061a69e8e7ce682ddad6))
* **release:** 1.8.0 [automated] ([86f556a](https://github.com/bauer-group/automation-templates/commit/86f556acaaf298f707f7f5ca2e47ec8ce6affb5d))
* **release:** 1.8.1 [automated] ([d9c4594](https://github.com/bauer-group/automation-templates/commit/d9c45945c0b20f8f5d62764e77cbb03a8096ab39))
* **release:** 1.9.0 [automated] ([c8b9dc7](https://github.com/bauer-group/automation-templates/commit/c8b9dc7de3e661d1da8cb3a04b828659f3b4f2da))
* **release:** 2.0.0 [automated] ([52a265c](https://github.com/bauer-group/automation-templates/commit/52a265c753faba369b867cfbd86ab01a1009eaab))
* **release:** 3.0.0 [automated] ([1de72d2](https://github.com/bauer-group/automation-templates/commit/1de72d2fc7b8b15fd044cef003638be314746477))
* **release:** 3.1.0 [automated] ([80819e2](https://github.com/bauer-group/automation-templates/commit/80819e2cb1fcea4a817f12a41d0c67eb4bfdbd48))
* **release:** 3.2.0 [automated] ([354df61](https://github.com/bauer-group/automation-templates/commit/354df61ecbd887154b998cb032731f15b65080fb))
* Remove bug report template from issue templates ([e990bb4](https://github.com/bauer-group/automation-templates/commit/e990bb49eeb0e36aa910d877ea8332449774d05d))
* remove obsolete README-TEST.md file ([c1b113d](https://github.com/bauer-group/automation-templates/commit/c1b113da71b66c9a174e46a739cdde51c0d41586))
* remove obsolete security report files and configurations ([054c5ce](https://github.com/bauer-group/automation-templates/commit/054c5ce6b2711089038b87e03dfd57c63204b56c))
* remove outdated comment about workflow validation ([eab5f0c](https://github.com/bauer-group/automation-templates/commit/eab5f0c9ee54b82e465e820f4336d3d02e5fbfd1))
* remove outdated README.md for workflows ([f12f14a](https://github.com/bauer-group/automation-templates/commit/f12f14a98b8c3a6f733be9d10a8dc6f56b2e8881))
* remove temporary changelog file ([ff017fb](https://github.com/bauer-group/automation-templates/commit/ff017fb6e6a85f462378a1b94f6bb7b6353f8803))
* remove unnecessary ci: false parameter from semantic-release action ([d58cd02](https://github.com/bauer-group/automation-templates/commit/d58cd02eb9d3633ea45c4bd1cac61a935070a03e))
* remove workflow testing comment from generate_readme.py ([003d505](https://github.com/bauer-group/automation-templates/commit/003d505cce79711928f917a1499f3329bc4af255))
* update AI model from gpt-3.5-turbo to gpt-4o in workflows ([6761c2b](https://github.com/bauer-group/automation-templates/commit/6761c2b6b3fe5e148451437fca1099b9ff5ec488))
* update default Python version to 3.12 in build and publish workflows ([efce5d8](https://github.com/bauer-group/automation-templates/commit/efce5d879bb2d430b7af327e9763f9679bbf6825))
* update pipeline name for clarity in python-example.yml ([2176dcb](https://github.com/bauer-group/automation-templates/commit/2176dcbb56504906bf45309aa0d663219623ebb6))

## [3.2.0](https://github.com/bauer-group/automation-templates/compare/v3.1.0...v3.2.0) (2025-10-26)

### 🚀 Features

* add initial Dependabot configuration for GitHub Actions updates ([4af7ffd](https://github.com/bauer-group/automation-templates/commit/4af7ffddb1a903bdba61f038a96bba11c79660c6))

### 🐛 Bug Fixes

* enhance submodule removal process with detailed logging and error handling ([452d50f](https://github.com/bauer-group/automation-templates/commit/452d50f8bed47171afb53d1175eca3b65909e4d1))
* improve submodule processing logic to add new submodules and verify existing ones ([a5395df](https://github.com/bauer-group/automation-templates/commit/a5395dfa8e7d7dea9bc76faacc648daaa5dad3de))
* resolve GitHub Actions workflow failures caused by DSA addition ([5631b17](https://github.com/bauer-group/automation-templates/commit/5631b17b7958437ffe7546a16751396315ef1845))
* update submodule sync command to fetch latest commits and stage updates ([839232a](https://github.com/bauer-group/automation-templates/commit/839232ad169c22857b15642c84d3dd258a680b24))

### ♻️ Code Refactoring

* use process substitution to avoid subshell variable scope issues in repository sync workflow ([c09ec74](https://github.com/bauer-group/automation-templates/commit/c09ec74362f49512da67887828b93540b9f33f18))

### 🔧 Maintenance

* **deps:** bump actions/setup-dotnet from 4 to 5 ([f608620](https://github.com/bauer-group/automation-templates/commit/f6086208e66b61c66af4ec31bb477ef4b5b08ee2))
* **deps:** bump actions/setup-python from 5 to 6 ([6adc7b2](https://github.com/bauer-group/automation-templates/commit/6adc7b20d11f940b67a9e15768648aa15b3ed746))
* **deps:** bump actions/upload-artifact from 4 to 5 ([e2d80f8](https://github.com/bauer-group/automation-templates/commit/e2d80f8b51c8edbfbc5bfc984bd90005a43d72e6))
* **deps:** bump dorny/test-reporter from 1 to 2 ([38124cd](https://github.com/bauer-group/automation-templates/commit/38124cdd54f6cc1079ff2a0428139499d223b7c5))
* **deps:** bump peter-evans/dockerhub-description from 4 to 5 ([255a96f](https://github.com/bauer-group/automation-templates/commit/255a96f95e7031b1aaab62699e5a1fa4b3107370))

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
