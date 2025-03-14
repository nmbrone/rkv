defmodule Rkv.MixProject do
  use Mix.Project

  def project do
    [
      app: :rkv,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rkv.Application, []}
    ]
  end

  defp deps do
    []
  end
end
