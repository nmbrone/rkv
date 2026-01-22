defmodule Rkv.MixProject do
  use Mix.Project

  @source_url "https://github.com/nmbrone/rkv"

  def project do
    [
      app: :rkv,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Rkv",
      source_url: @source_url,
      homepage_url: @source_url,
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Rkv.Application, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp description do
    "A simple ETS-based key-value storage with the ability to watch changes."
  end

  defp package do
    [
      maintainers: ["Serhii Snozyk"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Rkv",
      extras: ["CHANGELOG.md"]
    ]
  end
end
