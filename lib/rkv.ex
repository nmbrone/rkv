defmodule Rkv do
  @moduledoc """
  A simple ETS-based key-value storage with the ability to watch changes.

  ## Usage

  You can start the bucket process under a supervisor:

      children = [
        {Rkv, bucket: :my_bucket}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  Or start it directly:

      Rkv.start_link(bucket: :my_bucket)

  Then you can use the bucket:

      Rkv.put(:my_bucket, "foo", "bar")
      Rkv.get(:my_bucket, "foo")
      #=> "bar"
  """
  use GenServer

  alias Rkv.PubSub

  @type bucket :: term()
  @type key :: any()
  @type value :: any()
  @type option :: {:bucket, bucket()} | {:ets_options, list()}

  @registry Rkv.Registry

  @doc """
  Returns the underlying ETS table.
  """
  @spec ets(bucket()) :: :ets.table()
  def ets(bucket) do
    case Registry.lookup(@registry, registry_key(bucket)) do
      [{_pid, value}] -> value
      [] -> raise "Rkv: unknown bucket #{inspect(bucket)}"
    end
  end

  @doc """
  Returns all key/value pairs.

  ## Examples

      iex> Rkv.put(:my_bucket, "foo", "bar")
      iex> Rkv.all(:my_bucket)
      [{"foo", "bar"}]

  """
  @spec all(bucket()) :: [{key(), value()}]
  def all(bucket) do
    bucket |> ets() |> :ets.tab2list()
  end

  @doc """
  Returns the value by key.

  Returns `default` if the key does not exist.

  ## Examples

      iex> Rkv.put(:my_bucket, "foo", "bar")
      iex> Rkv.get(:my_bucket, "foo")
      "bar"

      iex> Rkv.get(:my_bucket, "missing")
      nil

      iex> Rkv.get(:my_bucket, "missing", :default)
      :default

  """
  @spec get(bucket(), key(), any()) :: value() | nil
  def get(bucket, key, default \\ nil) do
    case bucket |> ets() |> :ets.lookup(key) do
      [{_key, value}] -> value
      [] -> default
    end
  end

  @doc """
  Fetches the value for the key.

  Returns `{:ok, value}` if the key exists, otherwise `:error`.

  ## Examples

      iex> Rkv.put(:my_bucket, "foo", "bar")
      iex> Rkv.fetch(:my_bucket, "foo")
      {:ok, "bar"}

      iex> Rkv.fetch(:my_bucket, "missing")
      :error

  """
  @spec fetch(bucket(), key()) :: {:ok, value()} | :error
  def fetch(bucket, key) do
    case get(bucket, key) do
      nil -> :error
      val -> {:ok, val}
    end
  end

  @doc """
  Puts the key into the bucket.

  If the key already exists, the value is updated.

  ## Examples

      iex> Rkv.put(:my_bucket, "foo", "bar")
      :ok

  """
  @spec put(bucket(), key(), value()) :: :ok
  def put(bucket, key, value) do
    bucket |> ets() |> :ets.insert({key, value})
    broadcast_update(bucket, key)
    :ok
  end

  @doc """
  Puts the key into the bucket only if the key does not exist.

  Returns `:ok` if successful, or `{:error, :already_exists}` if the key already exists.

  ## Examples

      iex> Rkv.put_new(:my_bucket, "foo", "bar")
      :ok
      iex> Rkv.put_new(:my_bucket, "foo", "baz")
      {:error, :already_exists}

  """
  @spec put_new(bucket(), key(), value()) :: :ok | {:error, :already_exists}
  def put_new(bucket, key, value) do
    case bucket |> ets() |> :ets.insert_new({key, value}) do
      true ->
        broadcast_update(bucket, key)
        :ok

      false ->
        {:error, :already_exists}
    end
  end

  @doc """
  Deletes the key from the bucket.

  ## Examples

      iex> Rkv.put(:my_bucket, "foo", "bar")
      iex> Rkv.delete(:my_bucket, "foo")
      :ok
      iex> Rkv.get(:my_bucket, "foo")
      nil

  """
  @spec delete(bucket(), key()) :: :ok
  def delete(bucket, key) do
    bucket |> ets() |> :ets.delete(key)
    broadcast_delete(bucket, key)
    :ok
  end

  @doc """
  Returns `true` if the key exists in the bucket, otherwise `false`.

  ## Examples

      iex> Rkv.put(:my_bucket, "foo", "bar")
      iex> Rkv.exists?(:my_bucket, "foo")
      true

      iex> Rkv.exists?(:my_bucket, "missing")
      false

  """
  @spec exists?(bucket(), key()) :: boolean()
  def exists?(bucket, key) do
    bucket |> ets() |> :ets.member(key)
  end

  @doc """
  Subscribes the caller to key updates.

  The caller will receive:
  * `{:updated, bucket, key}` when the key is updated
  * `{:deleted, bucket, key}` when the key is deleted

  ## Examples

      iex> Rkv.watch_key(:my_bucket, "foo")
      :ok

  """
  @spec watch_key(bucket(), key()) :: :ok | {:error, term()}
  def watch_key(bucket, key) do
    PubSub.subscribe({bucket, key})
  end

  @doc """
  Subscribes the caller to all updates.

  The caller will receive:
  * `{:updated, bucket, key}` when any key is updated
  * `{:deleted, bucket, key}` when any key is deleted

  ## Examples

      iex> Rkv.watch_all(:my_bucket)
      :ok

  """
  @spec watch_all(bucket()) :: :ok | {:error, term()}
  def watch_all(bucket) do
    PubSub.subscribe(bucket)
  end

  @doc """
  Unsubsribes the caller from key updates.

  ## Examples

      iex> Rkv.unwatch_key(:my_bucket, "foo")
      :ok

  """
  @spec unwatch_key(bucket(), key()) :: :ok
  def unwatch_key(bucket, key) do
    PubSub.unsubscribe({bucket, key})
  end

  @doc """
  Unsubsribes the caller from all updates.

  ## Examples

      iex> Rkv.unwatch_all(:my_bucket)
      :ok

  """
  @spec unwatch_all(bucket()) :: :ok
  def unwatch_all(bucket) do
    PubSub.unsubscribe(bucket)
  end

  @spec default_ets_options() :: list()
  def default_ets_options do
    [:public, read_concurrency: true, write_concurrency: :auto]
  end

  @spec child_spec([option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts
    |> super()
    |> Supervisor.child_spec(id: {__MODULE__, Keyword.fetch!(opts, :bucket)})
  end

  @doc """
  Starts the Rkv bucket.

  The `opts` keyword list must contain the `:bucket` key, which is used to
  register the process.

  ## Options

    * `:bucket` - the name of the bucket (required)
    * `:ets_options` - options passed to `:ets.new/2` (optional).
      Defaults to `[:public, read_concurrency: true, write_concurrency: :auto]`.
      The table type must be `:set` or `:ordered_set`, and protection must be `:public`.
  """
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    bucket = Keyword.fetch!(opts, :bucket)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {@registry, registry_key(bucket)}}
    )
  end

  @impl true
  def init(opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    ets = :ets.new(__MODULE__, Keyword.get(opts, :ets_options, default_ets_options()))

    if :ets.info(ets, :type) not in [:set, :ordered_set] do
      raise "Rkv: table must be :set or :ordered_set"
    end

    if :ets.info(ets, :protection) != :public do
      raise "Rkv: table must be :public"
    end

    Registry.update_value(@registry, registry_key(bucket), fn _ -> ets end)
    {:ok, nil}
  end

  defp registry_key(bucket), do: {__MODULE__, bucket}

  defp broadcast_update(bucket, key) do
    message = {:updated, bucket, key}
    PubSub.broadcast({bucket, key}, message)
    PubSub.broadcast(bucket, message)
  end

  defp broadcast_delete(bucket, key) do
    message = {:deleted, bucket, key}
    PubSub.broadcast({bucket, key}, message)
    PubSub.broadcast(bucket, message)
  end
end
