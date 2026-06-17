# Module | Code Quality (SonarQube)

Reusable workflow for **self-hosted SonarQube Server** static code analysis.

It is **opt-in** and **tolerant by design**: it never breaks an existing build.

- The job only runs when `enable-sonar: true`.
- If enabled but `SONARQUBE_HOST_URL` / `SONARQUBE_TOKEN` are missing, it emits a
  **warning** and skips — it does **not** fail the build.
- The SonarQube Quality Gate is **non-blocking** unless `fail-on-quality-gate: true`.

> Reference: [`.github/workflows/modules-code-quality.yml`](../../.github/workflows/modules-code-quality.yml)
> · Action: [`.github/actions/sonar-scan`](../../.github/actions/sonar-scan/action.yml)
> · Consumer guide: [SonarQube integration](../guides/sonarqube-integration.md)

## Usage

### Standalone

```yaml
name: Code Quality

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  code-quality:
    uses: bauer-group/automation-templates/.github/workflows/modules-code-quality.yml@main
    with:
      enable-sonar: true
      # fail-on-quality-gate: true   # enforce the Quality Gate
    secrets: inherit
```

### Via a language build workflow

`dotnet-build`, `nodejs-build`, `python-build` and `php-build` expose the same
opt-in flag — no extra job needed:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/nodejs-build.yml@main
    with:
      enable-sonar: true   # default: false
    secrets: inherit       # provides SONARQUBE_TOKEN + SONARQUBE_HOST_URL
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `enable-sonar` | Run the analysis (skips with a warning if host/token missing) | `true` |
| `project-base-dir` | Base directory to analyze | `.` |
| `args` | Additional `-Dsonar.*` arguments (one per line) | `''` |
| `fail-on-quality-gate` | Wait for and fail on a failing Quality Gate | `false` |
| `runs-on` | Runner (string or JSON array for self-hosted) | `ubuntu-latest` |

## Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `SONARQUBE_TOKEN` | Self-hosted SonarQube Server API token | No (skips with warning if absent) |
| `SONARQUBE_HOST_URL` | Self-hosted SonarQube Server URL | No (skips with warning if absent) |

Both are intended as **organization-level secrets** and flow in via `secrets: inherit`.

## Outputs

| Output | Description |
|--------|-------------|
| `executed` | Whether the scan actually ran (`true`/`false`) |
| `quality-gate` | Quality Gate status when waited (`PASSED`/`FAILED`/`unknown`) |

## Project configuration

Project-specific settings live in a `sonar-project.properties` file in the
**consumer repository** (keeps this module generic). It is read from the analysis
base directory, so to keep it outside the repo root set `project-base-dir`
accordingly — or skip the file entirely and pass settings via `args`:

```properties
sonar.projectKey=my-team_my-service
sonar.sources=src
sonar.tests=test
# Coverage (point at the report your test step produces)
sonar.javascript.lcov.reportPaths=coverage/lcov.info
# sonar.python.coverage.reportPaths=coverage.xml
# sonar.php.coverage.reportPaths=coverage.xml
```

## Optimization notes

- **Caching:** the scanner + analysis data are cached via `SONAR_USER_HOME`
  (`.sonar` inside the workspace) across runs.
- **History:** the job checks out with `fetch-depth: 0` so SonarQube can compute
  the new-code period and SCM blame correctly.
- **Cost control:** gate the analysis behind `enable-sonar` and run it on push to
  the default branch + PRs rather than on every tag/release.

## Limitations

- **Coverage** is not auto-wired from the build job. The analysis runs in its own
  job, so test coverage must be produced where SonarQube can read it (via
  `sonar-project.properties` report paths). Cross-job coverage hand-off is a
  planned follow-up.
- **.NET / C#:** the generic CLI scanner is used. For full Roslyn-based C#
  analysis, the `dotnet-sonarscanner begin/end` flow (MSBuild scanner) is the
  upgrade path.
- **Linux only:** `SonarSource/sonarqube-scan-action` is a Docker action and runs
  on Linux runners.
