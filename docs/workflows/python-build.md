# Python Build Workflows

Diese Dokumentation beschreibt die verfügbaren Python Build Workflows und Konfigurationen für verschiedene Projekttypen.

## Übersicht

Das Python Build System besteht aus zwei wiederverwendbaren Workflows und fertigen Konfigurationen für verschiedene Projekttypen:

- **`python-build.yml`** - Build & Test: Installation, Tests mit Coverage, Lint, Format- und Type-Check, Security-Scan, Package-Build
- **`python-semantic-release.yml`** - Release & PyPI-Publishing, beschrieben in [Python Semantic Release](python-semantic-release.md)

## Erforderliche Caller-Permissions

`python-build.yml` ruft `modules-code-quality.yml` auf, das `pull-requests: write` deklariert. Ein aufgerufener Workflow kann die Permissions des Callers nur **einschränken**, nie erweitern — der Scope muss also aus dem **aufrufenden** Job kommen:

```yaml
jobs:
  build:
    permissions:
      contents: read
      pull-requests: write    # Pflicht: von modules-code-quality.yml deklariert
    uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main
    with:
      python-version: '3.12'
    secrets: inherit
```

Das gilt **auch bei `enable-sonar: false`** (dem Default). GitHub prüft die Permissions aller aufgerufenen Workflows beim Erzeugen des Runs, **bevor** irgendein `if:` eines Jobs ausgewertet wird — das Opt-in erspart den Scope also nicht.

Fehlt er, startet der Run gar nicht. Es gibt keinen Job und kein Log, nur `startup_failure`:

```text
The workflow is requesting 'pull-requests: write', but is only allowed 'pull-requests: none'.
```

Den Scope explizit deklarieren, nicht auf den Default verlassen: Ein **partieller** `permissions:`-Block setzt jeden nicht genannten Scope auf `none`, und der Repository-Default `Read repository contents and package permissions` steht ohnehin schon auf `pull-requests: none`. Nur der Default `Read and write permissions` deckt ihn implizit ab.

Die vollständige Obergrenzen-Regel — und dieselbe Falle für `packages: read` — steht in [GHCR internal visibility](../ghcr-internal-visibility.md).

## Verfügbare Workflows

### Python Build & Test (`python-build.yml`)

Wiederverwendbarer Workflow (`workflow_call`) für Anwendungen und Pakete. Die einzelnen Prüfungen werden über Inputs ein- und ausgeschaltet:

| Bereich | Inputs |
|---------|--------|
| Python-Version | `python-version` (kommagetrennt für mehrere), `python-version-file`, `enable-matrix` |
| Installation | `package-manager`, `requirements-files`, `install-command`, `use-venv`, `cache-dependencies` |
| Tests | `run-tests`, `test-framework`, `test-command`, `collect-coverage`, `coverage-threshold` |
| Code-Qualität | `run-lint`, `linter`, `run-format-check`, `formatter`, `run-isort-check`, `run-type-check`, `type-checker` |
| Security | `run-security-scan`, `security-tools` |
| Paket | `build-package`, `build-tools`, `package-check` |

