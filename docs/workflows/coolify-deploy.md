# Coolify Deployment Workflow

This document describes the Coolify deployment workflow provided by the automation-templates repository. The workflow enables standardized, automated deployments to Coolify-hosted applications via the Coolify REST API.

## Overview

The Coolify deployment workflow provides:

- **REST API Integration**: Direct integration with Coolify's REST API for programmatic deployments
- **Wait for Completion**: Optional polling for deployment status
- **Force Rebuild**: Trigger complete rebuilds when needed
- **Tag-based Deployment**: Deploy specific image versions
- **Error Handling**: Comprehensive error handling with detailed messages
- **Status Tracking**: Real-time deployment status with GitHub job summaries

## REST API vs. GitHub App

Coolify offers two deployment methods:

| Method                       | Trigger                              | Use Case                             |
|------------------------------|--------------------------------------|--------------------------------------|
| **GitHub App** (Webhooks)    | Automatic on every push              | Simple projects, auto-deploy         |
| **REST API** (this workflow) | Manual/controlled via GitHub Actions | CI/CD pipelines, multi-environment   |

**Use this REST API workflow when:**

- You build Docker images externally (in GitHub Actions) before deploying
- You need deployments only after tests/scans pass
- You have multiple environments (staging → production)
- You want deployment status feedback in GitHub Actions
- You need manual approval gates

**Use the GitHub App when:**

- You want automatic deployments on every push
- Coolify builds your Docker image
- You have a simple single-environment setup

> **Note:** If you use the GitHub App with Auto Deploy enabled, you don't need this workflow.
> Webhooks are handled automatically by the GitHub App integration.

## Quick Start

### Minimal Usage (Fire & Forget)

```yaml
name: Deploy to Coolify
on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'your-app-uuid-here'
    secrets: inherit
```

### With Wait for Completion

```yaml
name: Deploy to Coolify
on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'your-app-uuid-here'
      wait-for-completion: true
      wait-timeout: 600
    secrets: inherit
```

## Input Parameters

### Required Inputs

| Parameter | Type | Description |
|-----------|------|-------------|
| `coolify-url` | string | Coolify instance URL (without trailing slash) |
| `app-uuid` | string | UUID of the Coolify application to deploy |

### Optional Inputs

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `force` | boolean | `false` | Force a complete rebuild of the application |
| `tag` | string | `''` | Specific image tag to deploy (empty = latest) |
| `wait-for-completion` | boolean | `false` | Wait for deployment to complete before finishing |
| `wait-timeout` | number | `300` | Timeout in seconds when waiting for completion |
| `fail-on-error` | boolean | `true` | Fail the workflow if deployment fails or times out |

## Required Secrets

| Secret | Required | Description |
|--------|----------|-------------|
| `COOLIFY_API_TOKEN` | Yes | API token for Coolify authentication |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `deployment-id` | string | UUID of the triggered deployment |
| `deployment-status` | string | Final status: `started`, `success`, `failed`, `timeout` |
| `deployment-url` | string | URL to view the deployment in Coolify |

## Deployment Modes

### Fire & Forget

The default mode triggers the deployment and completes immediately without waiting:

```yaml
with:
  coolify-url: 'https://coolify.example.com'
  app-uuid: 'abc123'
  # wait-for-completion: false (default)
```

**Pros:**
- Fastest workflow execution
- No timeout concerns
- Suitable for non-critical deployments

**Cons:**
- No immediate feedback on deployment success
- Must check Coolify dashboard for status

### Wait for Completion

Polls the Coolify API until deployment finishes:

```yaml
with:
  coolify-url: 'https://coolify.example.com'
  app-uuid: 'abc123'
  wait-for-completion: true
  wait-timeout: 600  # 10 minutes
```

**Pros:**
- Immediate feedback in GitHub Actions
- Can trigger subsequent jobs based on success
- Clear failure indication in workflow

**Cons:**
- Longer workflow execution time
- Consumes GitHub Actions minutes while polling

## Deployment Status Values

When `wait-for-completion` is enabled, the workflow tracks these statuses:

