# Phoenix Integration Guide

Learn how to integrate ExOutlines into Phoenix applications for AI-powered features.

## Overview

This guide demonstrates how to use ExOutlines in Phoenix controllers, LiveView components, and background jobs. You'll learn practical patterns for handling structured LLM outputs in web applications.

**What You'll Learn:**
- Using ExOutlines in Phoenix controllers
- LiveView integration patterns
- Background job processing with Oban
- Caching strategies
- Error handling in web context
- Production deployment considerations

## Prerequisites

- Phoenix 1.7+ application
- ExOutlines added to `mix.exs`
- Basic understanding of Phoenix controllers and LiveView
- (Optional) Oban for background jobs

```elixir
# mix.exs
defp deps do
  [
    {:ex_outlines, "~> 0.2.0"},
    {:phoenix, "~> 1.7"},
    {:oban, "~> 2.17"}, # Optional, for background jobs
    # ... other deps
  ]
end
```

## Pattern 1: Controller Actions

Use ExOutlines in controller actions to process user input and return structured data.

### Basic Controller Example

```elixir
defmodule MyAppWeb.AIController do
  use MyAppWeb, :controller

  alias ExOutlines.{Spec.Schema, Backend.Anthropic}

  @schema Schema.new(%{
    summary: %{type: :string, required: true, max_length: 200},
    sentiment: %{type: {:enum, ["positive", "neutral", "negative"]}, required: true},
    topics: %{
      type: {:array, %{type: :string, max_length: 30}},
      required: true,
      min_items: 1,
      max_items: 5
    }
  })

  def analyze_text(conn, %{"text" => text}) do
    case ExOutlines.generate(@schema,
      backend: Anthropic,
      backend_opts: [
        api_key: get_api_key(),
        model: "claude-sonnet-4-5-20250929"
      ],
      max_retries: 2
    ) do
      {:ok, result} ->
        json(conn, %{
          success: true,
          data: result
        })

      {:error, :max_retries_exceeded} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          success: false,
          error: "Failed to analyze text after multiple attempts"
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          success: false,
          error: "Analysis failed: #{inspect(reason)}"
        })
    end
  end

  defp get_api_key do
    Application.fetch_env!(:my_app, :anthropic_api_key)
  end
end
```

### Controller with Validation

```elixir
def create_product(conn, params) do
  with {:ok, validated_input} <- validate_input(params),
       {:ok, enriched_data} <- enrich_with_llm(validated_input),
       {:ok, product} <- Products.create_product(enriched_data) do
    conn
    |> put_status(:created)
    |> json(%{data: product})
  else
    {:error, %Ecto.Changeset{} = changeset} ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: format_errors(changeset)})

    {:error, :max_retries_exceeded} ->
      conn
      |> put_status(:service_unavailable)
      |> json(%{error: "AI service temporarily unavailable"})
  end
end

defp enrich_with_llm(input) do
  schema = Schema.new(%{
    category: %{type: {:enum, ["electronics", "clothing", "home"]}, required: true},
    tags: %{type: {:array, %{type: :string}}, max_items: 5},
    description_enhanced: %{type: :string, max_length: 500}
  })

  ExOutlines.generate(schema,
    backend: Anthropic,
    backend_opts: [api_key: get_api_key()]
  )
end
```

## Pattern 2: LiveView Integration

Integrate ExOutlines into LiveView for real-time AI-powered features.

### LiveView Component

```elixir
defmodule MyAppWeb.ContentAnalyzerLive do
  use MyAppWeb, :live_view

  alias ExOutlines.{Spec.Schema, Backend.Anthropic}

  @impl true
  def mount(_params, _session, socket) do
    schema = Schema.new(%{
      title: %{type: :string, required: true, max_length: 100},
      summary: %{type: :string, required: true, max_length: 300},
      key_points: %{
        type: {:array, %{type: :string, max_length: 100}},
        min_items: 3,
        max_items: 5
      }
    })

    {:ok,
     socket
     |> assign(:schema, schema)
     |> assign(:input_text, "")
     |> assign(:result, nil)
     |> assign(:loading, false)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("analyze", %{"text" => text}, socket) do
    # Start analysis asynchronously
    send(self(), {:run_analysis, text})

    {:noreply,
     socket
     |> assign(:loading, true)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_info({:run_analysis, text}, socket) do
    case ExOutlines.generate(socket.assigns.schema,
      backend: Anthropic,
      backend_opts: [api_key: get_api_key()],
      max_retries: 2
    ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:result, result)
         |> assign(:loading, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:error, format_error(reason))
         |> assign(:loading, false)}
    end
  end

  defp format_error(:max_retries_exceeded),
    do: "Unable to analyze content after multiple attempts. Please try again."

  defp format_error({:backend_error, _}),
    do: "Service temporarily unavailable. Please try again later."

  defp format_error(_),
    do: "An unexpected error occurred. Please try again."

  defp get_api_key do
    Application.fetch_env!(:my_app, :anthropic_api_key)
  end
end
```

