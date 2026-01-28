# Testing Strategies Guide

Learn how to effectively test applications using ExOutlines with Mock backends, integration tests, and property-based testing.

## Overview

Testing LLM-powered features requires special strategies since actual LLM calls are expensive, slow, and non-deterministic. This guide shows you how to write fast, reliable tests using ExOutlines' Mock backend and other testing techniques.

**What You'll Learn:**
- Using the Mock backend for unit tests
- Writing deterministic test data
- Testing retry and error handling
- Integration test patterns
- Property-based testing with StreamData
- CI/CD integration
- Test organization strategies

## Prerequisites

- ExUnit test framework (included with Elixir)
- Basic understanding of ExUnit and testing patterns
- (Optional) StreamData for property-based testing

```elixir
# mix.exs - test dependencies
defp deps do
  [
    {:ex_outlines, "~> 0.2.0"},
    {:stream_data, "~> 0.6", only: :test}
  ]
end
```

## Pattern 1: Unit Tests with Mock Backend

The Mock backend provides deterministic, fast tests without actual LLM calls.

### Basic Mock Usage

```elixir
defmodule MyApp.ContentAnalyzerTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Spec.Schema, Backend.Mock}
  alias MyApp.ContentAnalyzer

  describe "analyze/1" do
    test "successfully analyzes content" do
      schema = Schema.new(%{
        summary: %{type: :string, required: true},
        sentiment: %{type: {:enum, ["positive", "neutral", "negative"]}, required: true}
      })

      # Create mock with predefined response
      mock_response = Jason.encode!(%{
        summary: "This is a test summary",
        sentiment: "positive"
      })

      mock = Mock.new([{:ok, mock_response}])

      # Use mock in your function
      result = ContentAnalyzer.analyze("test content",
        backend: Mock,
        backend_opts: [mock: mock]
      )

      assert {:ok, %{summary: "This is a test summary", sentiment: "positive"}} = result
    end

    test "handles validation errors" do
      schema = Schema.new(%{
        sentiment: %{type: {:enum, ["positive", "neutral", "negative"]}, required: true}
      })

      # Mock returns invalid data
      mock_response = Jason.encode!(%{
        sentiment: "invalid_value" # Not in enum
      })

      mock = Mock.new([{:ok, mock_response}])

      result = ContentAnalyzer.analyze("test content",
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 1
      )

      assert {:error, :max_retries_exceeded} = result
    end
  end
end
```

### Testing Retry Behavior

```elixir
describe "retry behavior" do
  test "succeeds after repair attempt" do
    schema = Schema.new(%{
      count: %{type: :integer, required: true, min: 0, max: 10}
    })

    # First response fails validation, second succeeds
    invalid_response = Jason.encode!(%{count: 15}) # > max
    valid_response = Jason.encode!(%{count: 5})

    mock = Mock.new([
      {:ok, invalid_response},
      {:ok, valid_response}
    ])

    result = ExOutlines.generate(schema,
      backend: Mock,
      backend_opts: [mock: mock],
      max_retries: 2
    )

    assert {:ok, %{count: 5}} = result
  end

  test "fails after max retries" do
    schema = Schema.new(%{
      value: %{type: :integer, required: true}
    })

    # All responses are invalid
    invalid_response = Jason.encode!(%{value: "not an integer"})

    mock = Mock.new([
      {:ok, invalid_response},
      {:ok, invalid_response},
      {:ok, invalid_response}
    ])

    result = ExOutlines.generate(schema,
      backend: Mock,
      backend_opts: [mock: mock],
      max_retries: 2
    )

    assert {:error, :max_retries_exceeded} = result
  end
end
```

### Testing Error Handling

