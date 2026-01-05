# Claude Code Assistant Examples

Example workflows demonstrating how to integrate the Claude Code Assistant into your repository.

## Available Examples

| Example | File | Description |
|---------|------|-------------|
| Basic | `basic-claude-assistant.yml` | Simple setup responding to @claude mentions |
| Code Review | `code-review-assistant.yml` | Thorough code reviews on PRs |
| Security Review | `security-review-assistant.yml` | Security-focused code analysis |
| Restricted | `restricted-claude-assistant.yml` | Limited to specific users/teams |
| Multi-Trigger | `multi-trigger-assistant.yml` | Different behaviors per trigger phrase |

## Quick Start

### 1. Copy the Example

```bash
# Basic assistant
cp github/workflows/examples/claude-code/basic-claude-assistant.yml .github/workflows/claude-code.yml
```

### 2. Configure Secrets

Add the following secret to your repository:

| Secret | Description | Required |
|--------|-------------|----------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code OAuth token from Anthropic | Yes |

To get your OAuth token:
1. Visit [console.anthropic.com](https://console.anthropic.com)
2. Navigate to API Keys
3. Create a new OAuth token for Claude Code

### 3. Test the Integration

1. Create a new issue with `@claude` in the title or body
2. Comment `@claude help me understand this code` on any issue or PR
3. Request a code review with `@claude review` on a pull request

## Usage Examples

### Basic Assistance

```
@claude What does this function do?
```

```
@claude Help me fix this bug
```

### Code Review

```
@claude review Please review this PR for code quality and best practices
```

### Security Review

```
@claude security Check this PR for security vulnerabilities
```

## Configuration

### Using Configuration Files

The workflow supports configuration files in `.github/config/claude-code/`:

```yaml
uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
with:
  config-file: 'code-review'    # Uses .github/config/claude-code/code-review.yml
```

Available configurations:
- `default` - General purpose assistance
- `code-review` - Detailed code reviews
- `security-review` - Security-focused analysis
- `issue-helper` - Issue triage and assistance
- `minimal` - Quick, concise responses

### Inline Configuration

Override settings directly in the workflow:

```yaml
uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
with:
  model: 'opus'
  trigger-phrase: '@claude'
  analyze-diff: true
  max-files-to-analyze: 50
  timeout-minutes: 30
```

## Permissions

The workflow requires these permissions:

```yaml
permissions:
  contents: read
  issues: write
  pull-requests: write
  id-token: write
```

## Rate Limiting

To prevent abuse, configure rate limits:

```yaml
with:
  rate-limit-per-issue: 10      # Max invocations per issue per hour
  rate-limit-per-user: 20       # Max invocations per user per hour
```

## Restricting Access

### By Users

```yaml
with:
  allowed-users: 'admin,lead-dev,security-team'
```

### By Teams

```yaml
with:
  allowed-teams: 'core-team,security'
```

### By Labels

Only respond to issues/PRs with specific labels:

```yaml
with:
  allowed-labels: 'claude-enabled,needs-review'
```

## Sensitive Files

By default, Claude won't analyze sensitive files. Customize the blocklist:

```yaml
with:
  block-sensitive-files: '*.env,*secret*,*credential*,*.key'
```

## Troubleshooting

### Claude Not Responding

1. Check that `CLAUDE_CODE_OAUTH_TOKEN` secret is set
2. Verify the trigger phrase is in the comment
3. Check workflow run logs for errors
4. Ensure user is in `allowed-users` (if configured)

### Timeout Errors

Increase the timeout for complex analysis:

```yaml
with:
  timeout-minutes: 60
```

### Rate Limit Exceeded

Either wait for the rate limit to reset or increase limits:

```yaml
with:
  rate-limit-per-user: 50
```

## Best Practices

1. **Start Simple**: Use `basic-claude-assistant.yml` first
2. **Restrict in Production**: Use `allowed-users` or `allowed-teams`
3. **Use Configurations**: Leverage predefined configs for consistent behavior
4. **Monitor Usage**: Check workflow runs for usage patterns
5. **Security First**: Use `security-review` config for security-sensitive repos

## Support

- [Full Documentation](../../../../docs/workflows/claude-code.md)
- [Main Documentation](../../../claude-code/README.md)
- [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
