# Next.js performance — Core Web Vitals, images, fonts, bundles, streaming

Deep dive behind the "Performance" section of `SKILL.md`. Measure first; the levers below map to
specific Core Web Vitals. INP replaced FID as the responsiveness metric.

## Core Web Vitals map

| Metric | Target  | Primary levers                                         |
| ------ | ------- | ------------------------------------------------------ |
| LCP    | < 2.5s  | `next/image priority`, kill waterfalls, `preload`/`preconnect` hints |
| CLS    | < 0.1   | image dimensions, `next/font`, reserve Suspense space, `contain-intrinsic-size` |
| INP    | < 200ms | smaller bundles, narrow store selectors, list virtualization, defer 3rd-party JS |

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
"use client"; // ssr: false only works in a Client Component — it errors in a Server Component (App Router)
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

## Resource hints (`react-dom`)

React 19 exposes the resource-hint APIs from `react-dom`. Call them from a Server Component to warm
up the connections and assets the next interaction needs, ahead of the LCP/INP that depends on them.

```tsx
import { preconnect, prefetchDNS, preload } from "react-dom";

export function HeroHints() {
  prefetchDNS("https://cdn.example.com"); // resolve DNS early
  preconnect("https://api.example.com"); // open the TCP+TLS connection early
  preload("/fonts/brand.woff2", { as: "font", type: "font/woff2", crossOrigin: "anonymous" });
  preload("/hero.jpg", { as: "image", fetchPriority: "high" }); // help the LCP image
  return null;
}
```

`next/font` and `next/image priority` already emit hints for fonts and the LCP image; reach for the
manual APIs for cross-origin assets and third-party endpoints they do not cover.

## Long lists: virtualization + `content-visibility`

Rendering more than ~50 rows at once inflates DOM size, hurts INP, and lengthens hydration. Two
levers, smallest first:

`content-visibility: auto` lets the browser skip layout/paint for off-screen blocks with **zero JS**.
Pair it with `contain-intrinsic-size` so the skipped block still reserves space (no CLS, no scrollbar
jump).

```css
.feed-item {
  content-visibility: auto;
  contain-intrinsic-size: auto 120px; /* estimated row height — reserves space while skipped */
}
```

For long, scrollable, uniform lists (hundreds+ of rows), **windowing** renders only the visible
slice. Use `@tanstack/react-virtual` in a `"use client"` component:

```tsx
"use client";
import { useRef } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";

export function VirtualList({ rows }: { rows: string[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 40, // row height in px
    overscan: 8,
  });
  return (
    <div ref={parentRef} style={{ height: 400, overflow: "auto" }}>
      <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
        {virtualizer.getVirtualItems().map((item) => (
          <div
            key={item.key}
            style={{ position: "absolute", top: 0, left: 0, width: "100%", height: item.size, transform: `translateY(${item.start}px)` }}
          >
            {rows[item.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Client store granularity (Zustand / `useSyncExternalStore`)

When state lives in an external store, **subscribe to the narrowest slice** so a component re-renders
only when the value it reads changes — coarse subscriptions are a common INP regression.

```tsx
"use client";
import { create } from "zustand";

const useStore = create<{ count: number; user: string; inc: () => void }>((set) => ({
  count: 0,
  user: "ada",
  inc: () => set((s) => ({ count: s.count + 1 })),
}));

// Bad: subscribes to the whole store — re-renders on ANY field change (including user)
const { count } = useStore();

// Good: selector subscribes to one field — re-renders only when count changes
const count = useStore((s) => s.count);
// returning a new object/array each call needs a custom equality fn (e.g. useShallow) to avoid loops
```

Any external store (a custom one, a browser API like `matchMedia`) should expose itself to React via
`useSyncExternalStore` so reads are tear-free and SSR-safe:

```tsx
"use client";
import { useSyncExternalStore } from "react";

function subscribe(cb: () => void) {
  const mql = window.matchMedia("(prefers-reduced-motion: reduce)");
  mql.addEventListener("change", cb);
  return () => mql.removeEventListener("change", cb);
}

export function usePrefersReducedMotion() {
  return useSyncExternalStore(
    subscribe,
    () => window.matchMedia("(prefers-reduced-motion: reduce)").matches, // client snapshot
    () => false, // server snapshot — avoids hydration mismatch
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
- `../design/SKILL.md` — accessibility (focus, contrast, semantics): a fast page must also be usable.
  The `chrome-devtools-mcp:a11y-debugging` skill audits a11y, focus, tap targets, and contrast live.
