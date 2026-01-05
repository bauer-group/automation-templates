# Claude Code Assistant

AI-powered code assistant that responds to @claude mentions in GitHub issues, PRs, and comments

## 🤖 Overview

This directory provides a comprehensive AI-powered code assistant solution using Claude (Anthropic's AI). The assistant integrates directly into your GitHub workflow, responding to @claude mentions with intelligent code analysis, reviews, and suggestions.

## 📦 Components

### Workflow & Action

- **Reusable Workflow**: `.github/workflows/claude-code.yml` - Ready-to-use workflow
- **Composite Action**: `.github/actions/claude-code/action.yml` - Flexible action component
- **Configuration Profiles**: `.github/config/claude-code/` - Pre-configured profiles

### Supported Triggers

- **Issue Comments**: Respond to @claude in issue discussions
- **PR Comments**: Provide code suggestions in pull requests
- **PR Reviews**: Deliver structured code reviews
- **New Issues**: Auto-analyze newly created issues

### AI Capabilities

- **Code Reviews**: Thorough analysis with severity ratings
- **Security Analysis**: OWASP-based vulnerability scanning
- **Issue Triage**: Automatic categorization and suggestions
- **General Assistance**: Answer questions about code

## 🚀 Quick Start

### Basic Setup

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

### Using Configuration Profiles

```yaml
jobs:
  claude-review:
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      config-file: 'code-review'    # Use code-review.yml profile
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

## 🔧 Configuration

### Environment Variables / Secrets

```bash
# Required - Authentication (one of these)
CLAUDE_CODE_OAUTH_TOKEN=xxxxxxxxxxxxx    # Claude Code OAuth token
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx   # Anthropic API key (alternative)

# Optional - Model Configuration
MODEL=opus                               # Claude model: opus, sonnet, haiku
MAX_TOKENS=16384                         # Maximum response tokens
TIMEOUT_MINUTES=30                       # Response timeout
```

### Configuration Profiles

| Profile | Model | Use Case | Description |
|---------|-------|----------|-------------|
| `default` | opus | General | Standard configuration for all-purpose assistance |
| `code-review` | opus | PR Reviews | Thorough code reviews with structured feedback |
| `issue-helper` | opus | Issues | Issue triage and feature request analysis |
| `security-review` | opus | Security | OWASP-based security vulnerability scanning |
| `minimal` | sonnet | Quick | Fast, concise responses for simple questions |

### Input Parameters

```yaml
with:
  # Model Configuration
  model: 'opus'                    # opus, sonnet, haiku
  max-tokens: '16384'              # Maximum response tokens
  timeout-minutes: 30              # Response timeout

  # Trigger Configuration
  trigger-phrase: '@claude'        # Phrase to trigger Claude
  allowed-users: ''                # Comma-separated allowed users
  allowed-teams: ''                # Comma-separated allowed teams
  allowed-labels: ''               # Only respond to labeled issues/PRs

  # Code Analysis
  analyze-code: true               # Enable code analysis
  analyze-diff: true               # Analyze PR diffs
  max-files-to-analyze: 20         # Maximum files to analyze
  max-diff-size: 100000            # Maximum diff size (chars)

  # Safety
  rate-limit-per-issue: 10         # Max invocations per issue/hour
  rate-limit-per-user: 20          # Max invocations per user/hour
  block-sensitive-files: '*.env,*secret*,*.key'
```

## 🛡️ Safety Features

### Access Control

- **User Restrictions**: Limit to specific users or teams
- **Label Requirements**: Only respond to labeled issues/PRs
- **Rate Limiting**: Prevent abuse with per-user and per-issue limits

### Sensitive Data Protection

- **File Blocking**: Automatically skip sensitive files (*.env, *secret*, etc.)
- **Context Filtering**: Exclude credentials from analysis
- **Dry-Run Mode**: Test without posting comments

### Security Analysis

- **OWASP Guidelines**: Security reviews follow OWASP best practices
- **Vulnerability Detection**: SQL injection, XSS, SSRF, and more
- **Severity Ratings**: Critical/High/Medium/Low classifications

## 📊 Usage Examples

### General Assistance

```markdown
@claude What does this function do?
```

```markdown
@claude Help me understand this error
```

### Code Review

```markdown
@claude review Please review this PR for code quality and best practices
```

### Security Review

```markdown
@claude security Check this code for vulnerabilities
```

### Specific Questions

```markdown
@claude How can I optimize this database query?
```

## 🔄 Advanced Configurations

### Restricted Access Setup

```yaml
with:
  allowed-users: 'admin,lead-dev,security-team'
  allowed-teams: 'core-team'
  rate-limit-per-user: 5
```

### Multi-Trigger Setup

Create different behaviors for different trigger phrases:

```yaml
jobs:
  general:
    if: contains(github.event.comment.body, '@claude') && !contains(github.event.comment.body, '@claude review')
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      config-file: 'default'

  review:
    if: contains(github.event.comment.body, '@claude review')
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      config-file: 'code-review'

  security:
    if: contains(github.event.comment.body, '@claude security')
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      config-file: 'security-review'
```

## 🔧 Troubleshooting

### Common Issues

1. **Claude Not Responding**: Verify `CLAUDE_CODE_OAUTH_TOKEN` secret is set
2. **Permission Errors**: Check workflow has `issues: write` and `pull-requests: write`
3. **Rate Limit Exceeded**: Wait for limit reset or increase `rate-limit-per-user`
4. **Timeout Errors**: Increase `timeout-minutes` for complex analysis

### Debug Commands

```yaml
# Enable dry-run mode for testing
with:
  dry-run: true

# Use verbose logging
with:
  config-file: 'default'  # Check workflow logs for details
```

## 📚 Documentation

- [Workflow Documentation](../../docs/workflows/claude-code.md)
- [Examples](../workflows/examples/claude-code/)
- [Secrets Naming Convention](../workflows/SECRETS-NAMING-CONVENTION.MD)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
- **Anthropic**: [Claude Documentation](https://docs.anthropic.com)

---

*This AI assistant solution provides intelligent code analysis and review capabilities directly in your GitHub workflow.*
