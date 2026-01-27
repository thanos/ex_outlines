defmodule ExOutlines.Prompt do
  @moduledoc """
  Prompt construction for generation and repair cycles.

  Builds structured prompts from specs and diagnostics.
  """

  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Build initial generation prompt from a spec.
  """
  @spec build_initial(ExOutlines.Spec.t()) :: [message()]
  def build_initial(_spec) do
    []
  end

  @doc """
  Build repair prompt from previous attempt and diagnostics.
  """
  @spec build_repair(String.t(), ExOutlines.Diagnostics.t()) :: [message()]
  def build_repair(_previous_output, _diagnostics) do
    []
  end
end
