# AI-crawler control (robots.txt, 2026)

AI access to your site is governed by **robots.txt + real on-page authority** — not by
`llms.txt` (Google ignores it; AI bots skip it). The lever that matters is *which
user-agent you allow*, because vendors split their crawlers **by purpose**, and blocking
the wrong one silently removes you from an engine's citations.

## The purpose split

| User-agent | Vendor | Purpose | Block effect |
|---|---|---|---|
| `GPTBot` | OpenAI | Training corpus | Out of training; **still citable** |
| `OAI-SearchBot` | OpenAI | ChatGPT Search index | **Out of ChatGPT Search citations** |
| `ChatGPT-User` | OpenAI | Live user-triggered fetch | No live fetch on user action |
| `ClaudeBot` | Anthropic | Training corpus | Out of training; still citable |
| `Claude-SearchBot` | Anthropic | Search index | Out of Claude search citations |
| `Claude-User` | Anthropic | Live user-triggered fetch | No live fetch |
| `PerplexityBot` | Perplexity | Search index | **Out of Perplexity citations** |
| `Google-Extended` | Google | Gemini/Vertex training opt-out | Out of Google AI training |
| `Googlebot` | Google | Search crawl + **AI Overviews** | Out of Search entirely (see caveat) |
| `Applebot-Extended` | Apple | Apple AI training opt-out | Out of Apple AI training |
| `CCBot` | Common Crawl | Open dataset (feeds many models) | Out of Common Crawl |
| `meta-externalagent` | Meta | Meta AI crawl | Out of Meta AI |

## Caveats that bite

- **Google AI Overviews ride ordinary Googlebot.** `Google-Extended` opts you out of
  Gemini *training* only. There is **no way to opt out of AI Overviews without blocking
  Googlebot — i.e. leaving Google Search.** Do not promise a client "AI Overviews opt-out."
- **Search bot ≠ training bot.** "We blocked GPTBot" does **not** remove you from ChatGPT
  Search citations — that is `OAI-SearchBot`. People routinely block the wrong one.
- **Perplexity circumvention.** Cloudflare reported (Aug 2025) that Perplexity fetched
  pages via undeclared agents after being disallowed. robots.txt is an honor-system
  directive; enforce hard blocks with a WAF/firewall, not just robots.txt, if you truly
  must keep a bot out.

## Template — "cite me, but don't train on me"

Keep search/citation bots in; keep training bots out.

```text
# robots.txt — citation-eligible, training opted out

User-agent: GPTBot
Disallow: /

User-agent: ClaudeBot
Disallow: /

User-agent: CCBot
Disallow: /

User-agent: Google-Extended
Disallow: /

# Search/citation bots: ALLOWED (no Disallow = allowed)
User-agent: OAI-SearchBot
Allow: /

User-agent: PerplexityBot
Allow: /

User-agent: Claude-SearchBot
Allow: /

User-agent: Googlebot
Allow: /

Sitemap: https://example.com/sitemap.xml
```

## Template — "block all AI"

Accepts loss of AI citations. Note this does NOT block Google AI Overviews (that needs
blocking Googlebot, which leaves Search).

```text
# robots.txt — block AI training AND AI search

User-agent: GPTBot
User-agent: OAI-SearchBot
User-agent: ChatGPT-User
User-agent: ClaudeBot
User-agent: Claude-SearchBot
User-agent: Claude-User
User-agent: PerplexityBot
User-agent: CCBot
User-agent: Google-Extended
User-agent: Applebot-Extended
User-agent: meta-externalagent
Disallow: /

# Googlebot left ALLOWED — blocking it would remove you from Search.
User-agent: Googlebot
Allow: /

Sitemap: https://example.com/sitemap.xml
```

## Audit check

If the brief says "we want AI citations," confirm robots.txt does **not** `Disallow: /`
under `OAI-SearchBot`, `PerplexityBot`, `Claude-SearchBot`, or `Googlebot`. A self-blocking
robots.txt is the most common reason a "GEO-optimized" page earns zero citations.
