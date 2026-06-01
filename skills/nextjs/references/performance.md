# Next.js performance — Core Web Vitals, images, fonts, bundles, streaming

Deep dive behind the "Performance" section of `SKILL.md`. Measure first; the levers below map to
specific Core Web Vitals. INP replaced FID as the responsiveness metric.

## Core Web Vitals map

| Metric | Target  | Primary levers                                         |
| ------ | ------- | ------------------------------------------------------ |
| LCP    | < 2.5s  | `next/image priority`, kill waterfalls, resource hints |
| CLS    | < 0.1   | image dimensions, `next/font`, reserve Suspense space  |
| INP    | < 200ms | smaller bundles, fewer re-renders, defer 3rd-party JS  |

## Waterfalls

Sequential `await`s serialize independent work. Start every independent request early and await
late, or run them with `Promise.all`.

```ts
// Bad: three round-trips in series (user → posts → comments)
const user = await getUser(id);
const posts = await getPosts(id);
const comments = await getComments(id);

// Good: independent fetches run in parallel
const [user, posts, comments] = await Promise.all([
  getUser(id),
  getPosts(id),
  getComments(id),
]);
```

```ts
// Good: start early, await late — do cheap sync work between kickoff and await
const userPromise = getUser(id); // fire immediately
const isValid = id.length === 36; // cheap synchronous guard, no await yet
if (!isValid) notFound();
const user = await userPromise; // await only when you need it
```

Split sibling fetches into **parallel child components**, each wrapped in its own `<Suspense>`, so
the shell streams while slow sections fill in independently:

```tsx
import { Suspense } from "react";

export default function Page() {
  return (
    <main>
      <Suspense fallback={<ProfileSkeleton />}>
        <Profile /> {/* awaits getUser */}
      </Suspense>
      <Suspense fallback={<FeedSkeleton />}>
        <Feed /> {/* awaits getPosts — does not block Profile */}
      </Suspense>
    </main>
  );
}
```

## Images

`next/image` prevents CLS (reserves space) and serves optimized formats. Always give it intrinsic
dimensions, or use `fill` inside a sized, positioned parent. Mark the LCP image `priority`.

```tsx
import Image from "next/image";

// fixed dimensions
<Image src="/hero.jpg" alt="Product hero" width={1200} height={630} priority />;

// responsive with fill — parent must be sized + position: relative
<div style={{ position: "relative", width: "100%", aspectRatio: "16 / 9" }}>
  <Image
    src="/banner.jpg"
    alt="Banner"
    fill
    sizes="(max-width: 768px) 100vw, 50vw"
    style={{ objectFit: "cover" }}
  />
</div>;
```

```ts
// next.config.ts — allowlist remote image hosts (required for external src)
import type { NextConfig } from "next";
const config: NextConfig = {
  images: {
    remotePatterns: [{ protocol: "https", hostname: "images.example.com" }],
  },
};
export default config;
```

## Fonts

`next/font` self-hosts the font files at build time (no request to Google), inlines a size-adjust
fallback, and applies `font-display: swap` — eliminating CLS and a render-blocking round-trip.

```tsx
// app/layout.tsx
import { Inter } from "next/font/google";
import localFont from "next/font/local";

const inter = Inter({ subsets: ["latin"], display: "swap", variable: "--font-inter" });
const brand = localFont({ src: "./brand.woff2", display: "swap", variable: "--font-brand" });

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${brand.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```

## Bundle

```ts
// next.config.ts — tree-shake heavy icon/util libraries that ship as barrels
import type { NextConfig } from "next";
const config: NextConfig = {
  experimental: {
    optimizePackageImports: ["lucide-react", "date-fns", "@mui/icons-material"],
  },
};
export default config;
```

Prefer **direct imports** over barrel files (`import debounce from "lodash/debounce"`, not
`import { debounce } from "lodash"`). Lazy-load heavy client-only islands:

```tsx
import dynamic from "next/dynamic";

// client-only heavy lib (charts, editors) — skip SSR, code-split it out of the initial bundle
const Editor = dynamic(() => import("./rich-editor"), {
  ssr: false,
  loading: () => <p>Loading editor…</p>,
});
```

```bash
npm install --save-dev @next/bundle-analyzer   # bundle-analyzer wiring
```

```ts
// next.config.ts
import bundleAnalyzer from "@next/bundle-analyzer";
const withAnalyzer = bundleAnalyzer({ enabled: process.env.ANALYZE === "true" });
export default withAnalyzer({ /* ...rest of config... */ });
// run: ANALYZE=true next build
```

```tsx
// third-party scripts: pick the strategy, never a raw <script>
import Script from "next/script";
<Script src="https://example.com/analytics.js" strategy="afterInteractive" />;
<Script src="https://example.com/chat-widget.js" strategy="lazyOnload" />;
```

## PPR / streaming

Partial Prerendering serves a static shell instantly and streams the dynamic holes. Always reserve
space for the dynamic part (fixed height / skeleton) so filling it does not shift layout (CLS).

```tsx
import { Suspense } from "react";

export default function Page() {
  return (
    <main>
      <h1>Store</h1> {/* static shell — prerendered */}
      <div style={{ minHeight: 240 }}>
        <Suspense fallback={<CartSkeleton />}>
          <Cart /> {/* dynamic hole — streamed, space reserved above */}
        </Suspense>
      </div>
    </main>
  );
}
```

## Edge vs Node runtime

- **Edge** (`export const runtime = "edge"`): low latency, runs close to users, but a limited Web
  API subset — no native Node modules, no most DB drivers. Good for redirects, geolocation, light
  JSON, auth gating.
- **Node** (`export const runtime = "nodejs"`, the default): full Node APIs, all DB drivers, larger
  cold start. Use for anything touching the database or Node-only libraries.

## React Compiler

With `reactCompiler: true`, the compiler memoizes automatically. Demote manual
`useMemo`/`useCallback`/`React.memo` to **review-only**: do not add them, and flag existing ones as
removable unless a profile proves they help.

## Measurement

- Read `next build` output: the **First Load JS** column per route is the budget to watch.
- Run Lighthouse, or collect field data with the `web-vitals` package (`onLCP`, `onCLS`, `onINP`).
- Capture a Chrome DevTools performance trace to find the LCP element and long tasks driving INP.
- The `chrome-devtools-mcp` skill can drive these traces and a Lighthouse audit programmatically.

## See Also

- `react.md` — re-render discipline and `useTransition`/`useDeferredValue` for INP.
- `data-and-caching.md` — caching and streaming reduce LCP and round-trips.
