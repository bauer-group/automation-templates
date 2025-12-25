# Coolify Deployment Examples

This folder contains example workflows for deploying applications to Coolify using the reusable `coolify-deploy.yml` workflow.

## Examples

| Example | Description | Use Case |
|---------|-------------|----------|
| [simple-deploy.yml](simple-deploy.yml) | Minimal fire-and-forget deployment | Quick deployments without status tracking |
| [deploy-with-wait.yml](deploy-with-wait.yml) | Deployment with status monitoring | When you need deployment confirmation |
| [docker-build-and-deploy.yml](docker-build-and-deploy.yml) | Full CI/CD pipeline with Docker build | Containerized applications on GHCR |
| [multi-environment-deploy.yml](multi-environment-deploy.yml) | Staged deployment (staging -> production) | Production-grade deployment pipelines |

## Quick Start

### 1. Configure Secrets

Add the following secret to your repository or organization:

- `COOLIFY_API_TOKEN`: Your Coolify API token

### 2. Get Your App UUID

1. Open your Coolify dashboard
2. Navigate to your application
3. Copy the UUID from the URL: `/project/xxx/application/YOUR-UUID`

### 3. Copy an Example

Choose an example that fits your needs and copy it to your repository's `.github/workflows/` folder.

### 4. Update Configuration

Replace the placeholder values:

```yaml
with:
  coolify-url: 'https://your-coolify-instance.com'  # Your Coolify URL
  app-uuid: 'your-actual-app-uuid'                   # Your app UUID
```

## Workflow Comparison

| Feature | Simple | With Wait | Docker+Deploy | Multi-Env |
|---------|--------|-----------|---------------|-----------|
| Fire & Forget | ✅ | ❌ | ❌ | ❌ |
| Status Tracking | ❌ | ✅ | ✅ | ✅ |
| Docker Build | ❌ | ❌ | ✅ | ✅ |
| Multiple Environments | ❌ | ❌ | ❌ | ✅ |
| Smoke Tests | ❌ | ❌ | ❌ | ✅ |
| Manual Triggers | ✅ | ✅ | ✅ | ✅ |
| Tag Deployments | ❌ | ✅ | ✅ | ✅ |

## Common Customizations

### Deploy on Tags Only

```yaml
on:
  push:
    tags: ['v*.*.*']
```

### Deploy Specific Branch

```yaml
on:
  push:
    branches: [production]
```

### Add Manual Approval

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://example.com
    # Configure environment protection rules in GitHub settings
```

### Notify on Failure

```yaml
notify:
  needs: deploy
  if: failure()
  runs-on: ubuntu-latest
  steps:
    - name: Send Alert
      run: |
        curl -X POST "$WEBHOOK_URL" \
          -d '{"text": "Deployment failed!"}'
```

## Troubleshooting

### Deployment Not Triggering

1. Check `COOLIFY_API_TOKEN` is set correctly
2. Verify the `app-uuid` is correct
3. Ensure Coolify instance is accessible

### Timeout Issues

Increase the timeout for slow deployments:

```yaml
with:
  wait-timeout: 900  # 15 minutes
```

### Force Rebuild Not Working

Ensure your Coolify application is configured to accept force rebuilds:

```yaml
with:
  force: true
```

## Related Documentation

- [Coolify Deploy Workflow Documentation](../../../../docs/workflows/coolify-deploy.md)
- [Docker Build Workflow Documentation](../../../../docs/workflows/docker-build.md)
- [Coolify Official Docs](https://coolify.io/docs)
