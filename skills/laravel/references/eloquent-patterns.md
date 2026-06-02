# Eloquent patterns (deep dive)

Offloaded depth from SKILL.md §Eloquent. The non-negotiables (`$fillable` allowlist, eager
loading to kill N+1) live in the body; this file is the catalog you reach for when a
relationship, scope, or cast gets non-trivial.

## Relationship catalog

| Relationship | Method | Use when |
|---|---|---|
| One-to-one | `hasOne` / `belongsTo` | a user has one profile |
| One-to-many | `hasMany` / `belongsTo` | a post has many comments |
| Many-to-many | `belongsToMany` (pivot table) | posts ↔ tags |
| Has-many-through | `hasManyThrough` | a country's posts via its users |
| Polymorphic one-to-many | `morphMany` / `morphTo` | comments on posts *and* videos |
| Polymorphic many-to-many | `morphToMany` / `morphedByMany` | tags on posts *and* videos |

```php
// Polymorphic: one Comment model attaches to many parent types.
class Comment extends Model {
    public function commentable(): MorphTo { return $this->morphTo(); }
}
class Post extends Model {
    public function comments(): MorphMany { return $this->morphMany(Comment::class, 'commentable'); }
}
```

Pivot tables: name the table alphabetically (`post_tag`, singular), or set `->using()` for a
custom pivot model when the pivot carries its own columns/casts. Use `withPivot('role')` and
`withTimestamps()` to surface extra pivot columns.

## Eager loading strategies

| Strategy | API | When |
|---|---|---|
| Eager load | `Model::with('rel')->get()` | you know up front you need the relation |
| Nested | `with('posts.comments')` | load a relation of a relation in one go |
| Constrained | `with(['posts' => fn ($q) => $q->where('published', true)])` | only some related rows |
| Lazy eager | `$collection->load('rel')` | you already have the models and decided you need it |
| Counts only | `withCount('comments')` | you need `comments_count`, not the rows |

Catch N+1 in dev by enabling strict mode so a lazy load throws instead of silently
fanning out:

```php
// AppServiceProvider::boot()
Model::preventLazyLoading(! app()->isProduction());
```

## Scopes

```php
// Global scope: applied to every query for the model (e.g. multi-tenant isolation).
class Post extends Model {
    protected static function booted(): void {
        static::addGlobalScope('published', fn (Builder $q) => $q->where('published', true));
    }

    // Local scope: opt-in, chainable.
    public function scopeForUser(Builder $q, User $u): Builder {
        return $q->where('user_id', $u->id);
    }
}

Post::forUser($user)->get();
Post::withoutGlobalScope('published')->get();   // escape hatch when you need drafts
```

## Observers & model events

Observers centralize lifecycle hooks (`creating`, `updated`, `deleting`) instead of
scattering them. Register in a service provider.

```php
class OrderObserver {
    public function creating(Order $order): void { $order->reference ??= Str::ulid(); }
    public function deleting(Order $order): void { $order->lineItems()->delete(); }
}
// AppServiceProvider::boot(): Order::observe(OrderObserver::class);
```

Keep observers thin and synchronous-cheap. Heavy work (emails, external calls) belongs in a
queued job dispatched from the observer, not in the hook itself.

## Casts

| Cast | Maps | Note |
|---|---|---|
| `'datetime'` | column ↔ `Carbon` | add a format: `'datetime:Y-m-d'` |
| `EnumName::class` | column ↔ backed enum | invalid DB value throws — keep the column constrained |
| `'array'` / `'collection'` | json text ↔ array/Collection | the DB column is `json` |
| `'encrypted'` / `'encrypted:array'` | plaintext ↔ at-rest ciphertext | uses the app key; rotating the key breaks old rows |
| `'hashed'` | plaintext ↔ bcrypt on set | for password columns |
| `AsStringable::class` | string ↔ `Stringable` | fluent string ops |

Use the L11+ `casts()` **method**, not the legacy `protected $casts = []` array.

### Custom casts & value objects

```php
// A custom cast turns a column into a value object both ways.
class MoneyCast implements CastsAttributes {
    public function get($model, string $key, $value, array $attrs): Money {
        return new Money((int) $value);   // cents -> value object
    }
    public function set($model, string $key, $value, array $attrs): array {
        return [$key => $value instanceof Money ? $value->cents() : $value];
    }
}
// casts(): ['price' => MoneyCast::class]
```

## Accessors & mutators (the Attribute class)

The modern form is one `Attribute`-returning method, not the old `getXAttribute`/`setXAttribute` pair:

```php
protected function fullName(): Attribute {
    return Attribute::make(
        get: fn ($value, array $attrs) => "{$attrs['first_name']} {$attrs['last_name']}",
    )->shouldCache();   // cache a computed accessor that is hit repeatedly
}
```

A `set` closure on the same `Attribute` handles the write side. Prefer this over the legacy
magic-method accessors — it is the form current Laravel generates and documents.
