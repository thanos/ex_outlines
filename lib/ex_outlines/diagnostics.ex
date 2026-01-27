defmodule ExOutlines.Diagnostics do
  @moduledoc """
  Structured error representation with repair instructions.

  Used to communicate validation failures and guide LLM correction.

  ## Error Structure

  Each error contains:
  - `field` - The field path (e.g., "user.email" or nil for top-level)
  - `expected` - Description of expected format/type
  - `got` - The actual value received
  - `message` - Human-readable error message

  ## Repair Instructions

  Repair instructions are generated from errors to guide LLM correction.
  They provide actionable steps to fix validation failures.
  """

  @type error_detail :: %{
          field: String.t() | nil,
          expected: String.t(),
          got: any(),
          message: String.t()
        }

  @type t :: %__MODULE__{
          errors: [error_detail()],
          repair_instructions: String.t()
        }

  defstruct errors: [], repair_instructions: ""

  @doc """
  Create a new diagnostics struct with a single error.

  ## Examples

      iex> ExOutlines.Diagnostics.new("integer", "hello", "age")
      %ExOutlines.Diagnostics{
        errors: [%{
          field: "age",
          expected: "integer",
          got: "hello",
          message: "Field 'age': Expected integer but got \\"hello\\""
        }],
        repair_instructions: "Field 'age' must be: integer"
      }
  """
  @spec new(String.t(), any(), String.t() | nil) :: t()
  def new(expected, got, field \\ nil) do
    error = build_error(field, expected, got)

    %__MODULE__{
      errors: [error],
      repair_instructions: build_repair_instructions([error])
    }
  end

  @doc """
  Create diagnostics from a list of errors.

  Each error should have `:field`, `:expected`, `:got`, and optionally `:message`.
  """
  @spec from_errors([error_detail()]) :: t()
  def from_errors(errors) when is_list(errors) do
    normalized = Enum.map(errors, &normalize_error/1)

    %__MODULE__{
      errors: normalized,
      repair_instructions: build_repair_instructions(normalized)
    }
  end

  @doc """
  Add an error to existing diagnostics.

  Returns a new diagnostics struct with the additional error.
  """
  @spec add_error(t(), String.t() | nil, String.t(), any()) :: t()
  def add_error(%__MODULE__{errors: errors}, field, expected, got) do
    new_error = build_error(field, expected, got)
    updated_errors = errors ++ [new_error]

    %__MODULE__{
      errors: updated_errors,
      repair_instructions: build_repair_instructions(updated_errors)
    }
  end

  @doc """
  Merge multiple diagnostics into one.

  Combines all errors and regenerates repair instructions.
  Duplicate errors are automatically removed.
  """
  @spec merge([t()]) :: t()
  def merge(diagnostics_list) when is_list(diagnostics_list) do
    all_errors =
      diagnostics_list
      |> Enum.flat_map(& &1.errors)
      |> Enum.uniq()

    %__MODULE__{
      errors: all_errors,
      repair_instructions: build_repair_instructions(all_errors)
    }
  end

  @doc """
  Check if diagnostics has any errors.

  ## Examples

      iex> ExOutlines.Diagnostics.new("integer", "string", "age") |> ExOutlines.Diagnostics.has_errors?()
      true

      iex> %ExOutlines.Diagnostics{} |> ExOutlines.Diagnostics.has_errors?()
      false
  """
  @spec has_errors?(t()) :: boolean()
  def has_errors?(%__MODULE__{errors: []}), do: false
  def has_errors?(%__MODULE__{errors: [_ | _]}), do: true

  @doc """
  Get the number of errors in diagnostics.

  ## Examples

      iex> ExOutlines.Diagnostics.new("integer", "string", "age") |> ExOutlines.Diagnostics.error_count()
      1
  """
  @spec error_count(t()) :: non_neg_integer()
  def error_count(%__MODULE__{errors: errors}), do: length(errors)

  @doc """
  Format diagnostics as a human-readable string.

  ## Examples

      iex> diag = ExOutlines.Diagnostics.new("integer", "hello", "age")
      iex> ExOutlines.Diagnostics.format(diag)
      "Validation failed with 1 error:\\n- [age] Field 'age': Expected integer but got \\"hello\\""
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{errors: errors}) do
    count = length(errors)
    plural = if count == 1, do: "error", else: "errors"
    formatted_errors = Enum.map_join(errors, "\n", &format_error/1)

    "Validation failed with #{count} #{plural}:\n#{formatted_errors}"
  end

  # Private functions

  defp build_error(nil, expected, got) do
    %{
      field: nil,
      expected: expected,
      got: got,
      message: "Expected #{expected} but got #{format_value(got)}"
    }
  end

  defp build_error(field, expected, got) when is_binary(field) do
    %{
      field: field,
      expected: expected,
      got: got,
      message: "Field '#{field}': Expected #{expected} but got #{format_value(got)}"
    }
  end

  defp build_error(field, expected, got) when is_atom(field) do
    build_error(to_string(field), expected, got)
  end

  defp normalize_error(%{field: _, expected: _, got: _, message: _} = error), do: error

  defp normalize_error(%{field: field, expected: expected, got: got}) do
    build_error(field, expected, got)
  end

  defp normalize_error(error) when is_map(error) do
    field = Map.get(error, :field)
    expected = Map.get(error, :expected, "valid value")
    got = Map.get(error, :got, "invalid value")
    build_error(field, expected, got)
  end

  defp build_repair_instructions([]), do: ""

  defp build_repair_instructions(errors) do
    instructions =
      errors
      |> Enum.map(&build_single_instruction/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    if instructions == "" do
      "Please correct the validation errors and provide valid output."
    else
      instructions
    end
  end

  defp build_single_instruction(%{field: nil, expected: expected}) do
    "Output must be: #{expected}"
  end

  defp build_single_instruction(%{field: field, expected: expected}) do
    "Field '#{field}' must be: #{expected}"
  end

  defp format_error(%{field: nil, message: message}), do: "- #{message}"

  defp format_error(%{field: field, message: message}), do: "- [#{field}] #{message}"

  defp format_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_value(value) when is_nil(value), do: "null"
  defp format_value(value) when is_boolean(value), do: to_string(value)
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(value) when is_atom(value), do: ":#{value}"
  defp format_value(value) when is_list(value), do: "list with #{length(value)} items"
  defp format_value(value) when is_map(value), do: "map with #{map_size(value)} keys"
  defp format_value(_value), do: "invalid type"
end