```elixir
describe "error handling" do
  test "handles backend errors" do
    schema = Schema.new(%{name: %{type: :string, required: true}})

    # Mock returns an error
    mock = Mock.new([{:error, :connection_failed}])

    result = ExOutlines.generate(schema,
      backend: Mock,
      backend_opts: [mock: mock]
    )

    assert {:error, {:backend_error, :connection_failed}} = result
  end

  test "handles invalid JSON" do
    schema = Schema.new(%{name: %{type: :string, required: true}})

    # Mock returns invalid JSON
    mock = Mock.new([{:ok, "not valid json {"}])

    result = ExOutlines.generate(schema,
      backend: Mock,
      backend_opts: [mock: mock],
      max_retries: 1
    )

    assert {:error, :max_retries_exceeded} = result
  end
end
```

## Pattern 2: Testing Phoenix Controllers

Test controllers using Mock backend for fast, deterministic tests.

### Controller Test Example

```elixir
defmodule MyAppWeb.AIControllerTest do
  use MyAppWeb.ConnCase, async: true

  alias ExOutlines.Backend.Mock

  describe "POST /api/analyze" do
    test "returns analysis results", %{conn: conn} do
      # Mock successful LLM response
      mock_response = Jason.encode!(%{
        summary: "Test summary",
        sentiment: "positive",
        topics: ["elixir", "testing"]
      })

      # Store mock in conn assigns for controller to use
      conn = assign(conn, :llm_mock, Mock.new([{:ok, mock_response}]))

      conn = post(conn, ~p"/api/analyze", %{text: "Test content"})

      assert %{
        "success" => true,
        "data" => %{
          "summary" => "Test summary",
          "sentiment" => "positive",
          "topics" => ["elixir", "testing"]
        }
      } = json_response(conn, 200)
    end

    test "returns error when LLM fails", %{conn: conn} do
      # Mock LLM failure
      mock = Mock.new([{:error, :service_unavailable}])
      conn = assign(conn, :llm_mock, mock)

      conn = post(conn, ~p"/api/analyze", %{text: "Test content"})

      assert %{
        "success" => false,
        "error" => _error_message
      } = json_response(conn, 500)
    end
  end
end

# In your controller, use the mock if present
defp get_backend(conn) do
  case conn.assigns[:llm_mock] do
    nil -> {ExOutlines.Backend.Anthropic, [api_key: get_api_key()]}
    mock -> {Mock, [mock: mock]}
  end
end
```

### Testing LiveView

```elixir
defmodule MyAppWeb.ContentAnalyzerLiveTest do
  use MyAppWeb.ConnCase

  import Phoenix.LiveViewTest
  alias ExOutlines.Backend.Mock

  describe "content analysis" do
    test "displays analysis results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analyze")

      # Mock LLM response
      mock_response = Jason.encode!(%{
        title: "Test Title",
        summary: "Test Summary",
        key_points: ["Point 1", "Point 2", "Point 3"]
      })

      # Inject mock into LiveView process
      send(view.pid, {:set_mock, Mock.new([{:ok, mock_response}])})

      # Submit form
      view
      |> form("form", %{text: "Test content"})
      |> render_submit()

      # Wait for async analysis
      assert render(view) =~ "Test Title"
      assert render(view) =~ "Test Summary"
      assert render(view) =~ "Point 1"
    end

    test "displays error message on failure", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/analyze")

      # Mock failure
      send(view.pid, {:set_mock, Mock.new([{:error, :timeout}])})

      view
      |> form("form", %{text: "Test content"})
      |> render_submit()

      assert render(view) =~ "error"
    end
  end
end
```

## Pattern 3: Integration Tests

Test actual LLM integration in a controlled way (use sparingly, these are slow and costly).

### Integration Test Setup

```elixir
# test/support/integration_case.ex
defmodule MyApp.IntegrationCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

      def skip_if_no_api_key(context) do
        if System.get_env("ANTHROPIC_API_KEY") do
          context
        else
          {:ok, Map.put(context, :skip, true)}
        end
      end
    end
  end
end

# In test_helper.exs
ExUnit.configure(exclude: [integration: true])

# Run integration tests with:
# mix test --only integration
```

### Integration Test Example

