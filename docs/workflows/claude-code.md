# Claude Code Assistant Workflow

AI-powered code assistant that responds to @claude mentions in issues, PRs, and comments with intelligent code analysis and suggestions.

## Overview

The Claude Code Assistant integrates Claude AI directly into your GitHub workflow, providing:

- **Intelligent Code Reviews**: Thorough analysis of pull requests
- **Issue Assistance**: Help with bug reports and feature requests
- **Security Analysis**: Security-focused code scanning
- **General Q&A**: Answer questions about your codebase

## Quick Start

### Basic Setup

1. **Copy the workflow** to your repository:

```yaml
# .github/workflows/claude-code.yml
name: Claude Code Assistant

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]
  issues:
    types: [opened, assigned]
  pull_request_review:
    types: [submitted]

jobs:
  claude:
    if: |
      (github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||
      (github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||
      (github.event_name == 'issues' && (contains(github.event.issue.body, '@claude') || contains(github.event.issue.title, '@claude')))

    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      model: 'opus'
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

2. **Add the secret** `CLAUDE_CODE_OAUTH_TOKEN` to your repository

3. **Test it** by creating an issue with `@claude` in the body

## Required Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code OAuth token from Anthropic | Yes* |
| `ANTHROPIC_API_KEY` | Anthropic API key (alternative) | Yes* |

*One of these is required

### Getting Your Token

1. Visit [console.anthropic.com](https://console.anthropic.com)
2. Navigate to API Keys
3. Create a new OAuth token or API key
4. Add it to your repository secrets

## Input Parameters

### Model Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | string | `opus` | Claude model: `opus`, `sonnet`, `haiku` |
| `max-tokens` | string | `16384` | Maximum tokens for response |
| `timeout-minutes` | number | `30` | Timeout for Claude response |

### Trigger Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `trigger-phrase` | string | `@claude` | Phrase to trigger Claude |
| `allowed-users` | string | `''` | Comma-separated allowed users (empty = all) |
| `allowed-teams` | string | `''` | Comma-separated allowed teams (empty = all) |
| `allowed-labels` | string | `''` | Only respond to issues/PRs with these labels |

### Response Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `response-mode` | string | `comment` | Response mode: `comment`, `suggestion`, `review` |
| `add-reaction` | string | `eyes` | Reaction to add: `eyes`, `rocket`, `+1`, `heart` |
| `mention-user` | boolean | `true` | Mention triggering user in response |

### Code Analysis

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `analyze-code` | boolean | `true` | Enable code analysis for PRs |
| `analyze-diff` | boolean | `true` | Analyze PR diff for context |
| `max-files-to-analyze` | number | `20` | Maximum files to analyze |
| `max-diff-size` | number | `100000` | Maximum diff size in characters |

### Context Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `include-issue-body` | boolean | `true` | Include issue/PR description |
| `include-comments` | boolean | `true` | Include previous comments |
| `max-comments` | number | `10` | Maximum comments to include |

### Safety & Rate Limiting

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `rate-limit-per-issue` | number | `10` | Max invocations per issue/hour |
| `rate-limit-per-user` | number | `20` | Max invocations per user/hour |
| `block-sensitive-files` | string | `*.env,*secret*,...` | Blocked file patterns |
| `dry-run` | boolean | `false` | Run without posting comments |

### Configuration File

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `config-file` | string | `default` | Config file from `.github/config/claude-code/` |

## Configuration Files

Pre-configured profiles in `.github/config/claude-code/`:

| Profile | Model | Use Case |
|---------|-------|----------|
| `default` | opus | General assistance |
| `code-review` | opus | Thorough code reviews |
| `issue-helper` | opus | Issue triage and help |
| `security-review` | opus | Security analysis |
| `minimal` | sonnet | Quick, concise responses |

### Using a Configuration File

```yaml
uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
with:
  config-file: 'code-review'
secrets:
  CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

## Usage Examples

### Basic Assistance

```
@claude What does this function do?
```

```
@claude Help me fix this error: [error message]
```

### Code Review

```
@claude review Please review this PR for code quality
```

### Security Review

```
@claude security Check this code for vulnerabilities
```

### Specific Questions

```
@claude How can I optimize this database query?
```

```
@claude What's the best way to handle this edge case?
```

## Advanced Configuration

### Restricting Access

#### By Users

```yaml
with:
  allowed-users: 'admin,lead-developer,security-team'
```

#### By Teams

```yaml
with:
  allowed-teams: 'core-team,security'
```

#### By Labels

```yaml
with:
  allowed-labels: 'claude-enabled,needs-ai-review'
```

### Custom System Prompt

```yaml
with:
  append-system-prompt: |
    Focus on TypeScript best practices.
    Always suggest unit tests for new code.
    Be concise but thorough.
```

### Multi-Trigger Setup

Create different behaviors for different triggers:

```yaml
jobs:
  general:
    if: contains(github.event.comment.body, '@claude') && !contains(github.event.comment.body, '@claude review')
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      config-file: 'default'
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}

  review:
    if: contains(github.event.comment.body, '@claude review')
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      config-file: 'code-review'
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

## Permissions

The workflow requires:

```yaml
permissions:
  contents: read
  issues: write
  pull-requests: write
  id-token: write
```

## Outputs

| Output | Description |
|--------|-------------|
| `response` | Claude response text |
| `response-url` | URL to the posted comment |
| `tokens-used` | Number of tokens used |
| `model-used` | Model used for response |
| `trigger-type` | Type of trigger event |

## Examples

See complete examples in [`github/workflows/examples/claude-code/`](../../github/workflows/examples/claude-code/):

- `basic-claude-assistant.yml` - Simple setup
- `code-review-assistant.yml` - Code reviews
- `security-review-assistant.yml` - Security analysis
- `restricted-claude-assistant.yml` - Limited access
- `multi-trigger-assistant.yml` - Multiple behaviors

## Security Considerations

1. **Token Security**: Never commit OAuth tokens; use repository secrets
2. **Sensitive Files**: Configure `block-sensitive-files` appropriately
3. **Access Control**: Use `allowed-users`/`allowed-teams` in production
4. **Rate Limiting**: Set appropriate rate limits to prevent abuse
5. **Audit Logs**: Monitor workflow runs for unusual activity

## Troubleshooting

### Claude Not Responding

1. Verify `CLAUDE_CODE_OAUTH_TOKEN` is set correctly
2. Check that trigger phrase is in the comment
3. Review workflow run logs
4. Ensure user is authorized (if restrictions are configured)

### Timeout Errors

Increase timeout for complex analysis:

```yaml
with:
  timeout-minutes: 60
```

### Rate Limit Exceeded

Wait for the limit to reset or increase limits:

```yaml
with:
  rate-limit-per-user: 50
```

### Large PRs

Adjust limits for large PRs:

```yaml
with:
  max-files-to-analyze: 100
  max-diff-size: 500000
```

## Best Practices

1. **Start Simple**: Begin with `basic-claude-assistant.yml`
2. **Use Configurations**: Leverage predefined profiles
3. **Restrict Access**: Limit who can trigger Claude
4. **Monitor Usage**: Review workflow runs regularly
5. **Security First**: Use `security-review` for sensitive repos
6. **Rate Limit**: Prevent abuse with appropriate limits
7. **Custom Prompts**: Tailor Claude's behavior to your needs

## Support

- [Examples](../../github/workflows/examples/claude-code/)
- [Main Documentation](../../github/claude-code/README.md)
- [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
