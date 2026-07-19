# Renovate Configuration for Docker Maintenance

Copy one of these files to `renovate.json` (or `.github/renovate.json`) in your repository.

| File | Use when |
|------|----------|
| `docker-maintenance.json` | All base images are **public** |
| `docker-maintenance-internal-ghcr.json` | At least one base image is an **internal or private** GHCR package |

## Public base images

`docker-maintenance.json` needs no credentials. Copy it and you are done.

## Internal or private base images

Without credentials Renovate queries `ghcr.io` anonymously, is denied, and reports **no updates** — silently and permanently. There is no error to notice, which is why this is worth setting up deliberately.

`docker-maintenance-internal-ghcr.json` adds a `hostRules` entry for `ghcr.io`. How you supply the token depends on how Renovate runs:

### Mend Renovate App (hosted)

The config must carry an **encrypted** token. Encrypt a PAT with `read:packages` at [app.renovatebot.com/encrypt](https://app.renovatebot.com/encrypt), then replace the placeholder:

```json
"hostRules": [
  {
    "matchHost": "ghcr.io",
    "hostType": "docker",
    "username": "x-access-token",
    "encrypted": {
      "password": "wcFMA/xDdHCJBTolAQ...."
    }
  }
]
```

> The shipped file contains `REPLACE_WITH_ENCRYPTED_TOKEN`. Renovate will fail to authenticate until you replace it — deliberately, so a half-finished setup is visible rather than silently reverting to anonymous access.

### Self-hosted Renovate

Drop the `encrypted` block and supply the token through the environment instead:

```json
"hostRules": [
  {
    "matchHost": "ghcr.io",
    "hostType": "docker",
    "username": "x-access-token",
    "password": "{{ env.GHCR_READ_TOKEN }}"
  }
]
```

Then set `GHCR_READ_TOKEN` in the runner environment and allow it via `RENOVATE_ALLOWED_ENV`.

## Why not the workflow's `GITHUB_TOKEN`?

Renovate runs outside your workflow. It has no access to the automatic `GITHUB_TOKEN`, so a real PAT with `read:packages` is required — unlike the workflows in this repository, which do use `GITHUB_TOKEN`.

## References

- [GHCR Internal Visibility](../../../docs/ghcr-internal-visibility.md)
- [Dependabot alternative](../docker-maintenance-dependabot/dependabot.yml)
- [Renovate host rules](https://docs.renovatebot.com/configuration-options/#hostrules)