```elixir
defmodule MyApp.LLMIntegrationTest do
  use MyApp.IntegrationCase, async: false

  alias ExOutlines.{Spec.Schema, Backend.Anthropic}

  @moduletag :integration

  setup :skip_if_no_api_key

  describe "real LLM integration" do
    @tag timeout: 60_000 # Longer timeout for real API
    test "generates valid structured output" do
      schema = Schema.new(%{
        language: %{type: {:enum, ["elixir", "python", "javascript"]}, required: true}
      })

      result = ExOutlines.generate(schema,
        backend: Anthropic,
        backend_opts: [
          api_key: System.fetch_env!("ANTHROPIC_API_KEY"),
          model: "claude-sonnet-4-5-20250929"
        ],
        max_retries: 2
      )

      assert {:ok, %{language: lang}} = result
      assert lang in ["elixir", "python", "javascript"]
    end
  end
end
```

## Pattern 4: Property-Based Testing

Use StreamData to generate test cases automatically.

### Basic Property Test

```elixir
defmodule MyApp.SchemaPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ExOutlines.{Spec, Spec.Schema}

  describe "schema validation properties" do
    property "valid integers are accepted" do
      schema = Schema.new(%{
        value: %{type: :integer, required: true, min: 0, max: 100}
      })

      check all value <- integer(0..100) do
        assert {:ok, %{value: ^value}} = Spec.validate(schema, %{"value" => value})
      end
    end

    property "strings within length constraints are accepted" do
      schema = Schema.new(%{
        text: %{type: :string, required: true, min_length: 5, max_length: 20}
      })

      check all text <- string(:alphanumeric, min_length: 5, max_length: 20) do
        result = Spec.validate(schema, %{"text" => text})
        assert {:ok, %{text: ^text}} = result
      end
    end

    property "arrays respect size constraints" do
      schema = Schema.new(%{
        items: %{
          type: {:array, %{type: :integer}},
          min_items: 1,
          max_items: 5
        }
      })

      check all items <- list_of(integer(), min_length: 1, max_length: 5) do
        result = Spec.validate(schema, %{"items" => items})
        assert {:ok, %{items: ^items}} = result
      end
    end
  end
end
```

### Testing Complex Schemas

```elixir
defmodule MyApp.ComplexSchemaTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ExOutlines.{Spec, Spec.Schema}

  property "nested objects validate correctly" do
    user_schema = Schema.new(%{
      name: %{type: :string, required: true, min_length: 1, max_length: 50},
      age: %{type: :integer, required: true, min: 0, max: 120}
    })

    schema = Schema.new(%{
      user: %{type: {:object, user_schema}, required: true}
    })

    check all name <- string(:alphanumeric, min_length: 1, max_length: 50),
              age <- integer(0..120) do
      data = %{"user" => %{"name" => name, "age" => age}}
      result = Spec.validate(schema, data)

      assert {:ok, %{user: %{name: ^name, age: ^age}}} = result
    end
  end
end
```

## Pattern 5: Test Helpers

Create reusable test helpers for common patterns.

### Test Helpers Module

