# mkdocs brand stylesheets

Reference stylesheets that map BAUER GROUP brand tokens onto
mkdocs-material's published CSS variables. Consumed by:

- The [`mkdocs-deploy-pages`][reusable] reusable workflow.
- The [`mkdocs-apply-brand`][composite] composite action.

[reusable]: ../../workflows/mkdocs-deploy-pages.yml
[composite]: ../../actions/mkdocs-apply-brand

## Files

| File | Brand |
| ---- | ----- |
| [`bauer-group.css`](bauer-group.css) | BAUER GROUP corporate identity (orange #FF8500 primary, warm-gray neutrals, semantic accent palette). |

## Editing

Edit `bauer-group.css` here. Every downstream consumer pinned at
`@main` picks up the change on the next workflow run; pinned tags
roll forward only when the consumer bumps its `@vX.Y.Z`.

The token block at the top of the stylesheet (`--orange-*`,
`--warm-*`, semantic `--success-*`, etc.) is a verbatim mirror of
the published palette at
[brand.docs.bauer-group.com](https://brand.docs.bauer-group.com/).
The mkdocs-material override block below it (`--md-*` variables)
maps those tokens onto the theme.

## Adding a new brand variant

1. Drop a new `<brand-id>.css` file alongside `bauer-group.css`.
2. Add a case for it in
   [`mkdocs-apply-brand/action.yml`](../../actions/mkdocs-apply-brand/action.yml).
3. Document it in the table above.

The reusable workflow's `apply-brand` input then accepts the new id.
