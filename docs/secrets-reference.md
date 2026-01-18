# Secrets Reference

Diese Dokumentation listet alle Secrets auf, die von den Workflows in diesem Repository verwendet werden.

## Quick Setup

Für die meisten Projekte werden folgende **Organization Secrets** benötigt:

| Secret | Erforderlich | Beschreibung |
|--------|--------------|--------------|
| `CODECOV_TOKEN` | Empfohlen | Global Upload Token für Code Coverage |
| `DOCKER_USERNAME` | Optional | Docker Hub Benutzername |
| `DOCKER_PASSWORD` | Optional | Docker Hub Passwort/Token |
| `GITGUARDIAN_API_KEY` | Optional | GitGuardian Secret Scanning |
| `GITLEAKS_LICENSE` | Optional | Gitleaks Enterprise License |
| `NUGET_API_KEY` | Optional | NuGet.org API Key |
| `PYPI_API_TOKEN` | Optional | PyPI Publishing Token |
| `TEAMS_WEBHOOK_URL` | Optional | Microsoft Teams Notifications |

## Secrets nach Kategorie

### Automatisch verfügbar

| Secret | Beschreibung |
|--------|--------------|
| `GITHUB_TOKEN` | Automatisch von GitHub bereitgestellt. Berechtigt für das aktuelle Repository. |

