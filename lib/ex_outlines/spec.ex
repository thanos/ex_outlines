defprotocol ExOutlines.Spec do
  @moduledoc """
  Protocol for defining constraint specifications.

  Implementations must provide schema generation and validation logic.
  """

  @doc """
  Convert spec to a schema representation (typically a map).
  Used for prompt construction.
  """
  @spec to_schema(t()) :: map()
  def to_schema(spec)

  @doc """
  Validate a value against the spec.

  Returns `{:ok, validated_value}` or `{:error, diagnostics}`.
  """
  @spec validate(t(), any()) :: {:ok, any()} | {:error, ExOutlines.Diagnostics.t()}
  def validate(spec, value)
end
