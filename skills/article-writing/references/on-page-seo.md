# On-page SEO — title/meta tables, slug rules, JSON-LD templates

The full pixel/char detail and copy-ready schema the SKILL.md body points to. Every number is sourced and dated in the spec (accessed 2026-06-02).

## Title tag — char and pixel bands

| Metric | Desktop | Mobile |
| --- | --- | --- |
| Display ceiling | ~580–600 px | ~480 px |
| Practical char band | 50–60 chars | shorter; front-load |
| Rewritten least often | 51–55 chars | — |
| Keyword position | first ~30–35 chars | first ~30–35 chars |

Notes:

- Google rewrites titles ~33–40% of the time overall; the 51–55 char band is rewritten *least*. Stay in it.
- Pixel width varies by character (an `m` is wide, an `i` is narrow), so the char band is a proxy — if the title is title-case with many wide caps, lean toward 50–55.
- Front-load the primary keyword. A title that buries the keyword past char 35 risks truncation cutting it off on mobile.
- One title per page. The `<title>` tag and the on-page H1 may differ; the H1 can be longer and more human.

## Meta description — char and pixel bands

| Metric | Desktop | Mobile |
| --- | --- | --- |
| Display ceiling | ~920 px ≈ 158 chars | ~680 px ≈ 120 chars |
| Practical char band | 140–160 chars | front-load value in first ~120 |
| Sentences | 1–3 | 1–2 |

Notes:

- The meta description does **not** rank directly, but it drives click-through and is frequently the snippet AI engines echo verbatim. Treat it as ad copy for the result.
- Lead with the value/answer, not a windup. Include the primary keyword once, naturally (Google bolds matched terms).
- If you write past 160 chars, write so the first ~120 stand alone — that is what mobile shows.

## Slug rules

- Lowercase, words hyphen-separated, ASCII.
- 3–5 meaningful words; drop stop words (`the`, `a`, `to`, `your`, `how`) unless they carry meaning.
- Keyword-bearing and stable — do not change a published slug without a 301 redirect.
- Bad: `/how-to-start-composting-in-your-apartment-today` → Good: `/compost-in-apartment`.
- No dates or volatile params in evergreen slugs (`/standing-desk-guide`, not `/2026/03/standing-desk-guide-v2`).

## Worked answer-first ledes

Pattern: **state the answer in sentence 1–2, qualify in 3–4, signpost what follows.**

Query: *how to choose a standing desk*

> The best standing desk for most people is an electric sit-stand desk with a 70–120 cm height range, a dual motor, and at least 100 kg lift capacity. Pick by adjustment range (match your height), stability at full extension, and warranty (aim 5+ years on the frame). Below: how to size it, what specs actually matter, and the mistakes that waste money.

Query: *is oat milk good for you*

> Oat milk is a reasonable dairy alternative: ~120 kcal and 3 g protein per cup, naturally low in saturated fat, and usually fortified with calcium and B12. It is not ideal if you need high protein or are watching blood sugar (it is higher in carbs than soy or almond milk). Here is how it compares cup-for-cup and who should pick something else.

Both answer the query before the reader scrolls — the requirement for featured snippets and AI Overview extraction.

## JSON-LD templates (JSON-LD only — never microdata)

Embed in a `<script type="application/ld+json">` block in the page `<head>` or body. Use **one** article type per page. The schema must describe what is actually visible on the page.

### Article / BlogPosting

```json
{
  "@context": "https://schema.org",
  "@type": "BlogPosting",
  "headline": "How to Choose a Standing Desk: Specs That Matter",
  "description": "A spec-by-spec guide to choosing a sit-stand desk: height range, motor, lift capacity, stability, and warranty.",
  "image": ["https://example.com/img/standing-desk-guide.jpg"],
  "datePublished": "2026-06-02T08:00:00+01:00",
  "dateModified": "2026-06-02T08:00:00+01:00",
  "author": {
    "@type": "Person",
    "name": "Jordi Vila",
    "url": "https://example.com/author/jordi-vila",
    "jobTitle": "Ergonomics editor"
  },
  "publisher": {
    "@type": "Organization",
    "name": "Example Media",
    "logo": {
      "@type": "ImageObject",
      "url": "https://example.com/logo.png"
    }
  },
  "mainEntityOfPage": {
    "@type": "WebPage",
    "@id": "https://example.com/standing-desk-guide"
  }
}
```

Use `Article` for general/news, `BlogPosting` for blog content. Keep `headline` ≤110 chars. `author` should be a real named `Person` with a `url` to a bio (an E-E-A-T signal). Set `dateModified` honestly on every meaningful edit.

### FAQPage (only when a real FAQ section exists on the page)

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "How much does a good standing desk cost?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "A reliable electric sit-stand desk runs roughly €300–€600. Below that, motors and stability suffer; above it you pay for materials and brand."
      }
    },
    {
      "@type": "Question",
      "name": "Is a standing desk worth it?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Yes if you currently sit all day — alternating sitting and standing reduces reported lower-back discomfort. The benefit comes from movement, not standing all day."
      }
    }
  ]
}
```

### FAQPage eligibility caveat

Google narrowed FAQ rich-result *display* to authoritative government and health sites in 2023; most sites no longer get the visible FAQ rich result in the SERP. **Still ship the `FAQPage` JSON-LD** — it remains valid structured data that AI engines and assistants parse for extraction, and the Q&A structure is exactly what AI Overviews cite. Every `Question`/`Answer` in the schema must match a visible Q&A on the page; schema-only answers not shown to users are a spam signal.

## On-page surface — assembly order

1. Draft the body and FAQ first.
2. Write the title from the H1 (tighter, keyword-front-loaded, 50–60 chars).
3. Write the meta description from the answer-first lede (140–160 chars, value-first).
4. Generate the slug from the primary keyword.
5. Build the `Article`/`BlogPosting` JSON-LD; add `FAQPage` only if a visible FAQ exists.
6. Run `scripts/verify.sh` over the assembled markdown.
