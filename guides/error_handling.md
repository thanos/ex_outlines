# Error Handling Guide

Master error handling strategies for ExOutlines applications, from understanding diagnostics to implementing graceful degradation.

## Overview

LLM applications face unique error scenarios: validation failures, API timeouts, rate limiting, and non-deterministic outputs. This guide teaches you how to build resilient applications that handle these errors gracefully.

**What You'll Learn:**
- Understanding Diagnostics structure
- Custom error messages and user feedback
- Retry strategies and configuration
- Graceful degradation patterns
- Logging and monitoring with telemetry
- Circuit breaker patterns
- Production error handling

## Prerequisites

- Basic understanding of ExOutlines
- Familiarity with Elixir error handling (`{:ok, result}` / `{:error, reason}`)
- (Optional) Logger and telemetry for monitoring

## Understanding Diagnostics

ExOutlines returns detailed diagnostics when validation fails.

### Diagnostics Structure

```elixir
%ExOutlines.Diagnostics{
  errors: [
    %{
      field: "age",              # Field that failed
      expected: "integer",       # What was expected
      got: "thirty",             # What was received
      message: "Field 'age' must be an integer"
    }
  ],
  repair_instructions: "Field 'age' must be an integer. Got: \"thirty\""
}
```

### Inspecting Diagnostics

```elixir
case ExOutlines.generate(schema, opts) do
  {:ok, result} ->
    {:ok, result}

  {:error, :max_retries_exceeded} ->
    # Validation failed after all retries
    # Original diagnostics are lost at this point
    {:error, "Unable to generate valid output"}

  {:error, {:backend_error, reason}} ->
    # Backend communication failure
    {:error, "Service unavailable: #{inspect(reason)}"}

  {:error, reason} ->
    {:error, "Unexpected error: #{inspect(reason)}"}
end
```

### Capturing Diagnostics

To capture diagnostics, use telemetry events:

```elixir
:telemetry.attach(
  "diagnostics-logger",
  [:ex_outlines, :attempt, :validation_failed],
  fn _event, _measurements, metadata, _config ->
    diagnostics = metadata.diagnostics

    IO.puts("Validation failed:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  - #{error.message}")
    end)
  end,
  nil
)
```

## Pattern 1: User-Friendly Error Messages

Transform technical errors into user-friendly messages.

### Error Message Formatter

```elixir
defmodule MyApp.ErrorFormatter do
  @moduledoc """
  Converts ExOutlines errors into user-friendly messages.
  """

  def format_error({:error, :max_retries_exceeded}) do
    %{
      message: "We couldn't process your request. Please try again or contact support.",
      code: :generation_failed,
      retryable: true
    }
  end

  def format_error({:error, {:backend_error, :rate_limited}}) do
    %{
      message: "Our service is experiencing high demand. Please try again in a few minutes.",
      code: :rate_limited,
      retryable: true,
      retry_after: 60 # seconds
    }
  end

  def format_error({:error, {:backend_error, :invalid_api_key}}) do
    %{
      message: "Service configuration error. Please contact support.",
      code: :configuration_error,
      retryable: false
    }
  end

  def format_error({:error, {:backend_error, reason}}) do
    %{
      message: "Our AI service is temporarily unavailable. Please try again later.",
      code: :service_unavailable,
      retryable: true,
      technical_details: inspect(reason)
    }
  end

  def format_error({:error, :no_backend}) do
    %{
      message: "Service is not properly configured.",
      code: :configuration_error,
      retryable: false
    }
  end

  def format_error({:error, reason}) do
    %{
      message: "An unexpected error occurred. Please try again.",
      code: :unknown_error,
      retryable: true,
      technical_details: inspect(reason)
    }
  end

  def format_error({:ok, result}), do: {:ok, result}
end

# Usage in controller
def analyze(conn, params) do
  case MyApp.LLM.analyze(params) |> ErrorFormatter.format_error() do
    {:ok, result} ->
      json(conn, %{success: true, data: result})

    error_info ->
      conn
      |> put_status(error_status(error_info.code))
      |> json(%{
        success: false,
        error: error_info.message,
        code: error_info.code,
        retryable: error_info.retryable
      })
  end
end

defp error_status(:rate_limited), do: 429
defp error_status(:service_unavailable), do: 503
defp error_status(:configuration_error), do: 500
defp error_status(_), do: 500
```

