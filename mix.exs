defmodule ExOutlines.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/your_org/ex_outlines"

  def project do
    [
      app: :ex_outlines,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      name: "ExOutlines",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Deterministic structured output from LLMs via retry-repair loops.
    Backend-agnostic constraint satisfaction for Elixir.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      maintainers: ["Your Name"]
    ]
  end

  defp docs do
    [
      main: "ExOutlines",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
