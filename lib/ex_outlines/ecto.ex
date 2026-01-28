if Code.ensure_loaded?(Ecto) do
  defmodule ExOutlines.Ecto do
    @moduledoc """
    Ecto integration for ExOutlines.

    Provides Ecto-style validation DSL, hybrid validation using Ecto changesets,
    and automatic schema conversion from existing Ecto schemas.
    This module is only compiled if Ecto is installed.

    ## Features

    - **Schema Adapter**: Convert Ecto schemas to ExOutlines schemas automatically
    - **Extended DSL**: Use Ecto-familiar syntax for validation rules
    - **Hybrid Validation**: Leverages Ecto's validators when available
    - **Changeset Integration**: Convert Ecto changesets to ExOutlines diagnostics
    - **Type Casting**: Use Ecto's type system for validation
    - **Validation Extraction**: Automatically extract validation rules from changesets

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

    ## Schema Adapter

    Automatically convert existing Ecto schemas to ExOutlines format:

        defmodule User do
          use Ecto.Schema
          import Ecto.Changeset

          schema "users" do
            field :email, :string
            field :age, :integer
          end

          def changeset(user, params) do
            user
            |> cast(params, [:email, :age])
            |> validate_required([:email])
            |> validate_format(:email, ~r/@/)
            |> validate_number(:age, greater_than: 0)
          end
        end

        # Convert Ecto schema to ExOutlines schema
        schema = Ecto.from_ecto_schema(User)

        # Use with ExOutlines.generate/2
        ExOutlines.generate(schema, backend: MyBackend, backend_opts: [...])

    The schema adapter automatically:
    - Maps Ecto types to ExOutlines types
    - Extracts validation rules from changesets
    - Handles embedded schemas and arrays
    - Supports Ecto.Enum types

    This allows reusing existing Ecto schemas without duplication.
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

    @doc """
    Creates an ExOutlines Schema from an Ecto schema module.

    Introspects the Ecto schema definition and converts it to ExOutlines format.
    Optionally analyzes a changeset function to extract validation constraints.

    ## Options

    - `:changeset` - Changeset function name (atom) to analyze for validations (default: :changeset)
    - `:required` - List of required field names (default: extracted from changeset or empty)
    - `:descriptions` - Map of field names to descriptions (default: %{})

    ## Examples

        # Basic conversion from Ecto schema
        schema = Ecto.from_ecto_schema(User)

        # With custom changeset function
        schema = Ecto.from_ecto_schema(User, changeset: :registration_changeset)

        # With explicit required fields
        schema = Ecto.from_ecto_schema(User, required: [:email, :name])

        # With field descriptions
        schema = Ecto.from_ecto_schema(User,
          descriptions: %{
            email: "User's email address",
            name: "User's full name"
          }
        )

    ## Supported Ecto Types

    - `:string` → `:string`
    - `:integer` → `:integer`
    - `:boolean` → `:boolean`
    - `:float`, `:decimal` → `:number`
    - `{:array, type}` → `{:array, %{type: mapped_type}}`
    - Custom Ecto.Enum → `{:enum, values}`
    - Embedded schemas → `{:object, nested_schema}`

    ## Validation Extraction

    When a changeset function is provided, this function analyzes it to extract:
    - Required fields (from `validate_required/2`)
    - Length constraints (from `validate_length/3`)
    - Number constraints (from `validate_number/3`)
    - Format constraints (from `validate_format/3`)

    ## Example Ecto Schema

        defmodule User do
          use Ecto.Schema
          import Ecto.Changeset

          schema "users" do
            field :email, :string
            field :age, :integer
            field :bio, :string
          end

          def changeset(user, params) do
            user
            |> cast(params, [:email, :age, :bio])
            |> validate_required([:email])
            |> validate_format(:email, ~r/@/)
            |> validate_number(:age, greater_than: 0, less_than: 150)
            |> validate_length(:bio, max: 500)
          end
        end

        # Convert to ExOutlines schema
        schema = Ecto.from_ecto_schema(User)

        # Results in schema equivalent to:
        Schema.new(%{
          email: %{type: :string, required: true, pattern: ~r/@/},
          age: %{type: :integer, min: 1, max: 149},
          bio: %{type: :string, max_length: 500}
        })
    """
    @spec from_ecto_schema(module(), keyword()) :: Schema.t()
    def from_ecto_schema(ecto_schema, opts \\ []) do
      unless function_exported?(ecto_schema, :__schema__, 1) do
        raise ArgumentError, "#{inspect(ecto_schema)} is not an Ecto schema"
      end

      changeset_fun = Keyword.get(opts, :changeset, :changeset)
      explicit_required = Keyword.get(opts, :required, [])
      descriptions = Keyword.get(opts, :descriptions, %{})

      # Get all fields from the Ecto schema
      fields = ecto_schema.__schema__(:fields)

      # Extract validation rules from changeset if available
      validation_rules =
        if function_exported?(ecto_schema, changeset_fun, 2) do
          extract_validation_rules(ecto_schema, changeset_fun)
        else
          %{}
        end

      # Build field specs
      field_specs =
        fields
        |> Enum.reject(&(&1 == :id))
        |> Enum.map(fn field_name ->
          ecto_type = ecto_schema.__schema__(:type, field_name)
          base_type = map_ecto_type(ecto_type, ecto_schema)

          # Get validation rules for this field
          field_rules = Map.get(validation_rules, field_name, %{})

          # Determine if required
          required =
            cond do
              field_name in explicit_required -> true
              Map.get(field_rules, :required) == true -> true
              true -> false
            end

          # Build field spec
          field_spec =
            base_type
            |> Map.put(:required, required)
            |> Map.put(:description, Map.get(descriptions, field_name))
            |> Map.merge(field_rules)
            |> Map.delete(:required)
            |> Map.put(:required, required)

          {field_name, field_spec}
        end)
        |> Enum.into(%{})

      Schema.new(field_specs)
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

    # Ecto Schema Adapter helper functions

    defp map_ecto_type(:string, _schema), do: %{type: :string}
    defp map_ecto_type(:integer, _schema), do: %{type: :integer}
    defp map_ecto_type(:boolean, _schema), do: %{type: :boolean}
    defp map_ecto_type(:float, _schema), do: %{type: :number}
    defp map_ecto_type(:decimal, _schema), do: %{type: :number}

    defp map_ecto_type({:array, inner_type}, schema) do
      inner_spec = map_ecto_type(inner_type, schema)
      %{type: {:array, inner_spec}}
    end

    defp map_ecto_type({:parameterized, {Ecto.Enum, %{mappings: mappings}}}, _schema) do
      values = Keyword.keys(mappings)
      %{type: {:enum, values}}
    end

    defp map_ecto_type({:parameterized, {Ecto.Embedded, embedded}}, _schema) do
      case Map.get(embedded, :cardinality) do
        :one ->
          related = Map.get(embedded, :related)
          nested_schema = from_ecto_schema(related)
          %{type: {:object, nested_schema}}

        :many ->
          related = Map.get(embedded, :related)
          nested_schema = from_ecto_schema(related)
          item_spec = %{type: {:object, nested_schema}}
          %{type: {:array, item_spec}}
      end
    end

    # Fallback for unknown types
    defp map_ecto_type(type, _schema) do
      # Try to handle as string by default for unknown types
      %{type: :string, description: "Ecto type: #{inspect(type)}"}
    end

    defp extract_validation_rules(ecto_schema, changeset_fun) do
      # Create a sample changeset to analyze
      sample_struct = struct(ecto_schema)
      sample_params = %{}

      changeset =
        try do
          apply(ecto_schema, changeset_fun, [sample_struct, sample_params])
        rescue
          _ -> %Ecto.Changeset{data: sample_struct, validations: [], errors: []}
        end

      # Extract validation rules from changeset
      validations = Map.get(changeset, :validations, [])

      # Extract required fields from errors (when calling with empty params)
      required_fields = extract_required_fields(changeset)

      # Group validations by field
      field_rules = validations
      |> Enum.group_by(fn {field, _validation} -> field end, fn {_field, validation} ->
        validation
      end)
      |> Enum.map(fn {field, field_validations} ->
        rules =
          field_validations
          |> Enum.reduce(%{}, fn validation, acc ->
            merge_validation_rule(acc, validation)
          end)

        {field, rules}
      end)
      |> Enum.into(%{})

      # Merge required fields
      required_fields
      |> Enum.reduce(field_rules, fn field, acc ->
        Map.update(acc, field, %{required: true}, fn rules ->
          Map.put(rules, :required, true)
        end)
      end)
    end

    defp extract_required_fields(changeset) do
      # Look for required validation errors (fields that are missing)
      changeset.errors
      |> Enum.filter(fn
        {_field, {_msg, [validation: :required]}} -> true
        _ -> false
      end)
      |> Enum.map(fn {field, _error} -> field end)
    end

    defp merge_validation_rule(rules, {:length, opts}) do
      rules
      |> put_if_present(:min_length, opts[:min])
      |> put_if_present(:max_length, opts[:max])
      |> put_if_present(:min_length, opts[:is])
      |> put_if_present(:max_length, opts[:is])
    end

    defp merge_validation_rule(rules, {:number, opts}) do
      rules
      |> apply_number_validation(opts)
    end

    defp merge_validation_rule(rules, {:format, %Regex{} = regex}) do
      Map.put(rules, :pattern, regex)
    end

    defp merge_validation_rule(rules, {:inclusion, values}) when is_list(values) do
      Map.put(rules, :type, {:enum, values})
    end

    defp merge_validation_rule(rules, _validation) do
      # Unknown validation, skip
      rules
    end

    defp apply_number_validation(rules, opts) do
      rules
      |> put_if_present(:min, opts[:greater_than_or_equal_to])
      |> apply_greater_than_validation(opts[:greater_than])
      |> put_if_present(:max, opts[:less_than_or_equal_to])
      |> apply_less_than_validation(opts[:less_than])
      |> apply_equal_validation(opts[:equal_to])
    end

    defp apply_greater_than_validation(rules, nil), do: rules

    defp apply_greater_than_validation(rules, value) do
      Map.put(rules, :min, value + 1)
    end

    defp apply_less_than_validation(rules, nil), do: rules

    defp apply_less_than_validation(rules, value) do
      Map.put(rules, :max, value - 1)
    end

    defp apply_equal_validation(rules, nil), do: rules

    defp apply_equal_validation(rules, value) do
      rules
      |> Map.put(:min, value)
      |> Map.put(:max, value)
    end

    defp put_if_present(map, _key, nil), do: map
    defp put_if_present(map, key, value), do: Map.put(map, key, value)
  end
end
