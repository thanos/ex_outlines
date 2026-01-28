#!/usr/bin/env elixir

# Generation Loop Benchmarks
#
# Measures retry-repair loop performance:
# - First attempt success (no retries)
# - Retry with repair (1, 2, 3 retries)
# - Max retries exhaustion
# - JSON parsing overhead
# - Prompt building overhead
#
# Run with: mix run benchmarks/generation_loop.exs

alias ExOutlines.{Spec.Schema, Backend.Mock}

IO.puts("Setting up benchmark data...")

# Schema for testing
schema = Schema.new(%{
  name: %{type: :string, required: true, min_length: 2, max_length: 50},
  age: %{type: :integer, required: true, min: 0, max: 120},
  email: %{type: :string, required: true, format: :email}
})

# Test data scenarios

# Success on first attempt
valid_response = Jason.encode!(%{
  name: "Alice Smith",
  age: 30,
  email: "alice@example.com"
})

# Fail once, then succeed
invalid_then_valid_response = [
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"}), # Too short
  Jason.encode!(%{name: "Alice", age: 30, email: "alice@example.com"}) # Valid
]

# Fail twice, then succeed
invalid_twice_then_valid = [
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"}), # Too short
  Jason.encode!(%{name: "Alice", age: 200, email: "alice@example.com"}), # Age too high
  Jason.encode!(%{name: "Alice", age: 30, email: "alice@example.com"}) # Valid
]

# Fail three times, then succeed
invalid_thrice_then_valid = [
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"}), # Too short
  Jason.encode!(%{name: "Alice", age: 200, email: "alice@example.com"}), # Age too high
  Jason.encode!(%{name: "Alice", age: 30, email: "not-email"}), # Invalid email
  Jason.encode!(%{name: "Alice", age: 30, email: "alice@example.com"}) # Valid
]

# Always fail (max retries)
always_invalid = [
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"}),
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"}),
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"}),
  Jason.encode!(%{name: "A", age: 30, email: "alice@example.com"})
]

# JSON parsing scenarios
valid_json = valid_response
invalid_json = "not valid json {"
malformed_json_then_valid = [
  "not valid json {",
  valid_response
]

IO.puts("Running benchmarks...")
IO.puts("")

Benchee.run(
  %{
    # Success scenarios
    "first attempt success" => fn ->
      mock = Mock.new([{:ok, valid_response}])
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 3
      )
    end,

    # Retry scenarios
    "1 retry (then success)" => fn ->
      mock = Mock.new(Enum.map(invalid_then_valid_response, &{:ok, &1}))
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 3
      )
    end,

    "2 retries (then success)" => fn ->
      mock = Mock.new(Enum.map(invalid_twice_then_valid, &{:ok, &1}))
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 3
      )
    end,

    "3 retries (then success)" => fn ->
      mock = Mock.new(Enum.map(invalid_thrice_then_valid, &{:ok, &1}))
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 4
      )
    end,

    # Max retries exhaustion
    "max retries exceeded" => fn ->
      mock = Mock.new(Enum.map(always_invalid, &{:ok, &1}))
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 3
      )
    end,

    # JSON parsing
    "JSON parse success" => fn ->
      mock = Mock.new([{:ok, valid_json}])
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 3
      )
    end,

    "JSON parse fail then retry" => fn ->
      mock = Mock.new(Enum.map(malformed_json_then_valid, &{:ok, &1}))
      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock],
        max_retries: 2
      )
    end,

    # Overhead measurements
    "schema validation only" => fn ->
      data = %{
        "name" => "Alice Smith",
        "age" => 30,
        "email" => "alice@example.com"
      }
      Spec.validate(schema, data)
    end,

    "JSON parsing only" => fn ->
      Jason.decode(valid_response)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/output/generation_loop.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("")
IO.puts("✓ Benchmark complete!")
IO.puts("  HTML report: benchmarks/output/generation_loop.html")
IO.puts("")
IO.puts("Key Insights:")
IO.puts("  - Retry overhead: Compare '1 retry' vs 'first attempt success'")
IO.puts("  - Cost of failure: Each retry adds ~1 iteration worth of overhead")
IO.puts("  - Max retries: Shows full cost of exhausting all attempts")
