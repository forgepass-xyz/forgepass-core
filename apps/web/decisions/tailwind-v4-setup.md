# Tailwind CSS v4 Setup — apps/web

**Decision date:** 2026-06-19
**Resolved in:** #088 (scaffold gap audit)
**Related issue:** #012 (forgepass-core scaffold), #046 (Next.js app structure)

## Summary

apps/web uses Tailwind CSS v4, not v3. There is no `tailwind.config.ts` file and
there never will be. This is by design, not a gap.

## v4 Configuration Model

Tailwind v4 replaced the JavaScript config file with CSS-based configuration.
All theming is done via `@theme` blocks in `apps/web/app/globals.css`.

The full v4 setup in this project:

| File | Role |
|---|---|
| `apps/web/package.json` | `tailwindcss@^4` and `@tailwindcss/postcss@^4` as devDependencies |
| `apps/web/postcss.config.mjs` | Registers `@tailwindcss/postcss` as the PostCSS plugin |
| `apps/web/app/globals.css` | `@import "tailwindcss"` loads the framework; `@theme inline` block defines custom tokens |

## Why No tailwind.config.ts

The #015 scaffold audit flagged `tailwind.config.ts` as missing. That check was
based on v3 expectations. In v4:

- Content path scanning is automatic (no `content: []` array needed)
- Custom colours, fonts, and spacing go in the `@theme` block in CSS
- The `@tailwindcss/postcss` plugin replaces the old `tailwindcss` PostCSS plugin
- There is no equivalent of `tailwind.config.ts` in v4

## Adding Custom Tokens

To extend the design system, add tokens to `apps/web/app/globals.css`:

```css
@theme inline {
  --color-brand: #4f46e5;
  --font-display: "Inter", sans-serif;
  --spacing-section: 4rem;
}
```

These tokens are then available as Tailwind utilities (`bg-brand`, `font-display`,
`py-section`, etc.) without any config file change.

## Reference

- Tailwind v4 upgrade guide: https://tailwindcss.com/docs/upgrade-guide
- v4 configuration: https://tailwindcss.com/docs/configuration
