# Architecture

This guide explains the technical architecture and design decisions behind Ex Outlines. It covers system organization, key components, and implementation details that enable reliable structured LLM output validation.

## Table of Contents

- [System Overview](#system-overview)
- [Module Organization](#module-organization)
- [Schema Module Design](#schema-module-design)
- [Validation Engine](#validation-engine)
- [Backend Architecture](#backend-architecture)
- [Retry-Repair Loop Implementation](#retry-repair-loop-implementation)
- [Batch Processing Design](#batch-processing-design)
- [Telemetry Integration](#telemetry-integration)
- [Ecto Integration](#ecto-integration)
- [Extension Points](#extension-points)
- [Design Decisions](#design-decisions)
- [Future Architecture](#future-architecture)

---

## System Overview

Ex Outlines follows a modular architecture with clear separation of concerns. The system consists of four main layers:

```
┌─────────────────────────────────────────┐
│          Public API Layer               │
│         (ExOutlines module)             │
└─────────────┬───────────────────────────┘
              │
┌─────────────┴───────────────────────────┐
│       Schema & Validation Layer         │
│    (Spec.Schema, Spec modules)          │
└─────────────┬───────────────────────────┘
              │
┌─────────────┴───────────────────────────┐
│         Backend Layer                   │
│   (Backend.HTTP, Backend.Anthropic)     │
└─────────────┬───────────────────────────┘
              │
┌─────────────┴───────────────────────────┐
│         LLM APIs                        │
│   (OpenAI, Anthropic, etc.)             │
└─────────────────────────────────────────┘
```

### Data Flow

1. User calls `ExOutlines.generate/2` with schema and options
2. Schema validates configuration
3. Prompt module constructs initial prompt with JSON schema
4. Backend calls LLM API
5. Response is validated against schema
6. If invalid, repair prompt is constructed and loop repeats
7. Valid result or error is returned to user

### Design Principles

1. **Simple**: Minimal abstractions, predictable behavior
2. **Composable**: Small modules with single responsibilities
3. **Testable**: All components can be tested in isolation
4. **Concurrent**: Leverage BEAM for parallel processing
5. **Observable**: Telemetry events for monitoring

---

## Module Organization

```
lib/ex_outlines/
├── ex_outlines.ex                 # Public API
├── spec/
│   ├── spec.ex                    # Validation interface
│   └── schema.ex                  # Schema definition & validation
├── backend/
│   ├── backend.ex                 # Backend behaviour
│   ├── http.ex                    # OpenAI-compatible backend
│   ├── anthropic.ex               # Native Claude API backend
│   └── mock.ex                    # Testing backend
├── prompt.ex                      # Prompt construction (internal)
└── ecto.ex                        # Optional Ecto integration
```

### Module Responsibilities

**ExOutlines** (Public API)
- Main entry point: `generate/2`, `generate_batch/2`
- Configuration validation
- Telemetry event emission
- Error handling and normalization

**ExOutlines.Spec.Schema**
- Schema definition and storage
- Field specification normalization
- JSON Schema generation
- Type validation dispatch

**ExOutlines.Spec**
- Validation orchestration
- Diagnostics generation
- Key transformation (string to atom)

**ExOutlines.Backend.***
- LLM API communication
- Request formatting
- Response parsing
- Error handling

**ExOutlines.Prompt** (Internal)
- Initial prompt construction
- Repair prompt generation
- Message formatting

**ExOutlines.Ecto** (Optional)
- Schema conversion from Ecto
- Changeset validation extraction
- Type mapping

---

## Schema Module Design

The Schema module is the core of Ex Outlines' validation system.

### Internal Representation

```elixir
defmodule ExOutlines.Spec.Schema do
  @type t :: %__MODULE__{
    fields: %{atom() => field_spec()}
  }

  @type field_spec :: %{
    type: field_type(),
    required: boolean(),
    description: String.t() | nil,
    # Type-specific constraints...
  }

  @type field_type ::
    :string
    | :integer
    | :boolean
    | :number
    | {:enum, [any()]}
    | {:array, item_spec()}
    | {:object, t()}
    | {:union, [field_spec()]}

  defstruct fields: %{}
end
```

### Normalization Process

When a schema is created, field specifications are normalized:

```elixir
def new(fields) when is_map(fields) do
  normalized_fields =
    fields
    |> Enum.map(fn {name, spec} ->
      {to_atom(name), normalize_field_spec(spec)}
    end)
    |> Enum.into(%{})

  %__MODULE__{fields: normalized_fields}
end
```

Normalization includes:
1. Convert field names to atoms
2. Set default values (required: true, description: nil)
3. Apply Ecto normalization if available
4. Validate field specification structure

### Validation Dispatch

Validation uses pattern matching for type dispatch:

```elixir
defp validate_field_type(name, %{type: :string} = spec, value)
     when is_binary(value) do
  # Validate string constraints
  []
end

defp validate_field_type(name, %{type: :string}, value) do
  # Type mismatch error
  [build_error(name, :string, value)]
end

defp validate_field_type(name, %{type: :integer} = spec, value)
     when is_integer(value) do
  # Validate integer constraints
  []
end

# Pattern continues for each type...
```

This pattern provides:
- Type safety through guard clauses
- Clear error paths for type mismatches
- Easy extension for new types

### JSON Schema Generation

Schemas can be converted to JSON Schema format for LLM prompts:

```elixir
def to_json_schema(%Schema{fields: fields}) do
  %{
    "type" => "object",
    "properties" => generate_properties(fields),
    "required" => required_fields(fields)
  }
end
```

This allows the LLM to understand the expected output structure.

---

## Validation Engine

The validation engine processes input data against schemas and collects errors.

### Validation Algorithm

```elixir
def validate(%Schema{fields: fields}, input) do
  # 1. Parse JSON if needed
  data = parse_input(input)

  # 2. Validate each field
  errors =
    fields
    |> Enum.flat_map(fn {name, spec} ->
      validate_field(name, spec, data)
    end)

  # 3. Build diagnostics
  if Enum.empty?(errors) do
    # 4. Transform keys and return
    validated = transform_keys(data)
    {:ok, validated}
  else
    diagnostics = %Diagnostics{valid?: false, errors: errors}
    {:error, diagnostics}
  end
end
```

### Error Collection Strategy

Ex Outlines validates all fields before returning errors (not fail-fast):

**Advantages:**
- Complete feedback in one pass
- Better error messages for LLM repair
- Fewer retry cycles

**Implementation:**
```elixir
# Collect all errors using flat_map
errors =
  fields
  |> Enum.flat_map(fn {name, spec} ->
    case validate_field(name, spec, data) do
      [] -> []
      errors -> errors
    end
  end)
```

### Nested Validation

Nested objects are validated recursively:

```elixir
defp validate_field_type(name, %{type: {:object, nested_schema}}, value)
     when is_map(value) do
  case Spec.validate(nested_schema, value) do
    {:ok, _} ->
      []
    {:error, diagnostics} ->
      # Prefix error paths with parent field name
      diagnostics.errors
      |> Enum.map(fn error ->
        prefix_error_path(error, name)
      end)
  end
end
```

This provides error paths like `"address.city"` for nested fields.

### Array Validation

Arrays validate items with index tracking:

```elixir
defp validate_array_items(name, item_spec, items) do
  items
  |> Enum.with_index()
  |> Enum.flat_map(fn {item, index} ->
    errors = validate_field_type(:"#{name}[#{index}]", item_spec, item)
    # Error messages include index
    errors
  end)
end
```

### Union Type Validation

Union types try each specification in order:

```elixir
defp validate_field_type(name, %{type: {:union, specs}}, value) do
  results =
    specs
    |> Enum.map(fn spec ->
      validate_field_type(name, spec, value)
    end)

  # Find first successful validation
  case Enum.find(results, &(&1 == [])) do
    [] ->
      # Success
      []
    nil ->
      # All failed
      [build_union_error(name, specs, value)]
  end
end
```

---

## Backend Architecture

Backends handle communication with LLM APIs through a common interface.

### Backend Behaviour

```elixir
defmodule ExOutlines.Backend do
  @type message :: %{
    role: String.t(),
    content: String.t()
  }

  @callback call_llm(messages :: [message()], opts :: keyword()) ::
    {:ok, String.t()} | {:error, term()}
end
```

### HTTP Backend Implementation

The HTTP backend supports OpenAI-compatible APIs:

```elixir
defmodule ExOutlines.Backend.HTTP do
  @behaviour ExOutlines.Backend

  @impl true
  def call_llm(messages, opts) do
    with {:ok, config} <- validate_config(opts),
         {:ok, body} <- build_request_body(messages, config),
         {:ok, response} <- make_http_request(config, body) do
      parse_response(response)
    end
  end

  defp validate_config(opts) do
    required = [:api_key, :model]
    case Enum.find(required, &(!Keyword.has_key?(opts, &1))) do
      nil -> {:ok, build_config(opts)}
      missing -> {:error, {:missing_config, missing}}
    end
  end

  defp make_http_request(config, body) do
    url = config.api_url
    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"authorization", ~c"Bearer #{config.api_key}"}
    ]

    case :httpc.request(:post, {url, headers, ~c"application/json", body}, [], []) do
      {:ok, {{_, 200, _}, _, response_body}} ->
        {:ok, to_string(response_body)}
      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_error, status}}
      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
  end
end
```

### Anthropic Backend Implementation

The Anthropic backend handles Claude-specific API format:

```elixir
defmodule ExOutlines.Backend.Anthropic do
  @behaviour ExOutlines.Backend

  @impl true
  def call_llm(messages, opts) do
    with {:ok, config} <- validate_config(opts),
         {:ok, {system, conversation}} <- extract_system_message(messages),
         {:ok, body} <- build_anthropic_body(system, conversation, config),
         {:ok, response} <- make_anthropic_request(config, body) do
      parse_anthropic_response(response)
    end
  end

  defp extract_system_message(messages) do
    case Enum.split_with(messages, &(&1.role == "system")) do
      {[system | _], rest} -> {:ok, {system.content, rest}}
      {[], rest} -> {:ok, {"", rest}}
    end
  end

  defp build_anthropic_body(system, messages, config) do
    body = %{
      model: config.model,
      max_tokens: config.max_tokens,
      system: system,
      messages: Enum.map(messages, &format_message/1)
    }
    Jason.encode(body)
  end
end
```

### Mock Backend Implementation

The Mock backend provides deterministic responses for testing:

```elixir
defmodule ExOutlines.Backend.Mock do
  @behaviour ExOutlines.Backend

  defstruct [:agent_pid, call_count: 0]

  def new(responses) when is_list(responses) do
    {:ok, agent_pid} = Agent.start_link(fn -> {responses, 0} end)
    %__MODULE__{agent_pid: agent_pid, call_count: 0}
  end

  @impl true
  def call_llm(_messages, opts) do
    mock = Keyword.get(opts, :mock)
    if mock, do: get_next_response(mock), else: {:error, :no_mock_provided}
  end

  defp get_next_response(%__MODULE__{agent_pid: pid}) do
    Agent.get_and_update(pid, fn {responses, count} ->
      case responses do
        [] -> {{:error, :no_more_responses}, {[], count + 1}}
        [response | rest] -> {response, {rest, count + 1}}
      end
    end)
  end
end
```

---

## Retry-Repair Loop Implementation

The retry-repair loop is implemented in the main `ExOutlines` module.

### Loop Structure

```elixir
defp generate_loop(schema, messages, backend, backend_opts, attempt, max_retries) do
  # Emit telemetry
  :telemetry.execute([:ex_outlines, :generate, :attempt], %{attempt: attempt}, %{})

  # Call backend
  case backend.call_llm(messages, backend_opts) do
    {:ok, response_text} ->
      # Validate response
      case Spec.validate(schema, response_text) do
        {:ok, validated} ->
          # Success
          {:ok, validated}

        {:error, diagnostics} when attempt < max_retries ->
          # Build repair prompt
          repair_message = build_repair_message(diagnostics)
          new_messages = messages ++ [
            %{role: "assistant", content: response_text},
            %{role: "user", content: repair_message}
          ]

          # Retry
          generate_loop(schema, new_messages, backend, backend_opts, attempt + 1, max_retries)

        {:error, _diagnostics} ->
          # Max retries exceeded
          {:error, :max_retries_exceeded}
      end

    {:error, reason} ->
      # Backend error
      {:error, {:backend_error, reason}}
  end
end
```

### Repair Prompt Construction

```elixir
defp build_repair_message(%Diagnostics{errors: errors}) do
  error_list =
    errors
    |> Enum.map(fn error ->
      "- Field: #{error.field}\n  Expected: #{error.expected}\n  Got: #{inspect(error.got)}\n  Issue: #{error.message}"
    end)
    |> Enum.join("\n\n")

  """
  Your previous output had validation errors:

  #{error_list}

  Please provide corrected JSON that addresses all errors.
  Respond with valid JSON only.
  """
end
```

### Telemetry Events

```elixir
# Start event
:telemetry.execute(
  [:ex_outlines, :generate, :start],
  %{system_time: System.system_time()},
  %{schema: schema, backend: backend}
)

# Stop event
:telemetry.execute(
  [:ex_outlines, :generate, :stop],
  %{
    duration: duration,
    attempt_count: final_attempt
  },
  %{
    schema: schema,
    backend: backend,
    status: status
  }
)
```

---

## Batch Processing Design

Batch processing uses `Task.async_stream` for concurrent generation.

### Implementation

```elixir
def generate_batch(tasks, opts \\ []) do
  max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
  timeout = Keyword.get(opts, :timeout, 60_000)
  ordered = Keyword.get(opts, :ordered, true)

  # Emit batch start telemetry
  :telemetry.execute(
    [:ex_outlines, :batch, :start],
    %{system_time: System.system_time(), total_tasks: length(tasks)},
    %{max_concurrency: max_concurrency}
  )

  start_time = System.monotonic_time()

  # Process tasks concurrently
  results =
    tasks
    |> Task.async_stream(
      fn {schema, opts} -> generate(schema, opts) end,
      max_concurrency: max_concurrency,
      timeout: timeout,
      ordered: ordered
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:task_exit, reason}}
    end)

  # Emit batch stop telemetry
  duration = System.monotonic_time() - start_time
  {success_count, error_count} = count_results(results)

  :telemetry.execute(
    [:ex_outlines, :batch, :stop],
    %{
      duration: duration,
      total_tasks: length(tasks),
      success_count: success_count,
      error_count: error_count
    },
    %{}
  )

  results
end
```

### Concurrency Model

Ex Outlines leverages BEAM's lightweight processes:

**Advantages:**
- Thousands of concurrent tasks possible
- Fault isolation (one failure does not affect others)
- Efficient CPU scheduling
- Built-in backpressure through `max_concurrency`

**Performance:**
- Sequential: N tasks × average_time
- Concurrent (max_concurrency=10): N tasks × average_time / 10 (approximately)

---

## Telemetry Integration

Ex Outlines emits telemetry events for observability.

### Event Design

Events follow the pattern: `[:ex_outlines, operation, phase]`

**Generation events:**
- `[:ex_outlines, :generate, :start]` - Generation begins
- `[:ex_outlines, :generate, :stop]` - Generation completes

**Batch events:**
- `[:ex_outlines, :batch, :start]` - Batch processing begins
- `[:ex_outlines, :batch, :stop]` - Batch processing completes

### Measurement Data

Each event includes measurements and metadata:

```elixir
# Generate stop event
:telemetry.execute(
  [:ex_outlines, :generate, :stop],
  %{
    duration: integer(),        # Nanoseconds
    attempt_count: integer()    # Number of attempts
  },
  %{
    schema: Schema.t(),
    backend: module(),
    status: :ok | :error,
    error_reason: term() | nil
  }
)
```

### Handler Example

```elixir
:telemetry.attach(
  "ex-outlines-logger",
  [:ex_outlines, :generate, :stop],
  fn _event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    level = if metadata.status == :ok, do: :info, else: :warning

    Logger.log(level, """
    Generation #{metadata.status}:
      Backend: #{inspect(metadata.backend)}
      Duration: #{duration_ms}ms
      Attempts: #{measurements.attempt_count}
    """)
  end,
  nil
)
```

---

## Ecto Integration

The Ecto integration is optional and conditionally compiled.

### Conditional Compilation

```elixir
defmodule ExOutlines.Ecto do
  if Code.ensure_loaded?(Ecto) do
    # Ecto integration code
    def from_ecto_schema(ecto_schema, opts \\ []) do
      # Implementation
    end
  else
    def from_ecto_schema(_ecto_schema, _opts) do
      raise "Ecto is not available. Add {:ecto, \"~> 3.11\"} to your dependencies."
    end
  end
end
```

### Schema Conversion

```elixir
def from_ecto_schema(ecto_schema, opts) do
  fields =
    ecto_schema.__schema__(:fields)
    |> Enum.map(fn field_name ->
      type = ecto_schema.__schema__(:type, field_name)
      field_spec = convert_ecto_type(type, field_name, ecto_schema, opts)
      {field_name, field_spec}
    end)
    |> Enum.into(%{})

  Schema.new(fields)
end
```

### Type Mapping

```elixir
defp convert_ecto_type(:string, _name, _schema, _opts) do
  %{type: :string, required: false}
end

defp convert_ecto_type(:integer, _name, _schema, _opts) do
  %{type: :integer, required: false}
end

defp convert_ecto_type({:array, inner_type}, _name, _schema, opts) do
  item_spec = convert_ecto_type(inner_type, nil, nil, opts)
  %{type: {:array, item_spec}, required: false}
end

defp convert_ecto_type({:parameterized, {Ecto.Enum, %{mappings: mappings}}}, _name, _schema, _opts) do
  values = Keyword.keys(mappings)
  %{type: {:enum, values}, required: false}
end
```

### Changeset Analysis

```elixir
defp extract_validations_from_changeset(ecto_schema, changeset_function) do
  # Create sample changeset
  sample = struct(ecto_schema)
  changeset = apply(ecto_schema, changeset_function, [sample, %{}])

  # Extract required fields
  required_fields = extract_required_fields(changeset)

  # Extract validation rules
  validations = extract_validation_rules(changeset)

  {required_fields, validations}
end
```

---

## Extension Points

Ex Outlines is designed for extensibility.

### Custom Backends

Implement the `Backend` behaviour:

```elixir
defmodule MyApp.CustomBackend do
  @behaviour ExOutlines.Backend

  @impl true
  def call_llm(messages, opts) do
    # Custom implementation
    # Must return {:ok, response_text} or {:error, reason}
  end
end
```

### Custom Validators

Currently, validation is handled through the schema system. Future versions may support custom validator behaviours:

```elixir
# Future API
defmodule MyApp.CustomValidator do
  @behaviour ExOutlines.Validator

  @impl true
  def validate(field_name, value, opts) do
    # Custom validation logic
    # Return [] for valid, [error] for invalid
  end
end
```

### Telemetry Handlers

Attach custom telemetry handlers for monitoring:

```elixir
:telemetry.attach_many(
  "my-app-ex-outlines",
  [
    [:ex_outlines, :generate, :start],
    [:ex_outlines, :generate, :stop],
    [:ex_outlines, :batch, :start],
    [:ex_outlines, :batch, :stop]
  ],
  &MyApp.Telemetry.handle_event/4,
  %{}
)
```

---

## Design Decisions

### Post-Generation Validation vs. Token-Level Constraint

**Decision:** Use post-generation validation with repair loop

**Rationale:**
- Simpler implementation (no FSM compilation)
- Backend-agnostic (works with any LLM API)
- No special model support needed
- Clear error diagnostics for debugging
- LLMs are good at error correction

**Trade-off:**
- More LLM calls on validation failures
- Higher latency on repair cycles
- Potentially higher API costs

**Mitigation:**
- Configurable `max_retries`
- Good initial prompts reduce retries
- Telemetry for monitoring retry rates

### Atom Keys vs. String Keys

**Decision:** Convert validated output to use atom keys

**Rationale:**
- Elixir convention
- Better pattern matching
- Struct compatibility
- Clearer intent in code

**Implementation:**
- Input accepts string keys (JSON standard)
- Output uses atom keys (Elixir standard)
- Conversion happens after validation

### Error Collection vs. Fail-Fast

**Decision:** Collect all validation errors before returning

**Rationale:**
- Complete feedback to LLM for repair
- Fewer retry cycles
- Better developer experience

**Trade-off:**
- Slightly more computation per validation
- More complex error structure

**Benefit:**
- Single repair prompt can fix multiple issues
- Reduced total LLM calls

### Task.async_stream vs. GenServer Pool

**Decision:** Use `Task.async_stream` for batch processing

**Rationale:**
- Built-in, no dependencies
- Simple API
- BEAM scheduler handles load balancing
- Automatic cleanup

**When to reconsider:**
- Need for persistent worker processes
- Complex state management
- Advanced backpressure handling
- Custom scheduling logic

**Future:** May add GenStage support for advanced use cases

### Behavior vs. Protocol for Backends

**Decision:** Use behavior for backend interface

**Rationale:**
- Simpler for HTTP client abstraction
- Compile-time guarantees
- Clear contract with @callback

**When protocols might be better:**
- Need for polymorphic dispatch
- External implementations
- Dynamic backend selection

---

## Future Architecture

### Planned Enhancements

**Template System (v0.3)**
```elixir
# EEx-based prompt templates
template = ExOutlines.Template.new("""
<%= for example <- @examples do %>
Q: <%= example.question %>
A: <%= example.answer %>
<% end %>
Q: <%= @question %>
A:
""")

ExOutlines.generate(schema,
  template: template,
  assigns: %{examples: examples, question: question}
)
```

**Streaming Support (v0.3)**
```elixir
# Incremental validation
ExOutlines.generate_stream(schema, opts)
|> Stream.each(fn
  {:partial, data} -> IO.write(data)
  {:complete, validated} -> IO.puts("\nDone")
  {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
end)
|> Stream.run()
```

**Generator Abstraction (v0.3)**
```elixir
# Reusable model + schema combination
generator = ExOutlines.Generator.new(
  backend: HTTP,
  backend_opts: opts,
  schema: user_schema
)

# Reuse compiled schema for multiple prompts
{:ok, user1} = ExOutlines.Generator.generate(generator, prompt1)
{:ok, user2} = ExOutlines.Generator.generate(generator, prompt2)
```

**Context-Free Grammars (v0.4)**
```elixir
# Grammar-based validation
grammar = """
expression := term (('+' | '-') term)*
term := factor (('*' | '/') factor)*
factor := number | '(' expression ')'
number := [0-9]+
"""

schema = Schema.new(%{
  formula: %{type: {:grammar, grammar}}
})
```

### Architectural Improvements

**Caching Layer**
```elixir
# Cache schema compilation and LLM responses
config :ex_outlines,
  cache: [
    enabled: true,
    ttl: 3600,
    backend: ExOutlines.Cache.ETS
  ]
```

**Circuit Breaker**
```elixir
# Prevent cascading failures
config :ex_outlines,
  circuit_breaker: [
    enabled: true,
    threshold: 5,
    timeout: 60_000
  ]
```

**Middleware System**
```elixir
# Request/response middleware
ExOutlines.generate(schema,
  middleware: [
    MyApp.LoggingMiddleware,
    MyApp.RateLimitMiddleware,
    MyApp.CacheMiddleware
  ]
)
```

---

## Summary

Ex Outlines architecture prioritizes simplicity, testability, and composability. Key architectural features:

1. **Modular Design** - Clear separation of concerns across modules
2. **Validation-First** - Post-generation validation with repair loop
3. **Backend Agnostic** - Behavior-based backend system
4. **BEAM Native** - Leverage lightweight processes for concurrency
5. **Observable** - Comprehensive telemetry integration
6. **Extensible** - Clear extension points for customization

The architecture supports the current feature set while providing foundation for future enhancements like streaming, templates, and grammars.

For implementation details, see the source code in `lib/ex_outlines/`.
