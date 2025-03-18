defmodule Rkv do
  @moduledoc """
  A simple ETS-based key-value storage with the ability to watch changes.
  """
  use GenServer

  alias Rkv.PubSub

  @type name :: atom()
  @type key :: any()
  @type value :: any()
  @type option :: {:name, name()} | {:ets_options, list()}

  @registry Rkv.Registry

  @doc """
  Returns the underlying ETS table.
  """
  @spec ets(name()) :: :ets.table()
  def ets(name) do
    case Registry.lookup(@registry, registry_key(name)) do
      [{_pid, value}] -> value
      [] -> raise "Rkv: unknown #{inspect(name)}"
    end
  end

  @doc """
  Returns all key/value pairs
  """
  @spec all(name()) :: [{key(), value()}]
  def all(name) do
    name |> ets() |> :ets.tab2list()
  end

  @doc """
  Returns value by key.
  """
  @spec get(name(), key(), any()) :: value() | nil
  def get(name, key, default \\ nil) do
    case name |> ets() |> :ets.lookup(key) do
      [{_key, value}] -> value
      [] -> default
    end
  end

  @doc """
  Puts new value.
  """
  @spec put(name(), key(), value()) :: :ok
  def put(name, key, value) do
    name |> ets() |> :ets.insert({key, value})
    message = {__MODULE__, :updated, name, key}
    PubSub.broadcast({name, key}, message)
    PubSub.broadcast(name, message)
    :ok
  end

  @doc """
  Deletes value.
  """
  @spec del(name(), key()) :: :ok
  def del(name, key) do
    name |> ets() |> :ets.delete(key)
    message = {__MODULE__, :deleted, name, key}
    PubSub.broadcast({name, key}, message)
    PubSub.broadcast(name, message)
    :ok
  end

  @doc """
  Subscribes the caller to key updates.
  """
  @spec watch_key(name(), key()) :: :ok | {:error, term()}
  def watch_key(name, key) do
    PubSub.subscribe({name, key})
  end

  @doc """
  Subscribes the caller to all updates.
  """
  @spec watch_all(name()) :: :ok | {:error, term()}
  def watch_all(name) do
    PubSub.subscribe(name)
  end

  @doc """
  Unsubsribes the caller from key updates.
  """
  @spec unwatch_key(name(), key()) :: :ok
  def unwatch_key(name, key) do
    PubSub.unsubscribe({name, key})
  end

  @doc """
  Unsubsribes the caller from all updates.
  """
  @spec unwatch_all(name()) :: :ok
  def unwatch_all(name) do
    PubSub.unsubscribe(name)
  end

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {@registry, registry_key(name)}}
    )
  end

  @spec child_spec([option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts
    |> super()
    |> Supervisor.child_spec(id: {__MODULE__, Keyword.fetch!(opts, :name)})
  end

  @spec default_ets_options() :: list()
  def default_ets_options do
    [:public, read_concurrency: true, write_concurrency: :auto]
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    ets = :ets.new(__MODULE__, Keyword.get(opts, :ets_options, default_ets_options()))

    if :ets.info(ets, :type) not in [:set, :ordered_set] do
      raise "Rkv: table must be :set or :ordered_set"
    end

    if :ets.info(ets, :protection) != :public do
      raise "Rkv: table must be :public"
    end

    Registry.update_value(@registry, registry_key(name), fn _ -> ets end)
    {:ok, nil}
  end

  defp registry_key(name), do: {__MODULE__, name}
end
