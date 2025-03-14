defmodule Rkv do
  @moduledoc """
  A simple ETS-based key-value storage with the ability to watch changes.
  """
  use GenServer

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
    {table, _callback} = lookup(name)
    table
  end

  @doc """
  Returns all key/value pairs
  """
  @spec all(name()) :: [{key(), value()}]
  def all(name) do
    {table, _} = lookup(name)
    :ets.tab2list(table)
  end

  @doc """
  Returns value by key.
  """
  @spec get(name(), key(), any()) :: value() | nil
  def get(name, key, default \\ nil) do
    {table, _} = lookup(name)

    case :ets.lookup(table, key) do
      [{_key, value}] -> value
      [] -> default
    end
  end

  @doc """
  Puts new value.
  """
  @spec put(name(), key(), value()) :: :ok
  def put(name, key, value) do
    {table, callback} = lookup(name)
    :ets.insert(table, {key, value})
    invoke_callback(callback, {:put, key, value})
    :ok
  end

  @doc """
  Deletes value.
  """
  @spec del(name(), key()) :: :ok
  def del(name, key) do
    {table, callback} = lookup(name)
    :ets.delete(table, key)
    invoke_callback(callback, {:del, key})
    :ok
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

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    ets_options = Keyword.get(opts, :ets_options, [:public, read_concurrency: true])
    callback = Keyword.get(opts, :callback)
    table = :ets.new(__MODULE__, ets_options)

    case Registry.register(@registry, registry_key(name), {table, callback}) do
      {:ok, _owner} -> {:ok, %{table: table, callback: callback}}
      {:error, err} -> {:stop, err}
    end
  end

  defp lookup(name) do
    case Registry.lookup(@registry, registry_key(name)) do
      [{_pid, value}] -> value
      [] -> raise "Unknown KV #{inspect(name)}"
    end
  end

  defp registry_key(name), do: {__MODULE__, name}

  defp invoke_callback(nil, _), do: :ok
  defp invoke_callback(fun, arg), do: fun.(arg)
end
