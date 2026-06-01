# Next.js metadata & SEO — `generateMetadata`, sitemap, robots, OpenGraph

Deep dive behind the "Metadata & SEO" section of `SKILL.md`. This is the **build-side** layer:
how the App Router emits `<title>`, `<meta>`, OpenGraph/Twitter tags, `sitemap.xml`, and
`robots.txt`. For the *content/strategy* layer — keyword research, JSON-LD schema choice, GEO
(getting cited by AI engines), and Core Web Vitals as a ranking signal — see
`../marketing/references/seo-geo.md`. Sources: the Next.js `generate-metadata`,
`metadata/sitemap`, `metadata/robots`, and `metadata/opengraph-image` API docs.

The Metadata API works the same on Next.js 15 and 16. `metadata`/`generateMetadata` are
**Server-Component-only** exports — they cannot live in a `"use client"` file.

## Static vs dynamic metadata

Export a static `metadata` object when the values are known at build time; export an async
`generateMetadata` when they depend on `params`, `searchParams`, or fetched data. Use **one or the
other** in a given file, never both.

```ts
// app/layout.tsx — static, applied site-wide and merged into by child segments
import type { Metadata } from "next";

export const metadata: Metadata = {
  metadataBase: new URL("https://example.com"), // makes relative OG/canonical URLs absolute
  title: { default: "Acme", template: "%s · Acme" }, // child `title: "Pricing"` → "Pricing · Acme"
  description: "The fastest way to ship.",
  alternates: { canonical: "/" },
};
```

```tsx
// app/blog/[slug]/page.tsx — dynamic, derived from route params + data
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getPost } from "@/lib/dal";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ slug: string }>;
}): Promise<Metadata> {
  const { slug } = await params; // params is a Promise on v15+
  const post = await getPost(slug); // deduped with the page's own fetch via React.cache
  if (!post) return {};
  return {
    title: post.title,
    description: post.excerpt,
    alternates: { canonical: `/blog/${slug}` },
    openGraph: {
      title: post.title,
      description: post.excerpt,
      type: "article",
      url: `/blog/${slug}`,
      images: [{ url: post.cover, width: 1200, height: 630, alt: post.title }],
    },
    twitter: { card: "summary_large_image", title: post.title, description: post.excerpt },
  };
}
```

Wrap the data call in `React.cache` (see `data-and-caching.md`) so `generateMetadata` and the page
component share **one** query per request instead of fetching twice.

## OpenGraph & Twitter cards

OpenGraph drives the link preview on social/chat surfaces; Twitter falls back to OpenGraph when its
own fields are absent. Set `metadataBase` once in the root layout so relative `images`/`url`/
`canonical` paths resolve to absolute URLs. The recommended OG image size is **1200×630**.

```ts
// app/layout.tsx (excerpt) — site-wide OpenGraph defaults; pages override `title`/`images`
export const metadata: Metadata = {
  metadataBase: new URL("https://example.com"),
  openGraph: {
    siteName: "Acme",
    type: "website",
    locale: "en_US",
    images: ["/og-default.png"], // resolved against metadataBase → https://example.com/og-default.png
  },
};
```

### Dynamic OG images with `next/og`

Colocate an `opengraph-image.tsx` in a route segment. Its `default` export returns an
`ImageResponse` (from `next/og`), and Next.js wires up the `og:image` meta tag automatically —
no `openGraph.images` entry needed. `ImageResponse` renders JSX to PNG via Satori, so only
**flexbox + a subset of CSS** is supported (no `grid`, no external CSS).

```tsx
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from "next/og";
import { getPost } from "@/lib/dal";

export const alt = "Blog post cover";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await getPost(slug);
  return new ImageResponse(
    (
      <div
        style={{
          display: "flex", // Satori requires explicit flex layout
          flexDirection: "column",
          justifyContent: "center",
          width: "100%",
          height: "100%",
          padding: 80,
          background: "#0a0a0a",
          color: "#fff",
          fontSize: 64,
        }}
      >
        {post?.title ?? "Acme"}
      </div>
    ),
    { ...size },
  );
}
```

## `sitemap.ts`

Export a default function returning `MetadataRoute.Sitemap` from `app/sitemap.ts`. Next.js serves it
at `/sitemap.xml`. It can be async and fetch routes from the DB/CMS.

```ts
// app/sitemap.ts
import type { MetadataRoute } from "next";
import { getAllPostSlugs } from "@/lib/dal";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = "https://example.com";
  const posts = await getAllPostSlugs(); // [{ slug, updatedAt }, ...]
  return [
    { url: base, lastModified: new Date(), changeFrequency: "weekly", priority: 1 },
    { url: `${base}/pricing`, lastModified: new Date(), changeFrequency: "monthly", priority: 0.8 },
    ...posts.map((p) => ({
      url: `${base}/blog/${p.slug}`,
      lastModified: p.updatedAt,
      changeFrequency: "monthly" as const,
      priority: 0.5,
    })),
  ];
}
```

A single sitemap is capped at **50,000 URLs**. Past that, use `generateSitemaps()` to split into
multiple files (`/sitemap/0.xml`, `/sitemap/1.xml`, …) and return an array of `{ id }`.

```ts
// app/sitemap.ts — sharded for large catalogs
import type { MetadataRoute } from "next";
import { countProducts, getProductPage } from "@/lib/dal";

export async function generateSitemaps() {
  const pages = Math.ceil((await countProducts()) / 50_000);
  return Array.from({ length: pages }, (_, id) => ({ id }));
}

export default async function sitemap({ id }: { id: number }): Promise<MetadataRoute.Sitemap> {
  const products = await getProductPage(id, 50_000);
  return products.map((p) => ({ url: `https://example.com/p/${p.slug}`, lastModified: p.updatedAt }));
}
```

## `robots.ts`

Export a default function returning `MetadataRoute.Robots` from `app/robots.ts`; Next.js serves it
at `/robots.txt`. Point it at the sitemap and disallow private paths.

```ts
// app/robots.ts
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/", disallow: ["/api/", "/admin/", "/draft/"] }],
    sitemap: "https://example.com/sitemap.xml",
    host: "https://example.com",
  };
}
```

For the **AI-crawler** stance (allowing retrieval/citation bots like `OAI-SearchBot`/`PerplexityBot`
while optionally opting out of training crawlers like `GPTBot`/`ClaudeBot`/`Google-Extended`), the
per-bot `robots.txt` policy lives in `../marketing/references/seo-geo.md` — keep the `robots.ts`
`rules` array in sync with the policy decided there.

## What to verify on review

- `metadataBase` is set once in the root layout (otherwise relative OG/canonical URLs are dropped).
- Exactly one of `metadata` / `generateMetadata` per file; neither in a `"use client"` file.
- `generateMetadata`'s data fetch is `React.cache`-wrapped to dedupe with the page.
- Every indexable page has a unique `title`, `description`, and `alternates.canonical`.
- OG images are absolute (or relative under a set `metadataBase`) and ~1200×630.
- `sitemap.ts` excludes `noindex`/auth-gated routes; `robots.ts` disallows them and links the sitemap.

## See Also

- `../marketing/references/seo-geo.md` — keyword research, JSON-LD schema, GEO (AI-engine citation),
  per-engine optimization, and the SEO/GEO QA gate. This file emits the tags; that file decides the
  strategy and content structure behind them.
- `performance.md` — Core Web Vitals (LCP/CLS/INP), a direct ranking signal.
- `data-and-caching.md` — `React.cache` dedupe so metadata and the page share one query.
