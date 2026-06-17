# Integrating BAUER GROUP CI Workflows with SonarQube

A step-by-step guide for adding **automated, multi-language code analysis** to a
repository using the reusable workflows from
[`bauer-group/automation-templates`](https://github.com/bauer-group/automation-templates)
and **SonarQube** — either a self-hosted **Server** or **SonarQube Cloud**
(switchable via `sonar-edition`).

Copy the parts you need into your repository.

---

## 0. How it fits together

```
your repo (.github/workflows/ci.yml)
        │  uses: …/<lang>-build.yml@main   with: enable-sonar: true
        ▼
automation-templates → <lang>-build.yml
        │  job: code-quality  (uses modules-code-quality.yml)
        ▼
modules-code-quality.yml → actions/sonar-scan → SonarQube Server
```

Two integration levels — pick per repository:

| Level | What you get | Effort |
|-------|--------------|--------|
| **A — Analysis only** | Bugs, code smells, security hotspots, duplication. **No test coverage.** | One line: `enable-sonar: true` |
| **B — Analysis + coverage** | Everything above **plus** test coverage %. | A small per-language job that runs tests and the scan together |

> Coverage is **not** auto-handed from the build job to the analysis job yet, so
> Level A intentionally reports no coverage. Use Level B when you need coverage.

---

## 1. Prerequisites (once per repository)

1. **Grant the repo access to the org secrets** (they already exist
   organization-wide):
   - `SONARQUBE_TOKEN` — SonarQube Server API token
   - `SONARQUBE_HOST_URL` — e.g. `https://sonar.bauer-group.com`

   GitHub → Organization → *Settings → Secrets and variables → Actions* →
   open each secret → *Repository access* → add your repo.

2. **Create the project in SonarQube** and note its **Project Key**.

3. **Add `sonar-project.properties`** to the repo root (see §3).

No secrets are stored in the repo — they flow in via `secrets: inherit`.

---

## 2. Level A — analysis only (fastest)

Add `enable-sonar: true` to your existing build-workflow call. Done.

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write   # lets SonarQube decorate the PR

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/nodejs-build.yml@main
    with:
      enable-sonar: true          # default: false
    secrets: inherit              # provides SONARQUBE_TOKEN + SONARQUBE_HOST_URL
```

Swap `nodejs-build.yml` for `dotnet-build.yml`, `python-build.yml`, or
`php-build.yml` as needed — the `enable-sonar` input and `secrets: inherit`
pattern is identical for all four.

### Custom `sonar-project.properties` location or inline settings

All four build workflows expose three optional Sonar inputs:

| Input | Purpose | Default |
|-------|---------|---------|
| `sonar-edition` | Target platform: `server` (self-hosted) or `cloud` (SonarQube Cloud) | `server` |
| `sonar-organization` | SonarQube Cloud organization key (cloud edition) | `''` |
| `sonar-project-base-dir` | Directory SonarQube analyzes and where `sonar-project.properties` is read from | `.` |
| `sonar-args` | Extra `-Dsonar.*` arguments (one per line) — relocate the config or pass settings inline | `''` |
| `sonar-fail-on-quality-gate` | Fail the build on a failing Quality Gate | `false` |

The SonarScanner has **no "settings-file path" flag** — it always reads
`sonar-project.properties` from the analysis base directory. So to keep the file
somewhere other than the repo root you have two supported options:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main
    with:
      enable-sonar: true
      # Option 1 — properties file lives in a subdirectory:
      sonar-project-base-dir: services/api
      # Option 2 — no properties file at all, pass settings inline:
      # sonar-args: |
      #   -Dsonar.projectKey=my-team_my-service
      #   -Dsonar.sources=src
      # sonar-fail-on-quality-gate: true   # optional: enforce the gate
    secrets: inherit
```

> Note (scanner v6+): `sonar-args` are parsed as discrete tokens (not bash), so
> use one `-Dkey=value` per line and avoid spaces inside a value — put anything
> complex in `sonar-project.properties`.

### SonarQube Cloud instead of self-hosted Server

Set `sonar-edition: cloud` and provide the organization. Cloud needs **no host
URL** — only the token (reuse the `SONARQUBE_TOKEN` secret, set to a SonarQube
Cloud token) plus `sonar.organization`:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main
    with:
      enable-sonar: true
      sonar-edition: cloud
      sonar-organization: my-org-key   # or set sonar.organization in sonar-project.properties
    secrets: inherit                   # SONARQUBE_TOKEN (a Cloud token); SONARQUBE_HOST_URL is ignored
```

The project must already exist in SonarQube Cloud — the scanner does not
auto-provision Cloud projects.

---

## 3. `sonar-project.properties` (per language)

Place this in the analysis base directory — the repo root by default, or
wherever `sonar-project-base-dir` points (see §2). The coverage report path must
match what your test step produces (see §4).

```properties
# Common
sonar.projectKey=my-team_my-service
sonar.sources=src
sonar.tests=test
sonar.sourceEncoding=UTF-8

# --- pick the line(s) for your language ---
# Node.js / TypeScript
sonar.javascript.lcov.reportPaths=coverage/lcov.info
# Python
# sonar.python.coverage.reportPaths=coverage.xml
# PHP
# sonar.php.coverage.reportPaths=coverage.xml
# .NET (OpenCover)
# sonar.cs.opencover.reportsPaths=**/coverage.opencover.xml
```

---

## 4. Level B — analysis **with coverage** (tests + scan in one job)

Coverage requires the coverage report to exist in the same job that runs the
scan. Add a dedicated job that runs your tests **and then** calls the
`sonar-scan` composite action. `fetch-depth: 0` is required for accurate
new-code detection.

### Node.js / TypeScript

```yaml
jobs:
  sonar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npm test -- --coverage        # produces coverage/lcov.info
      - uses: bauer-group/automation-templates/.github/actions/sonar-scan@main
        with:
          sonar-host-url: ${{ secrets.SONARQUBE_HOST_URL }}
          sonar-token: ${{ secrets.SONARQUBE_TOKEN }}
```

### Python

```yaml
jobs:
  sonar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -r requirements.txt pytest pytest-cov
      - run: pytest --cov --cov-report=xml  # produces coverage.xml
      - uses: bauer-group/automation-templates/.github/actions/sonar-scan@main
        with:
          sonar-host-url: ${{ secrets.SONARQUBE_HOST_URL }}
          sonar-token: ${{ secrets.SONARQUBE_TOKEN }}
```

### PHP

```yaml
jobs:
  sonar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          coverage: xdebug
      - run: composer install --no-interaction --prefer-dist
      - run: vendor/bin/phpunit --coverage-clover coverage.xml
      - uses: bauer-group/automation-templates/.github/actions/sonar-scan@main
        with:
          sonar-host-url: ${{ secrets.SONARQUBE_HOST_URL }}
          sonar-token: ${{ secrets.SONARQUBE_TOKEN }}
```

### .NET / C# (use the MSBuild scanner for full coverage)

For C#, the dedicated `dotnet-sonarscanner` (begin → build → test → end) gives
proper Roslyn-based analysis and coverage — better than the generic CLI scanner.

```yaml
jobs:
  sonar:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '8.0.x' }
      - uses: actions/setup-java@v4        # scanner needs a JRE
        with: { distribution: 'temurin', java-version: '17' }
      - run: dotnet tool install --global dotnet-sonarscanner
      - name: Begin analysis
        env:
          SONAR_TOKEN: ${{ secrets.SONARQUBE_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONARQUBE_HOST_URL }}
        run: >
          dotnet sonarscanner begin
          /k:"my-team_my-service"
          /d:sonar.host.url="$SONAR_HOST_URL"
          /d:sonar.token="$SONAR_TOKEN"
          /d:sonar.cs.opencover.reportsPaths='**/coverage.opencover.xml'
      - run: dotnet build --no-incremental
      # OpenCover format requires the `coverlet.msbuild` package in the test project
      - run: >
          dotnet test
          /p:CollectCoverage=true
          /p:CoverletOutputFormat=opencover
          /p:CoverletOutput=coverage.opencover.xml
      - name: End analysis
        env:
          SONAR_TOKEN: ${{ secrets.SONARQUBE_TOKEN }}
        run: dotnet sonarscanner end /d:sonar.token="$SONAR_TOKEN"
