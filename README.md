# Rkv

[![CI](https://github.com/nmbrone/rkv/actions/workflows/ci.yml/badge.svg)](https://github.com/nmbrone/rkv/actions/workflows/ci.yml)

A simple ETS-based key-value storage with the ability to watch changes.

## Installation

The package can be installed by adding `rkv` to your list of dependencies in `mix.exs`:

<!-- x-release-please-start-version -->

```elixir
def deps do
  [
    {:rkv, "~> 0.1.0"}
  ]
end
```

<!-- x-release-please-end -->

## Usage

You can start `Rkv` directly or as part of a supervision tree.

### Starting the bucket

```elixir
# Start the process
{:ok, _pid} = Rkv.start_link(bucket: :my_bucket)
```

### Basic Operations

```elixir
# Put a value
:ok = Rkv.put(:my_bucket, "key", "value")

# Get a value
"value" = Rkv.get(:my_bucket, "key")

# Get a missing value
nil = Rkv.get(:my_bucket, "missing")

# Get with default
"default" = Rkv.get(:my_bucket, "missing", "default")

# Delete a value
:ok = Rkv.delete(:my_bucket, "key")
```

### Supervision

Add `Rkv` to your supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Rkv, bucket: :my_app_cache}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

### Watching Changes

You can subscribe to changes on a specific key or the entire bucket.

```elixir
# Watch a specific key
Rkv.watch_key(:my_bucket, "config")

Rkv.put(:my_bucket, "config", %{debug: true})

receive do
  {:updated, :my_bucket, "config"} -> IO.puts "Config updated!"
end

# Watch all keys
Rkv.watch_all(:my_bucket)

Rkv.put(:my_bucket, "other_key", 123)

receive do
  {:updated, :my_bucket, "other_key"} -> IO.puts "Something changed!"
end
```
