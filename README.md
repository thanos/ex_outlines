# Ex Outlines

[![CI](https://github.com/thanos/ex_outlines/workflows/CI/badge.svg)](https://github.com/thanos/ex_outlines/actions)
[![Coverage](https://coveralls.io/repos/github/thanos/ex_outlines/badge.svg)](https://coveralls.io/github/thanos/ex_outlines)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_outlines.svg)](https://hex.pm/packages/ex_outlines)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/ex_outlines)

**Structured LLM output validation for Elixir.** Guarantee valid, type-safe data from any LLM through automatic validation and repair.

```elixir
# Define what you expect
schema = Schema.new(%{
  sentiment: %{type: {:enum, ["positive", "negative", "neutral"]}},
  confidence: %{type: :number, min: 0, max: 1},
  summary: %{type: :string, max_length: 100}
})

# Generate and validate
{:ok, result} = ExOutlines.generate(schema, backend: HTTP, backend_opts: opts)

# Use validated data
result.sentiment  # Guaranteed to be "positive", "negative", or "neutral"
result.confidence # Guaranteed to be 0-1
result.summary    # Guaranteed to be ≤100 characters
```

---

## Why Ex Outlines?

**The Problem:** LLMs generate unpredictable outputs. You ask for JSON, you might get:
- Invalid JSON: `{name: Alice}`
- Wrong types: `{"age": "thirty"}`
- Missing fields: `{"name": "Alice"}` (no age)
- Extra text: ` ```json\n{"name": "Alice"}\n``` `

**The Solution:** Ex Outlines validates LLM outputs against your schema and automatically repairs errors through a retry loop:

1. **Define Schema** → Specify exact structure and constraints
2. **Generate** → LLM creates output
3. **Validate** → Check against schema
4. **Repair** → If invalid, send diagnostics back to LLM and retry
5. **Guarantee** → Return `{:ok, validated_data}` or `{:error, reason}`

**Result:** No more parsing failures. No more invalid data. Just validated, type-safe outputs.

---

## Features

### Core Capabilities

- **Rich Type System** - Strings, integers, booleans, numbers, enums, arrays, nested objects, union types
- **Comprehensive Constraints** - Length limits, min/max values, regex patterns, unique items
- **Automatic Retry-Repair** - Failed validations trigger repair prompts with clear diagnostics
- **Backend Agnostic** - Works with OpenAI, Anthropic, or any LLM API
- **Batch Processing** - Concurrent generation using BEAM lightweight processes
- **Ecto Integration** - Convert Ecto schemas automatically (optional)
- **Telemetry Built-In** - Observable with Phoenix.LiveDashboard
- **Testing First-Class** - Deterministic Mock backend for tests

### Elixir-Specific Advantages

- **BEAM Concurrency** - Process 100s of requests concurrently
- **Phoenix Integration** - Works seamlessly in controllers and LiveView
- **Type Safety** - Dialyzer type specifications throughout
- **Battle-Tested** - 364 tests, 93% coverage, production-grade

---

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_outlines, "~> 0.2.0"}
  ]
end
```

Optional: Add Ecto for schema adapter:

```elixir
def deps do
  [
    {:ex_outlines, "~> 0.2.0"},
    {:ecto, "~> 3.11"}  # Optional
  ]
end
```

Run `mix deps.get`

---

## Quick Start

### 1. Define a Schema

```elixir
alias ExOutlines.Spec.Schema

schema = Schema.new(%{
  name: %{
    type: :string,
    required: true,
    min_length: 2,
    max_length: 50
  },
  age: %{
    type: :integer,
    required: true,
    min: 0,
    max: 120
  },
  email: %{
    type: :string,
    required: true,
    pattern: ~r/@/
  }
})
```

### 2. Generate Structured Output

```elixir
{:ok, user} = ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    model: "gpt-4o-mini",
    messages: [
      %{role: "system", content: "Extract user data."},
      %{role: "user", content: "My name is Alice, I'm 30 years old, email alice@example.com"}
    ]
  ]
)