```

> Tip: run tests/coverage in your normal build, and the `sonar` job above in
> parallel — or combine them if you want a single job.

---

## 5. Enforce the Quality Gate (optional)

By default the scan is **non-blocking** (it reports but never fails the build).
To make a failing Quality Gate fail the workflow:

- **Level A:** call `modules-code-quality.yml` directly with
  `fail-on-quality-gate: true`.
- **Level B:** add `fail-on-quality-gate: 'true'` to the `sonar-scan` step.

```yaml
  code-quality:
    uses: bauer-group/automation-templates/.github/workflows/modules-code-quality.yml@main
    with:
      enable-sonar: true
      fail-on-quality-gate: true
    secrets: inherit
```

---

## 6. Behaviour & tolerance

- **Opt-in:** nothing runs unless `enable-sonar: true` (build workflows) or you
  add the job explicitly.
- **Tolerant:** if the scan is enabled but `SONARQUBE_TOKEN` / `SONARQUBE_HOST_URL`
  are missing, it logs a **warning and skips** — it never fails the build.
- **Caching:** the scanner and analysis data are cached automatically.

---

## 7. Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `SonarQube analysis was enabled but … not set` warning | Repo has no access to the org secrets — grant it (§1.1). |
| Coverage shows 0% | Level A reports no coverage by design — use Level B (§4) and verify the report path in `sonar-project.properties`. |
| `You're not authorized to analyze this project … and you're not authorized to create it` | Token authenticated but has no rights for that project key. Either **create the project** in SonarQube first (Projects → Create Project → Manually, using the exact `sonar.projectKey`), **or** grant the token user the **Create Projects** global permission for auto-provisioning. Then ensure that user has **Execute Analysis** on the project. Server-side config — not a workflow issue. |
| `Project not found` / key mismatch | `sonar.projectKey` must match the SonarQube project exactly (case-sensitive). |
| New-code / blame inaccurate | Ensure `fetch-depth: 0` on checkout. |
| PR not decorated | Caller must grant `pull-requests: write`. |

---

## 8. Reference

- Module: [`docs/workflows/modules-code-quality.md`](../workflows/modules-code-quality.md)
- Examples: [`sonarqube-self-hosted.yml`](../../github/workflows/examples/code-quality/sonarqube-self-hosted.yml) · [`sonarqube-cloud.yml`](../../github/workflows/examples/code-quality/sonarqube-cloud.yml)
- Action: [`.github/actions/sonar-scan/action.yml`](../../.github/actions/sonar-scan/action.yml)
- Secrets: [`docs/secrets-reference.md`](../secrets-reference.md)
- SonarSource action: <https://github.com/SonarSource/sonarqube-scan-action>
