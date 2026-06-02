# WordPress hardening

The full baseline behind the SKILL.md security section. Apply top-down; each item closes a real attack path.

## wp-config.php constants

```php
// Block code edits from the dashboard entirely
define( 'DISALLOW_FILE_EDIT', true );   // no Theme/Plugin code editor
define( 'DISALLOW_FILE_MODS', true );   // also no install/update from UI (lock managed hosts)

// Transport & cookies
define( 'FORCE_SSL_ADMIN', true );

// Updates — keep minor/security patches automatic
define( 'WP_AUTO_UPDATE_CORE', 'minor' );

// Move wp-config one level above webroot when the host allows it.
```

Regenerate the salt keys (`AUTH_KEY`, `SECURE_AUTH_KEY`, `LOGGED_IN_KEY`, `NONCE_KEY` and their salts) from `https://api.wordpress.org/secret-key/1.1/salt/`. These are the only "secrets" that belong in `wp-config.php`. Never commit a real `wp-config.php` with live values — ship a `wp-config-sample.php` and inject via environment on deploy.

## File permission matrix

| Target | Mode | Note |
| --- | --- | --- |
| Directories | `755` | `find . -type d -exec chmod 755 {} \;` |
| Files | `644` | `find . -type f -exec chmod 644 {} \;` |
| `wp-config.php` | `600` (or `640`) | readable only by the web user |
| `wp-content/uploads` | `755`, no PHP execution | block `*.php` there |

The web server user should own files but not be able to write to core/theme/plugin dirs in production — write access is what turns a single upload bug into RCE.

## Block PHP execution in uploads

nginx:

```nginx
location ~* /wp-content/uploads/.*\.php$ { deny all; }
```

Apache (`wp-content/uploads/.htaccess`):

```apache
<FilesMatch "\.php$">
  Require all denied
</FilesMatch>
```

## Security headers

nginx:

```nginx
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
```

## Login & account hardening

- Enforce strong passwords and a 2FA/passkey plugin; WP 6.8 introduced bcrypt password hashing so legacy hashes are upgraded transparently on next login.
- Rate-limit `wp-login.php` (fail2ban, host WAF, or a lockout plugin). Brute force is the most common automated attack.
- Never ship a user literally named `admin`. Use least-privilege roles; editors do not need `manage_options`.

## Application Passwords (machine auth)

For REST/API access — a headless front end, CI, an integration — issue an Application Password (WP 5.6+) per consumer:

```bash
wp user application-password create admin "ci-deploy" --porcelain
```

They are individually revocable, do not grant `wp-login.php` access, and bypass interactive 2FA for machines. Send as HTTP Basic over TLS:

```bash
curl --user 'admin:xxxx xxxx xxxx xxxx xxxx xxxx' https://example.com/wp-json/wp/v2/posts
```

Revoke from Users → Profile → Application Passwords (or `wp user application-password delete`) when a consumer is retired.

## Reduce attack surface

```php
// Stop user enumeration via the REST users endpoint for anonymous callers
add_filter( 'rest_endpoints', function ( $endpoints ) {
	unset( $endpoints['/wp/v2/users'], $endpoints['/wp/v2/users/(?P<id>[\d]+)'] );
	return $endpoints;
} );

// Remove version disclosure
remove_action( 'wp_head', 'wp_generator' );
```

Disable XML-RPC unless something genuinely needs it (`add_filter('xmlrpc_enabled','__return_false')`) — it is a pingback-amplification and brute-force vector. Block `/xmlrpc.php` at the server when fully unused.

## Update discipline

2024 logged 7,966 new ecosystem vulnerabilities (+34% YoY); nearly all exploited installs were running a known-vulnerable plugin/theme. The cheapest defense is patching:

```bash
wp core update && wp core update-db
wp plugin update --all
wp theme update --all
```

Automate via cron + a staging smoke test before production.
