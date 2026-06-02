# Anti-bot reference

Anti-bot handling is mandatory in 2026, not optional — basic Puppeteer worked in 2024, but every major site now ships detection. This covers the *legitimate* techniques: realistic fingerprints and pacing on a scrape you are entitled to run. It does **not** cover defeating a control you were shown — that is the legal line from `legal-compliance.md`, and you do not cross it.

## TLS / JA3 fingerprinting with curl_cffi

Many blocks key on the TLS/JA3/HTTP2 fingerprint, not the User-Agent. A real Chrome handshake looks different from a Python `requests` handshake regardless of headers, so spoofing the UA alone fails. `curl_cffi` impersonates a real browser's full fingerprint.

```python
from curl_cffi import requests

# impersonate="chrome131" sends Chrome's real TLS/JA3 + HTTP2 fingerprint
r = requests.get(
    "https://example.com/listings",
    impersonate="chrome131",
    timeout=20,
)
r.raise_for_status()
html = r.text
```

Use this the moment a static target returns 403 to `httpx` but 200 in a real browser — that gap is almost always fingerprinting.

## Realistic header set

Send a full, current browser header set, not a lone User-Agent. A bare `python-requests/2.x` UA is an instant tell.

```python
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/131.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Accept-Encoding": "gzip, deflate, br",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Upgrade-Insecure-Requests": "1",
}
```

Keep the UA current — a stale Chrome version is its own tell. Refresh it when the major version moves.

## Playwright launch config

```python
from playwright.async_api import async_playwright

async def fetch(url: str) -> str:
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context(
            user_agent=HEADERS["User-Agent"],
            locale="en-US",
            viewport={"width": 1366, "height": 768},
        )
        page = await ctx.new_page()
        await page.goto(url, wait_until="networkidle", timeout=30_000)
        html = await page.content()
        await browser.close()
        return html
```

For scale, prefer Crawlee's `AdaptivePlaywrightCrawler` with browserforge fingerprints over hand-rolled stealth — it picks the cheapest mode (HTTP vs browser) per request and ships coherent fingerprints. See `frameworks.md`.

## Proxy taxonomy — when each is justified

Proxies distribute IP load and resolve geo-gating on a scrape you are entitled to run. They are not for evading a block you were explicitly shown.

| Type | Cost | Justified when |
|------|------|----------------|
| Datacenter | Lowest | High-volume scrape of a permissive target; easiest to detect/block |
| Residential | Medium | Geo-gated content; target blocks datacenter ranges but permits the scrape |
| Mobile | Highest | Mobile-only content or the strictest IP reputation requirements |

Rule: reach for a proxy to spread load or reach a geo, never to defeat a hard block. The latter is circumvention.

## CAPTCHA — the line you do not cross

A CAPTCHA is the site explicitly saying "prove you are human or do not proceed." Routing it to a solver service to keep scraping is circumventing a shown access control — exactly the posture at issue in *Reddit v. Perplexity AI* (2025), and the worst place to be legally.

When you hit a CAPTCHA or a hard block: **stop.** Re-run the legal gate. Slow down, narrow the path set, or seek permission/an API. Do not solve it.

Sources: brightdata.com "Web Scraping With curl_cffi 2026"; curl-cffi.readthedocs.io; dataresearchtools.com TLS mimicry 2026; crawlee.dev/python docs. All accessed 2026-06-02.
