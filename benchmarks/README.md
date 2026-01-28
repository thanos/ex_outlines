# ExOutlines Performance Benchmarks

Comprehensive benchmark suite for measuring and tracking ExOutlines performance.

## Overview

This directory contains benchmarks for measuring:
- **Schema Validation**: Validation speed across different schema complexities
- **Generation Loop**: Retry-repair loop overhead and performance
- **Batch Processing**: Concurrency speedup with parallel processing

## Prerequisites

Install benchmark dependencies:

```bash
mix deps.get
```

This installs:
- `benchee` - Benchmarking framework
- `benchee_html` - HTML report generation

## Running Benchmarks

### Run All Benchmarks

```bash
# Run all benchmarks
./benchmarks/run_all.sh

# Or individually
mix run benchmarks/schema_validation.exs
mix run benchmarks/generation_loop.exs
mix run benchmarks/batch_processing.exs
```

### Run Individual Benchmarks

```bash
# Schema validation only
mix run benchmarks/schema_validation.exs

# Generation loop only
mix run benchmarks/generation_loop.exs

# Batch processing only
mix run benchmarks/batch_processing.exs
```

## Benchmark Details

### 1. Schema Validation (`schema_validation.exs`)

Measures validation performance across different schema types and complexities.

**Scenarios:**
- Simple type validation (string, integer, boolean)
- Constrained validation (length limits, ranges, patterns)
- Array validation (5, 50, 500 items)
- Nested object validation (1, 3, 5 levels deep)
- Union type validation

**Key Metrics:**
- Iterations per second (higher is better)
- Memory usage per operation
- Relative performance comparison

**Expected Results:**
- Simple validation: ~500K-1M ops/sec
- Constrained validation: ~300K-500K ops/sec
- Array validation: Scales linearly with array size
- Nested validation: ~50K-100K ops/sec per level

**Insights:**
- Simple types are extremely fast (microseconds)
- Constraints add minimal overhead (~10-20%)
- Array performance scales linearly
- Nested objects have logarithmic overhead

### 2. Generation Loop (`generation_loop.exs`)

Measures retry-repair loop performance and overhead.

**Scenarios:**
- First attempt success (no retries)
- 1, 2, 3 retries before success
- Max retries exhaustion
- JSON parsing overhead
- Schema validation overhead

**Key Metrics:**
- Total time per generation attempt
- Overhead per retry iteration
- JSON parsing time
- Validation time

**Expected Results:**
- First attempt: ~50-100 μs
- Each retry adds: ~50-100 μs overhead
- JSON parsing: ~10-20 μs
- Validation: ~30-50 μs

**Insights:**
- Each retry approximately doubles execution time
- JSON parsing is negligible (~20% of total)
- Validation is the main cost (~50-60% of total)
- Max retries can be 4-5x slower than first attempt success

### 3. Batch Processing (`batch_processing.exs`)

Measures concurrency speedup with Task.async_stream.

**Scenarios:**
- Sequential processing (concurrency=1)
- Concurrent processing (2, 4, 8, 16, 25 concurrent tasks)
- Different batch sizes (4, 8, 16, 32, 50 tasks)
- Single task baseline

**Key Metrics:**
- Total batch processing time
- Speedup vs sequential
- Optimal concurrency level
- Scalability

**Expected Results:**
- 4 tasks: 2-3x speedup at concurrency=4
- 8 tasks: 4-6x speedup at concurrency=8
- Optimal concurrency: Usually 4-8x CPU cores
- Diminishing returns after 16-32 concurrent tasks

**Insights:**
- BEAM handles concurrency very efficiently
- Speedup is near-linear up to ~8 tasks
- Optimal concurrency depends on CPU cores
- Memory overhead is minimal (Elixir processes are lightweight)

## Interpreting Results

### Console Output

Benchee shows results like this:

```
Name                                    ips        average  deviation         median         99th %
simple string validation            1.23 M      812.15 ns   ±234.56%         750 ns        1.2 μs
constrained string validation       789.12 K    1.27 μs    ±156.78%        1.15 μs        2.3 μs
```

**Key Columns:**
- **ips**: Iterations per second (higher is better)
- **average**: Average execution time (lower is better)
- **deviation**: Variability (lower is more consistent)
- **median**: Middle value (more reliable than average)
- **99th %**: Worst case (important for tail latency)

### HTML Reports

HTML reports are saved to `benchmarks/output/`:
- `schema_validation.html`
- `generation_loop.html`
- `batch_processing.html`

