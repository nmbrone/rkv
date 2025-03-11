defmodule Rkv.Registry do
  @moduledoc false

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end
end
