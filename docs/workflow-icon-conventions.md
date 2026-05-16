# Workflow Icon Conventions

Single source of truth for Unicode icons used across reusable workflows in this repository. Workflows that follow these conventions stay scannable, consistent, and reviewer-friendly in the GitHub Actions UI.

> **Use real Unicode characters, never escape sequences.** `\U0001F4E6` instead of `📦` is a bug — see `bg-standards.md`.

## Why icons

GitHub renders step names and summaries in a monospace UI without much typographic hierarchy. Emoji are the cheapest visual marker that:

- Group related steps at a glance (`🔧 Setup`, `📥 Checkout`, `🏗️ Build`, `🧪 Test`, `📤 Upload`)
- Make summary tables actionable without parsing text (`✅ Success`, `❌ Failed`, `⏭️ Skipped`)
- Indicate workflow purpose in the Actions sidebar (`🐳`, `🔷`, `🐍`, `🛡️`)

Icons are for humans skimming, not for log parsers. We never depend on them programmatically.

## Status icons (summaries, banners, tables)

Use these for outcome reporting in GitHub Step Summaries, comments, or aggregate banners. **Always pair with a text label** so screen readers and copy-paste both work.

| Icon | Meaning | Examples |
|------|---------|----------|
| `✅` | Success / yes / enabled / passed | `✅ Success`, `✅ Yes`, `✅ Enabled`, `✅ Passed` |
| `❌` | Failure / error / blocked | `❌ Failed`, `❌ No`, `❌ Blocked` |
| `⚪` | Disabled / not applicable / no | `⚪ Disabled`, `⚪ No`, `⚪ Skipped (by config)` |
| `⏭️` | Skipped (by gate / condition) | `⏭️ Skipped (no test projects)`, `⏭️ Skipped (PR)` |
| `⏹️` | Cancelled | `⏹️ Cancelled` |
| `⚠️` | Warning / partial / unknown | `⚠️ Warning`, `⚠️ Partial`, `⚠️ Unknown state` |

## Step-name icons (by purpose)

Apply at the start of step names: `- name: 📥 Checkout Repository`. Most-used icons are listed first.

### Setup & configuration

| Icon | Use for | Example step names |
|------|---------|--------------------|
| `🔧` | SDK/runtime setup, config loading, env preparation | `🔧 Setup .NET SDK`, `🔧 Configure Git`, `🔧 Load Configuration` |
| `📥` | Code checkout, artifact/dep download | `📥 Checkout Repository`, `📥 Download Artifact` |
| `🔐` | Credentials, auth setup, signing key handling | `🔐 Configure NuGet`, `🔐 Setup SNK Key` |
| `📚` | Dependency restore / install | `📚 Restore Dependencies`, `📚 Install npm Packages` |

### Build, test, analyze

| Icon | Use for | Example step names |
|------|---------|--------------------|
| `🏗️` | Build / compile (heavy / multi-target) | `🏗️ Build Project`, `🏗️ Build Application` |
| `🔨` | Build / compile (single / quick) | `🔨 Build & Test`, `🔨 Make` |
| `🧪` | Test execution | `🧪 Run Tests`, `🧪 Run PHPUnit` |
| `🔍` | Scan, lint, code analysis | `🔍 Code Analysis`, `🔍 Check Dockerfile` |
| `🛡️` | Security scan / vulnerability check | `🛡️ Security Scan`, `🛡️ License Compliance` |
| `🎨` | Format / style check | `🎨 Lint Code`, `🎨 Check Formatting` |

### Package, publish, deploy

| Icon | Use for | Example step names |
|------|---------|--------------------|
| `📦` | Package creation (`pack`, `pack`, archive) | `📦 Create NuGet Package`, `📦 Archive Binary` |
| `📤` | Upload / push / publish | `📤 Push to NuGet`, `📤 Upload Artifact`, `📤 Upload to Release` |
| `🚀` | Release / launch / deploy | `🚀 Deploy to Production`, `🚀 Create Release` |
| `🐳` | Docker build / push | `🐳 Build Docker Image`, `🐳 Push Image` |

### Reporting & notification

