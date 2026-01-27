defprotocol ExOutlines.Spec do
  @moduledoc """
  Protocol for defining constraint specifications.

  Implementations must provide schema generation and validation logic.

  ## Purpose

  The `Spec` protocol allows you to define constraints for structured output
  generation. Each implementation provides:

  1. **Schema generation** - Convert the spec to a schema representation
     (typically JSON Schema format) for LLM prompts
  2. **Validation** - Verify that output conforms to the constraints

  ## Implementing a Spec

  To create a custom spec type:

      defmodule MyApp.CustomSpec do
        defstruct [:rules]

        defimpl ExOutlines.Spec do
          def to_schema(%MyApp.CustomSpec{rules: rules}) do
            # Convert rules to schema format
            %{type: "object", properties: ...}
          end

          def validate(%MyApp.CustomSpec{rules: rules}, value) do
            # Validate value against rules
            case check_rules(value, rules) do
              :ok -> {:ok, value}
              {:error, reason} ->
                {:error, ExOutlines.Diagnostics.new(reason, value)}
            end
          end
        end
      end

  ## Built-in Implementations

  - `ExOutlines.Spec.Schema` - JSON schema-based validation (v0.1)

  ## Design Rationale

  We use a protocol (not a behaviour) because:

  - Specs are **data transformations**, not stateful services
  - External libraries can extend without wrapper modules
  - Protocols compose naturally with structs
  - Dispatch is based on data type, which is the right model
  """

  @doc """
  Convert spec to a schema representation (typically a map).

  The schema is used for prompt construction, typically formatted as JSON Schema.
  The LLM receives this schema as part of the generation instructions.

  ## Return Format

  Should return a map with at minimum:
  - `type` - The root type (e.g., "object", "array")
  - `properties` - For objects, a map of field definitions
  - `required` - For objects, a list of required field names

  Additional fields like `description`, `examples`, or constraint-specific
  metadata are allowed and encouraged.

  ## Examples

      iex> spec = %ExOutlines.Spec.Schema{...}
      iex> ExOutlines.Spec.to_schema(spec)
      %{
        type: "object",
        properties: %{
          name: %{type: "string"},
          age: %{type: "integer", minimum: 0}
        },
        required: ["name", "age"]
      }
  """
  @spec to_schema(t()) :: map()
  def to_schema(spec)

  @doc """
  Validate a value against the spec.

  Checks that the value conforms to all constraints defined by the spec.
  Returns the validated value (potentially transformed) or structured diagnostics.

  ## Return Values

  - `{:ok, validated_value}` - Value is valid, possibly with transformations
    (e.g., string keys converted to atoms, type coercion)
  - `{:error, diagnostics}` - Value is invalid, diagnostics contains structured
    error information and repair instructions

  ## Validation Semantics

  Implementations should:

  1. **Be deterministic** - Same input always produces same result
  2. **Validate structure** - Check types, required fields, constraints
  3. **Not perform I/O** - No external calls, database queries, etc.
  4. **Return all errors** - Collect multiple validation failures when possible
  5. **Provide actionable diagnostics** - Clear expected vs. got information

  ## Examples

      iex> spec = %ExOutlines.Spec.Schema{...}
      iex> ExOutlines.Spec.validate(spec, %{"name" => "Alice", "age" => 30})
      {:ok, %{name: "Alice", age: 30}}

      iex> ExOutlines.Spec.validate(spec, %{"name" => "Bob"})
      {:error, %ExOutlines.Diagnostics{
        errors: [%{field: "age", expected: "integer", got: nil, ...}],
        repair_instructions: "Field 'age' must be: integer"
      }}
  """
  @spec validate(t(), any()) :: {:ok, any()} | {:error, ExOutlines.Diagnostics.t()}
  def validate(spec, value)
end
