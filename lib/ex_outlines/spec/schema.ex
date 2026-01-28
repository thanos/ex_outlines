defmodule ExOutlines.Spec.Schema do
  @moduledoc """
  JSON schema-based constraint specification.

  Defines field types, required fields, enums, and validation rules.

  ## Supported Types

  - `:string` - String values
  - `:integer` - Integer values (supports `:positive` constraint)
  - `:boolean` - Boolean values (true/false)
  - `:number` - Numeric values (integer or float)
  - `{:enum, values}` - Enumerated values from a list
  - `{:array, item_spec}` - Array/list of items with validation

  ## Field Specification

  Each field can have:
  - `type` - The field type (required)
  - `required` - Whether the field must be present (default: false)
  - `description` - Documentation for the field (optional)
  - `positive` - For integers, must be > 0 (optional, default: false)
  - `min_length` - For strings, minimum length in characters (optional)
  - `max_length` - For strings, maximum length in characters (optional)
  - `min` - For integers/numbers, minimum value (optional)
  - `max` - For integers/numbers, maximum value (optional)

  ## Example

      schema = %ExOutlines.Spec.Schema{
        fields: %{
          name: %{type: :string, required: true, description: "User's full name"},
          age: %{type: :integer, required: true, positive: true},
          role: %{type: {:enum, ["admin", "user"]}, required: false},
          active: %{type: :boolean, required: false}
        }
      }

      # Valid input
      ExOutlines.Spec.validate(schema, %{"name" => "Alice", "age" => 30})
      # => {:ok, %{name: "Alice", age: 30}}

      # Invalid input (missing required field)
      ExOutlines.Spec.validate(schema, %{"name" => "Bob"})
      # => {:error, %Diagnostics{...}}
  """

  alias ExOutlines.Diagnostics

  @type item_spec :: %{
          type: :string | :integer | :boolean | :number | {:enum, [any()]},
          min_length: non_neg_integer() | nil,
          max_length: pos_integer() | nil,
          min: number() | nil,
          max: number() | nil
        }

  @type field_type :: :string | :integer | :boolean | :number | {:enum, [any()]} | {:array, item_spec()}

  @type field_spec :: %{
          type: field_type(),
          required: boolean(),
          description: String.t() | nil,
          positive: boolean(),
          min_length: non_neg_integer() | nil,
          max_length: pos_integer() | nil,
          min: number() | nil,
          max: number() | nil,
          min_items: non_neg_integer() | nil,
          max_items: pos_integer() | nil,
          unique_items: boolean()
        }

  @type t :: %__MODULE__{
          fields: %{atom() => field_spec()}
        }

  defstruct fields: %{}

  @doc """
  Create a new schema with field specifications.

  ## Examples

      iex> schema = ExOutlines.Spec.Schema.new(%{
      ...>   name: %{type: :string, required: true},
      ...>   age: %{type: :integer, required: true, positive: true}
      ...> })
      iex> is_struct(schema, ExOutlines.Spec.Schema)
      true
  """
  @spec new(map()) :: t()
  def new(fields) when is_map(fields) do
    normalized_fields =
      fields
      |> Enum.map(fn {key, spec} -> {key, normalize_field_spec(spec)} end)
      |> Enum.into(%{})

    %__MODULE__{fields: normalized_fields}
  end

  @doc """
  Add a field to an existing schema.

  ## Examples

      iex> schema = ExOutlines.Spec.Schema.new(%{})
      iex> schema = ExOutlines.Spec.Schema.add_field(schema, :name, :string, required: true)
      iex> Map.has_key?(schema.fields, :name)
      true
  """
  @spec add_field(t(), atom(), field_type(), keyword()) :: t()
  def add_field(%__MODULE__{fields: fields} = schema, name, type, opts \\ []) do
    field_spec = %{
      type: type,
      required: Keyword.get(opts, :required, false),
      description: Keyword.get(opts, :description),
      positive: Keyword.get(opts, :positive, false),
      min_length: Keyword.get(opts, :min_length),
      max_length: Keyword.get(opts, :max_length),
      min: Keyword.get(opts, :min),
      max: Keyword.get(opts, :max),
      min_items: Keyword.get(opts, :min_items),
      max_items: Keyword.get(opts, :max_items),
      unique_items: Keyword.get(opts, :unique_items, false)
    }

    %{schema | fields: Map.put(fields, name, field_spec)}
  end

  @doc """
  Get required field names from the schema.

  ## Examples

      iex> schema = ExOutlines.Spec.Schema.new(%{
      ...>   name: %{type: :string, required: true},
      ...>   age: %{type: :integer, required: false}
      ...> })
      iex> ExOutlines.Spec.Schema.required_fields(schema)
      [:name]
  """
  @spec required_fields(t()) :: [atom()]
  def required_fields(%__MODULE__{fields: fields}) do
    fields
    |> Enum.filter(fn {_name, spec} -> Map.get(spec, :required, false) end)
    |> Enum.map(fn {name, _spec} -> name end)
    |> Enum.sort()
  end

  # Private helpers

  defp normalize_field_spec(spec) when is_map(spec) do
    %{
      type: Map.fetch!(spec, :type),
      required: Map.get(spec, :required, false),
      description: Map.get(spec, :description),
      positive: Map.get(spec, :positive, false),
      min_length: Map.get(spec, :min_length),
      max_length: Map.get(spec, :max_length),
      min: Map.get(spec, :min),
      max: Map.get(spec, :max),
      min_items: Map.get(spec, :min_items),
      max_items: Map.get(spec, :max_items),
      unique_items: Map.get(spec, :unique_items, false)
    }
  end

  defimpl ExOutlines.Spec do
    alias ExOutlines.{Diagnostics, Spec.Schema}

    @doc """
    Convert schema to JSON Schema format for LLM prompts.
    """
    def to_schema(%Schema{fields: fields}) do
      properties =
        fields
        |> Enum.map(fn {name, spec} -> {name, field_to_json_schema(spec)} end)
        |> Enum.into(%{})

      required_fields =
        fields
        |> Enum.filter(fn {_name, spec} -> Map.get(spec, :required, false) end)
        |> Enum.map(fn {name, _spec} -> to_string(name) end)
        |> Enum.sort()

      schema = %{
        type: "object",
        properties: properties
      }

      if required_fields == [] do
        schema
      else
        Map.put(schema, :required, required_fields)
      end
    end

    @doc """
    Validate a value against the schema.

    Returns validated value with string keys converted to atoms.
    """
    def validate(%Schema{fields: fields}, value) when is_map(value) do
      # Convert string keys to atoms for processing
      normalized_value = normalize_keys(value)

      # Collect all validation errors
      errors = validate_all_fields(fields, normalized_value)

      if errors == [] do
        # Return validated map with atom keys
        {:ok, normalized_value}
      else
        {:error, Diagnostics.from_errors(errors)}
      end
    end

    def validate(%Schema{}, value) do
      {:error, Diagnostics.new("object (map)", value)}
    end

    # Private helpers

    defp field_to_json_schema(%{type: :string} = spec) do
      base = %{type: "string"}

      base =
        case Map.get(spec, :min_length) do
          nil -> base
          min_length -> Map.put(base, :minLength, min_length)
        end

      base =
        case Map.get(spec, :max_length) do
          nil -> base
          max_length -> Map.put(base, :maxLength, max_length)
        end

      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :integer} = spec) do
      base = %{type: "integer"}

      # Handle backward compatibility: positive: true is equivalent to min: 1
      min_value =
        case {Map.get(spec, :min), Map.get(spec, :positive)} do
          {nil, true} -> 1
          {min, _} -> min
        end

      base =
        case min_value do
          nil -> base
          min -> Map.put(base, :minimum, min)
        end

      base =
        case Map.get(spec, :max) do
          nil -> base
          max -> Map.put(base, :maximum, max)
        end

      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :boolean} = spec) do
      base = %{type: "boolean"}
      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :number} = spec) do
      base = %{type: "number"}

      base =
        case Map.get(spec, :min) do
          nil -> base
          min -> Map.put(base, :minimum, min)
        end

      base =
        case Map.get(spec, :max) do
          nil -> base
          max -> Map.put(base, :maximum, max)
        end

      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: {:enum, values}} = spec) do
      base = %{enum: values}
      add_description(base, spec)
    end

    defp add_description(schema, %{description: desc}) when is_binary(desc) do
      Map.put(schema, :description, desc)
    end

    defp add_description(schema, _spec), do: schema

    defp normalize_keys(map) when is_map(map) do
      map
      |> Enum.map(fn
        {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
        {key, value} when is_atom(key) -> {key, value}
      end)
      |> Enum.into(%{})
    rescue
      ArgumentError ->
        # If string key doesn't exist as atom, keep as is
        map
    end

    defp validate_all_fields(fields, value) do
      fields
      |> Enum.flat_map(fn {name, spec} ->
        validate_field(name, spec, value)
      end)
    end

    defp validate_field(name, spec, value) do
      field_value = Map.get(value, name)
      required = Map.get(spec, :required, false)

      cond do
        # Missing required field
        is_nil(field_value) and required ->
          [
            %{
              field: to_string(name),
              expected: "required field",
              got: nil,
              message: "Field '#{name}' is required but was not provided"
            }
          ]

        # Missing optional field - OK
        is_nil(field_value) ->
          []

        # Field present - validate type
        true ->
          validate_field_type(name, spec, field_value)
      end
    end

    defp validate_field_type(name, %{type: :string} = spec, value) when is_binary(value) do
      validate_string_constraints(name, spec, value)
    end

    defp validate_field_type(name, %{type: :string}, value) do
      [
        %{
          field: to_string(name),
          expected: "string",
          got: value,
          message: "Field '#{name}' must be a string"
        }
      ]
    end

    defp validate_field_type(name, %{type: :integer} = spec, value) when is_integer(value) do
      validate_integer_constraints(name, spec, value)
    end

    # Backward compatibility: non-integer with positive: true should show "positive integer" message
    defp validate_field_type(name, %{type: :integer, positive: true}, value) do
      [
        %{
          field: to_string(name),
          expected: "positive integer (> 0)",
          got: value,
          message: "Field '#{name}' must be a positive integer"
        }
      ]
    end

    defp validate_field_type(name, %{type: :integer}, value) do
      [
        %{
          field: to_string(name),
          expected: "integer",
          got: value,
          message: "Field '#{name}' must be an integer"
        }
      ]
    end

    defp validate_field_type(_name, %{type: :boolean}, value) when is_boolean(value), do: []

    defp validate_field_type(name, %{type: :boolean}, value) do
      [
        %{
          field: to_string(name),
          expected: "boolean",
          got: value,
          message: "Field '#{name}' must be a boolean (true or false)"
        }
      ]
    end

    defp validate_field_type(name, %{type: :number} = spec, value) when is_number(value) do
      validate_number_constraints(name, spec, value)
    end

    defp validate_field_type(name, %{type: :number}, value) do
      [
        %{
          field: to_string(name),
          expected: "number",
          got: value,
          message: "Field '#{name}' must be a number"
        }
      ]
    end

    defp validate_field_type(name, %{type: {:enum, allowed_values}}, value) do
      if value in allowed_values do
        []
      else
        [
          %{
            field: to_string(name),
            expected: "one of #{inspect(allowed_values)}",
            got: value,
            message: "Field '#{name}' must be one of: #{inspect(allowed_values)}"
          }
        ]
      end
    end

    defp validate_integer_constraints(name, spec, value) do
      errors = []

      # Handle backward compatibility: positive: true is equivalent to min: 1
      {min_value, use_positive_message} =
        case {Map.get(spec, :min), Map.get(spec, :positive)} do
          {nil, true} -> {1, true}
          {min, _} -> {min, false}
        end

      errors = errors ++ validate_min_constraint(name, min_value, value, use_positive_message)
      errors = errors ++ validate_max_constraint(name, Map.get(spec, :max), value)

      errors
    end

    defp validate_min_constraint(_name, nil, _value, _use_positive_message), do: []

    defp validate_min_constraint(name, min, value, use_positive_message) when value < min do
      {expected, message} =
        if use_positive_message do
          {"positive integer (> 0)", "Field '#{name}' must be a positive integer (greater than 0)"}
        else
          {"integer >= #{min}", "Field '#{name}' must be at least #{min}"}
        end

      [
        %{
          field: to_string(name),
          expected: expected,
          got: value,
          message: message
        }
      ]
    end

    defp validate_min_constraint(_name, _min, _value, _use_positive_message), do: []

    defp validate_max_constraint(_name, nil, _value), do: []

    defp validate_max_constraint(name, max, value) when value > max do
      [
        %{
          field: to_string(name),
          expected: "integer <= #{max}",
          got: value,
          message: "Field '#{name}' must be at most #{max}"
        }
      ]
    end

    defp validate_max_constraint(_name, _max, _value), do: []

    defp validate_number_constraints(name, spec, value) do
      errors = []

      errors =
        case Map.get(spec, :min) do
          nil ->
            errors

          min when value < min ->
            [
              %{
                field: to_string(name),
                expected: "number >= #{min}",
                got: value,
                message: "Field '#{name}' must be at least #{min}"
              }
              | errors
            ]

          _ ->
            errors
        end

      errors =
        case Map.get(spec, :max) do
          nil ->
            errors

          max when value > max ->
            [
              %{
                field: to_string(name),
                expected: "number <= #{max}",
                got: value,
                message: "Field '#{name}' must be at most #{max}"
              }
              | errors
            ]

          _ ->
            errors
        end

      Enum.reverse(errors)
    end

    defp validate_string_constraints(name, spec, value) do
      errors = []
      length = String.length(value)

      errors =
        case Map.get(spec, :min_length) do
          nil ->
            errors

          min_length when length < min_length ->
            [
              %{
                field: to_string(name),
                expected: "string with at least #{min_length} characters",
                got: value,
                message: "Field '#{name}' must be at least #{min_length} characters"
              }
              | errors
            ]

          _ ->
            errors
        end

      errors =
        case Map.get(spec, :max_length) do
          nil ->
            errors

          max_length when length > max_length ->
            [
              %{
                field: to_string(name),
                expected: "string with at most #{max_length} characters",
                got: value,
                message: "Field '#{name}' must be at most #{max_length} characters"
              }
              | errors
            ]

          _ ->
            errors
        end

      Enum.reverse(errors)
    end
  end
end