## Pattern 2: Retry Strategies

Configure retry behavior for different scenarios.

### Basic Retry Configuration

```elixir
# Conservative - for expensive operations
ExOutlines.generate(schema,
  backend: Anthropic,
  backend_opts: [...],
  max_retries: 1  # Try once, give up if fails
)

# Standard - for most use cases
ExOutlines.generate(schema,
  backend: Anthropic,
  backend_opts: [...],
  max_retries: 3  # Default
)

# Aggressive - for critical operations
ExOutlines.generate(schema,
  backend: Anthropic,
  backend_opts: [...],
  max_retries: 5  # More attempts
)
```

### Custom Retry Logic

```elixir
defmodule MyApp.RetryableGeneration do
  require Logger

  def generate_with_backoff(schema, opts, max_attempts \\ 3) do
    do_generate(schema, opts, 1, max_attempts)
  end

  defp do_generate(schema, opts, attempt, max_attempts) when attempt > max_attempts do
    Logger.error("Failed to generate after #{max_attempts} attempts")
    {:error, :max_attempts_exceeded}
  end

  defp do_generate(schema, opts, attempt, max_attempts) do
    case ExOutlines.generate(schema, Keyword.put(opts, :max_retries, 2)) do
      {:ok, result} ->
        {:ok, result}

      {:error, :max_retries_exceeded} = error ->
        backoff_ms = calculate_backoff(attempt)
        Logger.warning("Generation failed, retrying after #{backoff_ms}ms",
          attempt: attempt,
          max_attempts: max_attempts
        )

        Process.sleep(backoff_ms)
        do_generate(schema, opts, attempt + 1, max_attempts)

      {:error, {:backend_error, :rate_limited}} = error ->
        # Special handling for rate limits
        backoff_ms = 60_000 # Wait 1 minute
        Logger.warning("Rate limited, waiting #{backoff_ms}ms")

        Process.sleep(backoff_ms)
        do_generate(schema, opts, attempt + 1, max_attempts)

      {:error, _reason} = error ->
        # Don't retry for other errors
        error
    end
  end

  defp calculate_backoff(attempt) do
    # Exponential backoff: 1s, 2s, 4s, 8s, ...
    :math.pow(2, attempt - 1) * 1000 |> round()
  end
end
```

## Pattern 3: Graceful Degradation

Provide fallback behavior when LLM fails.

### Fallback Pattern

```elixir
defmodule MyApp.ContentEnricher do
  def enrich_content(content) do
    case enrich_with_llm(content) do
      {:ok, enriched} ->
        {:ok, enriched}

      {:error, _reason} ->
        # Fall back to rule-based enrichment
        {:ok, enrich_with_rules(content)}
    end
  end

  defp enrich_with_llm(content) do
    schema = Schema.new(%{
      summary: %{type: :string, max_length: 200},
      category: %{type: {:enum, ["tech", "business", "health"]}}
    })

    ExOutlines.generate(schema,
      backend: Anthropic,
      backend_opts: [api_key: get_api_key()],
      max_retries: 2
    )
  end

  defp enrich_with_rules(content) do
    %{
      summary: String.slice(content, 0..200),
      category: detect_category_by_keywords(content)
    }
  end

  defp detect_category_by_keywords(content) do
    cond do
      String.contains?(content, ~w[technology software code]) -> "tech"
      String.contains?(content, ~w[market revenue profit]) -> "business"
      true -> "general"
    end
  end
end
```

### Cached Fallback

```elixir
defmodule MyApp.SmartFallback do
  @moduledoc """
  Use cached previous result as fallback.
  """

  def generate_with_cache_fallback(schema, opts, cache_key) do
    case ExOutlines.generate(schema, opts) do
      {:ok, result} = success ->
        # Cache successful result
        Cachex.put(:llm_cache, cache_key, result)
        success

      {:error, reason} ->
        # Try to use cached result
        case Cachex.get(:llm_cache, cache_key) do
          {:ok, cached_result} when not is_nil(cached_result) ->
            Logger.warning("Using cached fallback due to error",
              reason: inspect(reason)
            )
            {:ok, cached_result}

          _ ->
            {:error, reason}
        end
    end
  end
end
```

## Pattern 4: Circuit Breaker

Prevent cascading failures by temporarily stopping LLM calls after repeated failures.

