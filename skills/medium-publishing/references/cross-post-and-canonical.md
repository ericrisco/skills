# Cross-posting & canonical — deep reference

Detail for the import tool, manual canonical, and the static-HTML workaround for stubborn imports. The SKILL.md body covers the happy path; come here when the import fails or you need the exact UI walkthrough.

## Import tool — step by step

1. Go to **New story -> import icon**, or directly to `https://medium.com/p/import`.
2. Paste the **original article URL** (the one on your own site).
3. Click **Import**. Medium crawls the page and creates a draft.
4. What it sets automatically:
   - **Canonical link** -> the URL you pasted (your origin keeps SEO credit).
   - **Publish date** -> backdated, read from the page's `article:published_time` meta tag.
5. Review the draft for formatting drift (see the formatting gotchas in SKILL.md), set up to 5 tags, then **Publish**.

The import is a one-time content copy plus metadata. Editing the Medium draft afterward does not sync back to your site, and vice versa.

## Manual canonical link — exact UI path

Use this when you drafted natively in Medium, or after a failed import where you pasted the body manually.

1. Open the story in the editor (draft or published).
2. Click **More options (•••)** in the top bar.
3. **Story settings** -> the advanced/edit settings panel.
4. Find **"Customize canonical link"**, paste the **origin URL**, save.
5. Publish (or update if already published).

This is per-story. There is no account-wide canonical default. The canonical must always point at the *original* location, never at the Medium story itself.

Manual paste does **not** backdate. If the date matters, the import tool is the only path that backdates automatically; otherwise the Medium publish date is "now".

## Static-HTML workaround for stubborn imports

When the importer can't crawl your real page (JS-only rendering, bot wall, login wall, timeout), give it a clean page it *can* read:

1. Export the article to a single static HTML file — content in the initial server markup (no client-side hydration required).
2. Include both metadata tags the importer relies on:

```html
<link rel="canonical" href="https://mysite.com/original-post" />
<meta property="article:published_time" content="2026-04-12T09:00:00Z" />
```

3. Host it at a public, anonymously reachable URL (a temporary path is fine).
4. Run the import against **that** URL. Canonical and backdate come from the tags above, so they still point at your real origin and your real date.
5. Once the Medium draft exists with correct metadata, you can take the temporary static page down.

The canonical in the static page should still be your *real* origin URL, not the temporary static page — that's what search engines will credit.

## HTTP error -> cause -> fix matrix

| HTTP / symptom | Root cause | Fix |
|---|---|---|
| 400 | Malformed/redirecting URL, or required page metadata absent | Use the final canonical URL; confirm `<link rel="canonical">` and `article:published_time` present |
| 404 | Page not reachable for the crawler (private, moved, geo/IP-blocked) | Make it publicly reachable, or use the static-HTML workaround |
| 403 | Bot-blocking — WAF, Cloudflare challenge, login/paywall | Allowlist the crawler, serve a clean static copy, or paste natively + set canonical manually |
| 500 | Origin server error during crawl | Retry; if persistent, serve a lightweight static version |
| 504 | Crawl timeout — heavy JS, slow TTFB | Provide a fast static HTML version with content in initial markup |
| Imports but body empty/garbled | Content rendered client-side only | Static HTML with the article text in the server-rendered markup |
| Catch-all "couldn't import" | Any of the above combined | Fall back to native paste + manual "Customize canonical link" |

## Verify a cross-post

- View source / story settings on the published Medium story; confirm canonical resolves to the origin URL.
- Confirm the displayed publish date matches the original.
- Confirm <=5 tags, code blocks intact, no broken tables.
