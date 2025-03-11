defmodule Rkv.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Rkv.Registry,
      Rkv.PubSub
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Rkv.Supervisor)
  end
end
