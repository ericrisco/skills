# PHP quality toolchain — full configs

Offloaded from SKILL.md. Drop-in configs for PHPStan, Pint / PHP-CS-Fixer, Rector,
PHPUnit / Pest, the composer `scripts` block, and a CI snippet. Versions per the
2025-2026 baseline: PHPStan 2.x, Rector 2.x, PHPUnit 12, Pest 4, Composer 2.8.x.

## phpstan.neon — level max

```neon
parameters:
    level: max
    paths:
        - src
        - tests
    # Tighten the screws beyond plain "max".
    checkMissingIterableValueType: true
    checkGenericClassInNonGenericObjectType: true
    treatPhpDocTypesAsCertain: true
    reportUnmatchedIgnoredErrors: true
    # Add a baseline only to freeze legacy debt, never as a default crutch:
    # includes:
    #     - phpstan-baseline.neon
```

Run: `vendor/bin/phpstan analyse`. Generate a baseline once when adopting on a legacy code
base: `vendor/bin/phpstan analyse --generate-baseline`, then drive it to empty over time.

## Style: Pint (preferred) or PHP-CS-Fixer

Pint is the zero-config formatter; point it at PER-CS. `pint.json`:

```json
{
    "preset": "per",
    "rules": {
        "declare_strict_types": true,
        "ordered_imports": { "sort_algorithm": "alpha" },
        "no_unused_imports": true,
        "global_namespace_import": { "import_classes": true, "import_functions": false }
    }
}
```

Run: `vendor/bin/pint --test` (check, read-only) in CI; `vendor/bin/pint` to fix locally.

If you prefer PHP-CS-Fixer, `.php-cs-fixer.dist.php`:

```php
<?php

declare(strict_types=1);

$finder = PhpCsFixer\Finder::create()->in([__DIR__ . '/src', __DIR__ . '/tests']);

return (new PhpCsFixer\Config())
    ->setRiskyAllowed(true)
    ->setRules([
        '@PER-CS'              => true,
        'declare_strict_types' => true,
        'no_unused_imports'    => true,
        'ordered_imports'      => ['sort_algorithm' => 'alpha'],
    ])
    ->setFinder($finder);
```

Run: `vendor/bin/php-cs-fixer fix --dry-run --diff` (check) / drop the flags to fix.

## rector.php — automated upgrades

```php
<?php

declare(strict_types=1);

use Rector\Config\RectorConfig;
use Rector\Set\ValueObject\LevelSetList;

return RectorConfig::configure()
    ->withPaths([__DIR__ . '/src', __DIR__ . '/tests'])
    ->withPhpSets(php84: true)          // bump to the runtime you target
    ->withPreparedSets(
        deadCode: true,
        codeQuality: true,
        typeDeclarations: true,
    );
```

Run: `vendor/bin/rector process --dry-run` to preview, then drop `--dry-run`. Always read
the diff — Rector rewrites real code.

## Tests: PHPUnit 12 or Pest 4

`phpunit.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         colors="true"
         failOnWarning="true"
         failOnRisky="true">
    <testsuites>
        <testsuite name="default">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
</phpunit>
```

Pest 4 runs on top of PHPUnit 12 and reads the same `phpunit.xml`. A test reads:

```php
<?php

declare(strict_types=1);

it('parses a known currency', function (): void {
    expect(Currency::tryFrom('EUR'))->toBe(Currency::EUR);
});
```

Run: `vendor/bin/pest` or `vendor/bin/phpunit`.

## composer scripts — one gate

```json
{
    "scripts": {
        "lint":  "pint --test",
        "stan":  "phpstan analyse",
        "rector":"rector process --dry-run",
        "test":  "pest",
        "check": ["@lint", "@stan", "@test"]
    },
    "scripts-descriptions": {
        "check": "Run style, static analysis, and tests — the full local gate."
    }
}
```

`composer check` is the local equivalent of CI. Match the two so a green local run means a
green pipeline.

## CI snippet (GitHub Actions)

```yaml
name: ci
on: [push, pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          coverage: none
      - run: composer validate --strict
      - run: composer install --no-interaction --prefer-dist
      - run: composer check
```

Pipeline authoring as a discipline belongs to the **github-actions** / **deployment** skills;
this snippet is only the PHP-gate wiring.
