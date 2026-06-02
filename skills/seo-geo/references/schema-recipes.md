# Schema / JSON-LD recipes

Copy-paste blocks for the structured-data types that **still earn rich results in 2026**,
plus the explicit list of types Google has **killed** (do not ship these). Validate every
block with the **Rich Results Test** and the **Schema Markup Validator
(validator.schema.org)** before it goes live.

All blocks go in a `<script type="application/ld+json">` in `<head>` or at the end of
`<body>`. JSON-LD must be valid JSON (double-quoted keys, no trailing commas) and carry
`@context` + `@type`.

## Article / BlogPosting

Use for any editorial page. `dateModified` doubles as a freshness signal for AI sources.

```json
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "Core Web Vitals: LCP, INP & CLS Thresholds (2026)",
  "image": ["https://example.com/img/cwv-cover.png"],
  "author": {
    "@type": "Person",
    "name": "Jane Doe",
    "url": "https://example.com/authors/jane-doe"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Example",
    "logo": { "@type": "ImageObject", "url": "https://example.com/logo.png" }
  },
  "datePublished": "2026-01-15T08:00:00+01:00",
  "dateModified": "2026-06-02T09:30:00+02:00",
  "mainEntityOfPage": "https://example.com/blog/core-web-vitals"
}
```

- **Required for the rich result:** `headline`, `image`, `datePublished`, `author`.
- **Strongly recommended:** `dateModified`, `publisher`, `mainEntityOfPage`.

## Product + Offer

```json
{
  "@context": "https://schema.org",
  "@type": "Product",
  "name": "Acme Wireless Headphones",
  "image": ["https://example.com/img/headphones.png"],
  "description": "Over-ear ANC headphones, 40h battery.",
  "sku": "ACME-WH-200",
  "brand": { "@type": "Brand", "name": "Acme" },
  "offers": {
    "@type": "Offer",
    "url": "https://example.com/p/acme-wh-200",
    "priceCurrency": "EUR",
    "price": "199.00",
    "availability": "https://schema.org/InStock"
  },
  "aggregateRating": {
    "@type": "AggregateRating",
    "ratingValue": "4.6",
    "reviewCount": "318"
  }
}
```

- **Required for the offer result:** `name`, `image`, `offers` with `price` +
  `priceCurrency` + `availability`.
- **Recommended:** `aggregateRating`/`review` (only with genuine on-page reviews), `brand`, `sku`.

## BreadcrumbList

```json
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Blog", "item": "https://example.com/blog" },
    { "@type": "ListItem", "position": 2, "name": "Core Web Vitals", "item": "https://example.com/blog/core-web-vitals" }
  ]
}
```

## Organization / WebSite (entity signals)

These corroborate *who you are* for both Google's Knowledge Graph and AI engines.

```json
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Example",
  "url": "https://example.com",
  "logo": "https://example.com/logo.png",
  "sameAs": [
    "https://www.linkedin.com/company/example",
    "https://github.com/example"
  ]
}
```

## DEAD types — never ship these for rich results

Shipping any of these renders nothing and is dead markup. Verify.sh fails the build if it
finds one.

| Dead `@type` | Status |
|---|---|
| `FAQPage` | Rich results restricted to health/gov since late 2023; **full deprecation May 7 2026**, API removed Aug 2026 |
| `Course` (Course Info rich result) | Retired **June 2025** |
| `ClaimReview` | Retired June 2025 |
| `SpecialAnnouncement` | Retired June 2025 |
| `VehicleListing` | Retired June 2025 |
| `EstimatedSalary` | Retired June 2025 |
| `LearningVideo` | Retired June 2025 |
| Book Actions | Retired June 2025 |

**Do instead:** for FAQ content, keep the questions and answers as **visible prose** on
the page (answer-first, the GEO levers still apply) — you simply do not wrap them in
FAQPage markup. The content stays; only the dead schema goes.

`HowTo` is also no longer eligible for the rich result on most surfaces — treat it as
display-only, not a visibility play.

## Validation step (always)

1. Paste the rendered page into the **Rich Results Test** (search.google.com/test/rich-results)
   — confirms eligibility for a specific rich result.
2. Paste into **validator.schema.org** — confirms the markup is well-formed schema.org.
3. Reject the block if either reports a dead/unsupported type or a missing required prop.