# Result is validated and typed
user.name   # "Alice"
user.age    # 30
user.email  # "alice@example.com"
```

### 3. Handle Errors

```elixir
case ExOutlines.generate(schema, opts) do
  {:ok, data} ->
    # Use validated data
    process_user(data)

  {:error, :max_retries_exceeded} ->
    # LLM couldn't produce valid output after all retries
    Logger.error("Generation failed after retries")

  {:error, {:backend_error, reason}} ->
    # API error (rate limit, timeout, etc.)
    Logger.error("Backend error: #{inspect(reason)}")
end
```

---

## Type System

### Primitive Types

```elixir
# String
%{type: :string}
%{type: :string, min_length: 3, max_length: 100}
%{type: :string, pattern: ~r/^[A-Z][a-z]+$/}

# Integer
%{type: :integer}
%{type: :integer, min: 0, max: 100}
%{type: :integer, positive: true}  # Shorthand for min: 1

# Boolean
%{type: :boolean}

# Number (integer or float)
%{type: :number, min: 0.0, max: 1.0}
```

### Composite Types

```elixir
# Enum (multiple choice)
%{type: {:enum, ["red", "green", "blue"]}}

# Array
%{type: {:array, %{type: :string}}}
%{type: {:array, %{type: :integer, min: 0}}, min_items: 1, max_items: 10, unique_items: true}

# Nested Object
address_schema = Schema.new(%{
  street: %{type: :string, required: true},
  city: %{type: :string, required: true},
  zip: %{type: :string, pattern: ~r/^\d{5}$/}
})

person_schema = Schema.new(%{
  name: %{type: :string, required: true},
  address: %{type: {:object, address_schema}, required: true}
})

# Union Types (optional/nullable fields)
%{type: {:union, [%{type: :string}, %{type: :null}]}}
%{type: {:union, [%{type: :string}, %{type: :integer}]}}  # Either string or int
```

---

## Backends

### HTTP Backend (OpenAI-Compatible)

Works with OpenAI, Azure OpenAI, and compatible APIs:

```elixir
alias ExOutlines.Backend.HTTP

ExOutlines.generate(schema,
  backend: HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    model: "gpt-4o-mini",
    api_url: "https://api.openai.com/v1/chat/completions",
    temperature: 0.0
  ]
)
```

### Anthropic Backend

Native Claude API support:

```elixir
alias ExOutlines.Backend.Anthropic

ExOutlines.generate(schema,
  backend: Anthropic,
  backend_opts: [
    api_key: System.get_env("ANTHROPIC_API_KEY"),
    model: "claude-3-5-sonnet-20241022",
    max_tokens: 1024
  ]
)
```

### Mock Backend (Testing)

Deterministic responses for tests:

```elixir
alias ExOutlines.Backend.Mock

# Single response
mock = Mock.new([{:ok, ~s({"name": "Alice", "age": 30})}])

# Multiple responses (for retry testing)
mock = Mock.new([
  {:ok, ~s({"name": "Alice", "age": "invalid"})},  # Invalid (will retry)
  {:ok, ~s({"name": "Alice", "age": 30})}          # Valid (succeeds)
])

# Always same response
mock = Mock.always({:ok, ~s({"status": "ok"})})

ExOutlines.generate(schema, backend: Mock, backend_opts: [mock: mock])
```

---

## Batch Processing

Process multiple schemas concurrently using BEAM's lightweight processes:

```elixir
# Define tasks
tasks = [
  {schema1, [backend: HTTP, backend_opts: opts1]},
  {schema2, [backend: HTTP, backend_opts: opts2]},
  {schema3, [backend: HTTP, backend_opts: opts3]}
]

# Process concurrently
results = ExOutlines.generate_batch(tasks, max_concurrency: 5)

# Results: [{:ok, data1}, {:ok, data2}, {:error, reason3}]
```

**Example: Classify 100 messages in parallel**

```elixir
messages = get_messages(100)

tasks = Enum.map(messages, fn msg ->
  {classification_schema, [
    backend: HTTP,
    backend_opts: build_opts(msg)
  ]}
end)

