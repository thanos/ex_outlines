# ExOutlines

[![CI](https://github.com/your_org/ex_outlines/workflows/CI/badge.svg)](https://github.com/your_org/ex_outlines/actions)
[![Coverage](https://coveralls.io/repos/github/your_org/ex_outlines/badge.svg)](https://coveralls.io/github/your_org/ex_outlines)
[![Hex.pm](https://img.shields.io/hexpm/v/ex_outlines.svg)](https://hex.pm/packages/ex_outlines)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/ex_outlines)

Deterministic structured output from LLMs via retry-repair loops.

ExOutlines is a backend-agnostic library for extracting validated, type-safe data structures from Large Language Models. Instead of token-level constraints, it uses OTP supervision principles: generate, validate, and repair until constraints are satisfied or retries are exhausted.

## Philosophy

**Validate, don't constrain.**

Unlike token-level guidance (Python Outlines, guidance), ExOutlines embraces the Erlang/OTP philosophy: let it crash, supervise, and retry. We don't control the LLM's generation process—we validate outputs and provide repair instructions when validation fails.

This approach:
- Works with any LLM backend (OpenAI, Anthropic, local models)
- Requires no special model configuration or custom samplers
- Leverages the LLM's natural error correction abilities
- Provides clear, actionable feedback for repairs

## Features

- **Schema-based validation** - Define constraints with type-safe schemas
- **Automatic retry with repair** - Failed validations trigger repair prompts with diagnostic feedback
- **Backend agnostic** - Works with OpenAI, Anthropic, or custom backends
- **Zero magic** - Simple, explicit API with predictable behavior
- **Battle-tested** - 201 tests, 93% coverage, production-grade error handling
- **Telemetry integration** - Built-in observability for monitoring and debugging
- **Deterministic mocking** - First-class testing support with mock backend

## Installation

Add `ex_outlines` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_outlines, "~> 0.1.0"}
  ]
end
```

## Quick Start

```elixir
alias ExOutlines.Spec.Schema

# Define a schema
schema = Schema.new(%{
  name: %{type: :string, required: true, description: "User's full name"},
  age: %{type: :integer, required: true, positive: true, description: "Age in years"},
  role: %{type: {:enum, ["admin", "user"]}, required: false}
})

# Generate validated output
{:ok, user} = ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    model: "gpt-4",
    temperature: 0.0
  ],
  max_retries: 3
)

# Use the validated data
IO.puts("Welcome, #{user.name}!")
IO.puts("Age: #{user.age}")
```

## How It Works

### 1. Initial Generation

ExOutlines sends the schema as JSON Schema to the LLM with instructions to generate valid JSON:

```
System: You are a structured data generator. Generate valid JSON matching the schema.
User: Generate JSON output conforming to this schema:
{
  "type": "object",
  "properties": {
    "name": {"type": "string", "description": "User's full name"},
    "age": {"type": "integer", "minimum": 1, "description": "Age in years"}
  },
  "required": ["name", "age"]
}
Respond with valid JSON only.
```

### 2. Validation

The LLM response is parsed and validated against the schema:

```elixir
# LLM responds with:
{"name": "Alice Smith", "age": -5}

# Validation fails:
# - Field: age
#   Expected: positive integer (> 0)
#   Got: -5
#   Issue: Field 'age' must be a positive integer (greater than 0)
```

### 3. Repair

On validation failure, ExOutlines extends the conversation with repair instructions:

```
Assistant: {"name": "Alice Smith", "age": -5}
User: Your previous output had validation errors:

- Field: age
  Expected: positive integer (> 0)
  Got: -5
  Issue: Field 'age' must be a positive integer (greater than 0)

Please provide corrected JSON that addresses all errors.
Respond with valid JSON only.
```

### 4. Retry Loop

This process continues until:
- ✅ Validation succeeds → `{:ok, validated_data}`
- ❌ Max retries exceeded → `{:error, :max_retries_exceeded}`
- ❌ Backend error → `{:error, {:backend_error, reason}}`

## Schema Definition

### Supported Types

```elixir
%{
  # String
  name: %{type: :string, required: true},

  # Integer
  count: %{type: :integer, required: true},

  # Positive integer (> 0)
  age: %{type: :integer, required: true, positive: true},

  # Boolean
  active: %{type: :boolean, required: true},

  # Number (integer or float)
  score: %{type: :number, required: true},

  # Enum
  status: %{type: {:enum, ["draft", "published", "archived"]}, required: true},

  # Optional field
  nickname: %{type: :string, required: false}
}
```

### Builder Pattern

```elixir
schema =
  Schema.new(%{})
  |> Schema.add_field(:id, :integer, required: true, positive: true)
  |> Schema.add_field(:title, :string, required: true, description: "Article title")
  |> Schema.add_field(:published, :boolean, required: false)
```

## Backends

### Mock Backend (Testing)

```elixir
alias ExOutlines.Backend.Mock

# Sequential responses
mock = Mock.new([
  {:ok, ~s({"name": "Alice", "age": 30})},
  {:ok, ~s({"name": "Alice", "age": 25})}  # Retry with corrected age
])

{:ok, user} = ExOutlines.generate(schema,
  backend: Mock,
  backend_opts: [mock: mock]
)
```

### HTTP Backend (Production)

```elixir
# OpenAI
ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    url: "https://api.openai.com/v1/chat/completions",
    model: "gpt-4",
    temperature: 0.0,
    max_tokens: 1000
  ]
)

