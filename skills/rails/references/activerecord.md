# ActiveRecord depth

Patterns for when a model method or migration outgrows the SKILL.md basics.

## Query objects

When a query gets reused or spans several conditions/joins, extract a PORO instead of
piling scopes or stuffing it in the controller.

```ruby
# app/queries/recent_active_posts_query.rb
class RecentActivePostsQuery
  def initialize(relation = Post.all)
    @relation = relation
  end

  def call(since: 30.days.ago)
    @relation
      .where("published_at > ?", since)
      .where(archived: false)
      .includes(:author)
      .order(published_at: :desc)
  end
end
```

Keep it returning a relation (not an array) so callers can chain or paginate.

## strict_loading

Make lazy loading raise instead of silently N+1-ing. Set it per-association, per-record,
or app-wide.

```ruby
class Post < ApplicationRecord
  has_many :comments, strict_loading: true
end

# Or per query:
Post.strict_loading.find(id).comments   # raises unless preloaded
```

App-wide default in an environment file: `config.active_record.strict_loading_by_default
= true`. Turn it on in CI to catch N+1 before production.

## includes vs preload vs eager_load

- `includes` — Rails decides: separate queries (preload) unless you reference the
  association in a `where`/`order`, then it switches to a JOIN (eager_load).
- `preload` — always separate queries (two `SELECT`s). Use when you don't filter on the
  association.
- `eager_load` — always a single `LEFT OUTER JOIN`. Use when you must filter/sort by the
  association's columns.

If you `includes(:author).where("users.name = ?", x)` without referencing the table in a
string condition, add `.references(:author)` so Rails knows to JOIN.

## Large datasets

Never `Model.all.each` over a big table — it loads every row into memory. Batch it:

```ruby
Post.find_each(batch_size: 1000) do |post|   # loads 1000 at a time
  post.recompute_score!
end
```

For bulk updates with no callbacks needed, `update_all` issues one SQL statement.

## Counter caches

Avoid `COUNT(*)` on every render by caching the count on the parent.

```ruby
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true   # maintains posts.comments_count
end
```

Add the `comments_count` integer column; backfill it once with
`Post.find_each { |p| Post.reset_counters(p.id, :comments) }`.

## Composite primary keys

Rails supports composite keys natively. Declare on the model when the table has a
two-column PK:

```ruby
class TravelRoute < ApplicationRecord
  self.primary_key = [:origin, :destination]
end
```

`find` then takes an array: `TravelRoute.find(["NYC", "LON"])`.

## Advisory locks

Serialize a critical section across processes without a row lock, e.g. a singleton
backfill:

```ruby
ApplicationRecord.with_advisory_lock("nightly-rollup") do
  # only one process runs this block at a time
end
```

(Via the `with_advisory_lock` gem; Solid Queue uses advisory locks internally for
concurrency control.)

## Safe migration recipes (per operation)

Each recipe assumes a large live table. `strong_migrations` will flag the unsafe form.

**Add a column** — modern Postgres + Rails handle `default:` without a table rewrite, but
verify; if in doubt, add the column nullable, then set the default in a follow-up.

```ruby
add_column :posts, :views_count, :integer, default: 0, null: false
```

**Add an index** — always concurrent on a hot table:

```ruby
class AddIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!
  def change
    add_index :posts, :slug, unique: true, algorithm: :concurrently
  end
end
```

**Rename a column/table** — never do it in place on a live app (old code still
references the old name). Add the new column, dual-write in the app, backfill, switch
reads, drop the old column in a later deploy.

**Backfill** — never a single `UPDATE` of millions of rows in a migration (long lock,
not reversible cleanly). Batch in a separate, idempotent task:

```ruby
Post.where(views_count: nil).in_batches do |batch|
  batch.update_all(views_count: 0)
end
```

**Add a NOT NULL constraint** — add it as `NOT VALID` then validate separately, or use
a check constraint, to avoid a full-table scan under lock.

Always confirm `change` is reversible; if not, write explicit `up`/`down`.