```elixir
defmodule MyApp.TestHelpers do
  alias ExOutlines.Backend.Mock

  @doc """
  Creates a mock that returns valid JSON for a schema.
  """
  def mock_success(data) when is_map(data) do
    Mock.new([{:ok, Jason.encode!(data)}])
  end

  @doc """
  Creates a mock that fails validation then succeeds.
  """
  def mock_with_retry(invalid_data, valid_data) do
    Mock.new([
      {:ok, Jason.encode!(invalid_data)},
      {:ok, Jason.encode!(valid_data)}
    ])
  end

  @doc """
  Creates a mock that always fails.
  """
  def mock_failure(error \\ :service_unavailable) do
    Mock.new([{:error, error}])
  end

  @doc """
  Creates a mock that returns invalid JSON.
  """
  def mock_invalid_json do
    Mock.new([{:ok, "not valid json"}])
  end

  @doc """
  Waits for async operation in LiveView tests.
  """
  def wait_for_condition(view, condition_fn, timeout \\ 1000) do
    deadline = System.monotonic_time(:millisecond) + timeout

    do_wait(view, condition_fn, deadline)
  end

  defp do_wait(view, condition_fn, deadline) do
    if condition_fn.(view) do
      :ok
    else
      if System.monotonic_time(:millisecond) < deadline do
        Process.sleep(50)
        do_wait(view, condition_fn, deadline)
      else
        raise "Timeout waiting for condition"
      end
    end
  end
end

# Usage in tests
import MyApp.TestHelpers

test "example with helpers" do
  mock = mock_success(%{name: "Alice", age: 30})

  result = MyFunction.call(
    backend: Mock,
    backend_opts: [mock: mock]
  )

  assert {:ok, %{name: "Alice"}} = result
end
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    env:
      MIX_ENV: test
      # Set if you want to run integration tests in CI
      # ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

    steps:
      - uses: actions/checkout@v3

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.16'
          otp-version: '26'

      - name: Install dependencies
        run: mix deps.get

      - name: Run unit tests
        run: mix test --exclude integration

      # Optional: Run integration tests
      # - name: Run integration tests
      #   run: mix test --only integration
      #   if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

### Test Organization

```
test/
├── ex_outlines/           # Library tests
├── my_app/
│   ├── unit/              # Fast unit tests with mocks
│   │   ├── analyzers/
│   │   └── processors/
│   ├── integration/       # Slow integration tests
│   │   └── llm_integration_test.exs
│   └── properties/        # Property-based tests
│       └── schema_properties_test.exs
├── my_app_web/
│   ├── controllers/       # Controller tests
│   └── live/              # LiveView tests
└── support/
    ├── conn_case.ex
    ├── integration_case.ex
    └── test_helpers.ex
```

## Common Pitfalls

### 1. Not Using Async Tests

**Problem:** Tests run slowly

**Solution:** Use `async: true` for tests with Mock backend

```elixir
# Good - runs concurrently
use ExUnit.Case, async: true

# Only use async: false for integration tests or shared state
use ExUnit.Case, async: false
```

### 2. Forgetting to Exclude Integration Tests

**Problem:** Slow, expensive tests run on every test run

**Solution:** Tag and exclude by default

```elixir
# test_helper.exs
ExUnit.configure(exclude: [integration: true])

# Run when needed
# mix test --only integration
```

### 3. Hardcoding Test Data

**Problem:** Tests are brittle and hard to maintain

**Solution:** Use factories or generators

```elixir
# Good - reusable test data
defmodule MyApp.Factory do
  def build(:analysis_result) do
    %{
      summary: "Test summary",
      sentiment: "positive",
      topics: ["test", "data"]
    }
  end
end

# Usage
mock = mock_success(Factory.build(:analysis_result))
```

## Best Practices

1. **Use Mock for Unit Tests**: Fast, deterministic, no API costs
2. **Tag Integration Tests**: Run separately, only when needed
3. **Test Error Paths**: Test failures, timeouts, invalid responses
4. **Use Property Tests**: Find edge cases automatically
5. **Keep Tests Fast**: Aim for < 5 seconds for full suite
6. **Organize by Speed**: unit/ vs integration/ directories
7. **Document Test Patterns**: Create helper modules for common patterns

## Testing Checklist

- [ ] Unit tests use Mock backend
- [ ] Integration tests are tagged and excluded by default
- [ ] Error handling is tested
- [ ] Retry behavior is tested
- [ ] Property tests for complex schemas
- [ ] Helper modules for common patterns
- [ ] CI/CD pipeline configured
- [ ] Tests run in < 5 seconds (excluding integration)
- [ ] All tests are deterministic (no random failures)

## Related Guides

- [Phoenix Integration](phoenix_integration.md) - Test your Phoenix integration
- [Error Handling](error_handling.md) - Test error scenarios
- [Performance Optimization](performance_optimization.md) - Benchmark your code

## Further Reading

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/)
- [StreamData Documentation](https://hexdocs.pm/stream_data/)
- [Testing Phoenix Applications](https://hexdocs.pm/phoenix/testing.html)
- [Property-Based Testing with StreamData](https://hexdocs.pm/stream_data/property_based_testing.html)
