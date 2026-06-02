# Ecto patterns — depth

Ecto is the data layer: `Repo` (the gateway to the DB), schemas (struct + field map), `Ecto.Changeset` (cast + validate + constraints), `Ecto.Multi` (transactional pipelines), `Ecto.Query`. `phoenix_ecto` adds the Phoenix integration and the concurrent SQL sandbox for tests.

## Changeset recipes

A changeset casts external params, applies validations, and maps DB constraints to field errors.

```elixir
def changeset(product, attrs) do
  product
  |> cast(attrs, [:name, :price, :sku, :org_id])
  |> validate_required([:name, :price, :org_id])
  |> validate_number(:price, greater_than: 0)
  |> validate_length(:name, max: 120)
  |> unique_constraint(:sku)                 # turns a DB unique violation into a field error
  |> foreign_key_constraint(:org_id)
end
```

Rule: validate in the changeset, not with `try/rescue`. `unique_constraint`/`foreign_key_constraint` require the matching DB index/constraint — they convert the DB error into `{:error, changeset}` instead of an exception. Why: only the database can atomically enforce uniqueness under concurrency; the changeset just translates the failure.

Use a separate changeset per operation when rules differ (`registration_changeset` vs `update_changeset`) rather than one changeset with conditional branches.

## `Ecto.Multi` — atomic multi-write

```elixir
def place_order(scope, cart) do
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:order, Order.changeset(%Order{org_id: scope.org.id}, cart))
  |> Ecto.Multi.insert_all(:items, OrderItem, &build_items(&1.order, cart))
  |> Ecto.Multi.update(:inventory, fn _ -> decrement_stock(cart) end)
  |> Repo.transaction()
end
# => {:ok, %{order: order, items: ..., inventory: ...}}  or  {:error, step, changeset, changes_so_far}
```

Every step commits or the whole thing rolls back. Each step can read the results of prior steps via the function form. Pattern-match `{:error, failed_step, changeset, _}` to know which step failed.

## Queries & preloads — killing N+1

```elixir
import Ecto.Query

# Preload (two queries: posts, then all authors) — preferred for has_many.
Post |> preload(:author) |> Repo.all()

# Join + preload in one query — for filtering/ordering by the association.
from(p in Post, join: a in assoc(p, :author), where: a.active, preload: [author: a])
|> Repo.all()

# Scoped, paginated, ordered.
from(p in Product,
  where: p.org_id == ^scope.org.id,
  order_by: [desc: p.inserted_at],
  limit: ^limit, offset: ^offset
) |> Repo.all()
```

Rule: never touch `record.assoc` inside a loop without preloading first — that is the N+1. Use `preload` for plain loading; use `join: ... preload:` when you also filter or sort by the association.

## Migrations & constraints

```elixir
def change do
  create table(:products) do
    add :name, :string, null: false
    add :sku, :string, null: false
    add :org_id, references(:orgs, on_delete: :delete_all), null: false
    timestamps()
  end
  create unique_index(:products, [:sku])
  create index(:products, [:org_id])         # back the scope filter with an index
end
```

Migrations are forward-only history: write a new migration to change schema, never edit a migration that has shipped. Constraints (`null: false`, `unique_index`, FK) belong in the migration; the changeset translates their violations into field errors. Index the columns the scope filters on, or every scoped query is a table scan.

## SQL sandbox for tests

```elixir
# config/test.exs
config :my_app, MyApp.Repo, pool: Ecto.Adapters.SQL.Sandbox

# test/support/data_case.ex setup
setup tags do
  pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
  on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  :ok
end
```

Each test runs in its own transaction that is rolled back at the end, so tests stay isolated and can run `async: true` concurrently. LiveView/Conn tests that spawn processes need `shared: true` (non-async) so the spawned process sees the same sandbox connection.