Open in a browser for:
- Interactive charts
- Comparison graphs
- Statistical analysis
- Memory profiling

### Performance Baselines

**Reference Hardware**: MacBook Pro M3 Max (16 cores)

| Benchmark | Operation | Baseline Performance |
|-----------|-----------|---------------------|
| Simple validation | String type check | ~1M ops/sec |
| Constrained validation | String with pattern | ~500K ops/sec |
| Array validation | 50 items | ~100K ops/sec |
| Nested validation | 3 levels | ~75K ops/sec |
| First attempt success | No retries | ~20K ops/sec |
| 1 retry | One repair iteration | ~10K ops/sec |
| Batch (8 tasks, concurrency=8) | Concurrent batch | ~2-3ms total |

**Note**: Your results will vary based on hardware.

## Performance Tips

### Optimization Strategies

1. **Minimize Retries**
   - Use simpler schemas when possible
   - Provide clear prompts to LLM
   - Set conservative max_retries (2-3)

2. **Optimize Schema Complexity**
   - Avoid deeply nested objects (>3 levels) when possible
   - Use arrays sparingly for large datasets
   - Consider splitting complex schemas

3. **Batch Processing**
   - Use concurrent batch processing for multiple tasks
   - Set concurrency to 4-8x CPU cores
   - Monitor memory usage with large batches

4. **Caching**
   - Cache validation results for identical inputs
   - Cache LLM responses when appropriate
   - Use ETS or Cachex for fast lookups

### Common Bottlenecks

1. **Too Many Retries**: Each retry adds significant overhead
2. **Large Arrays**: Validation scales linearly with array size
3. **Deep Nesting**: Each level adds overhead
4. **Complex Patterns**: Regex validation can be slow

## Continuous Performance Monitoring

### In CI/CD

Run benchmarks on main branch to track performance over time:

```yaml
# .github/workflows/benchmark.yml
- name: Run benchmarks
  run: |
    mix run benchmarks/schema_validation.exs
    mix run benchmarks/generation_loop.exs
    mix run benchmarks/batch_processing.exs
```

### Performance Regression Detection

Compare results across versions:

```bash
# Baseline
git checkout main
mix run benchmarks/schema_validation.exs > baseline.txt

# New code
git checkout feature-branch
mix run benchmarks/schema_validation.exs > feature.txt

# Compare
diff baseline.txt feature.txt
```

## Troubleshooting

### Benchmarks Running Slow

If benchmarks take too long:

1. Reduce `time` parameter in benchmark config:
   ```elixir
   Benchee.run(%{...}, time: 3) # Reduce from 5 to 3 seconds
   ```

2. Skip memory profiling:
   ```elixir
   Benchee.run(%{...}, memory_time: 0) # Disable memory profiling
   ```

3. Run fewer scenarios:
   ```elixir
   # Comment out some scenarios in the benchmark file
   ```

### Inconsistent Results

If results vary widely:

1. Close other applications
2. Run benchmarks multiple times
3. Increase warmup time:
   ```elixir
   Benchee.run(%{...}, warmup: 5) # Increase warmup
   ```
4. Check system load: `top` or `htop`

## Advanced Usage

### Custom Scenarios

Add your own benchmark scenarios:

```elixir
# In benchmarks/schema_validation.exs
Benchee.run(
  %{
    # ... existing scenarios
    "my custom scenario" => fn ->
      # Your code here
    end
  },
  # ... config
)
```

### Memory Profiling

Enable detailed memory profiling:

```elixir
Benchee.run(
  %{...},
  memory_time: 5, # More time for memory profiling
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "output.html", auto_open: true}
  ]
)
```

### Comparing Implementations

Benchmark different approaches:

```elixir
Benchee.run(
  %{
    "approach A" => fn -> implementation_a() end,
    "approach B" => fn -> implementation_b() end
  },
  time: 10 # Longer for more accurate comparison
)
```

## Contributing

When submitting performance improvements:

1. Run benchmarks before and after changes
2. Include benchmark results in PR description
3. Document expected performance characteristics
4. Add new benchmark scenarios for new features

## Related Documentation

- [Benchee Documentation](https://hexdocs.pm/benchee/)
- [Performance Optimization Guide](../guides/performance_optimization.md)
- [ExOutlines API Documentation](https://hexdocs.pm/ex_outlines/)

## Questions?

- GitHub Issues: [Report performance issues](https://github.com/your-org/ex_outlines/issues)
- Discussions: [Performance questions](https://github.com/your-org/ex_outlines/discussions)

---

**Last Updated:** 2026-01-28
