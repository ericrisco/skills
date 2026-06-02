# Performance & debugging deep dive

## Re-render profiling

Before optimizing, measure. Don't guess which component re-renders.

1. Open React DevTools Profiler, record, do the slow interaction (scroll, type), stop. Components that flash on every commit are your targets.
2. Highlight updates / the Profiler's "why did this render" tells you whether props, state, or context changed.
3. `why-did-you-render` (dev-only) logs the exact prop that changed reference. Useful for the classic "new object/array literal every render" leak.

With React Compiler on (SDK 54+), most manual `useMemo`/`useCallback` are redundant — but the compiler can't memoize across a virtualized list boundary, so list-row discipline still matters.

The keystroke re-render storm: a search box whose `onChangeText` calls `setState` at the screen root re-renders the whole list on each character. Fix by either (a) keeping the input state local to a memoized search component and debouncing the query, or (b) deriving filtered data with a stable selector so only the list body recommits.

## FlashList tuning knobs

- `getItemType` — return a discriminator (`'header' | 'product' | 'ad'`). Recycling happens within a type; mixing types without it forces remeasures.
- `keyExtractor` — stable domain id, never index.
- Disable entry/layout animations on the **initial** mount — rows can flash into the wrong position for a split second when mounted while animations run.
- Keep `renderItem` pure: no inline closures, no inline style objects, memoized row component.
- For images, use a caching image component and fixed dimensions so layout doesn't thrash during scroll.

## Reanimated thread model

- Worklets run on the **UI thread**; shared values mutate there without a JS round-trip, so motion survives a busy JS thread.
- A worklet calling a plain JS function crashes — cross back only via `runOnJS(fn)(...args)`, and only at the boundary (gesture end, completion callback).
- Build gesture objects in `useMemo`; a fresh object each render reattaches the recognizer and drops in-flight touches.
- Reanimated 4 needs the New Architecture / RN 0.76+. Reanimated 4 CSS animations cover simple declarative motion; reserve worklets for gesture-driven or physics-based animation.

## Hermes crash triage

- Read Hermes stack traces bottom-up; the meaningful JS frame usually sits just above the native bridge frames.
- Symbolicate release crashes against the matching source map — an un-symbolicated trace is just addresses.
- A red screen citing the interop layer under Fabric almost always means an old-architecture dependency. Update it or replace it with a New-Arch-ready package. Do not set `newArchEnabled: false` — it is a no-op on RN 0.82+/SDK 55 and only hides the cause.

## Platform-divergence checklist

When something works on one platform and breaks on the other, walk this before guessing:

1. Is there a `.ios.tsx`/`.android.tsx` fork or a `Platform.select` branch diverging behavior?
2. `KeyboardAvoidingView` behavior prop — `padding` (iOS) vs `height`/none (Android)?
3. Safe-area insets — hardcoded padding that only fits one device family?
4. Permissions — declared in `Info.plist` (iOS) and `AndroidManifest.xml` (Android), requested at runtime on both?
5. A native dependency that ships only one platform's implementation, or differs in New-Arch readiness?
6. Shadow/elevation — `shadow*` (iOS) vs `elevation` (Android) styled separately?
7. Default font, line height, and ripple/highlight feedback differ — is the divergence cosmetic and expected, or a real bug?