# Process 10 at a time to respect rate limits
results = ExOutlines.generate_batch(tasks, max_concurrency: 10)
```

---

## Ecto Integration

Automatically convert Ecto schemas to Ex Outlines schemas:

```elixir
defmodule User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :email, :string
    field :age, :integer
    field :username, :string
  end

  def changeset(user, params) do
    user
    |> cast(params, [:email, :age, :username])
    |> validate_required([:email, :username])
    |> validate_format(:email, ~r/@/)
    |> validate_number(:age, greater_than_or_equal_to: 0, less_than: 150)
    |> validate_length(:username, min: 3, max: 20)
  end
end

# Convert automatically
schema = Schema.from_ecto_schema(User, changeset_function: :changeset)

# Now use with LLM
{:ok, user} = ExOutlines.generate(schema, backend: HTTP, backend_opts: opts)
```

See [Ecto Schema Adapter Guide](guides/ecto_schema_adapter.md) for details.

---

## Phoenix Integration

Use in Phoenix controllers:

```elixir
defmodule MyAppWeb.TicketController do
  use MyAppWeb, :controller

  def create(conn, %{"message" => message}) do
    case classify_ticket(message) do
      {:ok, classification} ->
        {:ok, ticket} = Tickets.create(classification)

        conn
        |> put_flash(:info, "Ticket created with #{ticket.priority} priority")
        |> redirect(to: ~p"/tickets/#{ticket.id}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to classify ticket")
        |> render("new.html")
    end
  end

  defp classify_ticket(message) do
    schema = Schema.new(%{
      priority: %{type: {:enum, ["low", "medium", "high", "critical"]}},
      category: %{type: {:enum, ["technical", "billing", "account"]}}
    })

    ExOutlines.generate(schema,
      backend: HTTP,
      backend_opts: [
        api_key: Application.get_env(:my_app, :openai_api_key),
        model: "gpt-4o-mini",
        messages: build_messages(message)
      ]
    )
  end
end
```

See [Phoenix Integration Guide](guides/phoenix_integration.md) for more patterns.

---

## Examples

Browse `examples/` for production-ready examples:

- **[Classification](examples/classification.exs)** - Customer support triage with priority, category, sentiment
- **[E-commerce Categorization](examples/ecommerce_categorization.exs)** - Product classification with features and tags
- **[Document Metadata](examples/document_metadata_extraction.exs)** - Extract structured metadata from documents
- **[Customer Support Triage](examples/customer_support_triage.exs)** - Automated ticket routing

Run examples:

```bash
elixir examples/classification.exs
```

---

## Documentation

### Guides

- **[Getting Started](guides/getting_started.md)** - Installation, first schema, validation basics
- **[Core Concepts](guides/core_concepts.md)** - Deep dive into schemas, validation, retry-repair loop
- **[Phoenix Integration](guides/phoenix_integration.md)** - Controllers, LiveView, Oban patterns
- **[Ecto Schema Adapter](guides/ecto_schema_adapter.md)** - Automatic Ecto schema conversion
- **[Testing Strategies](guides/testing_strategies.md)** - Testing with Mock backend
- **[Error Handling](guides/error_handling.md)** - Robust error handling patterns

### API Reference

Complete API documentation: [hexdocs.pm/ex_outlines](https://hexdocs.pm/ex_outlines)

### Interactive Tutorials

Check `livebooks/` directory for hands-on Livebook tutorials (coming soon).

---

## Telemetry & Observability

Ex Outlines emits telemetry events for monitoring:

```elixir
:telemetry.attach(
  "ex-outlines-monitor",
  [:ex_outlines, :generate, :stop],
  fn _event, measurements, metadata, _config ->
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    Logger.info("""
    LLM Generation:
      Duration: #{duration_ms}ms
      Attempts: #{measurements.attempt_count}
      Status: #{metadata.status}
    """)
  end,
  nil
)
```

Integrate with Phoenix.LiveDashboard:

```elixir
# lib/my_app_web/telemetry.ex
def metrics do
  [
    summary("ex_outlines.generate.stop.duration",
      unit: {:native, :millisecond},
      tags: [:backend, :status]
    ),

    summary("ex_outlines.generate.stop.attempt_count",
      tags: [:backend]
    )
  ]
