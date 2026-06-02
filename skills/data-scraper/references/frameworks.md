# Frameworks reference

Copy-paste resilient starters. Match the tool to the site profile from the picker in `../SKILL.md`. Every starter assumes the legal gate already passed.

## Crawlee (Python) — resilient recurring crawler

Default for recurring jobs that must not break. The `RequestQueue` is disk-persisted, so a crash resumes from where it stopped. Per-host concurrency and pacing are config, not hand-rolled.

```python
import asyncio
from crawlee.crawlers import PlaywrightCrawler, PlaywrightCrawlingContext

crawler = PlaywrightCrawler(
    max_requests_per_crawl=10_000,
    max_request_retries=4,                 # retries use backoff internally
    concurrency_settings={"max_concurrency": 4},  # cap per run; pace per host below
    request_handler_timeout_secs=45,
)

@crawler.router.default_handler
async def handle(ctx: PlaywrightCrawlingContext) -> None:
    title = await ctx.page.text_content('[data-testid="listing-card"] h2')
    if not title:
        raise LookupError(f"required field 'title' missing at {ctx.request.url}")  # fail loud
    await ctx.push_data({                  # idempotent: keyed on url downstream
        "url": ctx.request.url,
        "title": title.strip(),
    })
    await ctx.enqueue_links(selector='a[href^="/listing/"]')  # follow only listing links

async def main() -> None:
    # seed from sitemap, not a blind crawl
    await crawler.run(["https://example.com/sitemap.xml"])

if __name__ == "__main__":
    asyncio.run(main())
```

Why Crawlee for new resilient work: it wraps Playwright, rotates proxies, ships browserforge fingerprints, and the queue resumes after a crash — all the resilience patterns from `../SKILL.md` come built in instead of hand-rolled.

## Playwright direct — one-off SPA scrape

When the job is one-shot and a full crawler is overkill, but the data only exists after JS runs.

```python
import asyncio, random
from playwright.async_api import async_playwright

async def scrape(urls: list[str]) -> list[dict]:
    out = []
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context(locale="en-US")
        for url in urls:
            page = await ctx.new_page()
            await page.goto(url, wait_until="networkidle", timeout=30_000)
            title = await page.text_content('[data-testid="listing-card"] h2')
            if not title:
                raise LookupError(f"required field 'title' missing at {url}")
            out.append({"url": url, "title": title.strip()})
            await page.close()
            await asyncio.sleep(random.uniform(1.0, 3.0))  # 1-3s per host, jittered
        await browser.close()
    return out
```

## Scrapy — pure-Python static, AUTOTHROTTLE

Legacy/static targets. AUTOTHROTTLE adapts the delay to the host's response latency instead of a fixed sleep.

```python
# settings.py
ROBOTSTXT_OBEY = True               # honor robots.txt, non-negotiable
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 1.0      # seconds
AUTOTHROTTLE_MAX_DELAY = 10.0
AUTOTHROTTLE_TARGET_CONCURRENCY = 2.0   # keep it low, per host
CONCURRENT_REQUESTS_PER_DOMAIN = 4
DOWNLOAD_DELAY = 1.0
RETRY_ENABLED = True
RETRY_TIMES = 3                     # Scrapy backs off between retries
DEFAULT_REQUEST_HEADERS = {"Accept-Language": "en-US,en;q=0.9"}
HTTPCACHE_ENABLED = True            # conditional-GET style caching on re-crawl
```

Pick Scrapy only for an existing Scrapy codebase or pure static targets — its Twisted core lags the asyncio ecosystem, so new resilient work goes to Crawlee.

## httpx + selectolax — static, no fingerprint wall

Cheapest path when the HTML is server-rendered and the host does not fingerprint.

```python
import time, random, httpx
from selectolax.parser import HTMLParser

def scrape(urls: list[str], headers: dict) -> list[dict]:
    out = []
    with httpx.Client(headers=headers, timeout=20, follow_redirects=True) as c:
        for url in urls:
            r = c.get(url)
            if r.status_code == 429:                       # honor Retry-After
                time.sleep(int(r.headers.get("Retry-After", "30")))
                r = c.get(url)
            r.raise_for_status()
            tree = HTMLParser(r.text)
            node = tree.css_first('[data-testid="listing-card"] h2')
            if node is None:
                raise LookupError(f"required field 'title' missing at {url}")
            out.append({"url": url, "title": node.text(strip=True)})
            time.sleep(random.uniform(1.0, 3.0))           # 1-3s per host
    return out
```

If this starts returning 403 while a browser returns 200, swap `httpx` for `curl_cffi` with `impersonate="chrome131"` (see `anti-bot.md`).

Sources: crawlee.dev/python changelog; npmjs.com/package/playwright & pypi.org/project/playwright (1.60.0; 1.59 shipped 2026-04-01); use-apify.com "Crawlee vs Scrapy vs BeautifulSoup 2026". All accessed 2026-06-02.
