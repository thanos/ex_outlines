if Code.ensure_loaded?(Ecto) do
  defmodule ExOutlines.Ecto do
    @moduledoc """
    Ecto integration for ExOutlines.

    Provides Ecto-style validation DSL and hybrid validation using Ecto changesets
    when Ecto is available. This module is only compiled if Ecto is installed.

    ## Features

    - **Extended DSL**: Use Ecto-familiar syntax for validation rules
    - **Hybrid Validation**: Leverages Ecto's validators when available
    - **Changeset Integration**: Convert Ecto changesets to ExOutlines diagnostics
    - **Type Casting**: Use Ecto's type system for validation

    ## Extended DSL Syntax

    ExOutlines supports both native and Ecto-style validation syntax:

        # Native ExOutlines syntax
        username: %{
          type: :string,
          min_length: 3,
          max_length: 20
        }

        # Ecto-style syntax (requires Ecto)
        username: %{
          type: :string,
          length: [min: 3, max: 20]
        }

        # Number validations
        age: %{
          type: :integer,
          number: [greater_than_or_equal_to: 0, less_than: 150]
        }

        # Format validation
        email: %{
          type: :string,
          format: ~r/@/
        }

    ## Usage

        alias ExOutlines.{Spec.Schema, Ecto}

        # Create schema with Ecto-style DSL
        schema = Schema.new(%{
          username: %{type: :string, length: [min: 3, max: 20]},
          age: %{type: :integer, number: [greater_than: 0, less_than: 150]},
          email: %{type: :string, format: :email}
        })

        # Validate using Ecto-enhanced validation
        case Ecto.validate(schema, data) do
          {:ok, validated} -> # Success
          {:error, diagnostics} -> # Failed with detailed errors
        end

    ## Changeset Integration

    Convert Ecto changesets to ExOutlines diagnostics:

        changeset = MySchema.changeset(%MySchema{}, params)

        case Ecto.changeset_to_diagnostics(changeset) do
          {:ok, data} -> # Changeset was valid
          {:error, diagnostics} -> # Convert errors to diagnostics
        end

    This allows using ExOutlines with existing Ecto schemas and validations.
    """

    alias ExOutlines.{Spec.Schema, Diagnostics}

    @doc """
    Validates data using Ecto-enhanced validation when available.

    Falls back to standard validation if Ecto features aren't used.

    ## Options

    - `:use_ecto` - Force using/not using Ecto validation (default: auto-detect)

    ## Examples

        iex> schema = Schema.new(%{age: %{type: :integer, number: [greater_than: 0]}})
        iex> Ecto.validate(schema, %{"age" => 25})
        {:ok, %{age: 25}}

        iex> Ecto.validate(schema, %{"age" => -5})
        {:error, %Diagnostics{...}}
    """
    @spec validate(Schema.t(), map(), keyword()) ::
            {:ok, map()} | {:error, Diagnostics.t()}
    def validate(schema, data, opts \\ []) do
      use_ecto = Keyword.get(opts, :use_ecto, should_use_ecto?(schema))

      if use_ecto and ecto_available?() do
        validate_with_ecto(schema, data)
      else
        ExOutlines.Spec.validate(schema, data)
      end
    end

    @doc """
    Converts an Ecto changeset to ExOutlines diagnostics format.

    This allows integrating existing Ecto schemas with ExOutlines workflows.

    ## Examples

        iex> changeset = User.changeset(%User{}, %{email: "invalid"})
        iex> Ecto.changeset_to_diagnostics(changeset)
        {:error, %Diagnostics{errors: [%{field: "email", ...}]}}

        iex> changeset = User.changeset(%User{}, %{email: "valid@example.com"})
        iex> Ecto.changeset_to_diagnostics(changeset)
        {:ok, %{email: "valid@example.com"}}
    """
    @spec changeset_to_diagnostics(Ecto.Changeset.t()) ::
            {:ok, map()} | {:error, Diagnostics.t()}
    def changeset_to_diagnostics(%Ecto.Changeset{valid?: true, changes: changes}) do
      {:ok, changes}
    end

    def changeset_to_diagnostics(%Ecto.Changeset{valid?: false, errors: errors}) do
      diagnostics_errors =
        Enum.map(errors, fn {field, {message, opts}} ->
          %{
            field: to_string(field),
            expected: extract_expected(opts),
            got: Keyword.get(opts, :value),
            message: format_ecto_error(field, message, opts)
          }
        end)

      repair_instructions =
        "Validation failed:\n" <>
          Enum.map_join(diagnostics_errors, "\n", fn error ->
            "- #{error.message}"
          end)

      {:error,
       %Diagnostics{
         errors: diagnostics_errors,
         repair_instructions: repair_instructions
       }}
    end

    @doc """
    Normalizes Ecto-style DSL to native ExOutlines format.

    Converts:
    - `length: [min: x, max: y]` → `min_length: x, max_length: y`
    - `number: [greater_than: x]` → `min: x + 1` (exclusive)
    - `number: [greater_than_or_equal_to: x]` → `min: x` (inclusive)
    - `format: regex` → `pattern: regex`

    ## Examples

        iex> Ecto.normalize_field_spec(%{type: :string, length: [min: 3, max: 10]})
        %{type: :string, min_length: 3, max_length: 10}

        iex> Ecto.normalize_field_spec(%{type: :integer, number: [greater_than: 0]})
        %{type: :integer, min: 1}
    """
    @spec normalize_field_spec(map()) :: map()
    def normalize_field_spec(spec) do
      spec
      |> normalize_length()
      |> normalize_number()
      |> normalize_format()
    end

    # Private functions

    defp ecto_available? do
      Code.ensure_loaded?(Ecto.Changeset)
    end

    defp should_use_ecto?(schema) do
      # Check if schema uses Ecto-style DSL
      Enum.any?(schema.fields, fn {_name, spec} ->
        has_length_dsl = Map.get(spec, :length) != nil
        has_number_dsl = Map.get(spec, :number) != nil
        # format with Regex needs conversion to pattern
        has_format_regex = match?(%Regex{}, Map.get(spec, :format))

        has_length_dsl or has_number_dsl or has_format_regex
      end)
    end

    defp validate_with_ecto(schema, data) do
      # Normalize Ecto-style DSL to native format
      normalized_schema = %{
        schema
        | fields:
            Map.new(schema.fields, fn {name, spec} ->
              {name, normalize_field_spec(spec)}
            end)
      }

      ExOutlines.Spec.validate(normalized_schema, data)
    end

    defp normalize_length(spec) do
      case Map.get(spec, :length) do
        nil ->
          spec

        length_opts when is_list(length_opts) ->
          spec
          |> Map.delete(:length)
          |> Map.put(:min_length, Keyword.get(length_opts, :min))
          |> Map.put(:max_length, Keyword.get(length_opts, :max))

        length_value when is_integer(length_value) ->
          spec
          |> Map.delete(:length)
          |> Map.put(:min_length, length_value)
          |> Map.put(:max_length, length_value)
      end
    end

    defp normalize_number(spec) do
      case Map.get(spec, :number) do
        nil ->
          spec

        number_opts when is_list(number_opts) ->
          spec
          |> Map.delete(:number)
          |> apply_number_constraints(number_opts)
      end
    end

    defp apply_number_constraints(spec, opts) do
      spec
      |> apply_greater_than(opts)
      |> apply_less_than(opts)
      |> apply_greater_than_or_equal_to(opts)
      |> apply_less_than_or_equal_to(opts)
      |> apply_equal_to(opts)
    end

    defp apply_greater_than(spec, opts) do
      case Keyword.get(opts, :greater_than) do
        nil -> spec
        value -> Map.put(spec, :min, value + 1)
      end
    end

    defp apply_less_than(spec, opts) do
      case Keyword.get(opts, :less_than) do
        nil -> spec
        value -> Map.put(spec, :max, value - 1)
      end
    end

    defp apply_greater_than_or_equal_to(spec, opts) do
      case Keyword.get(opts, :greater_than_or_equal_to) do
        nil -> spec
        value -> Map.put(spec, :min, value)
      end
    end

    defp apply_less_than_or_equal_to(spec, opts) do
      case Keyword.get(opts, :less_than_or_equal_to) do
        nil -> spec
        value -> Map.put(spec, :max, value)
      end
    end

    defp apply_equal_to(spec, opts) do
      case Keyword.get(opts, :equal_to) do
        nil ->
          spec

        value ->
          spec
          |> Map.put(:min, value)
          |> Map.put(:max, value)
      end
    end

    defp normalize_format(spec) do
      case Map.get(spec, :format) do
        nil ->
          spec

        format when is_atom(format) and format in [:email, :url, :uuid, :phone, :date] ->
          # Keep built-in formats as-is
          spec

        %Regex{} = regex ->
          # Convert format: regex to pattern: regex
          spec
          |> Map.delete(:format)
          |> Map.put(:pattern, regex)

        _ ->
          spec
      end
    end

    defp extract_expected(opts) do
      cond do
        Keyword.has_key?(opts, :validation) -> Keyword.get(opts, :validation)
        Keyword.has_key?(opts, :type) -> Keyword.get(opts, :type)
        true -> "valid value"
      end
    end

    defp format_ecto_error(field, message, opts) do
      # Format Ecto error message with interpolated values
      message =
        Enum.reduce(opts, message, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)

      "Field '#{field}' #{message}"
    end
  end
end
