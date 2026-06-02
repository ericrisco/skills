# WooCommerce

The store layer behind the SKILL.md WooCommerce section. WordPress owns the back end; a Shopify store is a different platform (the `shopify` sibling).

## HPOS (High-Performance Order Storage)

Since WooCommerce 8.2, **HPOS is the default order datastore for new installs**. Orders, order items, and metadata move out of `wp_posts`/`wp_postmeta` into dedicated `wc_orders*` tables — fewer joins, faster queries, no autoload bloat.

Three states matter:
1. **Legacy posts storage** — orders in `wp_posts` (old sites).
2. **Compatibility mode** — writes to both stores, keeps them in sync (safe interim during migration).
3. **HPOS authoritative** — custom tables are the source of truth.

## Enable / migrate / verify (WP-CLI)

```bash
# Inspect current state
wp wc cot status

# Turn on custom order tables
wp wc hpos enable

# Backfill existing orders into the new tables (idempotent; re-runnable)
wp wc cot sync

# Verify parity before making HPOS authoritative
wp wc cot verify_cot_data

# Only after a clean verify: flip authority and (optionally) stop syncing legacy
```

Always `wp db export` before migrating a production store. Run `sync` and `verify_cot_data` again after the final plugin updates to catch drift.

## Plugin compatibility declaration

A plugin that reads or writes orders **must** declare HPOS compatibility or WooCommerce will disable it when HPOS is authoritative:

```php
add_action( 'before_woocommerce_init', function () {
	if ( class_exists( \Automattic\WooCommerce\Utilities\FeaturesUtil::class ) ) {
		\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility(
			'custom_order_tables', __FILE__, true
		);
	}
} );
```

Then stop using `WP_Query`/`get_post_meta` for orders. Use the CRUD API — `wc_get_orders()`, `wc_get_order( $id )`, `$order->get_meta()` / `$order->update_meta_data()` / `$order->save()` — which works against whichever datastore is active.

## Store setup checklist

- General: store address, currency, selling/shipping locations.
- Products: product types (simple/variable/grouped), tax classes, stock management.
- Payments: a gateway with a tested webhook path; never store raw card data.
- Checkout: use the **block-based Cart/Checkout blocks** (the modern default) over the classic shortcodes for new stores.
- Tax & shipping zones configured before launch; test a real end-to-end order in staging.
- Emails: verify transactional order emails actually deliver (sender domain, SPF/DKIM).

## Store-specific CLI

```bash
wp wc product list --user=admin
wp wc shop_order list --user=admin     # legacy alias still works in compat mode
wp wc tool run regenerate_product_lookup_tables --user=admin
```
