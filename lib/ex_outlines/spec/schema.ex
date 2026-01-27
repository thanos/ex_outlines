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

  ## Field Specification

  Each field can have:
  - `type` - The field type (required)
  - `required` - Whether the field must be present (default: false)
  - `description` - Documentation for the field (optional)
  - `positive` - For integers, must be > 0 (optional, default: false)

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

  @type field_type :: :string | :integer | :boolean | :number | {:enum, [any()]}

  @type field_spec :: %{
          type: field_type(),
          required: boolean(),
          description: String.t() | nil,
          positive: boolean()
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
      positive: Keyword.get(opts, :positive, false)
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
      positive: Map.get(spec, :positive, false)
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
      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :integer, positive: true} = spec) do
      base = %{type: "integer", minimum: 1}
      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :integer} = spec) do
      base = %{type: "integer"}
      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :boolean} = spec) do
      base = %{type: "boolean"}
      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :number} = spec) do
      base = %{type: "number"}
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

    defp validate_field_type(_name, %{type: :string}, value) when is_binary(value), do: []

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

    defp validate_field_type(_name, %{type: :integer, positive: true}, value)
         when is_integer(value) and value > 0,
         do: []

    defp validate_field_type(name, %{type: :integer, positive: true}, value)
         when is_integer(value) do
      [
        %{
          field: to_string(name),
          expected: "positive integer (> 0)",
          got: value,
          message: "Field '#{name}' must be a positive integer (greater than 0)"
        }
      ]
    end

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

    defp validate_field_type(_name, %{type: :integer}, value) when is_integer(value), do: []

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

    defp validate_field_type(_name, %{type: :number}, value) when is_number(value), do: []

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
  end
end
