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
  - `min_items` - For arrays, minimum number of items (optional)
  - `max_items` - For arrays, maximum number of items (optional)
  - `unique_items` - For arrays, whether items must be unique (default: false)
  - `pattern` - For strings, custom regex pattern (Regex.t() or string)
  - `format` - For strings, built-in format (:email, :url, :uuid, :phone, :date)

  ## Example

      address_schema = %ExOutlines.Spec.Schema{
        fields: %{
          city: %{type: :string, required: true},
          zip_code: %{type: :string, required: true, min_length: 5}
        }
      }

      schema = %ExOutlines.Spec.Schema{
        fields: %{
          name: %{type: :string, required: true, description: "User's full name"},
          age: %{type: :integer, required: true, positive: true},
          role: %{type: {:enum, ["admin", "user"]}, required: false},
          active: %{type: :boolean, required: false},
          tags: %{type: {:array, %{type: :string, max_length: 20}}, max_items: 10},
          address: %{type: {:object, address_schema}, required: true}
        }
      }

      # Valid input with nested object
      ExOutlines.Spec.validate(schema, %{
        "name" => "Alice",
        "age" => 30,
        "tags" => ["elixir"],
        "address" => %{"city" => "NYC", "zip_code" => "10001"}
      })
      # => {:ok, %{name: "Alice", age: 30, tags: ["elixir"], address: %{city: "NYC", zip_code: "10001"}}}

      # Invalid input (missing required field)
      ExOutlines.Spec.validate(schema, %{"name" => "Bob"})
      # => {:error, %Diagnostics{...}}
  """

  alias ExOutlines.Diagnostics

  # Built-in format patterns
  @email_pattern ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
  @url_pattern ~r/^https?:\/\/[^\s]+$/
  @uuid_pattern ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  @phone_pattern ~r/^\d{3}-\d{3}-\d{4}$/
  @date_pattern ~r/^\d{4}-\d{2}-\d{2}$/

  @type format :: :email | :url | :uuid | :phone | :date

  @type item_spec :: %{
          type: :string | :integer | :boolean | :number | {:enum, [any()]},
          min_length: non_neg_integer() | nil,
          max_length: pos_integer() | nil,
          min: number() | nil,
          max: number() | nil
        }

  @type field_type ::
          :string | :integer | :boolean | :number | {:enum, [any()]} | {:array, item_spec()}

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
          unique_items: boolean(),
          pattern: Regex.t() | nil
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
      unique_items: Keyword.get(opts, :unique_items, false),
      pattern: Keyword.get(opts, :pattern),
      format: Keyword.get(opts, :format)
    }

    %{schema | fields: Map.put(fields, name, normalize_field_spec(field_spec))}
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
    # If Ecto is available, normalize Ecto-style DSL first
    spec =
      if Code.ensure_loaded?(ExOutlines.Ecto) do
        ExOutlines.Ecto.normalize_field_spec(spec)
      else
        spec
      end

    # Compile string pattern to Regex if needed
    pattern =
      case Map.get(spec, :pattern) do
        nil -> nil
        %Regex{} = regex -> regex
        pattern when is_binary(pattern) -> Regex.compile!(pattern)
      end

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
      unique_items: Map.get(spec, :unique_items, false),
      pattern: pattern,
      format: Map.get(spec, :format),
      # Preserve Ecto-style DSL fields for optional Ecto integration
      length: Map.get(spec, :length),
      number: Map.get(spec, :number)
    }
  end

  # Get built-in regex pattern for a format type
  @doc false
  def get_format_pattern(:email), do: @email_pattern
  def get_format_pattern(:url), do: @url_pattern
  def get_format_pattern(:uuid), do: @uuid_pattern
  def get_format_pattern(:phone), do: @phone_pattern
  def get_format_pattern(:date), do: @date_pattern

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

    # Map internal formats to JSON Schema formats
    defp to_json_schema_format(:email), do: "email"
    defp to_json_schema_format(:url), do: "uri"
    defp to_json_schema_format(:uuid), do: "uuid"
    defp to_json_schema_format(:phone), do: "phone"
    defp to_json_schema_format(:date), do: "date"

    defp field_to_json_schema(%{type: :string} = spec) do
      base = %{type: "string"}

      base =
        case Map.get(spec, :format) do
          nil -> base
          format -> Map.put(base, :format, to_json_schema_format(format))
        end

      base =
        case Map.get(spec, :pattern) do
          nil -> base
          %Regex{source: source} -> Map.put(base, :pattern, source)
        end

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

    defp field_to_json_schema(%{type: {:array, item_spec}} = spec) do
      base = %{
        type: "array",
        items: item_spec_to_json_schema(item_spec)
      }

      base =
        case Map.get(spec, :min_items) do
          nil -> base
          min_items -> Map.put(base, :minItems, min_items)
        end

      base =
        case Map.get(spec, :max_items) do
          nil -> base
          max_items -> Map.put(base, :maxItems, max_items)
        end

      base =
        if Map.get(spec, :unique_items, false) do
          Map.put(base, :uniqueItems, true)
        else
          base
        end

      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: {:object, nested_schema}} = spec) do
      # Recursively generate JSON Schema for nested object
      nested_json_schema = ExOutlines.Spec.to_schema(nested_schema)

      base = %{
        type: "object",
        properties: nested_json_schema.properties
      }

      # Add required fields if present
      base =
        if Map.has_key?(nested_json_schema, :required) do
          Map.put(base, :required, nested_json_schema.required)
        else
          base
        end

      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: :null} = spec) do
      base = %{type: "null"}
      add_description(base, spec)
    end

    defp field_to_json_schema(%{type: {:union, type_specs}} = spec) do
      # Generate JSON Schema for each type in the union
      one_of =
        Enum.map(type_specs, fn type_spec ->
          # Convert each type spec to a mini field spec without description
          mini_spec = Map.delete(type_spec, :description)
          field_to_json_schema(mini_spec)
        end)

      base = %{oneOf: one_of}
      add_description(base, spec)
    end

    defp item_spec_to_json_schema(%{type: :string} = spec) do
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

      base
    end

    defp item_spec_to_json_schema(%{type: :integer} = spec) do
      base = %{type: "integer"}

      {min_value, _} =
        case {Map.get(spec, :min), Map.get(spec, :positive)} do
          {nil, true} -> {1, true}
          {min, _} -> {min, false}
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

      base
    end

    defp item_spec_to_json_schema(%{type: :number} = spec) do
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

      base
    end

    defp item_spec_to_json_schema(%{type: :boolean}) do
      %{type: "boolean"}
    end

    defp item_spec_to_json_schema(%{type: {:enum, values}}) do
      %{enum: values}
    end

    defp item_spec_to_json_schema(%{type: {:object, nested_schema}}) do
      # Recursively generate JSON Schema for nested object in array
      nested_json_schema = ExOutlines.Spec.to_schema(nested_schema)

      base = %{
        type: "object",
        properties: nested_json_schema.properties
      }

      # Add required fields if present
      if Map.has_key?(nested_json_schema, :required) do
        Map.put(base, :required, nested_json_schema.required)
      else
        base
      end
    end

    defp add_description(schema, %{description: desc}) when is_binary(desc) do
      Map.put(schema, :description, desc)
    end

    defp add_description(schema, _spec), do: schema

    defp normalize_keys(map) when is_map(map) do
      map
      |> Enum.map(fn
        {key, value} when is_binary(key) ->
          {String.to_existing_atom(key), normalize_value(value)}

        {key, value} when is_atom(key) ->
          {key, normalize_value(value)}
      end)
      |> Enum.into(%{})
    rescue
      ArgumentError ->
        # If string key doesn't exist as atom, keep as is
        map
    end

    # Recursively normalize nested maps and arrays
    defp normalize_value(value) when is_map(value), do: normalize_keys(value)
    defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)
    defp normalize_value(value), do: value

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

    defp validate_field_type(name, %{type: {:array, item_spec}} = spec, value)
         when is_list(value) do
      errors = []

      # Validate array length constraints
      errors = errors ++ validate_array_length(name, spec, value)

      # Validate unique items constraint
      errors = errors ++ validate_unique_items(name, spec, value)

      # Validate each item
      item_errors =
        value
        |> Enum.with_index()
        |> Enum.flat_map(fn {item, index} ->
          validate_array_item(name, index, item_spec, item)
        end)

      errors ++ item_errors
    end

    defp validate_field_type(name, %{type: {:array, _}}, value) do
      [
        %{
          field: to_string(name),
          expected: "array",
          got: value,
          message: "Field '#{name}' must be an array"
        }
      ]
    end

    defp validate_field_type(name, %{type: {:object, nested_schema}}, value)
         when is_map(value) do
      # Recursively validate nested object
      case ExOutlines.Spec.validate(nested_schema, value) do
        {:ok, _validated} ->
          # Nested object is valid
          []

        {:error, diagnostics} ->
          # Nested object has errors - prefix field names with parent path
          diagnostics.errors
          |> Enum.map(fn error ->
            prefix_field_path(error, name)
          end)
      end
    end

    defp validate_field_type(name, %{type: {:object, _}}, value) do
      [
        %{
          field: to_string(name),
          expected: "object",
          got: value,
          message: "Field '#{name}' must be an object"
        }
      ]
    end

    # Null type validation
    defp validate_field_type(_name, %{type: :null}, nil), do: []

    defp validate_field_type(name, %{type: :null}, value) do
      [
        %{
          field: to_string(name),
          expected: "null",
          got: value,
          message: "Field '#{name}' must be null"
        }
      ]
    end

    # Union type validation - try each type in order
    defp validate_field_type(name, %{type: {:union, type_specs}}, value) do
      # Try to validate against each type spec
      results =
        Enum.map(type_specs, fn spec ->
          # Create a temporary field spec and validate
          temp_spec = Map.merge(%{required: false}, spec)
          validate_field_type(name, temp_spec, value)
        end)

      # Find first successful validation (empty error list)
      case Enum.find(results, &(&1 == [])) do
        [] ->
          # Success! One type matched
          []

        nil ->
          # All failed - build combined error message
          type_descriptions = Enum.map(type_specs, &describe_type_spec/1)
          types_list = Enum.join(type_descriptions, "\n - ")

          message =
            """
            Field '#{name}' must match one of the following types:
             - #{types_list}
            Got: #{inspect(value)} which failed all validations
            """
            |> String.trim()

          [
            %{
              field: to_string(name),
              expected: "one of multiple types",
              got: value,
              message: message
            }
          ]
      end
    end

    # Generate human-readable description of a type spec for error messages
    defp describe_type_spec(%{type: :null}), do: "Null"

    defp describe_type_spec(%{type: :string, pattern: pattern}) when not is_nil(pattern),
      do: "String matching pattern #{inspect(pattern)}"

    defp describe_type_spec(%{type: :string, format: format}) when not is_nil(format),
      do: "String with #{format} format"

    defp describe_type_spec(%{type: :string, min_length: min, max_length: max})
         when not is_nil(min) and not is_nil(max),
         do: "String with length between #{min} and #{max}"

    defp describe_type_spec(%{type: :string, min_length: min}) when not is_nil(min),
      do: "String with minimum length #{min}"

    defp describe_type_spec(%{type: :string, max_length: max}) when not is_nil(max),
      do: "String with maximum length #{max}"

    defp describe_type_spec(%{type: :string}), do: "String"
    defp describe_type_spec(%{type: :integer, positive: true}), do: "Positive integer (> 0)"

    defp describe_type_spec(%{type: :integer, min: min, max: max})
         when not is_nil(min) and not is_nil(max),
         do: "Integer between #{min} and #{max}"

    defp describe_type_spec(%{type: :integer, min: min}) when not is_nil(min),
      do: "Integer >= #{min}"

    defp describe_type_spec(%{type: :integer, max: max}) when not is_nil(max),
      do: "Integer <= #{max}"

    defp describe_type_spec(%{type: :integer}), do: "Integer"
    defp describe_type_spec(%{type: :boolean}), do: "Boolean"

    defp describe_type_spec(%{type: :number, min: min, max: max})
         when not is_nil(min) and not is_nil(max),
         do: "Number between #{min} and #{max}"

    defp describe_type_spec(%{type: :number, min: min}) when not is_nil(min),
      do: "Number >= #{min}"

    defp describe_type_spec(%{type: :number, max: max}) when not is_nil(max),
      do: "Number <= #{max}"

    defp describe_type_spec(%{type: :number}), do: "Number"
    defp describe_type_spec(%{type: {:enum, values}}), do: "One of: #{inspect(values)}"
    defp describe_type_spec(%{type: {:array, _}}), do: "Array"
    defp describe_type_spec(%{type: {:object, _}}), do: "Object"
    defp describe_type_spec(%{type: {:union, _}}), do: "Union type"
    defp describe_type_spec(_), do: "Unknown type"

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
      errors = errors ++ validate_format_constraint(name, spec, value)
      errors = errors ++ validate_pattern_constraint(name, spec, value)
      errors = errors ++ validate_min_length_constraint(name, spec, value)
      errors = errors ++ validate_max_length_constraint(name, spec, value)
      errors
    end

    defp validate_format_constraint(name, spec, value) do
      case Map.get(spec, :format) do
        nil ->
          []

        format ->
          pattern = Schema.get_format_pattern(format)

          if Regex.match?(pattern, value) do
            []
          else
            [
              %{
                field: to_string(name),
                expected: "string matching #{format} format",
                got: value,
                message: "Field '#{name}' must be a valid #{format}"
              }
            ]
          end
      end
    end

    defp validate_pattern_constraint(name, spec, value) do
      case Map.get(spec, :pattern) do
        nil ->
          []

        pattern ->
          if Regex.match?(pattern, value) do
            []
          else
            [
              %{
                field: to_string(name),
                expected: "string matching pattern #{inspect(pattern)}",
                got: value,
                message: "Field '#{name}' must match pattern #{inspect(pattern)}"
              }
            ]
          end
      end
    end

    defp validate_min_length_constraint(name, spec, value) do
      length = String.length(value)

      case Map.get(spec, :min_length) do
        nil ->
          []

        min_length when length < min_length ->
          [
            %{
              field: to_string(name),
              expected: "string with at least #{min_length} characters",
              got: value,
              message: "Field '#{name}' must be at least #{min_length} characters"
            }
          ]

        _ ->
          []
      end
    end

    defp validate_max_length_constraint(name, spec, value) do
      length = String.length(value)

      case Map.get(spec, :max_length) do
        nil ->
          []

        max_length when length > max_length ->
          [
            %{
              field: to_string(name),
              expected: "string with at most #{max_length} characters",
              got: value,
              message: "Field '#{name}' must be at most #{max_length} characters"
            }
          ]

        _ ->
          []
      end
    end

    defp validate_array_length(name, spec, value) do
      errors = []
      length = length(value)

      errors =
        case Map.get(spec, :min_items) do
          nil ->
            errors

          min_items when length < min_items ->
            [
              %{
                field: to_string(name),
                expected: "array with at least #{min_items} items",
                got: value,
                message:
                  "Field '#{name}' must have at least #{min_items} #{if min_items == 1, do: "item", else: "items"}"
              }
              | errors
            ]

          _ ->
            errors
        end

      errors =
        case Map.get(spec, :max_items) do
          nil ->
            errors

          max_items when length > max_items ->
            [
              %{
                field: to_string(name),
                expected: "array with at most #{max_items} items",
                got: value,
                message:
                  "Field '#{name}' must have at most #{max_items} #{if max_items == 1, do: "item", else: "items"}"
              }
              | errors
            ]

          _ ->
            errors
        end

      errors
    end

    defp validate_unique_items(name, spec, value) do
      unique_required = Map.get(spec, :unique_items, false)

      if unique_required and length(value) != length(Enum.uniq(value)) do
        # Find the first duplicate
        duplicate = find_first_duplicate(value)

        [
          %{
            field: to_string(name),
            expected: "array with unique items",
            got: value,
            message: "Field '#{name}' must have unique items (duplicate: #{inspect(duplicate)})"
          }
        ]
      else
        []
      end
    end

    defp find_first_duplicate(list) do
      list
      |> Enum.reduce_while({MapSet.new(), nil}, fn item, {seen, _} ->
        if MapSet.member?(seen, item) do
          {:halt, {seen, item}}
        else
          {:cont, {MapSet.put(seen, item), nil}}
        end
      end)
      |> elem(1)
    end

    defp validate_array_item(array_name, index, item_spec, item) do
      # Create a temporary field name with index for error messages
      field_name = "#{array_name}[#{index}]"
      type = Map.get(item_spec, :type)

      # Dispatch to appropriate validator based on type
      validate_array_item_by_type(type, field_name, item_spec, item)
    end

    # Simple type validators for array items
    defp validate_array_item_by_type(:string, field_name, item_spec, item),
      do: validate_string_item(field_name, item_spec, item)

    defp validate_array_item_by_type(:integer, field_name, item_spec, item),
      do: validate_integer_item(field_name, item_spec, item)

    defp validate_array_item_by_type(:number, field_name, item_spec, item),
      do: validate_number_item(field_name, item_spec, item)

    defp validate_array_item_by_type(:boolean, field_name, _item_spec, item),
      do: validate_boolean_item(field_name, item)

    defp validate_array_item_by_type({:enum, allowed_values}, field_name, _item_spec, item),
      do: validate_enum_item(field_name, allowed_values, item)

    # Complex types use general validate_field_type
    defp validate_array_item_by_type({:union, _}, field_name, item_spec, item),
      do: validate_field_type(field_name, item_spec, item)

    defp validate_array_item_by_type({:object, _}, field_name, item_spec, item),
      do: validate_field_type(field_name, item_spec, item)

    defp validate_array_item_by_type({:array, _}, field_name, item_spec, item),
      do: validate_field_type(field_name, item_spec, item)

    defp validate_array_item_by_type(:null, field_name, item_spec, item),
      do: validate_field_type(field_name, item_spec, item)

    defp validate_array_item_by_type(_, _field_name, _item_spec, _item), do: []

    defp validate_string_item(field_name, item_spec, item) when is_binary(item) do
      validate_string_constraints(field_name, item_spec, item)
    end

    defp validate_string_item(field_name, _item_spec, item) do
      [
        %{
          field: field_name,
          expected: "string",
          got: item,
          message: "Field '#{field_name}' must be a string"
        }
      ]
    end

    defp validate_integer_item(field_name, item_spec, item) when is_integer(item) do
      validate_integer_constraints(field_name, item_spec, item)
    end

    defp validate_integer_item(field_name, _item_spec, item) do
      [
        %{
          field: field_name,
          expected: "integer",
          got: item,
          message: "Field '#{field_name}' must be an integer"
        }
      ]
    end

    defp validate_number_item(field_name, item_spec, item) when is_number(item) do
      validate_number_constraints(field_name, item_spec, item)
    end

    defp validate_number_item(field_name, _item_spec, item) do
      [
        %{
          field: field_name,
          expected: "number",
          got: item,
          message: "Field '#{field_name}' must be a number"
        }
      ]
    end

    defp validate_boolean_item(_field_name, item) when is_boolean(item), do: []

    defp validate_boolean_item(field_name, item) do
      [
        %{
          field: field_name,
          expected: "boolean",
          got: item,
          message: "Field '#{field_name}' must be a boolean"
        }
      ]
    end

    defp validate_enum_item(field_name, allowed_values, item) do
      if item in allowed_values do
        []
      else
        [
          %{
            field: field_name,
            expected: "one of #{inspect(allowed_values)}",
            got: item,
            message: "Field '#{field_name}' must be one of: #{inspect(allowed_values)}"
          }
        ]
      end
    end

    # Prefix error field path with parent field name for nested objects
    defp prefix_field_path(%{field: nil} = error, _parent), do: error

    defp prefix_field_path(%{field: field, message: message} = error, parent) do
      new_field = "#{parent}.#{field}"
      # Update both field and message to use the full path
      new_message = String.replace(message, "'#{field}'", "'#{new_field}'")

      %{error | field: new_field, message: new_message}
    end
  end
end
