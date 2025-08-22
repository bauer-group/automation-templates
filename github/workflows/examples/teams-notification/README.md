# 🔔 Microsoft Teams Notification Examples

This directory contains comprehensive examples for implementing Microsoft Teams notifications in your GitHub workflows. The Teams notification system provides rich, interactive Adaptive Card notifications for all repository events.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Basic Examples](#basic-examples)
- [Advanced Examples](#advanced-examples)
- [Event-Specific Examples](#event-specific-examples)
- [Configuration Examples](#configuration-examples)
- [Troubleshooting](#troubleshooting)

## 🚀 Quick Start

### 1. Setup Teams Webhook

1. In Microsoft Teams, go to your target channel
2. Click **⋯** → **Connectors** → **Incoming Webhook**
3. Configure the webhook and copy the URL
4. Add the webhook URL as a GitHub secret: `TEAMS_WEBHOOK_URL`

### 2. Use the Complete Notification System

The easiest way to get comprehensive Teams notifications:

```yaml
# .github/workflows/teams-notifications.yml
name: 🔔 Teams Notifications

on:
  workflow_run:
    workflows: ["*"]
    types: [completed]
  issues:
    types: [opened, closed, reopened]
  pull_request:
    types: [opened, closed, synchronize]
  push:
    branches: [main, develop]
  release:
    types: [published]

jobs:
  notifications:
    uses: bauer-group/automation-templates/.github/workflows/teams-notifications.yml@main
    secrets:
      TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
```

## 📝 Basic Examples

### Simple Success Notification

```yaml
- name: 🔔 Notify Success
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: '✅ Build Successful'
    summary: 'The build completed successfully!'
```

### Simple Failure Notification

```yaml
- name: 🔔 Notify Failure
  if: failure()
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_failure'
    title: '❌ Build Failed'
    summary: 'The build process encountered errors'
    mention-users: 'devops-team,maintainers'
```

## 🎯 Advanced Examples

### Custom Facts and Rich Content

```yaml
- name: 🔔 Rich Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: '🚀 Deployment Complete'
    summary: 'Application deployed to production environment'
    details: |
      **Deployment Summary:**
      - Environment: Production
      - Version: ${{ github.ref_name }}
      - Duration: 5 minutes 23 seconds
      - Health Check: ✅ Passed
    custom-facts: |
      [
        {"title": "Environment", "value": "Production"},
        {"title": "Version", "value": "${{ github.ref_name }}"},
        {"title": "Deployed By", "value": "${{ github.actor }}"},
        {"title": "Build Number", "value": "${{ github.run_number }}"}
      ]
    config-file: 'success'
```

### Conditional Notifications with Retry

```yaml
- name: 🔔 Conditional Notification
  if: ${{ github.ref == 'refs/heads/main' }}
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'push'
    title: '🚀 Main Branch Updated'
    summary: '${{ github.event.head_commit.message }}'
    enable-retry: 'true'
    retry-count: '5'
    timeout: '45'
```

## 📑 Event-Specific Examples

### Issue Notifications

```yaml
name: Issue Notifications
on:
  issues:
    types: [opened, closed, labeled]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: 🐛 New Issue Notification
        if: github.event.action == 'opened'
        uses: bauer-group/automation-templates/.github/actions/teams-notification@main
        with:
          webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
          event-type: 'issue_opened'
          title: '🐛 New Issue: ${{ github.event.issue.title }}'
          summary: 'Issue #${{ github.event.issue.number }} opened by ${{ github.event.issue.user.login }}'
          details: ${{ github.event.issue.body }}
          issue-number: ${{ github.event.issue.number }}
          issue-url: ${{ github.event.issue.html_url }}
          custom-facts: |
            [
              {"title": "Labels", "value": "${{ join(github.event.issue.labels.*.name, ', ') }}"},
              {"title": "Assignees", "value": "${{ join(github.event.issue.assignees.*.login, ', ') }}"}
            ]
          config-file: 'issue'
```

### Pull Request Notifications

```yaml
name: PR Notifications
on:
  pull_request:
    types: [opened, ready_for_review, closed]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: 🔀 PR Ready for Review
        if: github.event.action == 'ready_for_review'
        uses: bauer-group/automation-templates/.github/actions/teams-notification@main
        with:
          webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
          event-type: 'pr_opened'
          title: '👀 PR Ready: ${{ github.event.pull_request.title }}'
          summary: 'PR #${{ github.event.pull_request.number }} is ready for review'
          pr-number: ${{ github.event.pull_request.number }}
          pr-url: ${{ github.event.pull_request.html_url }}
          mention-users: 'code-reviewers,maintainers'
          custom-facts: |
            [
              {"title": "Changes", "value": "+${{ github.event.pull_request.additions }} -${{ github.event.pull_request.deletions }}"},
              {"title": "Files", "value": "${{ github.event.pull_request.changed_files }}"},
              {"title": "Commits", "value": "${{ github.event.pull_request.commits }}"}
            ]
          config-file: 'pull-request'
```

### Release Notifications

```yaml
name: Release Notifications
on:
  release:
    types: [published]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: 🏷️ New Release
        uses: bauer-group/automation-templates/.github/actions/teams-notification@main
        with:
          webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
          event-type: 'release'
          title: '🎉 New Release: ${{ github.event.release.name }}'
          summary: 'Version ${{ github.event.release.tag_name }} has been published!'
          details: ${{ github.event.release.body }}
          custom-facts: |
            [
              {"title": "Tag", "value": "${{ github.event.release.tag_name }}"},
              {"title": "Prerelease", "value": "${{ github.event.release.prerelease }}"},
              {"title": "Assets", "value": "${{ github.event.release.assets | length }}"}
            ]
          mention-users: 'stakeholders,product-team'
          config-file: 'release'
```

## ⚙️ Configuration Examples

### Custom Configuration File

Create `.github/config/teams-notification/custom.yml`:

```yaml
extends: "default"

theme:
  colors:
    workflow_success: "20c997"
    workflow_failure: "e83e8c"
    default: "6f42c1"

features:
  mentions: true
  facts: true
  retry: true

notifications:
  timeout: 45
  retry_count: 3

mentions:
  workflow_failure:
    - "devops-team"
    - "team-leads"
```

Use the custom configuration:

```yaml
- name: 🔔 Custom Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Custom Success'
    config-file: 'custom'  # Uses .github/config/teams-notification/custom.yml
```

## 🔧 Troubleshooting

### Debug Notifications

```yaml
- name: 🔔 Debug Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'test'
    title: '🧪 Debug Test'
    summary: 'Testing notification system'
    config-file: 'test'
    enable-retry: 'true'
    retry-count: '1'
    timeout: '60'
```

### Webhook URL Validation

```yaml
- name: 🔍 Validate Webhook
  run: |
    if [[ -z "${{ secrets.TEAMS_WEBHOOK_URL }}" ]]; then
      echo "❌ TEAMS_WEBHOOK_URL secret is not set"
      exit 1
    fi
    
    if [[ "${{ secrets.TEAMS_WEBHOOK_URL }}" != *"webhook.office.com"* ]]; then
      echo "⚠️ Webhook URL format may be invalid"
    fi
    
    echo "✅ Webhook URL validation passed"
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
```

## 🎨 Theme Customization

### Custom Colors

```yaml
- name: 🔔 Custom Theme
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: 'Success with Custom Color'
    theme-color: '20c997'  # Custom teal color
```

### Environment-Specific Themes

```yaml
- name: 🔔 Environment Notification
  uses: bauer-group/automation-templates/.github/actions/teams-notification@main
  with:
    webhook-url: ${{ secrets.TEAMS_WEBHOOK_URL }}
    event-type: 'workflow_success'
    title: '${{ github.ref_name }} Deployment'
    theme-color: ${{ github.ref == 'refs/heads/main' && '28a745' || github.ref == 'refs/heads/develop' && '17a2b8' || '6f42c1' }}
```

---

For more examples and detailed configuration options, see the [Teams Notification Documentation](../../../actions/teams-notification/README.md).