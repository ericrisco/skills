# Checkout extensibility — migration off `checkout.liquid`

Companion to the Checkout surface section of `../SKILL.md`. The old model (`checkout.liquid`,
additional scripts, script tags, Script Editor) is deprecated and being removed.

## The dated deadlines

- **2024-08-13** — Information / Shipping / Payment steps stopped supporting `checkout.liquid`.
- **2025-08-28** — Plus self-migrate deadline for Thank-you and Order-status page customizations
  (additional scripts, script tags, `checkout.liquid`). This is the date to *act by*, not the
  auto-upgrade date.
- **2026-01** — **automatic upgrades** of Thank-you and Order-status pages begin. Shopify gives a
  30-day email notice, then upgrades the store; any remaining additional-scripts, script-tag, or
  `checkout.liquid` customizations stop running. (Non-Plus stores have a later self-migrate deadline
  of 2026-08-26.)
- **2026-04-15** — legacy Shopify Scripts can no longer be **edited or published** (existing
  published scripts keep running until the shutdown below — so a bug after this date has no in-Script fix).
- **2026-06-30** — legacy Shopify Scripts (Script Editor) **stop executing**. Replace with Functions.

If a store says "checkout customizations broke after the August upgrade," they usually mean the
2025-08-28 deadline passed and they were caught by the automatic upgrade (rolling out from 2026-01) —
the old script no longer runs. Rebuild it on the seam below.

## Migration map

| Old mechanism | New seam | What you build |
|---|---|---|
| `checkout.liquid` markup / additional scripts (UI) | **Checkout UI extensions** | a sandboxed extension targeting a checkout location |
| Script Editor discount logic | **Discount Function** | Wasm function returning discount operations |
| Script Editor shipping/delivery logic | **Delivery customization Function** | reorder/rename/hide shipping options |
| Script Editor payment logic | **Payment customization Function** | reorder/rename/hide payment methods |
| `<script>` analytics/tracking in checkout | **Web Pixels** (+ server-side events) | sandboxed pixel; subscribe to standard events |
| custom checkout CSS / branding | **Checkout Branding API** | GraphQL mutations on the checkout profile |

## Checkout UI extensions

React/JS extensions that render at defined **targets** (e.g. `purchase.checkout.block.render`,
`purchase.checkout.delivery-address.render-before`). You get a typed API and components — **no DOM
access**, by design (PCI + stability). Configure target + capabilities in the extension's TOML.

```jsx
import { reactExtension, Banner } from "@shopify/ui-extensions-react/checkout";
export default reactExtension("purchase.checkout.block.render", () => <Banner>Free gift over 50</Banner>);
```

## Functions

Deterministic server-side logic compiled to Wasm — author in Rust or JavaScript. A Function takes a
typed input (a GraphQL query you define against the function's input schema) and returns operations.
Categories: product discount, order discount, shipping discount, delivery customization, payment
customization, cart/checkout validation. Generate with `shopify app generate extension`, build, and
ship with `shopify app deploy`.

```rust
#[shopify_function]
fn run(input: input::ResponseData) -> Result<output::FunctionRunResult> {
    // return discount operations from typed input
}
```

## Web Pixels

For tracking/analytics that previously lived in checkout `<script>` tags. A pixel runs in a sandbox
and subscribes to standard customer events (`checkout_completed`, `product_viewed`, …). It cannot
reach the page DOM; send events to your endpoint or a destination.

## Plus-only surfaces

Full checkout UI customization and some Function/branding capabilities are **Shopify Plus-only**.
Non-Plus stores get a constrained set of UI extension targets. Confirm the merchant's plan before
promising a checkout customization.
