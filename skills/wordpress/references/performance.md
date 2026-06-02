# WordPress performance

The depth behind the SKILL.md performance section. Order matters: measure first, fix the biggest object on the page, then cache.

## Two caches, different jobs

| Cache | Stores | Wins | Tool |
| --- | --- | --- | --- |
| Object cache | DB query results, computed values, transients | repeated/admin requests, logged-in users | Redis or Memcached drop-in |
| Page cache | full rendered HTML responses | anonymous traffic | host page cache, reverse proxy, plugin |

You usually want both. The object cache is what speeds up a slow wp-admin (logged-in, uncacheable pages).

## Redis object cache wiring

Install the Redis PHP extension and a drop-in (e.g. the Redis Object Cache plugin ships `object-cache.php` into `wp-content/`). Configure in `wp-config.php`:

```php
define( 'WP_REDIS_HOST', '127.0.0.1' );
define( 'WP_REDIS_PORT', 6379 );
define( 'WP_REDIS_PREFIX', 'site1:' );   // isolate keys per site on a shared Redis
define( 'WP_CACHE', true );
```

Verify it is actually serving:

```bash
wp redis status
wp cache flush          # after deploys that change cached data
```

## Audit autoloaded options first

When wp-admin crawls, the usual culprit is multi-MB autoloaded options loaded on *every* request (orphaned plugin data, runaway transients). Find offenders:

```sql
SELECT option_name, ROUND(LENGTH(option_value)/1024) AS size_kb
FROM wp_options
WHERE autoload IN ('yes','on','auto')
ORDER BY LENGTH(option_value) DESC
LIMIT 20;
```

Or via CLI:

```bash
wp option list --autoload=on --format=table --fields=option_name,size --orderby=size --order=desc | head -20
```

Set genuinely-not-needed-everywhere options to `autoload = no`, and delete orphaned plugin rows. Clean expired transients: `wp transient delete --expired`.

## Transients

Cache expensive computed data with an expiry; transients use the object cache when one exists, otherwise the DB.

```php
$data = get_transient( 'acme_report' );
if ( false === $data ) {
	$data = build_expensive_report();          // the slow part
	set_transient( 'acme_report', $data, HOUR_IN_SECONDS );
}
```

## Asset discipline

- Per-block CSS via `wp_enqueue_block_style()` — loads only when the block renders.
- Defer non-critical scripts: pass `array( 'strategy' => 'defer' )` (or `'async'`) as the `$args` to `wp_enqueue_script()` (WP 6.3+).
- Concatenate/minify at build time; never ship the dev bundle.
- No inline `<script>`/`<link>` in templates — uncacheable, no dependency graph.

## Speculative loading

WP 6.8 shipped speculative loading (prerender/prefetch on link hover or viewport) and 6.9 refined it. Tune the eagerness/mode rather than installing a separate prefetch plugin; over-eager prerendering wastes bandwidth and can fire analytics prematurely.

## Core Web Vitals, WP-flavored

- **LCP:** the hero is usually a featured image — size it, serve modern formats, and do not lazy-load the above-the-fold image (`fetchpriority="high"`).
- **CLS:** declare image/embed dimensions; reserve space for ad/menu slots.
- **INP:** trim heavy front-end JS from page builders and excess plugins; defer what is not interactive at load.
- Measure with field data, not just lab — a logged-out, cold-cache mobile run is the honest number.
