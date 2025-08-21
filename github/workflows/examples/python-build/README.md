# Python Build Workflows

Sammlung von GitHub Actions Workflows für Python-Projekte aller Art.

## 🚀 Schnellstart

1. **Workflow kopieren** - Wählen Sie den passenden Workflow für Ihr Projekt
2. **Konfiguration anpassen** - Nutzen Sie die entsprechende Config-Datei aus `.github/config/python-build/`
3. **Secrets einrichten** - Konfigurieren Sie die benötigten Repository-Secrets
4. **Workflow aktivieren** - Committen Sie die Datei nach `.github/workflows/`

## 📁 Verfügbare Workflows

### Basic Workflows

| Workflow | Beschreibung | Verwendung |
|----------|--------------|------------|
| [`python-app.yml`](./python-app.yml) | Einfache Python-Anwendung | Web-Apps, Scripts, CLI-Tools |
| [`python-package.yml`](./python-package.yml) | Python-Paket für PyPI | Libraries, Frameworks |
| [`python-publish.yml`](./python-publish.yml) | PyPI Publishing | Automatische Releases |
| [`python-docker.yml`](./python-docker.yml) | Docker Build & Deploy | Containerisierte Apps |

### Beispiel-Workflows

| Workflow | Framework | Features |
|----------|-----------|----------|
| [`python-fastapi-example.yml`](./python-fastapi-example.yml) | FastAPI | PostgreSQL, Redis, API-Tests |
| [`python-django-example.yml`](./python-django-example.yml) | Django | Migrations, Static Files, Frontend |
| [`python-ml-example.yml`](./python-ml-example.yml) | Scikit-learn/ML | Model Training, Validation, Deployment |

## ⚙️ Konfigurationen

Alle Konfigurationsdateien befinden sich in [`.github/config/python-build/`](../../.github/config/python-build/):

- **`default.yml`** - Standard-Konfiguration für einfache Projekte
- **`web-app.yml`** - Web-Anwendungen (Flask, Django, FastAPI)
- **`package.yml`** - PyPI-Pakete mit Multi-Platform Testing
- **`data-science.yml`** - Data Science und ML-Projekte
- **`microservice.yml`** - Microservices mit Kubernetes

## 🛠️ Setup-Anleitung

### 1. Basic Python Application

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-python@v5
      with:
        python-version: "3.11"
        cache: 'pip'
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
        pip install pytest pytest-cov
    - name: Run tests
      run: pytest --cov=. --cov-report=xml
```

### 2. FastAPI with Database

```yaml
# Kopiere python-fastapi-example.yml
# Anpassungen:
services:
  postgres:
    image: postgres:15
    env:
      POSTGRES_DB: your_db_name
      POSTGRES_USER: your_user
      POSTGRES_PASSWORD: your_password
```

### 3. Package Publishing

```yaml
# Kopiere python-publish.yml
# Erforderliche Secrets:
# - PYPI_API_TOKEN (für PyPI)
# - TEST_PYPI_API_TOKEN (für TestPyPI)
```

## 🔧 Erforderliche Dateien

### Minimal Setup

```
your-project/
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   └── your_package/
├── tests/
├── requirements.txt
├── requirements-dev.txt
├── setup.py oder pyproject.toml
└── README.md
```

### requirements.txt
```txt
# Produktions-Dependencies
requests>=2.28.0
click>=8.0.0
```

### requirements-dev.txt
```txt
# Entwicklungs-Dependencies
pytest>=7.0.0
pytest-cov>=4.0.0
black>=22.0.0
flake8>=5.0.0
mypy>=0.991
```

### pyproject.toml
```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "your-package"
version = "0.1.0"
description = "Your package description"
authors = [{name = "Your Name", email = "your.email@example.com"}]
license = {text = "MIT"}
```

## 🔐 Repository Secrets

Je nach Workflow benötigen Sie verschiedene Secrets:

### Basis Secrets
```
GITHUB_TOKEN          # Automatisch verfügbar
```

### PyPI Publishing
```
PYPI_API_TOKEN        # PyPI API Token
TEST_PYPI_API_TOKEN   # TestPyPI API Token
```

### Docker Registry
```
DOCKER_USERNAME       # Docker Hub Username
DOCKER_PASSWORD       # Docker Hub Token
```

### Cloud Deployment
```
AWS_ACCESS_KEY_ID     # AWS Credentials
AWS_SECRET_ACCESS_KEY
AZURE_CLIENT_ID       # Azure Credentials
AZURE_CLIENT_SECRET
```

## 📊 Unterstützte Features

### Testing & Quality
- ✅ pytest mit Coverage
- ✅ flake8 Linting
- ✅ Black Code Formatting
- ✅ isort Import Sorting
- ✅ mypy Type Checking
- ✅ bandit Security Scanning
- ✅ safety Dependency Scanning

### Builds & Deployment
- ✅ Multi-Platform Testing (Linux, Windows, macOS)
- ✅ Multiple Python Versions (3.9-3.12)
- ✅ Docker Multi-Platform Builds
- ✅ PyPI/TestPyPI Publishing
- ✅ GitHub Container Registry
- ✅ Kubernetes Deployment

### Integrations
- ✅ Codecov Coverage Reports
- ✅ GitHub Security Advisories
- ✅ Dependabot Integration
- ✅ Artifact Uploads
- ✅ Test Result Publishing

## 🚀 Erweiterte Beispiele

### ML-Pipeline mit DVC
```yaml
- name: Setup DVC
  run: |
    pip install dvc[s3]
    dvc pull

- name: Train Model
  run: |
    python train.py
    dvc add models/model.pkl
```

### Multi-Environment Deployment
```yaml
deploy-staging:
  if: github.ref == 'refs/heads/develop'
  environment:
    name: staging
    url: https://staging.example.com

deploy-production:
  if: github.ref == 'refs/heads/main'
  environment:
    name: production
    url: https://example.com
```

### Matrix Testing mit Services
```yaml
strategy:
  matrix:
    python-version: ["3.10", "3.11", "3.12"]
    database: ["postgresql", "mysql"]

services:
  db:
    image: ${{ matrix.database == 'postgresql' && 'postgres:15' || 'mysql:8' }}
```

## 🐛 Troubleshooting

### Häufige Probleme

**Import Error bei Tests**
```bash
# Lösung: Package installieren
pip install -e .
```

**Coverage zu niedrig**
```bash
# Lösung: Coverage-Konfiguration anpassen
pytest --cov=src --cov-fail-under=80
```

**Docker Build langsam**
```dockerfile
# Lösung: Multi-stage Build verwenden
FROM python:3.11-slim as builder
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.11-slim
COPY --from=builder /root/.local /root/.local
```

**Flake8 Fehler**
```ini
# setup.cfg
[flake8]
max-line-length = 88
extend-ignore = E203, W503
exclude = venv/, build/, dist/
```

## 📚 Zusätzliche Ressourcen

- [GitHub Actions Python Guide](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-python)
- [Python Packaging User Guide](https://packaging.python.org/)
- [pytest Documentation](https://docs.pytest.org/)
- [Docker Python Best Practices](https://docs.docker.com/language/python/)

## 🤝 Contributing

Beiträge sind willkommen! Bitte:

1. Fork das Repository
2. Erstelle einen Feature Branch
3. Teste deine Änderungen
4. Erstelle eine Pull Request

## 📄 Lizenz

MIT License - siehe [LICENSE](../../../LICENSE) für Details.