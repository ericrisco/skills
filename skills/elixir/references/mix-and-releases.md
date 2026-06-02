# mix project and releases

Depth offloaded from SKILL.md.

## mix.exs anatomy

```elixir
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # application/0 — `mod:` names the Application module + start args.
  # Omit `mod:` for a library that has no supervision tree of its own.
  def application do
    [
      extra_applications: [:logger],
      mod: {MyApp.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
```

- `elixir: "~> 1.19"` pins the language line; `~>` allows patch/minor within the constraint.
- Dev/test-only tooling uses `only:` and `runtime: false` so it is not shipped in a release.

## Common mix tasks

```bash
mix deps.get                         # fetch deps
mix compile --warnings-as-errors     # gate CI on this
mix format                           # canonical formatter (write)
mix format --check-formatted         # CI check (no write)
mix test                             # run ExUnit
mix release                          # build a self-contained release
```

## Config: config.exs vs runtime.exs

| File | Evaluated | Put here |
|---|---|---|
| `config/config.exs` | compile time (at build) | static, non-secret, compile-time settings; `import_config "#{config_env()}.exs"` |
| `config/runtime.exs` | runtime (release boot) | anything from `System.get_env/1` — DB URLs, secrets, ports, hostnames |

`runtime.exs` is the **only** config evaluated inside a built release at startup. Build-time `config.exs` values are frozen into the artifact, so secrets and per-environment values belong in `runtime.exs`:

```elixir
# config/runtime.exs
import Config

if config_env() == :prod do
  config :my_app, MyApp.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end
```

## mix release

`mix release` bundles your app, its deps, and the Erlang runtime (ERTS) into a tarball that runs on a target with no Elixir/Erlang installed.

```bash
MIX_ENV=prod mix release
_build/prod/rel/my_app/bin/my_app start    # foreground
_build/prod/rel/my_app/bin/my_app daemon   # background
_build/prod/rel/my_app/bin/my_app remote   # connect a remote IEx shell
```

Set runtime env vars (read in `runtime.exs`) in the deployment environment, not baked into the image. A release plus a small Docker base image is a common production shape.

## Umbrella projects: when and when not

An umbrella is multiple in-repo apps under one `apps/` directory sharing config and deps.

- **Use** when you have genuinely separate deployables/bounded contexts that you still want versioned and built together.
- **Do not** reach for it to organize one app — plain `lib/` directories and module namespacing handle that, and umbrellas add ceremony (per-app mix.exs, cross-app dep wiring) you will regret for a single service. Start as one app; split to an umbrella only when a real boundary appears.
