# Localization & dependency hygiene (deep dive)

Back to [`../SKILL.md`](../SKILL.md).

Two production concerns the rest of the skill only touches: localizing the app (ARB
files, ICU plurals/genders, RTL, locale-aware number/date/currency formatting) and keeping
the dependency tree healthy (pub points, outdated audits, and `melos`/`package:`
encapsulation in a workspace). Targets **Flutter 3.44 / Dart 3.12**.

## Localization (l10n)

Flutter's first-party path is `flutter_localizations` + the `intl`-backed `gen_l10n` tool —
no third-party package needed. Turn it on in `pubspec.yaml` and add an `l10n.yaml`:

```yaml
# pubspec.yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any            # version is pinned by the Flutter SDK constraint

flutter:
  generate: true       # enables ARB -> Dart codegen on build
```

```yaml
# l10n.yaml  (project root)
arb-dir: lib/src/common/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

One ARB file per locale. The template (`app_en.arb`) carries the `@`-metadata; translations
omit it:

```json
// lib/src/common/l10n/app_en.arb
{
  "@@locale": "en",
  "helloUser": "Hello, {name}!",
  "@helloUser": {
    "description": "Greeting on the home screen",
    "placeholders": { "name": { "type": "String" } }
  },
  "cartItems": "{count, plural, =0{Your cart is empty} =1{1 item} other{{count} items}}",
  "@cartItems": {
    "placeholders": { "count": { "type": "int" } }
  },
  "lastSeen": "Last seen {when}",
  "@lastSeen": {
    "placeholders": { "when": { "type": "DateTime", "format": "yMMMd" } }
  }
}
```

```json
// lib/src/common/l10n/app_es.arb
{
  "@@locale": "es",
  "helloUser": "¡Hola, {name}!",
  "cartItems": "{count, plural, =0{Tu carrito está vacío} =1{1 artículo} other{{count} artículos}}",
  "lastSeen": "Visto por última vez {when}"
}
```

Wire the generated delegate into `MaterialApp` and read strings through `context`:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // home, router, theme...
);

// In a widget — type-safe, no string keys at the call site:
final l10n = AppLocalizations.of(context);
Text(l10n.helloUser('Ada'));        // "Hello, Ada!"
Text(l10n.cartItems(count));        // ICU plural picks the right arm
```

### ICU plurals & genders

Use ICU `plural` (and `select` for gender) inside the ARB string, never an `if (count == 1)`
ladder in Dart — only the message author knows that Polish has three plural forms and Arabic
six. The `gen_l10n` tool compiles the ICU form into a locale-aware selector:

```json
"unreadCount": "{count, plural, =0{No new messages} =1{One new message} other{{count} new messages}}",
"invitedBy": "{gender, select, female{She invited you} male{He invited you} other{They invited you}}"
```

### RTL

Arabic/Hebrew/Persian flip the layout. Two rules:

- Use **direction-agnostic** geometry everywhere: `EdgeInsetsDirectional.only(start: 16)` (not
  `EdgeInsets.only(left: 16)`), `AlignmentDirectional.centerStart`, `PositionedDirectional`.
  Flutter then mirrors the layout automatically under an RTL locale.
- Mirror directional icons (a back chevron, a "send" arrow) but **never mirror logos, media
  controls, or numbers**:

```dart
Icon(Icons.arrow_back, textDirection: Directionality.of(context)); // flips in RTL
const Icon(Icons.play_arrow);                                      // must NOT flip
```

Test RTL by forcing the locale or wrapping a widget under test in
`Directionality(textDirection: TextDirection.rtl, child: ...)`.

### Locale-aware formatting

Never hand-format a number, date, or currency — `intl`'s `NumberFormat`/`DateFormat` read the
ambient locale so a German user sees `1.234,56 €` and a US user `$1,234.56` from the same code:

```dart
import 'package:intl/intl.dart';

final locale = Localizations.localeOf(context).toString();
NumberFormat.currency(locale: locale, name: 'EUR').format(1234.56); // 1.234,56 € (de) | €1,234.56 (en)
NumberFormat.decimalPattern(locale).format(1234567);                // 1.234.567 | 1,234,567
DateFormat.yMMMd(locale).format(DateTime.now());                    // 1. Juni 2026 | Jun 1, 2026
```

Initialize date-symbol data once at startup if you format dates before the first
`Localizations` is in scope: `await initializeDateFormatting()`.

## Dependency hygiene

### pub points & package health

Every package on pub.dev gets a **pub points** score (max 160) covering Dart conventions,
documentation, platform support, up-to-date dependencies, and static-analysis cleanliness.
Before adding a dependency, check its score, popularity, and last-publish date on its pub.dev
page. Run the same analysis locally against your own package before publishing or in CI:

```bash
dart pub global activate pana
dart pub global run pana --no-warning .   # scores your package the way pub.dev does
```

Prefer a first-party or widely-adopted package over a thin wrapper; every dependency is
attack surface and a future migration cost.

### Auditing for outdated & insecure deps

`flutter pub outdated` shows what is behind, distinguishing resolvable upgrades from those
blocked by a constraint:

```bash
flutter pub outdated                 # table: Current / Upgradable / Resolvable / Latest
flutter pub upgrade --major-versions # rewrites pubspec constraints to allow the latest majors
```

Columns to read: **Upgradable** is reachable under your current constraints (`pub upgrade`
gets it); **Resolvable** needs a constraint bump; **Latest** may need a breaking migration.
Keep `pubspec.lock` committed for apps (reproducible builds) and gitignored for published
libraries. Audit on a cadence, not all-at-once before a release.

### Workspace encapsulation with melos

In a multi-package repo (a `packages/` workspace, or the Dart 3.6+ native `pub workspaces`),
**melos** orchestrates bootstrap, versioning, and running a script across every package:

```yaml
# melos.yaml
name: my_app_workspace
packages:
  - apps/**
  - packages/**

scripts:
  analyze: { run: dart analyze, exec: { concurrency: 5 } }
  test:    { run: flutter test, exec: { failFast: true } }
```

```bash
dart pub global activate melos
melos bootstrap   # resolves + path-links every local package (a.k.a. `melos bs`)
melos run test    # runs the script in each package
```

`package:` encapsulation is the discipline that makes the workspace pay off: a feature package
exposes only its public surface through `lib/<package>.dart` and hides internals under
`lib/src/`. Other packages import `package:feature_cart/feature_cart.dart` and **never** reach
into `package:feature_cart/src/...`. Enforce it with a lint:

```yaml
# analysis_options.yaml
linter:
  rules:
    - implementation_imports   # forbids importing another package's lib/src
```

This keeps the dependency graph a DAG of public APIs — the same inward-pointing discipline as
the per-feature `presentation → domain ← data` layering, applied at package granularity.
