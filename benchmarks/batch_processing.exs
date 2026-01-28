#!/usr/bin/env elixir

# Batch Processing Benchmarks
#
# Measures concurrency performance with Task.async_stream:
# - Sequential vs concurrent (1, 2, 4, 8 tasks)
# - Different concurrency levels
# - Speedup measurement with parallelism
# - Batch size impact
#
# Run with: mix run benchmarks/batch_processing.exs

alias ExOutlines.{Spec.Schema, Backend.Mock}

IO.puts("Setting up benchmark data...")

# Simple schema for testing
schema = Schema.new(%{
  id: %{type: :integer, required: true, min: 1},
  value: %{type: :string, required: true}
})

# Helper to create tasks
defmodule BenchHelper do
  def create_tasks(count, schema) do
    for i <- 1..count do
      mock_response = Jason.encode!(%{id: i, value: "value_#{i}"})
      mock = ExOutlines.Backend.Mock.new([{:ok, mock_response}])

      {schema, [backend: ExOutlines.Backend.Mock, backend_opts: [mock: mock]]}
    end
  end
end

# Create task lists of different sizes
tasks_4 = BenchHelper.create_tasks(4, schema)
tasks_8 = BenchHelper.create_tasks(8, schema)
tasks_16 = BenchHelper.create_tasks(16, schema)
tasks_32 = BenchHelper.create_tasks(32, schema)
tasks_50 = BenchHelper.create_tasks(50, schema)

IO.puts("Running benchmarks...")
IO.puts("")

Benchee.run(
  %{
    # 4 tasks with different concurrency levels
    "4 tasks, sequential (concurrency=1)" => fn ->
      ExOutlines.generate_batch(tasks_4, max_concurrency: 1)
    end,
    "4 tasks, concurrent (concurrency=2)" => fn ->
      ExOutlines.generate_batch(tasks_4, max_concurrency: 2)
    end,
    "4 tasks, concurrent (concurrency=4)" => fn ->
      ExOutlines.generate_batch(tasks_4, max_concurrency: 4)
    end,

    # 8 tasks with different concurrency levels
    "8 tasks, sequential (concurrency=1)" => fn ->
      ExOutlines.generate_batch(tasks_8, max_concurrency: 1)
    end,
    "8 tasks, concurrent (concurrency=2)" => fn ->
      ExOutlines.generate_batch(tasks_8, max_concurrency: 2)
    end,
    "8 tasks, concurrent (concurrency=4)" => fn ->
      ExOutlines.generate_batch(tasks_8, max_concurrency: 4)
    end,
    "8 tasks, concurrent (concurrency=8)" => fn ->
      ExOutlines.generate_batch(tasks_8, max_concurrency: 8)
    end,

    # 16 tasks with different concurrency levels
    "16 tasks, sequential (concurrency=1)" => fn ->
      ExOutlines.generate_batch(tasks_16, max_concurrency: 1)
    end,
    "16 tasks, concurrent (concurrency=4)" => fn ->
      ExOutlines.generate_batch(tasks_16, max_concurrency: 4)
    end,
    "16 tasks, concurrent (concurrency=8)" => fn ->
      ExOutlines.generate_batch(tasks_16, max_concurrency: 8)
    end,
    "16 tasks, concurrent (concurrency=16)" => fn ->
      ExOutlines.generate_batch(tasks_16, max_concurrency: 16)
    end,

    # Larger batches
    "32 tasks, concurrent (concurrency=8)" => fn ->
      ExOutlines.generate_batch(tasks_32, max_concurrency: 8)
    end,
    "32 tasks, concurrent (concurrency=16)" => fn ->
      ExOutlines.generate_batch(tasks_32, max_concurrency: 16)
    end,

    "50 tasks, concurrent (concurrency=10)" => fn ->
      ExOutlines.generate_batch(tasks_50, max_concurrency: 10)
    end,
    "50 tasks, concurrent (concurrency=25)" => fn ->
      ExOutlines.generate_batch(tasks_50, max_concurrency: 25)
    end,

    # Single task baseline
    "single task (no batch)" => fn ->
      mock_response = Jason.encode!(%{id: 1, value: "value_1"})
      mock = Mock.new([{:ok, mock_response}])

      ExOutlines.generate(schema,
        backend: Mock,
        backend_opts: [mock: mock]
      )
    end
  },
  time: 3,
  memory_time: 1,
  warmup: 1,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/output/batch_processing.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("")
IO.puts("✓ Benchmark complete!")
IO.puts("  HTML report: benchmarks/output/batch_processing.html")
IO.puts("")
IO.puts("Key Insights:")
IO.puts("  - Speedup: Compare sequential vs concurrent for same batch size")
IO.puts("  - Optimal concurrency: Find the sweet spot (usually 4-8x cores)")
IO.puts("  - Diminishing returns: Higher concurrency doesn't always help")
IO.puts("  - BEAM efficiency: Note how well Elixir handles concurrent tasks")