| Status | Description | Workflow Result |
|--------|-------------|-----------------|
| `success` / `finished` / `deployed` | Deployment completed successfully | Success |
| `failed` / `error` / `cancelled` | Deployment failed | Failure (if `fail-on-error: true`) |
| `running` / `pending` / `queued` / `building` | Deployment in progress | Continue polling |
| `timeout` | Wait timeout exceeded | Failure (if `fail-on-error: true`) |

## Examples

### Deploy Specific Tag

```yaml
jobs:
  deploy:
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'abc123'
      tag: 'v1.2.3'
    secrets: inherit
```

### Force Rebuild

```yaml
jobs:
  deploy:
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'abc123'
      force: true
    secrets: inherit
```

### With Status Evaluation

```yaml
jobs:
  deploy:
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'abc123'
      wait-for-completion: true
    secrets: inherit

  notify:
    name: Send Notification
    needs: deploy
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Notify on Success
        if: needs.deploy.outputs.deployment-status == 'success'
        run: echo "Deployment successful!"

      - name: Notify on Failure
        if: needs.deploy.outputs.deployment-status == 'failed'
        run: echo "Deployment failed!"
```

### Combined with Docker Build

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'ghcr'
      ghcr-image-name: 'my-org/my-app'
      auto-tags: true
    secrets: inherit

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'abc123'
      wait-for-completion: true
    secrets: inherit
```

### Multi-Environment Deployment

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'ghcr'
      auto-tags: true
    secrets: inherit

  deploy-staging:
    needs: build
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'staging-app-uuid'
      wait-for-completion: true
    secrets: inherit

  deploy-production:
    needs: deploy-staging
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'production-app-uuid'
      wait-for-completion: true
      wait-timeout: 900
    secrets: inherit
```

## Secret Configuration

### Organization Level (Recommended)

1. Navigate to: `github.com/organizations/YOUR-ORG/settings/secrets/actions`
2. Click "New organization secret"
3. Name: `COOLIFY_API_TOKEN`
4. Value: Your Coolify API token
5. Repository access: Select repositories or "All repositories"

### Repository Level

1. Navigate to: `github.com/YOUR-ORG/YOUR-REPO/settings/secrets/actions`
2. Click "New repository secret"
3. Name: `COOLIFY_API_TOKEN`
4. Value: Your Coolify API token

### Creating a Coolify API Token

1. Open your Coolify dashboard
2. Navigate to: **Security** > **API Tokens**
3. Click "Create New Token"
4. Enter a descriptive name: `GitHub Actions - YOUR-REPO`
5. **Copy the token immediately** - it is only shown once!
6. Store as GitHub secret: `COOLIFY_API_TOKEN`

> **Important:** The REST API must be enabled in Coolify. If you see "API not enabled",
> go to **Settings** and enable the REST API.

## Error Handling

### HTTP Status Codes

| Code | Error | Resolution |
|------|-------|------------|
| `401` | Unauthorized | Check `COOLIFY_API_TOKEN` is valid |
| `403` | Forbidden | Verify token has deployment permissions |
| `404` | Not Found | Check `app-uuid` is correct |
| `422` | Validation Error | Review request parameters |
| `429` | Rate Limited | Wait and retry, or reduce deployment frequency |
| `5xx` | Server Error | Coolify server issue, retry later |

### Common Issues

**1. "COOLIFY_API_TOKEN secret is not set"**
- Ensure the secret is configured at organization or repository level
- Check the secret name matches exactly: `COOLIFY_API_TOKEN`
- Verify repository has access to organization secrets

**2. "Application not found"**
- Verify the `app-uuid` is correct
- Check the application exists in Coolify
- Ensure the API token has access to this application

**3. "Deployment timed out"**
- Increase `wait-timeout` value
- Check Coolify server performance
- Review application logs in Coolify

**4. "Cannot wait for completion - no deployment ID"**
- Some Coolify versions may not return deployment IDs
- Deployment was likely triggered successfully
- Check Coolify dashboard for status

## API Reference

The workflow uses the Coolify REST API. The API base URL is `https://your-coolify-instance.com/api/v1`.

