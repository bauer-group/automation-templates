# 🔔 Microsoft Teams Notification Action

Send sophisticated Adaptive Card notifications to Microsoft Teams channels for all repository events. This action provides rich, interactive notifications with customizable themes, mentions, facts, and actions.

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Usage](#-usage)
- [Configuration](#-configuration)
- [Examples](#-examples)
- [Adaptive Card Structure](#-adaptive-card-structure)
- [Troubleshooting](#-troubleshooting)
- [Advanced Usage](#-advanced-usage)

## ✨ Features

### 🎨 Rich Adaptive Cards
- **Interactive Elements**: Buttons, facts, and formatted text
- **Custom Themes**: Event-specific colors and styling
- **User Avatars**: Display GitHub user avatars
- **Action Buttons**: Direct links to repository, workflows, PRs, and issues

### 🎯 Event-Specific Support
- **Workflow Events**: Success, failure, completion
- **Issue Events**: Opened, closed, labeled, assigned
- **Pull Request Events**: Opened, merged, closed, ready for review
- **Push Events**: Commits, branch changes
- **Release Events**: Published, created, edited

### ⚙️ Advanced Configuration
- **YAML Configuration Files**: Centralized configuration management
- **Custom Facts**: Add custom metadata to notifications
- **Mentions**: Notify specific users or teams
- **Retry Logic**: Automatic retry on failure
- **Environment-Specific Webhooks**: Different channels for different environments

### 🛡️ Enterprise Features
- **Security Integration**: Special handling for security events
- **Branch Protection**: Enhanced notifications for protected branches
- **Performance Monitoring**: Track notification delivery times
- **Comprehensive Logging**: Detailed logs for debugging

## 🚀 Quick Start

### 1. Setup Teams Webhook

1. In Microsoft Teams, navigate to your target channel
2. Click **⋯** → **Connectors** → **Incoming Webhook**
3. Configure the webhook with a name and optional image
4. Copy the webhook URL
5. Add the webhook URL as a GitHub repository secret named `TEAMS_WEBHOOK_URL`

### 2. Basic Usage

```yaml
- name: 🔔 Notify Teams
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Build Successful'
    summary: 'The build completed successfully!'
```

## 📖 Usage

### Input Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `webhook-url` | Microsoft Teams webhook URL | ✅ | - |
| `event-type` | Type of event (see Event Types) | ✅ | - |
| `title` | Notification title | ❌ | 'Repository Event' |
| `summary` | Event summary text | ❌ | - |
| `details` | Additional event details | ❌ | - |
| `config-file` | Configuration file name | ❌ | 'default' |
| `theme-color` | Custom theme color (hex) | ❌ | Auto-determined |
| `custom-facts` | Additional facts as JSON array | ❌ | - |
| `mention-users` | Users to mention (comma-separated) | ❌ | - |
| `enable-retry` | Enable retry on failure | ❌ | 'true' |
| `retry-count` | Number of retry attempts | ❌ | '3' |
| `timeout` | Request timeout in seconds | ❌ | '30' |

#### Event Types

| Event Type | Description | Theme Color |
|------------|-------------|-------------|
| `workflow_success` | Workflow completed successfully | 🟢 Green |
| `workflow_failure` | Workflow failed | 🔴 Red |
| `issue_opened` | New issue opened | 🟠 Orange |
| `issue_closed` | Issue closed | 🟢 Green |
| `pr_opened` | Pull request opened | 🔵 Blue |
| `pr_closed` | Pull request closed | ⚫ Gray |
| `pr_merged` | Pull request merged | 🟢 Green |
| `push` | Code pushed | 🟣 Purple |
| `release` | Release published | 🟦 Teal |

### Output Parameters

| Output | Description |
|--------|-------------|
| `status` | Notification delivery status |
| `response` | Teams webhook response |
| `card-payload` | Generated Adaptive Card payload |

## ⚙️ Configuration

### Configuration Files

Configuration files are stored in `.github/config/teams-notification/` and use YAML format:

#### Default Configuration Structure

```yaml
# .github/config/teams-notification/default.yml
theme:
  colors:
    workflow_success: "28a745"
    workflow_failure: "dc3545"
    default: "0078d4"

features:
  mentions: true
  facts: true
  actions: true
  timestamps: true
  avatars: true
  retry: true

notifications:
  timeout: 30
  retry_count: 3
  retry_delay: 2

mentions:
  workflow_failure:
    - "devops-team"
    - "maintainers"
```

#### Available Configuration Files

| File | Purpose | Usage |
|------|---------|-------|
| `default.yml` | Standard configuration | General notifications |
| `success.yml` | Success events | Workflow success, PR merged |
| `failure.yml` | Failure events | Critical failures, urgent issues |
| `issue.yml` | Issue events | Issue management |
| `pull-request.yml` | PR events | Code review workflow |
| `push.yml` | Push events | Code commits |
| `release.yml` | Release events | Version releases |
| `test.yml` | Testing | Debug and testing |

## 🎯 Examples

### Basic Success Notification

```yaml
- name: ✅ Success Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Build Completed'
    summary: 'All tests passed successfully!'
    config-file: 'success'
```

### Advanced Failure Notification with Mentions

```yaml
- name: ❌ Failure Notification
  if: failure()
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_failure'
    title: 'Build Failed - Immediate Action Required'
    summary: 'The build process encountered critical errors'
    details: |
      **Error Details:**
      - Stage: Build
      - Duration: 5 minutes 23 seconds
      - Exit Code: 1
      
      **Next Steps:**
      1. Check build logs for detailed errors
      2. Verify recent code changes
      3. Contact DevOps if issue persists
    mention-users: 'devops-team,on-call-engineer,team-leads'
    config-file: 'failure'
```

### Rich Notification with Custom Facts

```yaml
- name: 🚀 Deployment Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Production Deployment Complete'
    summary: 'Version ${{ github.ref_name }} deployed successfully to production'
    details: |
      **Deployment Summary:**
      - Environment: Production
      - Duration: 12 minutes 34 seconds
      - Health Check: ✅ Passed
      - Rollback Plan: Available
    custom-facts: |
      [
        {"title": "Environment", "value": "Production"},
        {"title": "Version", "value": "${{ github.ref_name }}"},
        {"title": "Deployed By", "value": "${{ github.actor }}"},
        {"title": "Build Number", "value": "#${{ github.run_number }}"},
        {"title": "Health Status", "value": "✅ Healthy"},
        {"title": "Performance", "value": "🚀 Optimal"}
      ]
    theme-color: '20c997'
    mention-users: 'stakeholders,product-team'
    config-file: 'success'
```

### Issue Notification with Priority Handling

```yaml
- name: 🐛 Issue Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ contains(github.event.issue.labels.*.name, 'critical') && secrets.TEAMS_WEBHOOK_URGENT || secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'issue_opened'
    title: '${{ contains(github.event.issue.labels.*.name, 'critical') && '🚨 CRITICAL ISSUE' || '🐛 New Issue' }}: ${{ github.event.issue.title }}'
    summary: 'Issue #${{ github.event.issue.number }} opened by ${{ github.event.issue.user.login }}'
    details: ${{ github.event.issue.body }}
    custom-facts: |
      [
        {"title": "Issue Number", "value": "#${{ github.event.issue.number }}"},
        {"title": "Reporter", "value": "${{ github.event.issue.user.login }}"},
        {"title": "Labels", "value": "${{ join(github.event.issue.labels.*.name, ', ') }}"},
        {"title": "Assignees", "value": "${{ join(github.event.issue.assignees.*.login, ', ') || 'Unassigned' }}"},
        {"title": "Priority", "value": "${{ contains(github.event.issue.labels.*.name, 'critical') && '🚨 Critical' || contains(github.event.issue.labels.*.name, 'high') && '⚠️ High' || 'Normal' }}"}
      ]
    mention-users: ${{ contains(github.event.issue.labels.*.name, 'critical') && 'security-team,team-leads,on-call' || contains(github.event.issue.labels.*.name, 'high') && 'maintainers' || '' }}
    issue-number: ${{ github.event.issue.number }}
    issue-url: ${{ github.event.issue.html_url }}
    config-file: 'issue'
```

### Pull Request Notification

```yaml
- name: 🔀 PR Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'pr_opened'
    title: '🔀 New PR: ${{ github.event.pull_request.title }}'
    summary: 'PR #${{ github.event.pull_request.number }} opened by ${{ github.event.pull_request.user.login }}'
    details: |
      **Pull Request Details:**
      ${{ github.event.pull_request.body }}
      
      **Change Summary:**
      - Files Changed: ${{ github.event.pull_request.changed_files }}
      - Additions: +${{ github.event.pull_request.additions }}
      - Deletions: -${{ github.event.pull_request.deletions }}
    custom-facts: |
      [
        {"title": "PR Number", "value": "#${{ github.event.pull_request.number }}"},
        {"title": "Author", "value": "${{ github.event.pull_request.user.login }}"},
        {"title": "Target Branch", "value": "${{ github.event.pull_request.base.ref }}"},
        {"title": "Source Branch", "value": "${{ github.event.pull_request.head.ref }}"},
        {"title": "Changes", "value": "+${{ github.event.pull_request.additions }} -${{ github.event.pull_request.deletions }}"},
        {"title": "Files", "value": "${{ github.event.pull_request.changed_files }}"}
      ]
    pr-number: ${{ github.event.pull_request.number }}
    pr-url: ${{ github.event.pull_request.html_url }}
    config-file: 'pull-request'
```

### Environment-Specific Notifications

```yaml
- name: 🔔 Environment Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ 
      github.ref == 'refs/heads/main' && secrets.TEAMS_WEBHOOK_PROD ||
      github.ref == 'refs/heads/develop' && secrets.TEAMS_WEBHOOK_DEV ||
      secrets.TEAMS_WEBHOOK_URL 
    }}
    event-type: 'push'
    title: '🚀 Code Pushed to ${{ github.ref_name }}'
    theme-color: ${{ 
      github.ref == 'refs/heads/main' && '28a745' ||
      github.ref == 'refs/heads/develop' && '17a2b8' ||
      '6f42c1' 
    }}
    mention-users: ${{ 
      github.ref == 'refs/heads/main' && 'stakeholders,maintainers' ||
      github.ref == 'refs/heads/develop' && 'developers' ||
      '' 
    }}
```

## 🎨 Adaptive Card Structure

The action generates sophisticated Adaptive Cards with the following structure:

```json
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": {
        "type": "AdaptiveCard",
        "version": "1.5",
        "body": [
          {
            "type": "Container",
            "style": "emphasis",
            "items": [
              {
                "type": "ColumnSet",
                "columns": [
                  {
                    "type": "Column",
                    "items": [
                      {
                        "type": "Image",
                        "style": "Person",
                        "size": "Small"
                      }
                    ]
                  },
                  {
                    "type": "Column",
                    "items": [
                      {
                        "type": "TextBlock",
                        "text": "**Title**",
                        "weight": "Bolder",
                        "size": "Medium"
                      },
                      {
                        "type": "TextBlock",
                        "text": "Repository Link",
                        "color": "Accent"
                      }
                    ]
                  }
                ]
              }
            ]
          },
          {
            "type": "TextBlock",
            "text": "Summary text"
          },
          {
            "type": "TextBlock",
            "text": "Detailed description"
          },
          {
            "type": "FactSet",
            "facts": [
              {
                "title": "Actor:",
                "value": "github-user"
              }
            ]
          },
          {
            "type": "ActionSet",
            "actions": [
              {
                "type": "Action.OpenUrl",
                "title": "📂 Repository",
                "url": "https://github.com/..."
              }
            ]
          }
        ]
      }
    }
  ]
}
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Webhook URL Invalid

**Error**: `HTTP 400 - Bad Request`

**Solutions**:
- Verify the webhook URL is complete and correctly formatted
- Ensure the webhook URL starts with `https://`
- Check that the webhook is still active in Teams

```yaml
- name: 🔍 Validate Webhook
  run: |
    if [[ -z "${{ secrets.TEAMS_WEBHOOK_URL }}" ]]; then
      echo "❌ TEAMS_WEBHOOK_URL secret is not set"
      exit 1
    fi
```

#### 2. Card Payload Too Large

**Error**: `HTTP 413 - Payload Too Large`

**Solutions**:
- Reduce content length in `details` parameter
- Limit custom facts array size
- Use configuration files to set content limits

#### 3. Network Timeout

**Error**: `Network timeout` or `CURL_ERROR`

**Solutions**:
- Increase timeout value
- Enable retry with higher retry count
- Check network connectivity

```yaml
- name: 🔔 Robust Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Success with Retry'
    enable-retry: 'true'
    retry-count: '5'
    timeout: '60'
```

### Debug Mode

Enable debug mode for detailed logging:

```yaml
- name: 🧪 Debug Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'test'
    title: 'Debug Test'
    config-file: 'test'
```

### Error Handling

```yaml
- name: 🔔 Notification with Error Handling
  id: notify
  continue-on-error: true
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Build Complete'

- name: 📋 Handle Notification Failure
  if: steps.notify.outcome == 'failure'
  run: |
    echo "❌ Teams notification failed"
    echo "Status: ${{ steps.notify.outputs.status }}"
    echo "Response: ${{ steps.notify.outputs.response }}"
    # Optionally send to alternative notification system
```

## 🚀 Advanced Usage

### Custom Configuration File

Create `.github/config/teams-notification/custom.yml`:

```yaml
extends: "default"

theme:
  colors:
    workflow_success: "20c997"
    custom_event: "e83e8c"

features:
  mentions: true
  facts: true

mentions:
  workflow_failure:
    - "devops-team"
    - "team-leads"
    - "on-call-engineer"

content:
  title_max_length: 150
  summary_max_length: 800
```

### Multi-Environment Setup

```yaml
jobs:
  notify:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - name: 🔔 Environment Notification
        uses: bauer-group/automation-templates/.github/actions/teams-notification@main
        with:
          webhook-url: ${{ secrets[format('TEAMS_WEBHOOK_{0}', matrix.environment)] }}
          event-type: 'deployment_success'
          title: 'Deployed to ${{ matrix.environment }}'
          config-file: ${{ matrix.environment }}
```

### Integration with Other Actions

```yaml
- name: 🧪 Run Tests
  id: tests
  run: |
    # Run tests and capture results
    npm test
    echo "test-results=passed" >> $GITHUB_OUTPUT
    echo "coverage=87%" >> $GITHUB_OUTPUT

- name: 🔔 Test Results Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: ${{ steps.tests.outputs.test-results == 'passed' && 'workflow_success' || 'workflow_failure' }}
    title: 'Test Results: ${{ steps.tests.outputs.test-results }}'
    summary: 'Test coverage: ${{ steps.tests.outputs.coverage }}'
    custom-facts: |
      [
        {"title": "Status", "value": "${{ steps.tests.outputs.test-results }}"},
        {"title": "Coverage", "value": "${{ steps.tests.outputs.coverage }}"}
      ]
```

---

## 📚 Related Documentation

- [Teams Notification Workflow](../../workflows/teams-notifications.yml) - Complete notification system
- [Configuration Reference](../../config/teams-notification/README.md) - Detailed configuration guide  
- [Examples Collection](../../../github/workflows/examples/teams-notification/) - Usage examples
- [Microsoft Teams Webhook Documentation](https://docs.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/add-incoming-webhook)
- [Adaptive Cards Documentation](https://docs.microsoft.com/en-us/adaptive-cards/)

For more examples and advanced configurations, see the [Teams Notification Examples](../../../github/workflows/examples/teams-notification/).