# Content Layer — loaders, schemas, querying

The Content Layer (stable since Astro 5.0) sources content from anywhere through **loaders** and
gives you type-safe, queryable collections. Config lives in `src/content.config.ts` (v6 path; the
legacy `src/content/config.ts` location is removed in v6, per the
[upgrade-to-v6 guide](https://docs.astro.build/en/guides/upgrade-to/v6/)).

## defineCollection: loader + schema

A collection is `defineCollection({ loader, schema })`. The loader produces entries; the schema (Zod
4) validates and types their `data`.

```typescript
// src/content.config.ts
import { defineCollection, reference } from "astro:content";
import { z } from "astro/zod"; // v6: z is imported from astro/zod, not astro:content
import { glob, file } from "astro/loaders";

// glob() — many files, one entry per file. `id` = path minus base & extension.
const blog = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/data/blog" }),
  schema: ({ image }) =>
    z.object({
      title: z.string(),
      description: z.string().max(160),
      pubDate: z.coerce.date(),
      updated: z.coerce.date().optional(),
      draft: z.boolean().default(false),
      cover: image(), // astro:assets image, validated at build
      author: reference("authors"), // cross-collection reference
      tags: z.array(z.string()).default([]),
    }),
});

// file() — ONE structured file (JSON/YAML) holding an array of entries.
const authors = defineCollection({
  loader: file("./src/data/authors.json"), // each object needs an `id`
  schema: z.object({ id: z.string(), name: z.string(), url: z.string().url().optional() }),
});

export const collections = { blog, authors };
```

## Zod 4 notes (Astro 6)

In Astro 6 you import `z` from **`astro/zod`** (it is **Zod 4**); `z` was removed from `astro:content`
and the old `astro:schema` alias is gone — both consolidate into `astro/zod`. Source:
[upgrade-to-v6 guide](https://docs.astro.build/en/guides/upgrade-to/v6/) and the
[Astro 6.0 release post, 2026-03-10](https://astro.build/blog/astro-6/). When migrating from v5:

- Replace `import { z } from "astro:content"` with `import { z } from "astro/zod"` (and any
  `astro:schema` import likewise). `defineCollection`, `reference`, `getCollection`, etc. still come
  from `astro:content`.
- `z.coerce.date()` for ISO date strings in frontmatter — unchanged, still the right call.
- Review any custom error-map / `.refine()` usage and string-format helpers; Zod 4 changed some
  error shapes and deprecated a few v3 APIs. Run a build and read the validation errors.
- `image()` (injected via the `({ image }) => ...` schema form) validates and optimizes local images
  referenced in frontmatter.

## Querying & rendering

```astro
---
import { getCollection, getEntry, render } from "astro:content";

// All non-draft posts, newest first
const posts = (await getCollection("blog", ({ data }) => !data.draft))
  .sort((a, b) => b.data.pubDate.getTime() - a.data.pubDate.getTime());

// A single entry by id
const post = await getEntry("blog", "hello-world");

// Resolve a reference() to the full entry
const author = post ? await getEntry(post.data.author) : undefined;

// Render Markdown/MDX body to a component (standalone render(), not entry.render())
const { Content, headings } = await render(posts[0]);
---
<h2>{author?.data.name}</h2>
<Content />
```

## Custom & CMS loaders

When content comes from an API/CMS rather than files, write an inline loader or use a community one
(`@ascorbic/*`, Storyblok, Contentful, etc.). The contract: return an array of objects each with an
`id`, validated by the same `schema`.

```typescript
// src/content.config.ts — minimal inline loader fetching from a headless CMS at build time
const products = defineCollection({
  loader: async () => {
    const res = await fetch("https://cms.example.com/api/products");
    const items = await res.json();
    return items.map((p: any) => ({ id: String(p.id), ...p })); // each entry needs an `id`
  },
  schema: z.object({ id: z.string(), name: z.string(), price: z.number() }),
});
```

For incremental/syncing loaders that cache between builds, implement the full loader object
(`{ name, load(context) }`) and use `context.store` — see
`docs.astro.build/en/reference/content-loader-reference`.

## Live Content Collections (stable in Astro 6)

Stable as of the [Astro 6.0 release, 2026-03-10](https://astro.build/blog/astro-6/). Live collections
fetch **at request time** instead of build time, so data stays fresh without a rebuild — ideal for
inventory, prices, or anything that changes between deploys on an otherwise static site. They use a
separate `src/live.config.ts` and `getLiveCollection`/`getLiveEntry`. Use them only for genuinely
live data; build-time `glob()`/`file()` collections stay faster and cacheable for everything stable.
Reference: [Live Content Collections guide](https://docs.astro.build/en/guides/content-collections/).

## MDX

`npx astro add mdx` enables `.mdx` in the same `glob()` pattern. MDX lets a content file import and
render components (including hydrated islands with `client:*`). Keep islands inside MDX rare and
deferred for the same reason as everywhere else: they ship JS.
