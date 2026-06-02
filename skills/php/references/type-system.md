# PHP type system — depth

Offloaded from SKILL.md. Patterns and edge cases for enums, docblock generics,
`readonly`/`clone with`, property hooks, and asymmetric visibility. PHP 8.3 floor,
8.4 default, 8.5 features flagged.

## Enums: backed + interface + methods

Enums are first-class types, not class constants. A backed enum maps each case to a scalar;
a pure enum has no backing. Both can implement interfaces and carry methods and constants.

```php
<?php

declare(strict_types=1);

interface HasLabel {
    public function label(): string;
}

enum Priority: int implements HasLabel {
    case Low    = 10;
    case Normal = 20;
    case High   = 30;

    // Methods: behavior travels with the closed set.
    public function label(): string {
        return match ($this) {
            self::Low    => 'Low priority',
            self::Normal => 'Normal',
            self::High   => 'High priority',
        };
    }

    // A static "named constructor" over the raw value.
    public static function fromScore(int $score): self {
        return match (true) {
            $score >= 30 => self::High,
            $score >= 20 => self::Normal,
            default      => self::Low,
        };
    }

    // Enum constants are allowed.
    const Default = self::Normal;
}
```

Parsing rules:

- `Priority::from(20)` returns the case or **throws** `\ValueError` on a bad value.
- `Priority::tryFrom(99)` returns `null` on a bad value — use it for untrusted input.
- `Priority::cases()` returns every case in declaration order — iterate for menus/seeders.
- `$case->value` is the backing scalar; `$case->name` is the case name string.

Comparison is by identity: `$a === Priority::High` (cases are singletons). Never compare
`->value` when you mean the case.

## Docblock generics for PHPStan

The engine has no runtime generics; PHPStan and Psalm read `@template` annotations and
enforce them at analysis time. The runtime type stays `array`/`mixed`.

```php
<?php

declare(strict_types=1);

/**
 * @template TKey of array-key
 * @template TValue
 */
final class TypedMap {
    /** @var array<TKey, TValue> */
    private array $items = [];

    /**
     * @param TKey   $key
     * @param TValue $value
     */
    public function set(int|string $key, mixed $value): void {
        $this->items[$key] = $value;
    }

    /**
     * @param TKey $key
     * @return TValue|null
     */
    public function get(int|string $key): mixed {
        return $this->items[$key] ?? null;
    }

    /** @return list<TValue> */
    public function values(): array {
        return array_values($this->items);
    }
}
```

Useful pseudo-types PHPStan understands: `list<T>` (a 0-indexed sequential array),
`array<K, V>`, `non-empty-array<...>`, `non-empty-string`, `int<0, max>`, `class-string<T>`,
`callable(int): string`. Prefer `list<T>` over `array<int, T>` when the array is a sequence
— it documents and enforces the no-gaps invariant.

`@template T of SomeInterface` bounds the parameter; `@template-covariant` allows variance on
read-only containers. Annotate `@implements`/`@extends` when a class implements a generic
interface so the type flows through.

## readonly rules and the with-er pattern

`readonly` properties are write-once: assignable only from inside the declaring class scope,
and only before they hold a value. A `readonly class` makes every property readonly implicitly.

Constraints to know:

- A readonly property has no default value and must be typed.
- You cannot `unset()` or re-assign it, even inside the class.
- Cloning copies the value, but a plain `clone` then re-assigning a readonly prop in
  `__clone` is **not** allowed before 8.3; from 8.3 you may reinitialize a readonly property
  inside `__clone`. From **8.5**, prefer `clone with`.

```php
<?php

declare(strict_types=1);

final readonly class Point {
    public function __construct(
        public int $x,
        public int $y,
    ) {}

    // Pre-8.5 with-er: build a new instance explicitly.
    public function withX(int $x): self {
        return new self($x, $this->y);
    }
}

// 8.5+: clone with overrides named properties in one expression.
$p2 = clone $p1 with ['x' => 10];   // y is copied, x is replaced
```

## Property hooks — edge cases (8.4+)

A property may declare a `get` hook, a `set` hook, or both. A property with only a `get` hook
and no backing assignment is **virtual** (computed, stores nothing).

```php
<?php

declare(strict_types=1);

final class User {
    // Backed property with a guarded set and a normalizing get.
    public string $email {
        get => strtolower($this->email);
        set (string $value) {
            if (!filter_var($value, FILTER_VALIDATE_EMAIL)) {
                throw new \InvalidArgumentException("invalid email: {$value}");
            }
            $this->email = $value;
        }
    }

    // Virtual: no backing store, recomputed each read.
    public string $domain {
        get => substr($this->email, (int) strpos($this->email, '@') + 1);
    }

    public function __construct(string $email) {
        $this->email = $email; // runs the set hook -> validation
    }
}
```

Gotchas:

- Inside a hook, `$this->email` refers to the backing store, not the hook — no infinite loop
  for a backed property. A **virtual** property (get-only, never assigned) must not reference
  itself.
- Hooks run on **every** access. Do not do I/O, queries, or state mutation in a `get` hook —
  a field read becoming a side effect is a debugging trap. Use a named method instead.
- Hooks are inheritable and can be declared in interfaces (an interface can require a property
  with hooks).
- PHPStan 2.1+ analyzes hooks; older analyzers will misreport them.

## Asymmetric visibility matrix (8.4+)

Read visibility and write (set) visibility are declared independently. Write visibility must
be **equal to or narrower** than read visibility.

| Declaration | Readable from | Writable from |
|---|---|---|
| `public int $n` | anywhere | anywhere |
| `public protected(set) int $n` | anywhere | class + subclasses |
| `public private(set) int $n` | anywhere | declaring class only |
| `protected private(set) int $n` | class + subclasses | declaring class only |
| `private int $n` | declaring class | declaring class |

Use `public private(set)` for the common case: a value object whose fields are read freely
but mutated only through intent-revealing methods (`deposit()`, `rename()`), without writing a
getter for every field.

```php
<?php

declare(strict_types=1);

final class Counter {
    public function __construct(public private(set) int $count = 0) {}
    public function increment(): void { $this->count++; } // only path that writes
}

$c = new Counter();
echo $c->count;   // ok: public read
// $c->count = 5; // Error: write is private(set)
```

`readonly` plus `private(set)` is redundant — `readonly` already forbids writes after init.
Choose `private(set)` when you need controlled mutation, `readonly` when you need none.