### LiveView Template

```heex
<div class="content-analyzer">
  <.form for={%{}} phx-submit="analyze">
    <textarea
      name="text"
      placeholder="Enter text to analyze..."
      rows="10"
      class="w-full p-2 border rounded"
    ><%= @input_text %></textarea>

    <button
      type="submit"
      disabled={@loading}
      class="mt-2 px-4 py-2 bg-blue-500 text-white rounded"
    >
      <%= if @loading, do: "Analyzing...", else: "Analyze" %>
    </button>
  </.form>

  <%= if @error do %>
    <div class="mt-4 p-4 bg-red-100 text-red-700 rounded">
      <%= @error %>
    </div>
  <% end %>

  <%= if @result do %>
    <div class="mt-4 p-4 bg-green-50 rounded">
      <h3 class="font-bold"><%= @result.title %></h3>
      <p class="mt-2"><%= @result.summary %></p>
      <ul class="mt-2 list-disc pl-5">
        <%= for point <- @result.key_points do %>
          <li><%= point %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
</div>
```

## Pattern 3: Background Jobs with Oban

Process long-running LLM tasks in background jobs to avoid blocking requests.

### Oban Worker

```elixir
defmodule MyApp.Workers.ContentEnricher do
  use Oban.Worker,
    queue: :ai_processing,
    max_attempts: 3

  alias ExOutlines.{Spec.Schema, Backend.Anthropic}
  alias MyApp.{Content, Repo}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"content_id" => content_id}}) do
    content = Repo.get!(Content, content_id)

    schema = Schema.new(%{
      categories: %{
        type: {:array, %{type: {:enum, ["tech", "business", "health", "entertainment"]}}},
        min_items: 1,
        max_items: 3
      },
      seo_title: %{type: :string, max_length: 60},
      seo_description: %{type: :string, max_length: 160},
      readability_score: %{type: :integer, min: 1, max: 10}
    })

    case ExOutlines.generate(schema,
      backend: Anthropic,
      backend_opts: [api_key: get_api_key()],
      max_retries: 2,
      telemetry_metadata: %{content_id: content_id}
    ) do
      {:ok, enriched_data} ->
        content
        |> Content.changeset(enriched_data)
        |> Repo.update()

        :ok

      {:error, :max_retries_exceeded} ->
        # Let Oban retry the job
        {:error, "LLM generation failed after retries"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_api_key do
    Application.fetch_env!(:my_app, :anthropic_api_key)
  end
end
```

### Enqueueing Jobs

```elixir
# In your controller or context
def enrich_content_async(content_id) do
  %{content_id: content_id}
  |> MyApp.Workers.ContentEnricher.new()
  |> Oban.insert()
end

# Usage
def create_content(conn, params) do
  with {:ok, content} <- Content.create(params),
       {:ok, _job} <- enrich_content_async(content.id) do
    conn
    |> put_status(:created)
    |> json(%{data: content, enrichment_status: "processing"})
  end
end
```

## Pattern 4: Caching Strategies

Cache LLM results to reduce costs and improve response times.

### Simple ETS Cache

```elixir
defmodule MyApp.LLMCache do
  @table :llm_cache
  @ttl :timer.hours(24)

  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] ->
        if System.system_time(:millisecond) < expires_at do
          {:ok, value}
        else
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  def put(key, value) do
    expires_at = System.system_time(:millisecond) + @ttl
    :ets.insert(@table, {key, value, expires_at})
    :ok
  end

  def start_link do
    :ets.new(@table, [:named_table, :public, :set])
    {:ok, self()}
  end
end

# Usage in controller
def analyze_with_cache(text) do
  cache_key = :crypto.hash(:sha256, text) |> Base.encode16()

  case MyApp.LLMCache.get(cache_key) do
    {:ok, cached_result} ->
      {:ok, cached_result}

    :miss ->
      case ExOutlines.generate(schema, backend: Anthropic, backend_opts: [...]) do
        {:ok, result} = success ->
          MyApp.LLMCache.put(cache_key, result)
          success

        error ->
          error
      end
  end
end
```

### Cachex for Advanced Caching

