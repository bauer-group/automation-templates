# Python Build Workflows

Diese Dokumentation beschreibt die verfügbaren Python Build Workflows und Konfigurationen für verschiedene Projekttypen.

## Übersicht

Das Python Build System bietet mehrere vorgefertigte Workflows für unterschiedliche Python-Anwendungstypen:

- **Python Application** - Einfache Python-Anwendungen
- **Python Package** - Pakete für PyPI
- **Python Docker** - Containerisierte Anwendungen
- **Python Publish** - Publishing zu PyPI/TestPyPI

## Verfügbare Workflows

### 1. Python Application (`python-app.yml`)

Grundlegender CI-Workflow für Python-Anwendungen.

**Features:**
- Python 3.12 Setup
- Virtual Environment
- Dependency Installation
- Security Checks (Safety, Bandit)
- Linting (flake8)
- Testing (pytest mit Coverage)
- Codecov Integration
- Test Results Upload

**Verwendung:**
```yaml
name: My Python App CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    uses: ./.github/workflows/python-app.yml
```

### 2. Python Package (`python-package.yml`)

Multi-Platform CI für Python-Pakete mit verschiedenen Python-Versionen.

**Features:**
- Matrix Build (Python 3.9-3.12, Ubuntu/Windows/macOS)
- Code Formatting (Black, isort)
- Type Checking (mypy)
- Package Building
- Package Validation
- Cross-Platform Testing

**Verwendung:**
```yaml
name: Python Package CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    uses: ./.github/workflows/python-package.yml
```

### 3. Python Publishing (`python-publish.yml`)

Automatisches Publishing zu PyPI/TestPyPI.

**Features:**
- Trusted Publishing (OIDC)
- TestPyPI Support
- Production PyPI Publishing
- Pre-Publishing Tests
- GitHub Release Creation

**Verwendung:**
```yaml
name: Publish Python Package

on:
  release:
    types: [published]

jobs:
  publish:
    uses: ./.github/workflows/python-publish.yml
```

### 4. Python Docker (`python-docker.yml`)

Docker Build und Deployment Pipeline.

**Features:**
- Multi-Platform Docker Builds
- GitHub Container Registry
- Security Scanning (Trivy)
- Staging/Production Deployment
- Image Caching

**Verwendung:**
```yaml
name: Docker Build & Deploy

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]

jobs:
  docker:
    uses: ./.github/workflows/python-docker.yml
```

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
   - uses: actions/setup-python@v5
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
- uses: actions/setup-python@v5
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
- uses: actions/setup-python@v5
  with:
    python-version: "3.12"
    cache: 'pip'
- run: |
    pip install -r requirements.txt
    pytest
```

## Weitere Ressourcen

- [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
- [Python Packaging Leitfaden](https://packaging.python.org/)
- [pytest Dokumentation](https://docs.pytest.org/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)