### Circuit Breaker Implementation

```elixir
defmodule MyApp.CircuitBreaker do
  use GenServer
  require Logger

  @failure_threshold 5
  @open_duration_ms 60_000 # 1 minute

  defmodule State do
    defstruct [
      :status,           # :closed, :open, :half_open
      :failure_count,
      :last_failure_time
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def call(fun) when is_function(fun, 0) do
    GenServer.call(__MODULE__, {:call, fun})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %State{
      status: :closed,
      failure_count: 0,
      last_failure_time: nil
    }}
  end

  @impl true
  def handle_call({:call, fun}, _from, state) do
    case state.status do
      :open ->
        if should_attempt_half_open?(state) do
          # Try half-open
          execute_with_transition(fun, %{state | status: :half_open})
        else
          # Still open, reject immediately
          {:reply, {:error, :circuit_open}, state}
        end

      :half_open ->
        # In half-open, try the call
        execute_with_transition(fun, state)

      :closed ->
        # Normal operation
        execute_with_transition(fun, state)
    end
  end

  defp execute_with_transition(fun, state) do
    case fun.() do
      {:ok, _result} = success ->
        # Success - reset circuit
        {:reply, success, %{state |
          status: :closed,
          failure_count: 0,
          last_failure_time: nil
        }}

      {:error, _reason} = error ->
        # Failure - increment count
        new_failure_count = state.failure_count + 1
        new_status = if new_failure_count >= @failure_threshold do
          Logger.warning("Circuit breaker opening after #{new_failure_count} failures")
          :open
        else
          state.status
        end

        {:reply, error, %{state |
          status: new_status,
          failure_count: new_failure_count,
          last_failure_time: System.monotonic_time(:millisecond)
        }}
    end
  end

  defp should_attempt_half_open?(%{last_failure_time: nil}), do: false
  defp should_attempt_half_open?(%{last_failure_time: last_time}) do
    System.monotonic_time(:millisecond) - last_time > @open_duration_ms
  end
end

# Usage
MyApp.CircuitBreaker.call(fn ->
  ExOutlines.generate(schema, opts)
end)
```

## Pattern 5: Monitoring with Telemetry

Track errors and performance with telemetry events.

### Telemetry Handler

```elixir
defmodule MyApp.LLMTelemetry do
  require Logger

  def attach do
    events = [
      [:ex_outlines, :generate, :stop],
      [:ex_outlines, :attempt, :validation_failed],
      [:ex_outlines, :attempt, :backend_error],
      [:ex_outlines, :retry, :initiated]
    ]

    :telemetry.attach_many(
      "llm-monitoring",
      events,
      &handle_event/4,
      nil
    )
  end

  def handle_event(
        [:ex_outlines, :generate, :stop],
        %{duration: duration},
        %{result: :error, reason: reason},
        _config
      ) do
    Logger.error("LLM generation failed",
      duration_ms: duration / 1_000_000,
      reason: inspect(reason)
    )

    # Send to monitoring service
    MyApp.Metrics.increment("llm.generation.error", 1, tags: [
      error_type: error_type(reason)
    ])
  end

  def handle_event(
        [:ex_outlines, :attempt, :validation_failed],
        _measurements,
        metadata,
        _config
      ) do
    diagnostics = metadata.diagnostics

    Logger.warning("Validation failed, will retry",
      errors: Enum.map(diagnostics.errors, & &1.message)
    )

    MyApp.Metrics.increment("llm.validation.failed", 1)
  end

  def handle_event(
        [:ex_outlines, :attempt, :backend_error],
        _measurements,
        %{reason: reason},
        _config
      ) do
    Logger.error("Backend error", reason: inspect(reason))

    MyApp.Metrics.increment("llm.backend.error", 1, tags: [
      error_type: inspect(reason)
    ])
  end

  def handle_event([:ex_outlines, :retry, :initiated], _measurements, _metadata, _config) do
    MyApp.Metrics.increment("llm.retry.initiated", 1)
  end

  defp error_type(:max_retries_exceeded), do: "max_retries"
  defp error_type({:backend_error, _}), do: "backend_error"
  defp error_type(_), do: "unknown"
end

# In application.ex
def start(_type, _args) do
  MyApp.LLMTelemetry.attach()

  # ... rest of supervision tree
end
```

### Dashboard Metrics

