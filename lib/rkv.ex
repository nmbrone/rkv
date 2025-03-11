defmodule Rkv do
  @moduledoc """
  A simple ETS-based key-value storage with the ability to monitor changes.
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
    lookup_table(name)
  end

  @doc """
  Returns all key/value pairs
  """
  @spec all(name()) :: [{key(), value()}]
  def all(name) do
    name
    |> lookup_table()
    |> :ets.tab2list()
  end

  @doc """
  Returns value by key.
  """
  @spec get(name(), key(), any()) :: value() | nil
  def get(name, key, default \\ nil) do
    name
    |> lookup_table()
    |> :ets.lookup(key)
    |> case do
      [{_key, value}] -> value
      [] -> default
    end
  end

  @doc """
  Puts new value.
  """
  @spec put(name(), key(), value()) :: :ok
  def put(name, key, value) do
    name
    |> lookup_pid()
    |> GenServer.call({:put, key, value})
  end

  @doc """
  Deletes value.
  """
  @spec del(name(), key()) :: :ok
  def del(name, key) do
    name
    |> lookup_pid()
    |> GenServer.call({:del, key})
  end

  @doc """
  Subscribes the caller to key changes.
  """
  @spec subscribe(name(), key()) :: :ok
  def subscribe(name, key) do
    {:ok, _} = PubSub.subscribe({name, key})
    :ok
  end

  @doc """
  Unsubscribes the caller from key changes.
  """
  @spec unsubscribe(name(), key()) :: :ok
  def unsubscribe(name, key) do
    PubSub.unsubscribe({name, key})
  end

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec child_spec([option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts
    |> super()
    |> Supervisor.child_spec(id: {__MODULE__, Keyword.fetch!(opts, :name)})
  end

  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    ets_options = Keyword.get(opts, :ets_options, [])
    table = :ets.new(__MODULE__, ets_options ++ [:set, :protected, read_concurrency: true])
    state = %{name: name, table: table}

    case Registry.register(@registry, {:kv, name}, table) do
      {:ok, _owner} -> {:ok, state}
      {:error, err} -> {:stop, err}
    end
  end

  def handle_call({:put, key, value}, _from, %{name: name} = state) do
    :ets.insert(state.table, {key, value})
    PubSub.broadcast({name, key}, {:kv, :add, name, key})
    {:reply, :ok, state}
  end

  def handle_call({:del, key}, _from, %{name: name, table: table} = state) do
    if :ets.member(table, key) do
      :ets.delete(table, key)
      PubSub.broadcast({name, key}, {:kv, :del, name, key})
    end

    {:reply, :ok, state}
  end

  defp lookup(name) do
    case Registry.lookup(@registry, {:kv, name}) do
      [object] -> object
      [] -> raise "Unknown KV #{inspect(name)}"
    end
  end

  defp lookup_pid(name) do
    name
    |> lookup()
    |> elem(0)
  end

  defp lookup_table(name) do
    name
    |> lookup()
    |> elem(1)
  end
end
