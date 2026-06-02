# Liquid & Online Store 2.0 themes — deep dive

Companion to the Theme surface section of `../SKILL.md`. Everything here is OS 2.0 (GA 2021).

## The architecture, end to end

A storefront page is assembled top-down:

1. `layout/theme.liquid` — the HTML shell. Renders `{{ content_for_header }}` and
   `{{ content_for_layout }}`. One per theme (plus optional `checkout` layout on Plus).
2. A **JSON template** (`templates/product.json`, `templates/index.json`, …) declares which
   sections render and their order — not Liquid, pure JSON the theme editor mutates.
3. Each **section** (`sections/*.liquid`) is markup + a `{% schema %}` of settings and blocks.
4. **Section groups** (`sections/header.json`, `sections/footer.json`) make header/footer
   editable as section lists.
5. **Snippets** (`snippets/*.liquid`) are partials, always via `{% render %}`.

```json
// templates/product.json
{
  "sections": {
    "main": { "type": "main-product" },
    "related": { "type": "related-products", "settings": { "heading": "You may also like" } }
  },
  "order": ["main", "related"]
}
```

## `{% schema %}` setting types & presets

The schema is JSON inside the `.liquid` file. Common setting types: `text`, `textarea`,
`richtext`, `image_picker`, `url`, `product`, `collection`, `product_list`, `color`, `range`,
`select`, `checkbox`, `font_picker`, `metaobject`/`metaobject_list`.

```liquid
{% schema %}
{
  "name": "Featured collection",
  "tag": "section",
  "settings": [
    { "type": "collection", "id": "collection", "label": "Collection" },
    { "type": "range", "id": "limit", "min": 2, "max": 12, "step": 1, "default": 8, "label": "Products" }
  ],
  "blocks": [
    { "type": "text", "name": "Text", "settings": [{ "type": "richtext", "id": "body", "label": "Body" }] },
    { "type": "@app" }
  ],
  "presets": [{ "name": "Featured collection", "blocks": [{ "type": "text" }] }]
}
{% endschema %}
```

- `presets` is what makes the section show up in "Add section" in the editor. No preset → the
  section exists but a merchant can't add it.
- `blocks` with `{ "type": "@app" }` accepts app-provided blocks (theme app extensions).
- Iterate blocks in render order: `{% for block in section.blocks %}{% render block.type, block: block %}{% endfor %}`
  and emit `{{ block.shopify_attributes }}` on the block's root element so the editor can target it.

## Theme blocks (OS 2.0 reusable blocks)

`blocks/*.liquid` define reusable, nestable blocks usable across sections — distinct from a
section's inline `blocks`. They have their own `{% schema %}` and can accept child blocks via
`"blocks": [{ "type": "@theme" }]`. Use them to avoid copy-pasting block markup between sections.

## Dynamic sources, metafields & metaobjects

Bind structured content instead of hardcoding. A setting can carry a **dynamic source** so a
merchant connects it to a metafield in the editor. Read metafields in Liquid:

```liquid
{{ product.metafields.custom.care_instructions | metafield_tag }}
{% assign spec = product.metafields.custom.spec.value %}  {# metaobject reference #}
```

Prefer this over an `if product.type == ...` ladder: the branch becomes a metafield lookup, so
new product types need data, not a theme deploy.

## Storefront performance

- Responsive images: `{{ image | image_url: width: 800 | image_tag: loading: 'lazy', sizes: '...', widths: '300,600,800,1200' }}`.
- `loading="eager"` + a `<link rel="preload">` only for the LCP hero image; lazy-load the rest.
- Defer non-critical media and scripts; avoid render-blocking app embeds.
- Always `limit:` collection/loop output; unbounded loops dominate render time.

## Theme Check

`shopify theme check` (config: `.theme-check.yml`) flags deprecated `include`, unused
assigns, missing `{{ block.shopify_attributes }}`, untranslated strings, and parser errors. Run
it locally and in CI. `theme dev` gives hot reload as the inner loop.