### Code Coverage

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `CODECOV_TOKEN` | dotnet-build, nodejs-build, python-build | Upload Token für Codecov | [codecov.io](https://codecov.io) → Organization Settings → Global Upload Token |

> **Tipp:** Verwende den **Global Upload Token** auf Organization-Ebene, damit der gleiche Token für alle Repositories funktioniert.

### Docker & Container

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `DOCKER_USERNAME` | docker-build, dotnet-build, nodejs-build | Docker Hub Benutzername | [hub.docker.com](https://hub.docker.com) Account Settings |
| `DOCKER_PASSWORD` | docker-build, dotnet-build, nodejs-build | Docker Hub Access Token | Docker Hub → Account Settings → Security → Access Tokens |
| `COSIGN_PRIVATE_KEY` | docker-build | Sigstore Cosign Private Key | `cosign generate-key-pair` |
| `COSIGN_PASSWORD` | docker-build | Passwort für Cosign Key | Selbst festlegen |

### .NET

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `DOTNET_SIGNKEY_BASE64` | dotnet-build, dotnet-nuget | Base64-kodierter SNK Key für Assembly Signing | `base64 -w 0 MyKey.snk` |
| `DOTNET_NUGET_PUBLISH_API_KEY` | dotnet-build | NuGet.org API Key | [nuget.org](https://www.nuget.org) → API Keys |
| `NUGET_API_KEY` | dotnet-build | Alternative für NuGet API Key | [nuget.org](https://www.nuget.org) → API Keys |
| `DOTNET_SIGNING_CERTIFICATE_BASE64` | dotnet-desktop-build | Base64-kodiertes Code Signing Zertifikat (.pfx) | `base64 -w 0 cert.pfx` |
| `DOTNET_SIGNING_CERTIFICATE_PASSWORD` | dotnet-desktop-build | Passwort für das Signing Zertifikat | Zertifikat-Passwort |

### Python

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `PYPI_API_TOKEN` | python-build, python-publish | PyPI API Token für Publishing | [pypi.org](https://pypi.org) → Account Settings → API Tokens |
| `TEST_PYPI_API_TOKEN` | python-build | TestPyPI API Token | [test.pypi.org](https://test.pypi.org) → Account Settings → API Tokens |

### Node.js

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `NPM_TOKEN` | nodejs-build | NPM Access Token | [npmjs.com](https://www.npmjs.com) → Access Tokens |

### Security Scanning

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `GITGUARDIAN_API_KEY` | security-scan-meta, gitleaks-scan | GitGuardian API Key | [gitguardian.com](https://dashboard.gitguardian.com) → API → Personal Access Tokens |
| `GITLEAKS_LICENSE` | gitleaks-scan | Gitleaks Enterprise License Key | Gitleaks Enterprise Subscription |
| `FOSSA_API_KEY` | license-compliance | FOSSA License Scanning | [fossa.com](https://fossa.com) → Account Settings |

### Notifications

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `TEAMS_WEBHOOK_URL` | teams-notification | Microsoft Teams Incoming Webhook | Teams Channel → Connectors → Incoming Webhook |
| `TEAMS_WEBHOOK_PROD` | teams-notification | Webhook für Production Channel | Teams Channel → Connectors |
| `TEAMS_WEBHOOK_DEV` | teams-notification | Webhook für Development Channel | Teams Channel → Connectors |
| `TEAMS_WEBHOOK_STAGING` | teams-notification | Webhook für Staging Channel | Teams Channel → Connectors |
| `TEAMS_WEBHOOK_SECURITY` | teams-notification | Webhook für Security Channel | Teams Channel → Connectors |

### Deployment

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `COOLIFY_API_TOKEN` | coolify-deploy | Coolify API Token | Coolify Dashboard → API Tokens |

### AI / Claude Code

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `CLAUDE_CODE_OAUTH_TOKEN` | claude-code | Claude Code OAuth Token | [claude.ai](https://claude.ai) OAuth Setup |
| `ANTHROPIC_API_KEY` | claude-code | Anthropic API Key | [console.anthropic.com](https://console.anthropic.com) → API Keys |

### Shopware

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `SHOPWARE_ACCOUNT_EMAIL` | shopware5-build | Shopware Account E-Mail | Shopware Account |
| `SHOPWARE_ACCOUNT_PASSWORD` | shopware5-build | Shopware Account Passwort | Shopware Account |
| `COMPOSER_AUTH_JSON` | shopware5-build | Composer auth.json Inhalt | JSON mit Repository-Credentials |

### Cross-Repository Access

| Secret | Workflows | Beschreibung | Einrichtung |
|--------|-----------|--------------|-------------|
| `PAT_READONLY_ORGANISATION` | meta-repository-sync, etc. | Personal Access Token mit `read:org` Scope | GitHub → Settings → Developer Settings → PAT |

## Organization vs Repository Secrets

### Organization Secrets (empfohlen)

Secrets die für **alle Repositories** gelten sollen:

```
GitHub Organization → Settings → Secrets and variables → Actions → New organization secret
```

**Empfohlene Organization Secrets:**
- `CODECOV_TOKEN` (Global Upload Token)
- `DOCKER_USERNAME` / `DOCKER_PASSWORD`
- `GITGUARDIAN_API_KEY`
- `GITLEAKS_LICENSE`
- `NUGET_API_KEY`
- `PYPI_API_TOKEN`
- `TEAMS_WEBHOOK_URL`
- `PAT_READONLY_ORGANISATION`

### Repository Secrets

Secrets die nur für **ein spezifisches Repository** gelten:

```
Repository → Settings → Secrets and variables → Actions → New repository secret
```

**Typische Repository Secrets:**
- `DOTNET_SIGNKEY_BASE64` (projektspezifischer Signing Key)
- `COOLIFY_API_TOKEN` (projektspezifisches Deployment)
- Umgebungsspezifische Credentials

## Secrets erstellen

### Base64-Encoding (für Binärdateien)

```bash
# Linux/macOS
base64 -w 0 < MyKey.snk > MyKey.snk.base64
cat MyKey.snk.base64

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("MyKey.snk"))
```

### GitHub CLI

```bash
# Organization Secret
gh secret set CODECOV_TOKEN --org your-org --body "your-token-value"

# Repository Secret
gh secret set DOTNET_SIGNKEY_BASE64 --body "$(base64 -w 0 < MyKey.snk)"
```

## Workflow-spezifische Secrets

### dotnet-build.yml

```yaml
secrets:
  DOTNET_SIGNKEY_BASE64: ${{ secrets.DOTNET_SIGNKEY_BASE64 }}      # Assembly Signing
  DOTNET_NUGET_PUBLISH_API_KEY: ${{ secrets.NUGET_API_KEY }}       # NuGet Publishing
  CODECOV_UPLOAD_TOKEN: ${{ secrets.CODECOV_TOKEN }}               # Coverage Upload
  DOCKER_REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}         # Docker Push
  DOCKER_REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}         # Docker Push
```

### nodejs-build.yml

```yaml
secrets:
  NPM_TOKEN: ${{ secrets.NPM_TOKEN }}                # NPM Publishing
  CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}        # Coverage Upload
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}    # Docker Push
  DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}    # Docker Push
```

### python-build.yml

```yaml
secrets:
  PYPI_API_TOKEN: ${{ secrets.PYPI_API_TOKEN }}           # PyPI Publishing
  TEST_PYPI_API_TOKEN: ${{ secrets.TEST_PYPI_API_TOKEN }} # TestPyPI Publishing
  CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}             # Coverage Upload
```

### docker-build.yml

```yaml
secrets:
  DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}         # Docker Hub Auth
  DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}         # Docker Hub Auth
  COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}   # Image Signing
  COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}         # Cosign Key Password
```

## Troubleshooting

### Secret nicht gefunden

```
Error: Input required and not supplied: api-key
```

**Lösung:** Secret in Organization oder Repository Settings hinzufügen.

### Secret leer oder ungültig

```
Error: Authentication failed
```

**Lösung:**
1. Secret-Wert prüfen (keine führenden/nachfolgenden Leerzeichen)
2. Token-Berechtigungen prüfen
3. Token-Ablaufdatum prüfen

### Base64-Encoding Probleme

```
Error: Invalid base64 input
```

**Lösung:** Sicherstellen, dass `-w 0` (keine Zeilenumbrüche) verwendet wird:
```bash
base64 -w 0 < file.bin
```

## Siehe auch

- [GitHub Encrypted Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Self-Hosted Runner Documentation](./self-hosted-runners.md)
- [Workflow Documentation](./workflows/)
