# LiveView (1.1) — depth

Targets LiveView 1.1.x on Phoenix 1.8.7. LiveView holds UI state in `socket.assigns`, renders HEEx, and reacts to events over a persistent WebSocket (with a dead HTTP render first).

## Lifecycle in detail

```elixir
def mount(params, session, socket) do
  # Runs twice: once for the dead (HTTP) render, once on WS connect.
  # Gate expensive/subscription work on connected?/1.
  if connected?(socket), do: Phoenix.PubSub.subscribe(MyApp.PubSub, "products")
  {:ok, stream(socket, :products, Catalog.list_products(socket.assigns.current_scope))}
end

def handle_params(params, _uri, socket) do
  # Every live_patch / URL change lands here. Use for tab/filter/pagination state.
  {:noreply, apply_action(socket, socket.assigns.live_action, params)}
end

def handle_event("delete", %{"id" => id}, socket) do
  product = Catalog.get_product!(socket.assigns.current_scope, id)
  {:ok, _} = Catalog.delete_product(socket.assigns.current_scope, product)
  {:noreply, stream_delete(socket, :products, product)}
end

def handle_info({:created, product}, socket) do
  # External event (PubSub broadcast, send/2 from a Task). Apply to the stream.
  {:noreply, stream_insert(socket, :products, product, at: 0)}
end
```

`assign/2,3` for scalar state; `assign_new/3` to avoid recomputing on reconnect. Keep assigns small — they are state held per connected socket.

## Streams — collections without server-held lists

A stream keeps the collection in the DOM, not in `socket.assigns`. The server tracks only DOM ids, so a single `stream_insert/3` ships one row.

```elixir
stream(socket, :products, products)            # initial load
stream_insert(socket, :products, p, at: 0)     # prepend; at: -1 appends
stream_delete(socket, :products, p)            # remove one row
stream(socket, :products, [], reset: true)     # clear and reload
```

```heex
<table>
  <tbody id="products" phx-update="stream">
    <tr :for={{dom_id, p} <- @streams.products} id={dom_id}>
      <td>{p.name}</td>
      <td>{p.price}</td>
    </tr>
  </tbody>
</table>
```

The container needs an `id` and `phx-update="stream"`; each row's `id` must come from the stream's `{dom_id, item}`. For per-row change tracking (a row that re-renders independently), wrap the row in a `Phoenix.LiveComponent` keyed by id — only that component re-diffs.

## Forms with `to_form/2`

```elixir
def mount(_p, _s, socket) do
  {:ok, assign(socket, :form, to_form(Catalog.change_product(%Product{})))}
end

def handle_event("validate", %{"product" => attrs}, socket) do
  form = %Product{} |> Catalog.change_product(attrs) |> Map.put(:action, :validate) |> to_form()
  {:noreply, assign(socket, :form, form)}
end

def handle_event("save", %{"product" => attrs}, socket) do
  case Catalog.create_product(socket.assigns.current_scope, attrs) do
    {:ok, _product} -> {:noreply, socket |> put_flash(:info, "Created") |> push_navigate(to: ~p"/products")}
    {:error, changeset} -> {:noreply, assign(socket, :form, to_form(changeset))}
  end
end
```

```heex
<.form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} label="Name" />
  <.button>Save</.button>
</.form>
```

`to_form/2` wraps a changeset; rendering the same form back on `{:error, changeset}` surfaces field errors automatically. Setting `:action` makes "validate" errors show without a submit.

## Uploads

```elixir
socket = allow_upload(socket, :photo, accept: ~w(.jpg .png), max_entries: 1)
# in save: consume_uploaded_entries(socket, :photo, fn %{path: path}, _entry -> ... end)
```

## JS commands — client interactivity without a round trip

```heex
<button phx-click={JS.toggle(to: "#menu") |> JS.add_class("open", to: "#menu")}>Menu</button>
```

`Phoenix.LiveView.JS` runs show/hide/toggle/transition/dispatch on the client with no server message — use it for purely visual state.

## Colocated hooks & ColocatedJS (1.1, requires Phoenix 1.8+)

Define a JS hook next to the element that uses it; the compiler extracts it into the bundle.

```heex
<div id="chart" phx-hook=".Chart" data-series={Jason.encode!(@series)}>
  <script :type={Phoenix.LiveView.ColocatedHook} name=".Chart">
    export default { mounted() { renderChart(this.el); } }
  </script>
</div>
```

`ColocatedJS` extracts arbitrary colocated `<script>` modules. LiveView 1.1 also ships official TypeScript types for the JS client and **keyed comprehensions** (`:for` tracks items by key for finer diffs).

## Async assigns

Offload slow loads so mount returns immediately.

```elixir
def mount(_p, _s, socket) do
  {:ok, assign_async(socket, :stats, fn -> {:ok, %{stats: Reports.expensive_stats()}} end)}
end
```

```heex
<.async_result :let={stats} assign={@stats}>
  <:loading>Computing…</:loading>
  <:failed :let={_reason}>Could not load.</:failed>
  {stats.total}
</.async_result>
```

`assign_async/3` runs the work in a Task and pushes the result; the template renders loading/failed/ready states. Use it instead of blocking `mount/3` on a slow query.
