# mkdocs-deploy-pages — Examples

Drop-in workflow templates that consume the
[`mkdocs-deploy-pages`][reusable] reusable workflow.

[reusable]: ../../../../.github/workflows/mkdocs-deploy-pages.yml

## When to pick what

| Example | Use when |
| ------- | -------- |
| [`basic.yml`](basic.yml) | Standard BAUER project: mkdocs config at `docs/mkdocs.yml`, deps in `docs/requirements.txt`, BAUER brand applied automatically. The minimal consumer — one job, no `with:` block. |
| [`strict-and-self-hosted.yml`](strict-and-self-hosted.yml) | Run with `--strict` (warnings → errors) on a BAUER hardware runner, with the brand stylesheet opted out (e.g. project ships its own theme). |
| [`custom-paths.yml`](custom-paths.yml) | Project layout that doesn't follow the reference defaults — alternate `mkdocs.yml`, requirements file, output dir, brand-target path. |
| [`sync-brand-css.yml`](sync-brand-css.yml) | Scheduled sync of the BAUER brand stylesheet into the consumer's local committed copy. Daily cron, opens a PR when the upstream drifts. Pair with `basic.yml`. |

## Project requirements

For the **basic.yml** path to work as-is, the consumer repo needs:

1. **`docs/mkdocs.yml`** — standard mkdocs-material config. Two
   non-default lines matter:
   ```yaml
   site_dir: ../site             # build output lands at <repo>/site
   extra_css:
     - assets/_bauer-brand.css   # picks up the brand stylesheet
   ```
2. **`docs/requirements.txt`** — pinned mkdocs deps. Used by
   `setup-python` for the pip cache fingerprint AND the actual
   install. Loose lower bounds are fine; Dependabot keeps them in
   step.
3. **GitHub repo settings → Pages → Source = "GitHub Actions"** —
   the OIDC-backed `actions/deploy-pages` workflow refuses to push
   if Source is set to a branch.

## What `apply-brand: 'bauer-group'` does

The reusable invokes the
[`mkdocs-apply-brand`][composite] composite action **before**
`mkdocs build`. The composite copies
`.github/branding/mkdocs/bauer-group.css` from the templates repo
into your `docs_dir` at the path you nominated via
`brand-target-path` (default `docs/assets/_bauer-brand.css`). When
`mkdocs build` runs, it sees the file via the `extra_css` line in
your `mkdocs.yml` and the brand variables override mkdocs-material's
defaults.

[composite]: ../../../../.github/actions/mkdocs-apply-brand

To **opt out** of the brand styling (e.g. the project ships its own
theme), set `apply-brand: 'none'`. The reusable then skips the
composite step entirely; the `extra_css` line in your `mkdocs.yml`
becomes a dangling reference, so either remove it or have the file
exist some other way.