# Azure OpenAI
ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: System.get_env("AZURE_API_KEY"),
    url: "https://your-resource.openai.azure.com/openai/deployments/your-deployment/chat/completions?api-version=2024-02-01",
    model: "gpt-4"
  ]
)

# Custom endpoint (Anthropic, local model, etc.)
ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: "sk-custom",
    url: "https://your-llm-proxy.com/v1/chat/completions",
    model: "custom-model"
  ]
)
```

### Custom Backend

Implement the `ExOutlines.Backend` behaviour:

```elixir
defmodule MyApp.CustomBackend do
  @behaviour ExOutlines.Backend

  @impl true
  def call_llm(messages, opts) do
    # Your implementation
    # messages: [%{role: "system" | "user" | "assistant", content: String.t()}]
    # opts: [model: String.t(), temperature: float(), ...]

    case your_llm_call(messages, opts) do
      {:ok, response_text} -> {:ok, response_text}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

## Error Handling

### Success

```elixir
{:ok, validated_data}
```

### Validation Failures (Retry Exhausted)

```elixir
{:error, :max_retries_exceeded}
```

### Backend Errors

```elixir
{:error, {:backend_error, reason}}
# Examples:
# {:error, {:backend_error, :timeout}}
# {:error, {:backend_error, :rate_limited}}
# {:error, {:backend_error, {:api_error, "insufficient credits"}}}
```

### Backend Exceptions

```elixir
{:error, {:backend_exception, exception}}
```

### Configuration Errors

```elixir
{:error, :no_backend}
{:error, {:invalid_backend, value}}
```

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/ex_outlines).

## Limitations (v0.1)

- **No nested objects** - Only flat field structures
- **No lists/arrays** - Can't validate lists of items
- **No custom validators** - Limited to built-in type constraints
- **No streaming** - Responses must be complete before validation
- **Stateless mock** - Mock backend doesn't track state across calls

See [CHANGELOG.md](CHANGELOG.md) for planned features in future versions.

## Testing

ExOutlines includes a deterministic mock backend for testing:

```elixir
defmodule MyApp.DataExtractorTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Spec.Schema, Backend.Mock}

  test "extracts user data correctly" do
    schema = Schema.new(%{
      name: %{type: :string, required: true},
      email: %{type: :string, required: true}
    })

    mock = Mock.new([
      {:ok, ~s({"name": "Alice", "email": "alice@example.com"})}
    ])

    assert {:ok, user} = ExOutlines.generate(schema,
      backend: Mock,
      backend_opts: [mock: mock]
    )

    assert user.name == "Alice"
    assert user.email == "alice@example.com"
  end
end
```

## Comparison to Python Outlines

| Feature | ExOutlines | Python Outlines |
|---------|------------|-----------------|
| **Approach** | Validate & repair (OTP-style) | Token-level guidance |
| **Backend flexibility** | Works with any LLM API | Requires specific model support |
| **Error handling** | Explicit retry with diagnostics | Prevents invalid tokens |
| **Setup complexity** | Zero config | Requires custom samplers |
| **Runtime overhead** | Multiple LLM calls | Single call with constrained sampling |
| **Error visibility** | Full diagnostic feedback | N/A (prevents errors) |
| **Implementation** | Pure Elixir, backend-agnostic | Python, model-dependent |

Both approaches are valid. Use ExOutlines when you need backend flexibility and explicit error handling. Use Python Outlines when you need guaranteed correctness on first attempt and have model control.

## Contributing

Contributions are welcome! Please:

1. Open an issue for discussion before major changes
2. Add tests for new functionality
3. Maintain existing code style (use `mix format`)
4. Ensure `mix credo --strict` passes
5. Update documentation

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Inspired by [Python Outlines](https://github.com/outlines-dev/outlines) by the Outlines team.

Built with:
- [Elixir](https://elixir-lang.org/)
- [Jason](https://github.com/michalmuskala/jason) for JSON parsing
- [Telemetry](https://github.com/beam-telemetry/telemetry) for observability

## Links

- [Documentation](https://hexdocs.pm/ex_outlines)
- [Hex.pm](https://hex.pm/packages/ex_outlines)
- [GitHub](https://github.com/your_org/ex_outlines)
- [Changelog](CHANGELOG.md)
