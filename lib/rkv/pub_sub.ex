defmodule Rkv.PubSub do
  @moduledoc false

  @type topic :: term()
  @type message :: term()

  @spec child_spec(Keyword.t()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    Registry.child_spec(keys: :duplicate, name: __MODULE__)
  end

  @spec subscribe(topic()) :: :ok | {:error, term()}
  def subscribe(topic) do
    case Registry.register(__MODULE__, topic, nil) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @spec unsubscribe(topic()) :: :ok
  def unsubscribe(topic) do
    Registry.unregister(__MODULE__, topic)
  end

  @spec broadcast(topic(), message()) :: :ok
  def broadcast(topic, message) do
    Registry.dispatch(__MODULE__, topic, {__MODULE__, :dispatch, [message]})
  end

  @doc false
  def dispatch(entries, message) do
    for {pid, _} <- entries do
      send(pid, message)
    end
  end
end
