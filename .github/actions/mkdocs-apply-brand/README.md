# mkdocs Apply BAUER Brand

Composite action that copies the BAUER GROUP mkdocs brand stylesheet
into a consumer's docs tree before the mkdocs build runs. Used as a
step inside the
[`mkdocs-deploy-pages`][reusable] reusable workflow, but can also be
called from any custom workflow that builds mkdocs sites.

[reusable]: ../../workflows/mkdocs-deploy-pages.yml

## What it does

1. Resolves the requested brand to a stylesheet under
   `automation-templates/.github/branding/mkdocs/`.
2. Creates the target directory in the consumer's checkout.
3. Copies the stylesheet there.

The consumer's `mkdocs.yml` must reference the file via `extra_css`
(paths there are relative to `docs_dir`, default `docs/`):

```yaml
extra_css:
  - assets/_bauer-brand.css
```

## Inputs

| Name | Description | Default |
| ---- | ----------- | ------- |
| `brand` | `bauer-group` to apply the BAUER stylesheet, `none` to skip. | `bauer-group` |
| `target-css-path` | Where to copy the stylesheet (repo-relative). Must align with the consumer's `extra_css` entry. | `docs/assets/_bauer-brand.css` |

## Outputs

| Name | Description |
| ---- | ----------- |
| `css-path` | Final path of the materialised stylesheet (empty when `brand: none`). |

## Usage

### Inside the reusable workflow

You don't call this directly — `mkdocs-deploy-pages.yml` invokes it
when `apply-brand` is anything other than `none`.

### Inside a custom workflow

```yaml
- uses: actions/checkout@v6
- uses: bauer-group/automation-templates/.github/actions/mkdocs-apply-brand@main
  with:
    brand: bauer-group
- run: mkdocs build --config-file docs/mkdocs.yml
```

## Brand source of truth

The stylesheet at
[`.github/branding/mkdocs/bauer-group.css`](../../branding/mkdocs/bauer-group.css)
maps the brand tokens published at
[brand.docs.bauer-group.com](https://brand.docs.bauer-group.com/) to
mkdocs-material's CSS variables. Edit the stylesheet there — every
consumer using `@main` picks up the change on the next build.