end
```

---

## How It Works

### The Retry-Repair Loop

```
┌─────────────┐
│ User Prompt │
└──────┬──────┘
       │
       v
┌─────────────┐
│ LLM Generate│
└──────┬──────┘
       │
       v
┌─────────────┐     Valid      ┌────────┐
│  Validate   │───────────────>│ Return │
└──────┬──────┘                └────────┘
       │ Invalid
       │
       v
┌─────────────┐
│Build Repair │
│   Prompt    │
└──────┬──────┘
       │
       └──────────────────┘ (back to LLM Generate)
```

**Example:**

1. **Generate**: LLM returns `{"age": 150}`
2. **Validate**: Fails (age > 120)
3. **Repair**: "Field 'age' must be at most 120. Please fix."
4. **Retry**: LLM returns `{"age": 30}`
5. **Validate**: Success
6. **Return**: `{:ok, %{age: 30}}`

---

## Comparison to Python Outlines

| Aspect | Ex Outlines | Python Outlines |
|--------|-------------|-----------------|
| **Approach** | Post-generation validation + repair | Token-level constraint (FSM) |
| **Backend Support** | Any LLM API (HTTP-based) | Requires logit access |
| **Setup** | Zero config, works immediately | Requires FSM compilation |
| **LLM Calls** | 1-5 (with retries) | 1 (constrained) |
| **Error Feedback** | Full diagnostics to LLM | N/A (prevents errors) |
| **Complexity** | Low (validation logic) | High (FSM logic) |
| **Flexibility** | Works with any model | Model-dependent |
| **Ecosystem** | Elixir/Phoenix/Ecto | Python |

**When to use Ex Outlines:**
- Building in Elixir/Phoenix
- Need backend flexibility (any LLM API)
- Want explicit error handling and diagnostics
- Value BEAM concurrency for batch processing

**When to use Python Outlines:**
- Building in Python
- Have logit-level API access
- Need absolute minimum LLM calls
- Require context-free grammars

Both tools serve different ecosystems and constraints.

---

## Roadmap

### v0.3 (Planned)

- [ ] Template system (EEx-based prompt templates)
- [ ] Streaming support (incremental validation)
- [ ] Generator abstraction (reusable model + schema)
- [ ] Additional backends (Ollama, vLLM)
- [ ] More examples and Livebook tutorials

### v0.4+ (Future)

- [ ] Context-free grammar support
- [ ] Local model integration (Bumblebee)
- [ ] Function calling DSL
- [ ] Advanced caching layer

See [CHANGELOG.md](CHANGELOG.md) for full version history.

---

## Testing

Run the test suite:

```bash
mix test
```

With coverage:

```bash
mix test --cover
```

Strict checks:

```bash
mix format --check-formatted
mix credo --strict
mix dialyzer
```

---

## Contributing

Contributions are welcome! Please:

1. Open an issue for discussion before major changes
2. Add tests for new functionality
3. Follow existing code style (`mix format`)
4. Ensure `mix credo --strict` passes
5. Update documentation
6. Add type specs for public functions

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Credits

Inspired by [Python Outlines](https://github.com/dottxt-ai/outlines) by dottxt-ai.

Built using:
- [Elixir](https://elixir-lang.org/)
- [Jason](https://github.com/michalmuskala/jason) - JSON parsing
- [Telemetry](https://github.com/beam-telemetry/telemetry) - Observability
- [Ecto](https://hexdocs.pm/ecto/) - Optional schema adapter

---

## Links

- [Documentation](https://hexdocs.pm/ex_outlines)
- [Hex.pm](https://hex.pm/packages/ex_outlines)
- [GitHub](https://github.com/thanos/ex_outlines)
- [Changelog](CHANGELOG.md)
- [Issues](https://github.com/thanos/ex_outlines/issues)

---

Made with Elixir. Powered by BEAM.