Den Aufruf mit den nötigen Permissions zeigt [Erforderliche Caller-Permissions](#erforderliche-caller-permissions). Alle Inputs mit ihren Defaults stehen im Kopf von [`python-build.yml`](../../.github/workflows/python-build.yml).

### Release & PyPI-Publishing (`python-semantic-release.yml`)

Versionierung nach Conventional Commits, Build und Upload zu PyPI. Details in [Python Semantic Release](python-semantic-release.md).

> **Nicht mehr beschrieben:** Frühere Fassungen dieser Seite nannten `python-app.yml`, `python-package.yml`, `python-publish.yml` und `python-docker.yml`. Keiner dieser Workflows existiert in diesem Repository (`python-publish.yml` wurde am 2025-09-01 entfernt), und ein `uses:` darauf lässt den ganzen Run mit `startup_failure` scheitern. Fürs Publishing dient `python-semantic-release.yml`, für Container-Images von Python-Anwendungen [`docker-build.yml`](docker-build.md).

## Konfigurationsdateien

Alle Konfigurationen befinden sich in `.github/config/python-build/`:

### `default.yml`
Grundkonfiguration für einfache Python-Projekte.

```yaml
python:
  version: "3.12"
  cache: "pip"

testing:
  framework: "pytest"
  coverage: true
  coverage_threshold: 80

linting:
  flake8:
    enabled: true
    max_line_length: 127
```

### `web-app.yml`
Konfiguration für Web-Anwendungen (Flask, Django, FastAPI).

```yaml
python:
  version: "3.12"

testing:
  coverage_threshold: 85
  integration_tests: true

linting:
  black:
    enabled: true
  isort:
    enabled: true

security:
  bandit:
    enabled: true
    fail_on_error: true

docker:
  build: true
  security_scan: true
```

### `package.yml`
Konfiguration für PyPI-Pakete.

```yaml
python:
  versions: ["3.9", "3.10", "3.11", "3.12"]

matrix:
  os: ["ubuntu-latest", "windows-latest", "macos-latest"]

publishing:
  testpypi:
    enabled: true
  pypi:
    enabled: true
    trusted_publishing: true
```

### `data-science.yml`
Spezielle Konfiguration für Data Science Projekte.

```yaml
python:
  version: "3.12"
  conda_support: true

notebooks:
  execution_test: true
  output_cleanup: true

ml_specific:
  model_validation: true
  reproducibility_check: true
```

### `microservice.yml`
Konfiguration für Microservices.

```yaml
docker:
  build: true
  multi_platform: true
  security_scan: true

api_testing:
  openapi_validation: true
  contract_testing: true

deployment:
  kubernetes: true
  helm_charts: true
```

## Beispiel-Workflows

### FastAPI Anwendung (`python-fastapi-example.yml`)

Vollständige CI/CD Pipeline für FastAPI mit PostgreSQL und Redis.

**Features:**
- Service Container (PostgreSQL, Redis)
- Database Migrations (Alembic)
- API Integration Tests
- Security Scanning
- Container Deployment

### Django Anwendung (`python-django-example.yml`)

Django-spezifische Pipeline mit Frontend-Integration.

**Features:**
- Node.js für Frontend Assets
- Django Management Commands
- Static Files Collection
- Database Migrations
- Performance Tests

### Machine Learning (`python-ml-example.yml`)

ML-Pipeline mit Model Training und Deployment.

**Features:**
- Data Validation
- Model Training
- Model Testing
- Performance Validation
- ML Service Deployment
- Model Registry Integration

## Secrets und Umgebungsvariablen

### Erforderliche Secrets

Für verschiedene Workflows werden folgende Secrets benötigt:

```yaml
# GitHub Token (automatisch verfügbar)
GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

# Für PyPI Publishing
PYPI_API_TOKEN: ${{ secrets.PYPI_API_TOKEN }}
TEST_PYPI_API_TOKEN: ${{ secrets.TEST_PYPI_API_TOKEN }}

# Für Docker Registry
DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}

# Für Cloud Deployment
AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Umgebungsvariablen

```yaml
env:
  PYTHON_version: "3.12"
  DATABASE_URL: "postgresql://user:pass@localhost/db"
  REDIS_URL: "redis://localhost:6379"
  SECRET_KEY: ${{ secrets.SECRET_KEY }}
```

## Best Practices

### 1. Dependency Management

```yaml
# requirements.txt - Produktions-Dependencies
requests>=2.28.0
fastapi>=0.68.0
uvicorn[standard]>=0.15.0

# requirements-dev.txt - Entwicklungs-Dependencies
pytest>=7.0.0
pytest-cov>=4.0.0
black>=22.0.0
isort>=5.10.0
mypy>=0.991
```

### 2. Testing

```yaml
# pytest.ini
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = 
    --strict-markers
    --disable-warnings
    --cov=src
    --cov-report=term-missing
    --cov-report=html
```

### 3. Code Quality

```yaml
# pyproject.toml
[tool.black]
line-length = 88
target-version = ['py312']

[tool.isort]
profile = "black"
multi_line_output = 3

[tool.mypy]
python_version = "3.12"
strict = true
```

### 4. Security

```yaml
# .bandit
[bandit]
exclude_dirs = ["tests", "venv"]
skips = ["B101", "B601"]
```

## Troubleshooting

### Häufige Probleme

1. **Import Fehler**
   ```bash
   # Lösung: Package im Development Modus installieren
   pip install -e .
   ```

2. **Test Failures**
   ```bash
   # Debug mit verbose output
   pytest -v --tb=long
   ```

3. **Coverage zu niedrig**
   ```bash
   # Coverage Report anzeigen
   pytest --cov-report=html
   open htmlcov/index.html
   ```

4. **Docker Build Fehler**
   ```bash
   # Multi-stage Build verwenden
   FROM python:3.12-slim as builder
   # ... build steps
   FROM python:3.12-slim as runtime
   ```

### Performance Optimierung

1. **Caching**
   ```yaml
   - uses: actions/setup-python@v7
     with:
       python-version: "3.12"
       cache: 'pip'
   ```

2. **Parallel Testing**
   ```yaml
   - name: Test with pytest
     run: pytest -n auto
   ```

3. **Matrix Optimization**
   ```yaml
   strategy:
     fail-fast: false
     matrix:
       python-version: ["3.11", "3.12"]
       exclude:
         - python-version: "3.9"
           os: windows-latest
   ```

## Migration von anderen CI-Systemen

### Von Travis CI

```yaml
# Vorher (Travis CI)
language: python
python: "3.12"
script: pytest

# Nachher (GitHub Actions)
- uses: actions/setup-python@v7
  with:
    python-version: "3.12"
- run: pytest
```

### Von GitLab CI

```yaml
# Vorher (GitLab CI)
test:
  image: python:3.12
  script:
    - pip install -r requirements.txt
    - pytest

# Nachher (GitHub Actions)
- uses: actions/setup-python@v7
  with:
    python-version: "3.12"
    cache: 'pip'
- run: |
    pip install -r requirements.txt
    pytest
```

## Platform Configuration

| Input | Description | Default | Options |
|-------|-------------|---------|---------|
| `runs-on` | Runner to use | `ubuntu-latest` | String or JSON array (see below) |
| `timeout-minutes` | Job timeout | `30` | Minutes |

### Self-Hosted Runner Support

The `runs-on` parameter supports both GitHub-hosted and self-hosted runners:

```yaml
# GitHub-hosted (string)
runs-on: 'ubuntu-latest'

# Self-hosted (JSON array)
runs-on: '["self-hosted", "linux"]'
runs-on: '["self-hosted", "linux", "docker"]'
```

See [Self-Hosted Runner Documentation](../self-hosted-runners.md) for details.

## Weitere Ressourcen

- [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
- [Python Packaging Leitfaden](https://packaging.python.org/)
- [pytest Dokumentation](https://docs.pytest.org/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)