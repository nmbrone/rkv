defmodule Rkv.PubSub do
  @moduledoc false

  def child_spec(_opts) do
    Registry.child_spec(keys: :duplicate, name: __MODULE__)
  end

  def subscribe(topic, metadata \\ nil) do
    Registry.register(__MODULE__, topic, metadata)
  end

  def unsubscribe(topic) do
    Registry.unregister(__MODULE__, topic)
  end

  def broadcast(topic, message, dispatcher \\ __MODULE__) do
    Registry.dispatch(__MODULE__, topic, {dispatcher, :dispatch, [message]})
  end

  @doc false
  def dispatch(entries, message) do
    for {pid, _} <- entries do
      send(pid, message)
    end
  end
end
