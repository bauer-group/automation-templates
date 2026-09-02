# AI Issue Summary

Generates a summary for a newly opened issue or pull request and posts it as a comment,
optionally adding suggested labels and a priority.

Workflow: [`ai-issue-summary.yml`](../../.github/workflows/ai-issue-summary.yml) ·
Module: [`modules-ai-issue-summary.yml`](../../.github/workflows/modules-ai-issue-summary.yml)

## Authentication — no secret required

The default provider is **GitHub Copilot**, reached through
[`actions/ai-inference`](https://github.com/actions/ai-inference). It authenticates with
the built-in `github.token`. What it needs is a permission, not a secret:

```yaml
permissions:
  issues: write
  pull-requests: write
  contents: read
  copilot-requests: write     # this is the one that matters
```

Two things must hold:

1. **`copilot-requests: write` in the caller as well as the module.** In a `workflow_call`
   workflow the `permissions:` block is a **ceiling, not a grant** — a caller that declares
   its own block and omits this line hands over a token without the permission, and
   inference fails. See [ghcr-internal-visibility.md](../ghcr-internal-visibility.md) for
   the same mechanic in another context.

2. **The organisation setting "Allow use of Copilot CLI billed to the organisation".**
   It is enabled by default wherever Copilot CLI is enabled. Usage is metered to the
   organisation, and each run receives a short-lived scoped token, so nothing long-lived
   has to be stored or rotated.

This is GitHub's recommended arrangement for organisation-owned repositories. A personal
access token is only relevant outside an organisation, or when usage should be billed to
one user's Copilot seat rather than to the organisation.

## How the provider is chosen

Exactly one provider runs per job:

| `ai-api-key` secret | Provider | Notes |
| --- | --- | --- |
| not set | **Copilot** | The default. Uses `github.token` and `copilot-requests: write`. |
| set | **OpenAI** | Calls `api.openai.com` directly with that key; the Copilot path is skipped, including its CLI install. |

If both fail, the job posts a plain template summary instead — see
[When it silently stops working](#when-it-silently-stops-working).

## Models

`model` must name a model the **Copilot CLI** accepts. The default is `gpt-5-mini`.

The catalogue can be listed directly, which is the only reliable way to check a name
before configuring it:

```bash
curl -s -H "Authorization: Bearer $(gh auth token)" \
     -H "Copilot-Integration-Id: vscode-chat" \
     https://api.githubcopilot.com/models | jq -r '.data[].id' | sort
```

**GitHub Models identifiers no longer work.** That service has been retired — its
catalogue endpoint answers `HTTP 410 Gone` — and `actions/ai-inference` v3 speaks only to
Copilot. Names such as `gpt-4.1-mini` or `gpt-3.5-turbo` will not resolve. The `models: read`
permission these workflows used to declare belonged to that retired API.

When `ai-api-key` is set, `model` is passed to the OpenAI API instead and must be a name
that API accepts.

## What the job installs

The Copilot CLI is **not pre-installed on hosted runners**, so the module installs it
before invoking the action:

```yaml
- uses: actions/setup-node@v7
- run: npm install -g @github/copilot
```

Both steps are skipped when the OpenAI path is in use.

## When it silently stops working

The module ends with a `🧠 Fallback Summary (No AI)` step that runs only when **both**
inference paths have failed. It posts:

```
**Type:** issue
**Title:** …
**Author:** @…

This issue requires review. Please check the full description for details.
```

The inference steps carry `continue-on-error: true`, so this degradation does **not** turn
the run red. If summaries look like the block above rather than describing the issue, the
provider is failing — check, in this order:

1. Is `copilot-requests: write` present in **both** the caller and the module?
2. Is the organisation setting enabled?
3. Is `model` a name the Copilot catalogue actually lists?
4. Did the `Install Copilot CLI` step succeed?

The run log names the failing step; the comment alone cannot tell you which.

## Inputs

| Input | Default | Notes |
| --- | --- | --- |
| `summary-type` | `brief` | `brief`, `detailed`, `technical`, `user-friendly` |
| `model` | `gpt-5-mini` | Must be accepted by the Copilot CLI, or by the OpenAI API when `ai-api-key` is set |
| `add-labels` | — | Add suggested labels from the analysis |
| `add-priority` | — | Add a priority label |
| `translate` | `''` | Target language, empty to disable |
| `custom-prompt` | `''` | Overrides the built-in prompt template |

## Secrets

| Secret | Required | Purpose |
| --- | --- | --- |
| `token` | no | GitHub token for posting the comment; defaults to the job token |
| `ai-api-key` | no | Setting it switches the job to the OpenAI provider |

No Copilot secret is needed.