### Deploy Endpoint

Triggers a deployment for one or more applications.

```http
GET /api/v1/deploy
```

**Query Parameters:**

| Parameter | Type    | Required | Description                                    |
|-----------|---------|----------|------------------------------------------------|
| `uuid`    | string  | Yes      | Application UUID (comma-separated for multiple)|
| `force`   | boolean | No       | Force rebuild without cache (default: false)   |
| `tag`     | string  | No       | Specific image tag to deploy                   |

**Headers:**

```http
Authorization: Bearer <COOLIFY_API_TOKEN>
Accept: application/json
```

**Response (200 OK):**

```json
{
  "deployments": [
    {
      "message": "Deployment started",
      "resource_uuid": "abc123",
      "deployment_uuid": "dep-xyz-789"
    }
  ]
}
```

### Alternative: Application Start Endpoint

You can also trigger a deployment for a specific application:

```http
GET /api/v1/applications/{uuid}/start
POST /api/v1/applications/{uuid}/start
```

### Deployment Status Endpoint

Check the status of a running deployment:

```http
GET /api/v1/deployments/{deployment_uuid}
```

**Response:**

```json
{
  "status": "running",
  "started_at": "2024-01-15T10:30:00Z",
  "finished_at": null,
  "logs": "..."
}
```

### API Documentation

For the complete API reference, see the [Coolify API Documentation](https://coolify.io/docs/api-reference/api/).

## Best Practices

### 1. Use Wait for Critical Deployments

For production deployments, always enable wait-for-completion:

```yaml
with:
  wait-for-completion: true
  wait-timeout: 600
  fail-on-error: true
```

### 2. Chain Deployments with Dependencies

Use GitHub Actions job dependencies for staged rollouts:

```yaml
jobs:
  deploy-staging:
    # ...

  deploy-production:
    needs: deploy-staging
    # Only runs if staging succeeds
```

### 3. Use Tags for Version Control

Deploy specific versions instead of latest:

```yaml
with:
  tag: ${{ github.ref_name }}  # Use Git tag as image tag
```

### 4. Set Appropriate Timeouts

Configure timeouts based on your application:

| Application Type | Recommended Timeout |
|-----------------|---------------------|
| Static sites | 120s |
| Node.js apps | 300s |
| Large applications | 600s |
| Applications with migrations | 900s |

### 5. Handle Failures Gracefully

Use `fail-on-error: false` for non-blocking deployments:

```yaml
with:
  wait-for-completion: true
  fail-on-error: false

# Then check status in subsequent steps
```

## Integration with Other Workflows

### Docker Build + Coolify Deploy

See [docker-build.md](./docker-build.md) for Docker build configuration.

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      publish-to: 'ghcr'
    secrets: inherit

  deploy:
    needs: build
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    with:
      coolify-url: 'https://coolify.example.com'
      app-uuid: 'your-app-uuid'
    secrets: inherit
```

### Teams Notifications

Combine with Teams notifications for deployment alerts:

```yaml
jobs:
  deploy:
    uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main
    # ...

  notify:
    needs: deploy
    if: always()
    uses: bauer-group/automation-templates/.github/workflows/teams-notifications.yml@main
    with:
      status: ${{ needs.deploy.outputs.deployment-status }}
    secrets: inherit
```

## Troubleshooting

### Debug Mode

Check the workflow logs for detailed information:

1. Go to Actions tab in your repository
2. Click on the failed workflow run
3. Expand the "Deploy to Coolify" job
4. Review step outputs for error messages

### Test API Connection Locally

```bash
curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json" \
  "https://coolify.example.com/api/v1/deploy?uuid=YOUR_UUID&force=false"
```

### Verify Application UUID

1. Open Coolify dashboard
2. Navigate to your application
3. The UUID is in the URL: `/project/xxx/application/YOUR-UUID`

## Support

- **Documentation**: See examples in `github/workflows/examples/coolify-deploy/`
- **Issues**: Report issues in the automation-templates repository
- **Coolify Docs**: [https://coolify.io/docs](https://coolify.io/docs)