Track key metrics in your monitoring dashboard:

```elixir
defmodule MyApp.Metrics do
  use Telemetry.Metrics

  def metrics do
    [
      # Success rate
      counter("llm.generation.total"),
      counter("llm.generation.success"),
      counter("llm.generation.error"),

      # Performance
      distribution("llm.generation.duration",
        unit: {:native, :millisecond},
        tags: [:result]
      ),

      # Retries
      counter("llm.retry.initiated"),
      counter("llm.validation.failed"),

      # Backend
      counter("llm.backend.error", tags: [:error_type]),

      # Circuit breaker
      last_value("llm.circuit_breaker.status",
        measurement: :status,
        tags: [:status]
      )
    ]
  end
end
```

## Pattern 6: Structured Logging

Log errors with context for debugging.

```elixir
defmodule MyApp.LLMLogger do
  require Logger

  def log_generation_attempt(schema, opts, attempt) do
    Logger.metadata([
      schema_fields: Map.keys(schema.fields),
      backend: Keyword.get(opts, :backend),
      attempt: attempt
    ])

    Logger.debug("Starting LLM generation")
  end

  def log_validation_error(diagnostics, attempt) do
    error_summary = diagnostics.errors
    |> Enum.map(& &1.message)
    |> Enum.join("; ")

    Logger.warning("Validation failed",
      attempt: attempt,
      error_count: length(diagnostics.errors),
      errors: error_summary
    )
  end

  def log_success(result, duration_ms, attempts) do
    Logger.info("LLM generation succeeded",
      duration_ms: duration_ms,
      attempts: attempts,
      result_keys: Map.keys(result)
    )
  end

  def log_final_failure(reason, attempts) do
    Logger.error("LLM generation failed after retries",
      reason: inspect(reason),
      total_attempts: attempts
    )
  end
end
```

## Common Pitfalls

### 1. Swallowing Errors

**Problem:** Catching all errors without logging

**Solution:** Always log errors before handling

```elixir
# Bad
case generate() do
  {:ok, result} -> result
  {:error, _} -> nil  # Error lost!
end

# Good
case generate() do
  {:ok, result} ->
    result

  {:error, reason} = error ->
    Logger.error("Generation failed", reason: inspect(reason))
    nil
end
```

### 2. No Error Monitoring

**Problem:** Errors happen in production without visibility

**Solution:** Set up telemetry and alerting

```elixir
# Monitor error rates
MyApp.Metrics.increment("errors.llm", 1)

# Alert if error rate > threshold
if error_rate > 0.1 do
  MyApp.Alerting.send("High LLM error rate")
end
```

### 3. User Sees Technical Errors

**Problem:** Exposing internal errors to users

**Solution:** Use ErrorFormatter pattern

```elixir
# Bad
json(conn, %{error: inspect(reason)})

# Good
json(conn, %{error: ErrorFormatter.format_error(reason).message})
```

## Best Practices

1. **Use Telemetry**: Monitor all LLM interactions
2. **Graceful Degradation**: Always have fallback behavior
3. **User-Friendly Messages**: Translate technical errors
4. **Circuit Breaker**: Prevent cascading failures
5. **Structured Logging**: Include context for debugging
6. **Retry Intelligently**: Use exponential backoff
7. **Track Metrics**: Monitor success rates and latency

## Error Handling Checklist

- [ ] User-friendly error messages implemented
- [ ] Telemetry attached for monitoring
- [ ] Graceful degradation/fallbacks in place
- [ ] Circuit breaker for critical paths
- [ ] Structured logging with context
- [ ] Error alerts configured
- [ ] Retry strategies tuned for use case
- [ ] Error rates tracked in dashboard
- [ ] Error scenarios tested

## Related Guides

- [Phoenix Integration](phoenix_integration.md) - Handle errors in web context
- [Testing Strategies](testing_strategies.md) - Test error scenarios
- [Batch Processing](batch_processing.md) - Handle errors in concurrent operations

## Further Reading

- [Telemetry Documentation](https://hexdocs.pm/telemetry/)
- [Elixir Logger](https://hexdocs.pm/logger/)
- [Circuit Breaker Pattern](https://en.wikipedia.org/wiki/Circuit_breaker_design_pattern)
- [ExOutlines API Documentation](https://hexdocs.pm/ex_outlines/)
