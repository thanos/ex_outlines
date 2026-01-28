# Stage 6 Summary: Backend Implementation

## Overview

Implemented backend abstraction layer with deterministic mock and real HTTP adapter for LLM communication.

## Deliverables

### 1. Mock Backend (`ExOutlines.Backend.Mock`)

**Purpose:** Deterministic testing without external dependencies

**Features:**
- Pre-configured response sequences
- Error simulation
- Stateless design for simplicity
- Helper constructors for common patterns

**API:**
```elixir
# Sequential responses
mock = Mock.new([
  {:ok, ~s({"name": "Alice", "age": 30})},
  {:ok, ~s({"name": "Alice", "age": 25})}
])

# Always return same response
mock = Mock.always({:ok, "response"})

# Always fail
mock = Mock.always_fail(:timeout)

# Track call count
Mock.call_count(mock)  # => 0
```

**Usage:**
```elixir
ExOutlines.generate(schema,
  backend: ExOutlines.Backend.Mock,
  backend_opts: [mock: mock]
)
```

**Implementation Notes:**
- Stateless by design (responses don't advance automatically)
- For stateful retry testing, wrap in GenServer/Agent
- Passes mock instance in backend_opts
- Returns `:no_mock_provided` if mock not in opts
- Returns `:no_more_responses` when exhausted

**Test Coverage:**
- 20 tests covering all functionality
- Integration tests with ExOutlines.generate/2
- Retry flow verification
- Error handling simulation

### 2. HTTP Backend (`ExOutlines.Backend.HTTP`)

**Purpose:** Real LLM API communication using Erlang's :httpc

**Features:**
- OpenAI-compatible endpoint support
- Zero additional dependencies (uses :httpc from stdlib)
- SSL/TLS with certificate verification
- Configuration validation
- Comprehensive error handling

**Configuration:**
```elixir
backend_opts: [
  api_key: "sk-...",                                      # Required
  model: "gpt-4",                                         # Required
  url: "https://api.openai.com/v1/chat/completions",    # Optional (default)
  temperature: 0.0,                                       # Optional (default)
  max_tokens: 1000                                        # Optional (default)
]
```

**Validation:**
- `:api_key` - Must be non-empty string
- `:model` - Must be non-empty string
- `:url` - Must be valid string (defaults to OpenAI)
- `:temperature` - Number in range [0.0, 2.0]
- `:max_tokens` - Positive integer ≥ 1

**Error Types:**
```elixir
{:error, :missing_api_key}
{:error, :missing_model}
{:error, :invalid_url}
{:error, :invalid_temperature}
{:error, :invalid_max_tokens}
{:error, {:http_error, status_code, body}}
{:error, {:request_failed, reason}}
{:error, {:api_error, error}}
{:error, {:json_encode_error, error}}
{:error, {:json_decode_error, error}}
{:error, {:unexpected_response, data}}
```

**Implementation Details:**
- Uses `:httpc` for HTTP requests (no external deps)
- SSL verification with :verify_peer and system certs
- 60-second timeout per request
- Starts :inets and :ssl applications automatically
- Parses OpenAI chat completion response format
- Extracts content from first choice message

**Code Quality Improvements:**
- Refactored `validate_config/1` into smaller functions
- Reduced cyclomatic complexity from 12 to 3
- Each validation function handles one concern
- Uses `with` for clean error propagation

**Test Coverage:**
- 13 tests covering configuration validation
- Tests for all error conditions
- Tests for default value handling
- Tests for valid configuration ranges
- Does not make real HTTP calls (tests config only)

### 3. Application Configuration

**Updated `mix.exs`:**
```elixir
extra_applications: [:logger, :inets, :ssl, :public_key]
```

Added Erlang standard library applications needed for HTTP backend:
- `:inets` - HTTP client
- `:ssl` - TLS/SSL support
- `:public_key` - Certificate verification

## Test Results

```
12 doctests, 169 tests, 0 failures
```

**New tests:** 33 (20 Mock + 13 HTTP)
**Previous:** 136 tests
**Total:** 169 tests

## Code Quality

```
mix credo --strict
118 mods/funs, found no issues.
```

- Zero Credo warnings
- All code formatted with `mix format`
- Cyclomatic complexity within limits
- Clean compilation (no warnings)

## Design Decisions

### Why Mock is Stateless

The mock backend is intentionally stateless to keep it simple. For stateful retry testing, users can wrap it in a GenServer or Agent. This keeps the mock itself simple and deterministic.

Example stateful wrapper:
```elixir
{:ok, agent} = Agent.start_link(fn ->
  %{responses: [...], index: 0}
end)

# Use agent in tests to track state
```

### Why :httpc Instead of HTTPoison/Finch

Using Erlang's standard library `:httpc`:
- **Zero dependencies** - No need for external HTTP client
- **Always available** - Part of OTP
- **Production-ready** - Battle-tested in Erlang ecosystem
- **Sufficient** - Meets all requirements for simple HTTP calls

Future versions could add optional support for other clients if needed.

### Why OpenAI-Compatible Format

The HTTP backend uses OpenAI's chat completion format because:
- Industry standard for LLM APIs
- Many providers implement compatible endpoints
- Simple message format (role + content)
- Well-documented and widely understood

Other providers can:
1. Implement their own backend behaviour
2. Use proxy/adapter services
3. Self-host compatible endpoints

## Usage Examples

### Testing with Mock

```elixir
test "validates user schema" do
  schema = Schema.new(%{
    name: %{type: :string, required: true},
    age: %{type: :integer, required: true, positive: true}
  })

  mock = Mock.new([
    {:ok, ~s({"name": "Alice", "age": 30})}
  ])

  assert {:ok, user} = ExOutlines.generate(schema,
    backend: Mock,
    backend_opts: [mock: mock]
  )

  assert user.name == "Alice"
  assert user.age == 30
end
```

### Production with OpenAI

```elixir
schema = Schema.new(%{
  summary: %{type: :string, required: true},
  sentiment: %{type: {:enum, ["positive", "negative", "neutral"]}, required: true}
})

result = ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    model: "gpt-4",
    temperature: 0.0
  ],
  max_retries: 3
)

case result do
  {:ok, analysis} ->
    IO.puts("Summary: #{analysis.summary}")
    IO.puts("Sentiment: #{analysis.sentiment}")

  {:error, reason} ->
    Logger.error("Failed to analyze: #{inspect(reason)}")
end
```

### Custom Endpoint (Azure OpenAI, Anthropic proxy, etc.)

```elixir
ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: "custom-key",
    url: "https://your-endpoint.com/v1/chat/completions",
    model: "your-model",
    temperature: 0.0
  ]
)
```

## File Structure

```
lib/ex_outlines/
├── backend.ex                  # Behaviour definition (Stage 1)
└── backend/
    ├── mock.ex                 # Mock implementation (Stage 6)
    └── http.ex                 # HTTP implementation (Stage 6)

test/ex_outlines/backend/
├── mock_test.exs               # Mock tests (Stage 6)
└── http_test.exs               # HTTP tests (Stage 6)
```

## API Reference

### ExOutlines.Backend (behaviour)

```elixir
@callback call_llm(messages :: [message()], opts :: call_opts()) ::
            {:ok, String.t()} | {:error, term()}

@type message :: %{role: String.t(), content: String.t()}
@type call_opts :: keyword()
```

### ExOutlines.Backend.Mock

```elixir
@spec new([response()]) :: t()
@spec always(response()) :: t()
@spec always_fail(term()) :: t()
@spec call_count(t()) :: non_neg_integer()
```

### ExOutlines.Backend.HTTP

```elixir
# Uses ExOutlines.Backend behaviour
# No additional public API
# Configuration via opts keyword list
```

## Integration Points

**With Core Engine:**
- Called by `ExOutlines.generate/2` via `call_llm/2`
- Receives messages from `ExOutlines.Prompt`
- Returns raw LLM response text (JSON string)
- Errors wrapped in `{:error, {:backend_error, reason}}`

**With Prompt Module:**
- Consumes message format from `Prompt.build_initial/1`
- Consumes repair messages from `Prompt.build_repair/2`
- Messages have OpenAI-compatible structure:
  ```elixir
  %{role: "system" | "user" | "assistant", content: String.t()}
  ```

**With Retry Loop:**
- Backend errors trigger immediate failure (no retry)
- Backend exceptions caught and returned as errors
- Validation errors trigger repair retry (not backend retry)

## Future Enhancements

Potential additions for v0.2+:

1. **Streaming Support**
   - Stream tokens as they arrive
   - Early validation/rejection
   - Progress callbacks

2. **Additional Backends**
   - Anthropic Claude API
   - Google PaLM API
   - Local model support (Ollama, llama.cpp)
   - Azure OpenAI service

3. **Stateful Mock**
   - GenServer-based mock with state tracking
   - Assertion helpers for call verification
   - Sequence enforcement

4. **Advanced HTTP Features**
   - Connection pooling (Finch/Mint)
   - Request retry with backoff
   - Rate limit handling
   - Metrics collection

5. **Backend Middleware**
   - Caching layer
   - Request/response logging
   - Cost tracking
   - Latency monitoring

## Stage 6 Checklist

- [x] Implement `ExOutlines.Backend` behaviour
- [x] Implement `ExOutlines.Backend.Mock`
- [x] Implement one real backend adapter (HTTP)
- [x] Support temperature configuration
- [x] Support constraints (model, max_tokens)
- [x] Enable deterministic mock testing
- [x] Write comprehensive tests (33 tests)
- [x] Pass all tests (169 total)
- [x] Pass Credo strict checks
- [x] Format all code
- [x] Zero compilation warnings
- [x] Document implementation decisions
- [x] Provide usage examples

## Summary

Stage 6 successfully implemented:
- Complete backend abstraction with behaviour definition
- Deterministic mock backend for testing (zero dependencies)
- Production-ready HTTP backend (zero external dependencies)
- 33 comprehensive tests (169 total)
- Clean code quality (Credo strict passes)
- Clear documentation and examples

The backend system is now ready for Stage 7 (comprehensive test suite) and Stage 8 (documentation & polish).