```elixir
# mix.exs
{:cachex, "~> 3.6"}

# application.ex
children = [
  {Cachex, name: :llm_cache, limit: 1000}
]

# Helper module
defmodule MyApp.CachedLLM do
  def generate_with_cache(schema, opts, cache_key) do
    Cachex.fetch(:llm_cache, cache_key, fn ->
      case ExOutlines.generate(schema, opts) do
        {:ok, result} ->
          {:commit, result, ttl: :timer.hours(24)}

        {:error, _} = error ->
          {:ignore, error}
      end
    end)
  end
end
```

## Pattern 5: Error Handling

Robust error handling for production applications.

```elixir
defmodule MyApp.LLMHandler do
  require Logger

  def safe_generate(schema, opts \\ []) do
    case ExOutlines.generate(schema, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, :max_retries_exceeded} ->
        Logger.warning("LLM generation max retries exceeded",
          schema: inspect(schema),
          opts: inspect(opts)
        )
        {:error, :service_unavailable}

      {:error, {:backend_error, reason}} ->
        Logger.error("LLM backend error",
          reason: inspect(reason),
          schema: inspect(schema)
        )
        {:error, :backend_failure}

      {:error, reason} ->
        Logger.error("Unexpected LLM error",
          reason: inspect(reason),
          schema: inspect(schema)
        )
        {:error, :unexpected_error}
    end
  end

  def generate_with_fallback(schema, opts, fallback_fn) do
    case safe_generate(schema, opts) do
      {:ok, result} -> {:ok, result}
      {:error, _} -> {:ok, fallback_fn.()}
    end
  end
end

# Usage
case MyApp.LLMHandler.generate_with_fallback(schema, opts, fn ->
  %{summary: "Content summary unavailable", sentiment: "neutral"}
end) do
  {:ok, result} ->
    # Always have a result, either from LLM or fallback
    json(conn, %{data: result})
end
```

## Common Pitfalls

### 1. Blocking Requests

**Problem:** Long LLM generation blocking HTTP requests

**Solution:** Use background jobs for long-running tasks

```elixir
# Bad - blocks the request
def create_article(conn, params) do
  {:ok, article} = Articles.create(params)
  {:ok, enriched} = enrich_with_llm(article) # Blocks!
  json(conn, enriched)
end

# Good - async processing
def create_article(conn, params) do
  {:ok, article} = Articles.create(params)
  enrich_async(article.id) # Returns immediately
  json(conn, %{article | status: "processing"})
end
```

### 2. Missing Timeouts

**Problem:** Requests hanging indefinitely

**Solution:** Always set reasonable timeouts

```elixir
# In config/config.exs
config :my_app, :llm_timeout, 30_000 # 30 seconds

# In controller
timeout = Application.get_env(:my_app, :llm_timeout)
Task.async(fn -> generate_content() end)
|> Task.await(timeout)
```

### 3. No Error Recovery

**Problem:** Errors crash the entire request

**Solution:** Handle errors gracefully with fallbacks

```elixir
def get_recommendations(user_id) do
  case generate_llm_recommendations(user_id) do
    {:ok, recs} -> recs
    {:error, _} -> get_default_recommendations(user_id)
  end
end
```

## Best Practices

1. **Use Background Jobs**: Process LLM requests asynchronously with Oban
2. **Implement Caching**: Cache results to reduce API costs
3. **Set Timeouts**: Always configure appropriate timeouts
4. **Monitor Performance**: Use telemetry to track LLM performance
5. **Graceful Degradation**: Provide fallbacks when LLM fails
6. **Rate Limiting**: Implement rate limiting to prevent abuse
7. **Secure API Keys**: Store API keys in environment variables, never in code

## Production Checklist

- [ ] API keys stored in environment variables
- [ ] Timeouts configured for all LLM calls
- [ ] Error handling with appropriate HTTP status codes
- [ ] Telemetry instrumentation for monitoring
- [ ] Caching strategy implemented
- [ ] Background job processing for long tasks
- [ ] Rate limiting on AI endpoints
- [ ] Fallback behavior for service outages
- [ ] Cost monitoring and alerting
- [ ] Load testing completed

## Related Guides

- [Testing Strategies](testing_strategies.md) - Test your Phoenix integration
- [Error Handling](error_handling.md) - Advanced error handling patterns
- [Batch Processing](batch_processing.md) - Process multiple requests efficiently

## Further Reading

- [Phoenix Framework Documentation](https://hexdocs.pm/phoenix/)
- [Oban Documentation](https://hexdocs.pm/oban/)
- [Cachex Documentation](https://hexdocs.pm/cachex/)
- [ExOutlines API Documentation](https://hexdocs.pm/ex_outlines/)
