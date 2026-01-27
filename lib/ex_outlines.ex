defmodule ExOutlines do
  @moduledoc """
  ExOutlines — Deterministic structured output from LLMs.

  Main entry point for generating constrained outputs using retry-repair loops.
  """

  @type generate_opts :: [
          backend: module(),
          backend_opts: keyword(),
          max_retries: pos_integer(),
          telemetry_metadata: map()
        ]

  @type generate_result :: {:ok, any()} | {:error, term()}

  @doc """
  Generate structured output conforming to a spec.

  ## Options

  - `:backend` - Backend module implementing `ExOutlines.Backend`
  - `:backend_opts` - Options passed to backend (model, temperature, etc.)
  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:telemetry_metadata` - Additional telemetry context
  """
  @spec generate(ExOutlines.Spec.t(), generate_opts()) :: generate_result()
  def generate(_spec, _opts \\ []) do
    {:error, :not_implemented}
  end
end
