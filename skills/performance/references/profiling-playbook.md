# Profiling playbook

Tool-specific runbooks the SKILL body points to. Pick the tool that matches the phase you're attributing; each one answers a different question.

## Field data — the only number that decides "is it a problem"

Field = real users, 75th percentile. Two sources:

- **CrUX / PageSpeed Insights** — `https://pagespeed.web.dev/` gives you the field CWV for any public URL (28-day rolling p75) plus a lab Lighthouse run side by side. Read the field section first; the lab section is for the *why*.
- **RUM via the `web-vitals` library** — for your own real traffic, especially routes CrUX doesn't have enough data for.

```ts
// web-vitals: report each metric to your analytics endpoint (field RUM)
import { onLCP, onINP, onCLS } from "web-vitals";

function send(metric: { name: string; value: number; rating: string }) {
  navigator.sendBeacon("/rum", JSON.stringify(metric));
}
onLCP(send);
onINP(send);
onCLS(send);
```

Aggregate these at the 75th percentile per route. The mean lies — a p50 of 1.5 s with a p75 of 4 s is a failing route the average calls fine. Dashboards/alerting for this stream are `../../monitoring/SKILL.md` / observability's job; here you only need the p75 to know whether you've cleared the threshold.

## Lighthouse — the lab "why" for load

- Run from Chrome DevTools → Lighthouse panel, or CLI `npx lighthouse <url> --view`. Use **mobile + simulated throttling** (the default) — desktop hides the bottleneck most users hit.
- In CI, gate a build with Lighthouse CI (`lhci autorun`) and an assertion budget so a regression fails the PR. Treat the budget file as the source of truth (see `verify.sh`).
- Lighthouse is a single throttled lab load. If its LCP is far worse than field p75, trust the field — don't chase the lab phantom.

## Chrome DevTools Performance trace — read the flame chart

1. DevTools → Performance → record, reload or perform the interaction, stop.
2. **LCP/CLS markers** sit on the Timings track — the LCP marker tells you the element and the timestamp; hover for the subpart breakdown (TTFB / load delay / load duration / render delay).
3. **Main-thread track** is the flame chart. Wide bars = expensive functions. Bars flagged with a red corner are **long tasks (>50 ms)** — these are your INP suspects. Click one to see the call stack and which script owns it (often third-party).
4. Attribute before fixing: name the dominant subpart (LCP) or the owning script (INP). One sentence, then fix that one thing.

## React DevTools Profiler — re-render cost

1. Install React DevTools, open the **Profiler** tab, record an interaction, stop.
2. The flamegraph colors components by render time; the ranked chart lists the slowest. Click a component → **"Why did this render?"** shows hooks/props that changed.
3. Apply the **16 ms rule**: a manual `useMemo`/`useCallback` is only worth it if it saves more than one 60 fps frame (~16 ms). React 19's compiler already memoizes the common cases — don't add manual memo the Profiler can't justify.
4. The usual real cause is an unstable reference (new object/array/function created in render and passed as a prop). The compiler can't fix that — hoist or stabilize it; don't wrap the child in `memo` to paper over it.

## Bundle treemap — what's actually heavy

- **Next.js:** wire `@next/bundle-analyzer` into `next.config`, then `ANALYZE=true npm run build`. It opens an interactive treemap and (current Next) uses the Turbopack module graph to trace which `'use client'` boundary pulled a module into the client bundle.
- **Any webpack/Vite build:** `npx source-map-explorer 'dist/**/*.js'` attributes bytes back to source files via source maps.
- Reading it: box area = bytes. One or two boxes usually dwarf the rest — that's your first cut (replace the dep). Then look for whole-library imports (a giant box for a lib you use one function from) and for heavy UI that could be a dynamic `import()`.

## Order of attack

Field p75 says *which metric* fails → lab trace says *which phase/script* → fix that one phase → re-measure field p75. Stop at "good".
