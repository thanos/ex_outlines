defmodule ExOutlines.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/thanos/ex_outlines"

  def project do
    [
      app: :ex_outlines,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      package: package(),
      description: description(),
      name: "ExOutlines",
      source_url: @source_url,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :public_key]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:ecto, "~> 3.11", optional: true},
      {:benchee, "~> 1.3", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
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
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["Your Name"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "ExOutlines",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      # Root documentation
      "README.md": [title: "Overview"],
      "CHANGELOG.md": [title: "Changelog"],
      LICENSE: [title: "License"],

      # Getting started guides
      "guides/getting_started.md": [title: "Getting Started"],
      "guides/core_concepts.md": [title: "Core Concepts"],

      # Core guides
      "guides/schema_patterns.md": [title: "Schema Patterns"],
      "guides/architecture.md": [title: "Architecture"],
      "guides/batch_processing.md": [title: "Batch Processing"],

      # Integration guides
      "guides/phoenix_integration.md": [title: "Phoenix Integration"],
      "guides/ecto_schema_adapter.md": [title: "Ecto Schema Adapter"],

      # Best practices
      "guides/testing_strategies.md": [title: "Testing Strategies"],
      "guides/error_handling.md": [title: "Error Handling"],

      # Livebook tutorials - Beginner
      "livebooks/getting_started.livemd": [title: "Livebook: Getting Started"],

      # Livebook tutorials - Intermediate
      "livebooks/named_entity_extraction.livemd": [title: "Livebook: Named Entity Extraction"],
      "livebooks/dating_profiles.livemd": [title: "Livebook: Dating Profiles"],
      "livebooks/qa_with_citations.livemd": [title: "Livebook: Q&A with Citations"],
      "livebooks/sampling_and_self_consistency.livemd": [
        title: "Livebook: Sampling & Self-Consistency"
      ],

      # Livebook tutorials - Advanced
      "livebooks/models_playing_chess.livemd": [title: "Livebook: Models Playing Chess"],
      "livebooks/simtom_theory_of_mind.livemd": [title: "Livebook: SimToM Theory of Mind"],
      "livebooks/chain_of_thought.livemd": [title: "Livebook: Chain of Thought"],
      "livebooks/react_agent.livemd": [title: "Livebook: ReAct Agent"],
      "livebooks/structured_generation_workflow.livemd": [title: "Livebook: Structured Generation"],

      # Livebook tutorials - Vision & Documents
      "livebooks/read_pdfs.livemd": [title: "Livebook: PDF Reading"],
      "livebooks/earnings_reports.livemd": [title: "Livebook: Earnings Reports"],
      "livebooks/receipt_digitization.livemd": [title: "Livebook: Receipt Digitization"],
      "livebooks/extract_event_details.livemd": [title: "Livebook: Extract Event Details"],

      # Livebooks README
      "livebooks/README.md": [title: "Livebook Tutorials Index"],

      # Reference
      "DOCUMENTATION_INDEX.md": [title: "Documentation Index"],
      "GAP_ANALYSIS.md": [title: "Gap Analysis vs Python Outlines"]
      # "GITHUB_ANALYSIS_SUMMARY.md": [title: "GitHub Analysis Summary"]
    ]
  end

  defp groups_for_extras do
    [
      "Getting Started": ~r/guides\/(getting_started|core_concepts)/,
      "Core Guides": ~r/guides\/(schema_patterns|architecture|batch_processing)/,
      Integration: ~r/guides\/(phoenix_integration|ecto_schema_adapter)/,
      "Best Practices": ~r/guides\/(testing_strategies|error_handling)/,
      "Livebook Tutorials": ~r/livebooks\//,
      Reference: ~r/(DOCUMENTATION_INDEX|GAP_ANALYSIS|GITHUB_ANALYSIS_SUMMARY)/,
      "Project Info": ~r/(README|CHANGELOG|LICENSE)/
    ]
  end

  defp groups_for_modules do
    [
      "Core API": [
        ExOutlines,
        ExOutlines.Spec,
        ExOutlines.Spec.Schema
      ],
      Backends: [
        ExOutlines.Backend,
        ExOutlines.Backend.HTTP,
        ExOutlines.Backend.Anthropic,
        ExOutlines.Backend.Mock
      ],
      "Error Handling": [
        ExOutlines.Diagnostics
      ],
      "Ecto Integration": [
        ExOutlines.Ecto.SchemaAdapter
      ]
    ]
  end
end
