# Batch Processing and Concurrency

This guide demonstrates how to process multiple LLM generation requests concurrently using ExOutlines batch processing capabilities, leveraging the BEAM's excellent concurrency model.

## Table of Contents

- [Why Batch Processing?](#why-batch-processing)
- [Basic Batch Generation](#basic-batch-generation)
- [Concurrency Configuration](#concurrency-configuration)
- [Error Handling](#error-handling)
- [Performance Optimization](#performance-optimization)
- [Real-World Patterns](#real-world-patterns)
- [Monitoring and Telemetry](#monitoring-and-telemetry)
- [Best Practices](#best-practices)

## Why Batch Processing?

When you need to generate structured output for multiple prompts, processing them sequentially is inefficient:

```elixir
# Sequential processing - SLOW
results = for prompt <- prompts do
  ExOutlines.generate(schema, prompt: prompt, backend: HTTP, backend_opts: opts)
end
```

**Problems with sequential processing:**

- Each request waits for the previous one to complete
- Total time = sum of all request times
- CPU and network resources are underutilized
- Poor throughput for high-volume applications

**Batch processing advantages:**

- Multiple requests execute concurrently
- Total time ≈ longest request time (not sum)
- Better resource utilization
- Higher throughput
- Built-in error handling for individual failures

## Basic Batch Generation

### Using `generate_batch/2`

```elixir
alias ExOutlines.{Spec.Schema, Backend.HTTP}

# Define schema
schema = Schema.new(%{
  sentiment: %{type: {:enum, ["positive", "neutral", "negative"]}, required: true},
  confidence: %{type: :number, required: true, min: 0, max: 1}
})

# Prepare tasks (list of {schema, opts} tuples)
reviews = [
  "This product is amazing! Highly recommend.",
  "It's okay, nothing special.",
  "Terrible quality, very disappointed."
]

tasks = Enum.map(reviews, fn review ->
  {schema, [
    backend: HTTP,
    backend_opts: [
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4o-mini",
      messages: [
        %{role: "system", content: "Analyze sentiment"},
        %{role: "user", content: review}
      ]
    ]
  ]}
end)

# Generate concurrently
results = ExOutlines.generate_batch(tasks)

# Process results
Enum.each(results, fn
  {:ok, data} ->
    IO.puts("Sentiment: #{data.sentiment}, Confidence: #{data.confidence}")

  {:error, reason} ->
    IO.puts("Failed: #{inspect(reason)}")
end)
```

### Return Value

`generate_batch/2` returns a list of results matching the input order:

```elixir
[
  {:ok, %{sentiment: "positive", confidence: 0.95}},
  {:ok, %{sentiment: "neutral", confidence: 0.80}},
  {:error, :timeout}
]
```

## Concurrency Configuration

### Max Concurrency

Control how many requests run simultaneously:

```elixir
# Default: number of CPU cores
results = ExOutlines.generate_batch(tasks)

# Limit to 5 concurrent requests
results = ExOutlines.generate_batch(tasks, max_concurrency: 5)

# High concurrency (if API allows)
results = ExOutlines.generate_batch(tasks, max_concurrency: 20)
```

**Choosing concurrency level:**

- **API rate limits**: Check provider's concurrent request limits
- **Memory**: Each concurrent request consumes memory
- **Network**: Consider bandwidth and connection limits
- **Cost**: More concurrency = faster but potentially higher costs

### Timeout Configuration

Set timeout per task:

```elixir
# Default: 60 seconds per task
results = ExOutlines.generate_batch(tasks, timeout: 60_000)

# Longer timeout for complex generation
results = ExOutlines.generate_batch(tasks, timeout: 120_000)

# Short timeout for simple tasks
results = ExOutlines.generate_batch(tasks, timeout: 30_000)
```

### Ordered vs Unordered Results

```elixir
# Ordered results (default) - preserves input order
results = ExOutlines.generate_batch(tasks, ordered: true)

# Unordered results - slightly faster, results arrive as completed
results = ExOutlines.generate_batch(tasks, ordered: false)
```

**Use ordered when**: Result position matters (matching input indices)
**Use unordered when**: Processing results independently and speed matters

## Error Handling

### Mixed Success and Failure

Batch processing continues even when individual tasks fail:

```elixir
results = ExOutlines.generate_batch(tasks)

# Separate successes and failures
{successes, failures} = Enum.split_with(results, fn
  {:ok, _} -> true
  {:error, _} -> false
end)

IO.puts("Successful: #{length(successes)}/#{length(results)}")
IO.puts("Failed: #{length(failures)}/#{length(results)}")

# Process failures
Enum.each(failures, fn {:error, reason} ->
  Logger.error("Task failed: #{inspect(reason)}")
end)
```

### Retry Failed Tasks

```elixir
defmodule BatchProcessor do
  def process_with_retry(tasks, max_retries \\ 3) do
    results = ExOutlines.generate_batch(tasks)

    # Find failed tasks
    failed_indices = results
    |> Enum.with_index()
    |> Enum.filter(fn {{status, _}, _idx} -> status == :error end)
    |> Enum.map(fn {_, idx} -> idx end)

    if length(failed_indices) > 0 and max_retries > 0 do
      IO.puts("Retrying #{length(failed_indices)} failed tasks...")

      # Retry only failed tasks
      retry_tasks = Enum.map(failed_indices, fn idx -> Enum.at(tasks, idx) end)
      retry_results = process_with_retry(retry_tasks, max_retries - 1)

      # Merge retry results back
      merge_results(results, failed_indices, retry_results)
    else
      results
    end
  end

  defp merge_results(original, indices, retries) do
    Enum.reduce(Enum.zip(indices, retries), original, fn {idx, result}, acc ->
      List.replace_at(acc, idx, result)
    end)
  end
end

# Use with retry
results = BatchProcessor.process_with_retry(tasks, max_retries: 2)
```

### Timeout Handling

```elixir
results = ExOutlines.generate_batch(tasks,
  timeout: 30_000,
  on_timeout: :kill_task  # Default - kill timed-out tasks
)

# Or continue without killing
results = ExOutlines.generate_batch(tasks,
  timeout: 30_000,
  on_timeout: :continue  # Let tasks complete in background
)
```

## Performance Optimization

### Optimal Batch Size

Don't batch everything at once. Break large workloads into chunks:

```elixir
defmodule BatchOptimizer do
  @chunk_size 50
  @max_concurrency 10

  def process_large_dataset(items, schema, backend_opts) do
    items
    |> Enum.chunk_every(@chunk_size)
    |> Enum.flat_map(fn chunk ->
      tasks = build_tasks(chunk, schema, backend_opts)
      ExOutlines.generate_batch(tasks, max_concurrency: @max_concurrency)
    end)
  end

  defp build_tasks(items, schema, backend_opts) do
    Enum.map(items, fn item ->
      {schema, [backend: HTTP, backend_opts: backend_opts]}
    end)
  end
end
```

**Why chunk?**

- Prevents memory exhaustion with thousands of tasks
- Provides progress feedback
- Easier to handle partial failures
- Better rate limit management

### Progress Tracking

```elixir
defmodule ProgressTracker do
  def process_with_progress(items, schema, backend_opts) do
    total = length(items)
    chunk_size = 50

    items
    |> Enum.chunk_every(chunk_size)
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {chunk, batch_num} ->
      IO.write("\rProcessing batch #{batch_num}/#{div(total, chunk_size) + 1}...")

      tasks = build_tasks(chunk, schema, backend_opts)
      results = ExOutlines.generate_batch(tasks, max_concurrency: 10)

      success_count = Enum.count(results, fn {status, _} -> status == :ok end)
      IO.puts(" #{success_count}/#{length(chunk)} succeeded")

      results
    end)
  end

  defp build_tasks(items, schema, backend_opts) do
    # Build task list
  end
end
```

### Caching for Repeated Inputs

```elixir
defmodule CachedBatchProcessor do
  def process_with_cache(items, schema, backend_opts) do
    # Deduplicate items
    unique_items = Enum.uniq(items)

    # Process unique items
    tasks = build_tasks(unique_items, schema, backend_opts)
    results = ExOutlines.generate_batch(tasks)

    # Build cache
    cache = Enum.zip(unique_items, results) |> Map.new()

    # Map results back to original items
    Enum.map(items, fn item -> Map.get(cache, item) end)
  end

  defp build_tasks(items, schema, backend_opts) do
    # Build task list
  end
end
```

## Real-World Patterns

### Content Moderation at Scale

```elixir
defmodule ContentModerator do
  alias ExOutlines.{Spec.Schema, Backend.HTTP}

  @moderation_schema Schema.new(%{
    is_safe: %{type: :boolean, required: true},
    category: %{
      type: {:enum, ["safe", "spam", "hate_speech", "violence", "explicit"]},
      required: true
    },
    confidence: %{type: :number, required: true, min: 0, max: 1}
  })

  def moderate_comments(comments, api_key) do
    backend_opts = [
      api_key: api_key,
      model: "gpt-4o-mini",
      temperature: 0.0
    ]

    # Process in batches of 100
    comments
    |> Enum.chunk_every(100)
    |> Enum.flat_map(fn batch ->
      moderate_batch(batch, backend_opts)
    end)
  end

  defp moderate_batch(comments, backend_opts) do
    tasks = Enum.map(comments, fn comment ->
      {@moderation_schema, [
        backend: HTTP,
        backend_opts: backend_opts ++
          [messages: [
            %{role: "system", content: "You are a content moderator."},
            %{role: "user", content: "Moderate this: #{comment}"}
          ]]
      ]}
    end)

    ExOutlines.generate_batch(tasks, max_concurrency: 20)
  end
end

# Usage
comments = load_comments()  # Thousands of comments
results = ContentModerator.moderate_comments(comments, api_key)

# Filter unsafe content
unsafe_comments = results
|> Enum.zip(comments)
|> Enum.filter(fn {{:ok, moderation}, _comment} -> !moderation.is_safe end)
|> Enum.map(fn {_result, comment} -> comment end)
```

### Product Categorization Pipeline

```elixir
defmodule ProductCategorizer do
  alias ExOutlines.{Spec.Schema, Backend.HTTP}

  @category_schema Schema.new(%{
    category: %{
      type: {:enum, ["electronics", "clothing", "home", "sports", "toys"]},
      required: true
    },
    subcategory: %{type: :string, required: true},
    tags: %{
      type: {:array, %{type: :string}},
      required: true,
      min_items: 1,
      max_items: 5,
      unique_items: true
    }
  })

  def categorize_products(products, api_key) do
    backend_opts = [api_key: api_key, model: "gpt-4o-mini"]

    tasks = Enum.map(products, fn product ->
      {@category_schema, [
        backend: HTTP,
        backend_opts: backend_opts ++
          [messages: [
            %{role: "system", content: "Categorize products."},
            %{role: "user", content: product.description}
          ]]
      ]}
    end)

    results = ExOutlines.generate_batch(tasks, max_concurrency: 10)

    # Merge results back with products
    Enum.zip(products, results)
    |> Enum.map(fn {product, result} ->
      case result do
        {:ok, categorization} ->
          Map.merge(product, categorization)

        {:error, _reason} ->
          Map.put(product, :categorization_error, true)
      end
    end)
  end
end
```

### A/B Testing Different Prompts

```elixir
defmodule PromptTester do
  def test_prompts(test_cases, prompt_variants, schema, backend_opts) do
    # Create tasks for all combinations
    tasks = for test_case <- test_cases,
                prompt_variant <- prompt_variants do
      messages = [
        %{role: "system", content: prompt_variant.system_prompt},
        %{role: "user", content: test_case.input}
      ]

      {schema, [
        backend: HTTP,
        backend_opts: backend_opts ++ [messages: messages],
        metadata: %{
          test_case: test_case.id,
          prompt_variant: prompt_variant.name
        }
      ]}
    end

    # Run all tests concurrently
    results = ExOutlines.generate_batch(tasks, max_concurrency: 20)

    # Analyze results by variant
    analyze_by_variant(results, test_cases, prompt_variants)
  end

  defp analyze_by_variant(results, test_cases, variants) do
    # Group and analyze results
    # Calculate success rates, accuracy, etc.
  end
end
```

## Monitoring and Telemetry

### Batch Processing Telemetry

ExOutlines emits telemetry events for batch processing:

```elixir
:telemetry.attach(
  "batch-processing-logger",
  [:ex_outlines, :batch, :start],
  fn _event, measurements, metadata, _config ->
    IO.puts("Starting batch: #{metadata.total_tasks} tasks, concurrency: #{metadata.max_concurrency}")
  end,
  nil
)

:telemetry.attach(
  "batch-processing-complete",
  [:ex_outlines, :batch, :stop],
  fn _event, measurements, metadata, _config ->
    duration_sec = measurements.duration / 1_000_000_000
    success_rate = metadata.successes / metadata.total_tasks * 100

    IO.puts("""
    Batch complete:
    - Duration: #{Float.round(duration_sec, 2)}s
    - Success rate: #{Float.round(success_rate, 1)}%
    - Throughput: #{Float.round(metadata.total_tasks / duration_sec, 2)} tasks/sec
    """)
  end,
  nil
)
```

### Custom Metrics

```elixir
defmodule BatchMetrics do
  def track_batch_performance(tasks) do
    start_time = System.monotonic_time()

    results = ExOutlines.generate_batch(tasks, max_concurrency: 10)

    end_time = System.monotonic_time()
    duration_ms = System.convert_time_unit(end_time - start_time, :native, :millisecond)

    metrics = %{
      total_tasks: length(tasks),
      successes: Enum.count(results, fn {status, _} -> status == :ok end),
      failures: Enum.count(results, fn {status, _} -> status == :error end),
      duration_ms: duration_ms,
      throughput: length(tasks) / (duration_ms / 1000)
    }

    # Send to monitoring system
    send_metrics(metrics)

    results
  end

  defp send_metrics(metrics) do
    # Send to StatsD, Prometheus, etc.
  end
end
```

## Best Practices

### 1. Respect API Rate Limits

```elixir
# Check provider's rate limits
# OpenAI: 3,500 requests/min (tier 1) = ~58/sec
# Anthropic: 50 requests/min (free tier) = ~0.8/sec

# Adjust concurrency accordingly
results = ExOutlines.generate_batch(tasks,
  max_concurrency: 10  # Stay under rate limit
)
```

### 2. Use Appropriate Timeouts

```elixir
# Simple classification: short timeout
results = ExOutlines.generate_batch(classification_tasks, timeout: 10_000)

# Complex generation: longer timeout
results = ExOutlines.generate_batch(writing_tasks, timeout: 60_000)

# Very complex reasoning: very long timeout
results = ExOutlines.generate_batch(reasoning_tasks, timeout: 120_000)
```

### 3. Handle Partial Failures Gracefully

```elixir
results = ExOutlines.generate_batch(tasks)

{successes, failures} = Enum.split_with(results, fn
  {:ok, _} -> true
  {:error, _} -> false
end)

if length(failures) > 0 do
  Logger.warning("#{length(failures)} tasks failed, continuing with successes")
  # Decide: retry, skip, or use fallback
end

# Process successes
Enum.each(successes, fn {:ok, data} ->
  process_result(data)
end)
```

### 4. Chunk Large Workloads

```elixir
# Process 10,000 items
large_dataset
|> Enum.chunk_every(100)  # Batches of 100
|> Enum.each(fn chunk ->
  tasks = build_tasks(chunk)
  results = ExOutlines.generate_batch(tasks, max_concurrency: 10)
  save_results(results)
end)
```

### 5. Monitor Performance

```elixir
# Track key metrics
defmodule BatchMonitor do
  def process_with_monitoring(tasks) do
    :timer.tc(fn ->
      ExOutlines.generate_batch(tasks, max_concurrency: 10)
    end)
    |> case do
      {time_microseconds, results} ->
        log_performance(time_microseconds, results)
        results
    end
  end

  defp log_performance(time_us, results) do
    success_rate = Enum.count(results, fn {s, _} -> s == :ok end) / length(results)

    Logger.info("""
    Batch completed:
    - Time: #{time_us / 1_000_000}s
    - Tasks: #{length(results)}
    - Success: #{Float.round(success_rate * 100, 1)}%
    """)
  end
end
```

### 6. Use Background Jobs for Large Batches

```elixir
# Don't block HTTP requests with large batch processing
defmodule MyApp.BatchWorker do
  use Oban.Worker, queue: :batch_processing

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"items" => items}}) do
    tasks = build_tasks(items)

    results = ExOutlines.generate_batch(tasks,
      max_concurrency: 10,
      timeout: 60_000
    )

    save_results(results)
    :ok
  end
end

# Enqueue from controller
def batch_process(conn, %{"items" => items}) do
  %{items: items}
  |> MyApp.BatchWorker.new()
  |> Oban.insert()

  json(conn, %{status: "processing", job_id: job.id})
end
```

### 7. Test with Mock Backend First

```elixir
defmodule BatchProcessorTest do
  use ExUnit.Case
  alias ExOutlines.Backend.Mock

  test "processes batch successfully" do
    schema = Schema.new(%{value: %{type: :integer}})

    # Create mock responses
    mock = Mock.new([
      {:ok, ~s({"value": 1})},
      {:ok, ~s({"value": 2})},
      {:ok, ~s({"value": 3})}
    ])

    tasks = for _i <- 1..3 do
      {schema, [backend: Mock, backend_opts: [mock: mock]]}
    end

    results = ExOutlines.generate_batch(tasks, max_concurrency: 2)

    assert length(results) == 3
    assert Enum.all?(results, fn {status, _} -> status == :ok end)
  end
end
```

## Performance Comparison

### Sequential vs Batch Processing

```elixir
# Benchmark script
defmodule BatchBenchmark do
  def run do
    schema = Schema.new(%{result: %{type: :integer}})
    count = 20

    # Sequential
    sequential_time = measure(fn ->
      for _i <- 1..count do
        ExOutlines.generate(schema, backend: Mock, backend_opts: [mock: mock()])
      end
    end)

    # Batch
    batch_time = measure(fn ->
      tasks = for _i <- 1..count, do: {schema, [backend: Mock, backend_opts: [mock: mock()]]}
      ExOutlines.generate_batch(tasks, max_concurrency: 10)
    end)

    IO.puts("""
    Results for #{count} tasks:
    - Sequential: #{sequential_time}ms
    - Batch (concurrency: 10): #{batch_time}ms
    - Speedup: #{Float.round(sequential_time / batch_time, 2)}x
    """)
  end

  defp measure(fun) do
    {time, _result} = :timer.tc(fun)
    div(time, 1000)  # Convert to ms
  end

  defp mock do
    Mock.new([{:ok, ~s({"result": 42})}])
  end
end
```

**Expected results**: 5-10x speedup depending on concurrency and task complexity.

## Next Steps

- Read the **Performance Optimization** guide for advanced tuning
- See **Testing Strategies** for testing batch operations
- Explore **Phoenix Integration** for web application patterns
- Check **Telemetry** documentation for monitoring setup

## Further Reading

- [Task.async_stream documentation](https://hexdocs.pm/elixir/Task.html#async_stream/3)
- [Elixir concurrency patterns](https://elixir-lang.org/getting-started/processes.html)
- [BEAM scheduler documentation](https://www.erlang.org/doc/man/erlang.html#system_info-1)