| Icon | Use for | Example step names |
|------|---------|--------------------|
| `📊` | Summary, report, coverage | `📊 Aggregate Summary`, `📊 Test Report` |
| `📋` | List / changelog / inventory | `📋 Find Dockerfiles`, `📋 Validate Package` |
| `📝` | Documentation, comment, PR body | `📝 Comment on PR`, `📝 Update Changelog` |
| `🔔` | Notifications (Teams / Slack / Email) | `🔔 Notify Teams`, `🔔 Send Alert` |
| `💬` | Inline / discussion comment | `💬 Post Summary Comment` |

### Maintenance

| Icon | Use for | Example step names |
|------|---------|--------------------|
| `🔄` | Sync / refresh / update | `🔄 Sync Submodules`, `🔄 Update Dependencies` |
| `🧹` | Cleanup / removal | `🧹 Cleanup Workspace`, `🧹 Remove Old Artifacts` |
| `💾` | Commit / save | `💾 Commit Changes`, `💾 Push Branch` |
| `🗑️` | Delete (terminal action) | `🗑️ Cleanup Certificate` |

### AI / automation

| Icon | Use for |
|------|---------|
| `🤖` | AI agent, bot action, automated triage |
| `🧠` | AI inference step |
| `🎯` | Targeted automation (label apply, priority assignment) |

## Workflow-name icons (by domain)

Apply at the start of the workflow `name:` field. The icon signals workflow purpose in the GitHub Actions sidebar.

### Language / runtime

| Icon | Domain | Example workflow |
|------|--------|------------------|
| `🚀` | .NET / generic build | `🚀 .NET Build`, `🚀 Release & Publish` |
| `📚` | .NET library / NuGet pack | `📚 .NET Library Publish` |
| `📦` | .NET binaries / artifact publish | `📦 .NET Binary Publish` |
| `🖥️` | .NET desktop (WPF/WinForms/MAUI) | `🖥️ .NET Desktop Build` |
| `🐍` | Python | `🐍 Python Build & Test` |
| `🔨` | Makefile / generic | `🔨 Makefile Build & Test` |
| `⚡` | Zephyr RTOS | `⚡ Zephyr RTOS Build & Test` |

### Containers & deployment

| Icon | Domain |
|------|--------|
| `🐳` | Docker build / maintenance |
| `🚀` | Deployment / release pipelines |
| `🔄` | CI/CD orchestration |

### Cross-cutting / maintenance

| Icon | Domain |
|------|--------|
| `🔍` | Monitor / scan |
| `🛡️` | Security / compliance |
| `📦` | Module / artifact-producing reusable workflow |
| `🔧` | Module / maintenance reusable workflow |
| `📋` | Issue / PR automation |
| `🏷️` | Labeler |
| `🧹` | Cleanup |
| `🤖` | AI assistant |
| `🔔` | Notification |
| `📄` | Documentation |
| `⚙️` | Manual / configurable orchestration |

## Style rules

1. **Always Unicode characters, never escape sequences.** `📥` not `\U0001F4E5` and never `:inbox_tray:`.
2. **One icon at the start, then a space, then the label.** Not in the middle, not at the end, not stacked (`✅✅✅`).
3. **Pair status icons with text.** `✅ Success` is good. Bare `✅` in a table cell is bad — screen readers say "white heavy check mark" with no context.
4. **Workflow-level icon picks one purpose-class.** Don't try to encode both language and purpose (`🐍📦`); the sidebar truncates and it looks cluttered.
5. **Reuse over invention.** If a fitting icon already exists in the table above, use it. Adding a new icon to the table requires real semantic distinction, not aesthetic preference.
6. **Don't iconify trivial sub-steps.** A step named `Set RID` doesn't need an icon. Reserve icons for the structural steps (Checkout, Setup, Build, Test, Pack, Upload, Summary).

## Where to apply

- `.github/workflows/*.yml` — workflow `name:` + step `name:` fields
- `GITHUB_STEP_SUMMARY` content — status icons in tables, banners, headings
- Status comments on PRs / issues posted by workflows
- `docs/workflows/*.md` headings where they reinforce the workflow's purpose (e.g., the cover of `dotnet-publish-binaries.md`)

## Where NOT to apply

- Code comments inside `run:` blocks (clutters logs, not part of UI)
- Variable names, environment variables, file names
- Markdown that is consumed by tooling expecting plain text
- Anywhere they could be misread as part of code (regex patterns, JSON, etc.)
