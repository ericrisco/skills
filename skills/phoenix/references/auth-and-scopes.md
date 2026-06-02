# Auth & scopes — depth

Phoenix 1.8 makes authorization a property of data access via **scopes**, and `mix phx.gen.auth` scaffolds the whole login flow around them.

## `mix phx.gen.auth` in 1.8

```bash
mix phx.gen.auth Accounts User users
```

Defaults to **magic-link (passwordless) auth**: the user enters an email, receives a one-time login link, and is signed in — no password to store or leak. Email+password is still available if you opt in. The generator produces:

- The `Accounts` context (`User`, tokens, registration/login functions).
- LiveViews for login, registration, settings, confirmation.
- A `require_authenticated_user` plug/on_mount hook.
- A **sudo mode** re-auth gate (`require_sudo_mode`-style) for sensitive operations (changing email/password) — recent confirmation is required even when already logged in.
- The **default scope** wired into the router and `conn.assigns` / `socket.assigns`.

## Scopes — secure-by-default access

A scope is a struct carrying the current actor and whatever it is scoped to (user, org/tenant). Generators thread it through every context function and into every query.

```elixir
defmodule MyApp.Accounts.Scope do
  defstruct [:user, :org]
  def for_user(%User{} = user), do: %__MODULE__{user: user, org: user.org}
end
```

```elixir
# Router puts the scope on assigns once.
# Every context function takes it and filters by it.
def list_products(%Scope{} = scope) do
  from(p in Product, where: p.org_id == ^scope.org.id) |> Repo.all()
end

def get_product!(%Scope{} = scope, id) do
  from(p in Product, where: p.id == ^id and p.org_id == ^scope.org.id) |> Repo.one!()
end
```

Rule: the scope filter goes **in the query**, not in an `if` after the fetch. Why: `get_product!(scope, other_orgs_id)` then raises `NoResultsError` (a clean 404) instead of returning a row you forgot to check. The unsafe path stops compiling/working, the safe path is the only path.

## In LiveView

```elixir
# router.ex
live_session :authenticated, on_mount: [{MyAppWeb.UserAuth, :require_authenticated}] do
  live "/products", ProductLive.Index, :index
end

# the on_mount hook puts current_scope on the socket; use it everywhere:
def mount(_p, _s, socket) do
  {:ok, stream(socket, :products, Catalog.list_products(socket.assigns.current_scope))}
end
```

## Sudo mode for sensitive actions

```elixir
# Re-confirm recent authentication before allowing email/password changes.
plug :require_sudo_mode when action in [:update_email, :update_password]
```

If the user authenticated too long ago, they are bounced to re-confirm. This limits the blast radius of a hijacked session.

## Testing authz

```elixir
# DataCase — the scope filter is the authorization; test that cross-scope access fails.
test "get_product!/2 cannot read another org's product", %{scope: scope} do
  other = product_fixture(scope_fixture())          # different org
  assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(scope, other.id) end
end

# ConnCase / LiveViewTest — unauthenticated request redirects to login.
test "redirects when not logged in", %{conn: conn} do
  assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/products")
end
```

Rule: test authorization at the context with `DataCase` (the scope filter is where authz lives), and test the redirect/gate at the web layer with `ConnCase`/`LiveViewTest`. Why: proving the query refuses cross-scope rows is the real security assertion; the web test just proves the gate is wired.
