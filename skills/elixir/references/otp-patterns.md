# OTP patterns

Depth offloaded from SKILL.md. Pick the lightest behaviour that fits.

## Choosing an OTP behaviour

| Need | Reach for | Notes |
|---|---|---|
| State behind a custom API, callbacks | `GenServer` | The workhorse; full control over messages |
| Trivial state, get/update by function | `Agent` | A thin GenServer wrapper; no custom protocol |
| One-off concurrent computation | `Task` | `Task.async/await`, or `Task.async_stream` for bounded fan-out |
| Supervised fire-and-forget jobs | `Task.Supervisor` | Crashes isolated, no result needed |
| Many dynamic, identical children | `DynamicSupervisor` + `Registry` | Start/stop children at runtime, look them up by key |
| Explicit state machine with phases | `:gen_statem` (Erlang) | When transitions/events dominate; usable directly from Elixir |
| Shared read-heavy data | `:ets` | Concurrent lock-free reads; one owner process holds the table |

## DynamicSupervisor + Registry recipe

Use this when you want one process per logical entity (per user, per connection, per token bucket) started on demand and addressable by a key.

```elixir
# In application.ex children, before the workers:
#   {Registry, keys: :unique, name: MyApp.Registry},
#   {DynamicSupervisor, name: MyApp.WorkerSup, strategy: :one_for_one}

defmodule MyApp.Worker do
  use GenServer

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: via(id))
  end

  defp via(id), do: {:via, Registry, {MyApp.Registry, id}}

  # Start (or return existing) a worker for `id`.
  def ensure_started(id) do
    case DynamicSupervisor.start_child(MyApp.WorkerSup, {__MODULE__, id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @impl true
  def init(id), do: {:ok, %{id: id}}
end
```

`{:via, Registry, {Registry, key}}` lets you address a process by `key` without ever touching its pid. The Registry entry is removed automatically when the process dies — no stale-pid bookkeeping.

## Timeouts, backpressure, and mailbox growth

- `GenServer.call/3` defaults to a **5000 ms** timeout. If the server is slow, the *caller* gets an `:timeout` exit. Raise the timeout only when the operation is legitimately long; otherwise the slowness is the bug.
- A **growing mailbox** means messages arrive faster than `handle_*` drains them. Causes: an unbounded `cast` producer, an expensive `handle_info`, or a process doing too much. Fixes:
  - Switch hot producers from `cast` to `call` so the caller blocks (natural backpressure).
  - Move heavy work out of the GenServer (into a `Task` it supervises).
  - Shard the work across many processes instead of one.
  - For true streaming/backpressure, use `GenStage`/`Flow` (external deps).
- `handle_continue/2` runs immediately after `init` (or after the returning callback) before the next message — use it for post-init warm-up so `start_link` returns fast.

## Task and Task.Supervisor

```elixir
# Bounded concurrent fan-out — never spawns more than max_concurrency at once.
ids
|> Task.async_stream(&fetch/1, max_concurrency: 10, timeout: 30_000)
|> Enum.map(fn {:ok, result} -> result end)

# Supervised fire-and-forget (add {Task.Supervisor, name: MyApp.Tasks} to children):
Task.Supervisor.start_child(MyApp.Tasks, fn -> do_async_thing() end)
```

Prefer `Task.async_stream` over manually spawning N tasks — it bounds concurrency and applies a per-item timeout.

## Agent (when GenServer is overkill)

```elixir
{:ok, agent} = Agent.start_link(fn -> %{} end)
Agent.update(agent, &Map.put(&1, :k, 1))
Agent.get(agent, &Map.get(&1, :k))
```

Note: every `Agent.get`/`update` runs its function in the agent process — keep them tiny, or you recreate the god-process bottleneck.

## ETS for shared read state

```elixir
:ets.new(:cache, [:named_table, :set, :public, read_concurrency: true])
:ets.insert(:cache, {:key, value})
case :ets.lookup(:cache, :key) do
  [{:key, v}] -> {:ok, v}
  [] -> :error
end
```

ETS gives concurrent lock-free reads, so a read-heavy cache does not bottleneck on a single GenServer mailbox. Have one process own and create the table (so the table dies with it, or use `:heir` to transfer ownership on crash).
