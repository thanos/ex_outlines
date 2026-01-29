# Getting Started with Ex Outlines

Welcome to Ex Outlines! This guide will help you get up and running with structured LLM output validation in your Elixir applications.

## Table of Contents

- [What is Ex Outlines?](#what-is-ex-outlines)
- [Installation](#installation)
- [Your First Schema](#your-first-schema)
- [Basic Validation](#basic-validation)
- [Backend Configuration](#backend-configuration)
- [Structured Generation with LLMs](#structured-generation-with-llms)
- [Understanding the Retry-Repair Loop](#understanding-the-retry-repair-loop)
- [Working with Complex Schemas](#working-with-complex-schemas)
- [Batch Processing](#batch-processing)
- [Next Steps](#next-steps)

---

## What is Ex Outlines?

Ex Outlines is an Elixir library that guarantees valid, structured outputs from Large Language Models (LLMs). Instead of hoping the LLM returns valid JSON and parsing it after the fact, Ex Outlines:

1. **Defines a schema** - Specify exactly what fields, types, and constraints you expect
2. **Validates output** - Checks if the LLM's response matches your schema
3. **Automatically repairs** - If validation fails, sends diagnostics back to the LLM to fix the output
4. **Guarantees correctness** - Repeats until valid (up to configurable max retries)

**Key Benefits:**
- No more parsing failures or invalid JSON
- Type-safe outputs (validated at runtime)
- Clear error diagnostics for debugging
- Works with any LLM backend (OpenAI, Anthropic, etc.)
- Leverages BEAM concurrency for batch processing

---

## Installation

Add `ex_outlines` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_outlines, "~> 0.2.0"}
  ]
end
```

If you want to integrate with Ecto schemas:

```elixir
def deps do
  [
    {:ex_outlines, "~> 0.2.0"},
    {:ecto, "~> 3.11"}  # Optional, for Ecto integration
  ]
end
```

Then run:

```bash
mix deps.get
```

Verify installation in `iex`:

```elixir
iex -S mix
iex> ExOutlines.version()
"0.2.0"
```

---

## Your First Schema

A schema defines the structure of the data you expect from the LLM. Let's start with a simple example:

```elixir
alias ExOutlines.Spec.Schema

# Define a schema for a person
schema = Schema.new(%{
  name: %{type: :string, required: true},
  age: %{type: :integer, required: true}
})
```

This schema expects:
- A `name` field that must be a string
- An `age` field that must be an integer
- Both fields are required (validation fails if missing)

### Adding Constraints

You can add constraints to enforce additional rules:

```elixir
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
  }
})
```

Now:
- `name` must be 2-50 characters long
- `age` must be between 0 and 120

### Field Types

Ex Outlines supports these field types:

| Type | Description | Example |
|------|-------------|---------|
| `:string` | Text value | `"Alice"` |
| `:integer` | Whole number | `42` |
| `:boolean` | True/false | `true` |
| `:number` | Integer or float | `3.14` |
| `{:enum, list}` | One of specific values | `{:enum, ["red", "green", "blue"]}` |
| `{:array, spec}` | List of items | `{:array, %{type: :string}}` |
| `{:object, schema}` | Nested object | `{:object, address_schema}` |
| `{:union, specs}` | Multiple possible types | `{:union, [%{type: :string}, %{type: :null}]}` |

---

## Basic Validation

Before using an LLM, let's validate some data manually to understand how schemas work:

```elixir
alias ExOutlines.Spec

# Valid input
input = %{"name" => "Alice", "age" => 30}
{:ok, validated} = Spec.validate(schema, input)

IO.inspect(validated)
# Output: %{name: "Alice", age: 30}
```

Notice:
- Input uses **string keys** (`"name"`, `"age"`)
- Output uses **atom keys** (`:name`, `:age`)
- This conversion happens automatically

### Validation Errors

Let's see what happens with invalid input:

```elixir
# Invalid: age too high
input = %{"name" => "Bob", "age" => 150}
{:error, diagnostics} = Spec.validate(schema, input)

IO.inspect(diagnostics, pretty: true)
# Output:
# %ExOutlines.Diagnostics{
#   valid?: false,
#   errors: [
#     %{
#       field: "age",
#       expected: "integer between 0 and 120",
#       got: 150,
#       message: "Field 'age' must be at most 120"
#     }
#   ]
# }
```

The diagnostics structure contains:
- `valid?`: Boolean indicating overall validity
- `errors`: List of all validation errors
- Each error has: `field`, `expected`, `got`, `message`

### Multiple Errors

Validation collects **all errors**, not just the first one:

```elixir
input = %{"name" => "X", "age" => 200}
{:error, diagnostics} = Spec.validate(schema, input)

# Two errors:
# 1. name too short (< 2 characters)
# 2. age too high (> 120)
```

---

## Backend Configuration

To generate structured output from an LLM, you need to configure a backend. Ex Outlines supports multiple backends:

### HTTP Backend (OpenAI-Compatible)

Works with OpenAI, Azure OpenAI, and any OpenAI-compatible API:

```elixir
alias ExOutlines.Backend.HTTP

backend_opts = [
  api_key: System.get_env("OPENAI_API_KEY"),
  model: "gpt-4o-mini",
  api_url: "https://api.openai.com/v1/chat/completions"
]
```

### Anthropic Backend

Native support for Claude models:

```elixir
alias ExOutlines.Backend.Anthropic

backend_opts = [
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  model: "claude-3-5-sonnet-20241022"
]
```

### Mock Backend (Testing)

For tests and development without API calls:

```elixir
alias ExOutlines.Backend.Mock

mock = Mock.new([
  {:ok, ~s({"name": "Alice", "age": 30})}
])

backend_opts = [mock: mock]
```

### Configuration Best Practices

Store API keys securely:

```elixir
# config/runtime.exs
config :my_app, :openai_api_key, System.get_env("OPENAI_API_KEY")

# In your code
api_key = Application.get_env(:my_app, :openai_api_key)
```

---

## Structured Generation with LLMs

Now let's generate structured output from an LLM:

```elixir
alias ExOutlines.Spec.Schema
alias ExOutlines.Backend.HTTP

# Define what we want to extract
schema = Schema.new(%{
  sentiment: %{
    type: {:enum, ["positive", "negative", "neutral"]},
    required: true
  },
  summary: %{
    type: :string,
    required: true,
    min_length: 10,
    max_length: 100
  }
})

# Generate structured output
{:ok, result} = ExOutlines.generate(schema,
  backend: HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    model: "gpt-4o-mini",
    messages: [
      %{
        role: "system",
        content: "You analyze customer reviews and extract structured data."
      },
      %{
        role: "user",
        content: """
        Analyze this review:
        "This product exceeded my expectations! Fast shipping and great quality."

        Provide structured JSON output.
        """
      }
    ]
  ]
)

IO.inspect(result)
# Output: %{sentiment: "positive", summary: "Customer very satisfied with product quality and shipping speed"}
```

### What Happens Under the Hood

1. **Prompt Construction**: Ex Outlines builds a prompt including:
   - Your messages
   - JSON schema specification
   - Instructions for structured output

2. **LLM Call**: Sends prompt to the configured backend

3. **Validation**: Validates the LLM's response against your schema

4. **Success or Retry**:
   - If valid → returns `{:ok, validated_data}`
   - If invalid → constructs repair prompt and retries

---

## Understanding the Retry-Repair Loop

Ex Outlines automatically fixes invalid outputs through a retry-repair loop:

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
       │ (back to LLM Generate)
       └──────────────────┘
```

### Example: Retry in Action

```elixir
schema = Schema.new(%{
  age: %{type: :integer, required: true, min: 0, max: 120}
})

# Simulate LLM returning invalid age
# (In reality, this happens automatically)

# Attempt 1: LLM returns {"age": 150}
# Validation fails: age > 120

# Repair prompt sent:
# "The previous output was invalid:
#  - Field 'age' must be at most 120
#  Please fix the output and return valid JSON."

# Attempt 2: LLM returns {"age": 30}
# Validation succeeds → returns {:ok, %{age: 30}}
```

### Configuring Retries

```elixir
{:ok, result} = ExOutlines.generate(schema,
  backend: HTTP,
  backend_opts: backend_opts,
  max_retries: 5  # Default is 3
)
```

If all retries are exhausted:

```elixir
{:error, :max_retries_exceeded} = ExOutlines.generate(schema,
  backend: Mock.always({:ok, "invalid"}),
  backend_opts: [],
  max_retries: 2
)
```

---

## Working with Complex Schemas

### Nested Objects

```elixir
# Define address schema
address_schema = Schema.new(%{
  street: %{type: :string, required: true},
  city: %{type: :string, required: true},
  zip_code: %{type: :string, required: true, min_length: 5, max_length: 10}
})

# Use in parent schema
user_schema = Schema.new(%{
  name: %{type: :string, required: true},
  email: %{type: :string, required: true, pattern: ~r/@/},
  address: %{type: {:object, address_schema}, required: true}
})

# Example valid input:
input = %{
  "name" => "Alice",
  "email" => "alice@example.com",
  "address" => %{
    "street" => "123 Main St",
    "city" => "Springfield",
    "zip_code" => "12345"
  }
}

{:ok, validated} = Spec.validate(user_schema, input)
# validated.address.city == "Springfield"
```

### Arrays

```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true},
  tags: %{
    type: {:array, %{type: :string, max_length: 20}},
    required: true,
    min_items: 1,
    max_items: 5,
    unique_items: true
  }
})

# Valid input
input = %{
  "name" => "Product A",
  "tags" => ["electronics", "sale", "featured"]
}

{:ok, validated} = Spec.validate(schema, input)
# validated.tags == ["electronics", "sale", "featured"]
```

### Union Types (Optional Fields)

```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true},
  middle_name: %{
    type: {:union, [
      %{type: :string},
      %{type: :null}
    ]},
    required: false
  }
})

# Both valid:
Spec.validate(schema, %{"name" => "Alice", "middle_name" => "Marie"})
Spec.validate(schema, %{"name" => "Bob", "middle_name" => nil})
Spec.validate(schema, %{"name" => "Charlie"})  # middle_name omitted
```

### Enums

```elixir
schema = Schema.new(%{
  priority: %{
    type: {:enum, ["low", "medium", "high", "critical"]},
    required: true
  },
  category: %{
    type: {:enum, ["bug", "feature", "docs"]},
    required: true
  }
})
```

---

## Batch Processing

Process multiple schemas concurrently using BEAM's built-in concurrency:

```elixir
# Define multiple generation tasks
tasks = [
  {schema1, [backend: HTTP, backend_opts: opts1]},
  {schema2, [backend: HTTP, backend_opts: opts2]},
  {schema3, [backend: HTTP, backend_opts: opts3]}
]

# Generate concurrently
results = ExOutlines.generate_batch(tasks, max_concurrency: 3)

# Results is a list of {:ok, data} or {:error, reason} tuples
# Order is preserved by default
```

### Batch Options

```elixir
ExOutlines.generate_batch(tasks,
  max_concurrency: 5,    # Number of concurrent LLM calls
  timeout: 60_000,       # Timeout per task (ms)
  ordered: true          # Return results in input order
)
```

### Example: Classify Multiple Messages

```elixir
classification_schema = Schema.new(%{
  category: %{type: {:enum, ["spam", "important", "normal"]}},
  confidence: %{type: :number, min: 0, max: 1}
})

messages = [
  "Win a free iPhone now!",
  "Meeting at 3pm tomorrow",
  "Your package has been delivered"
]

tasks = Enum.map(messages, fn msg ->
  {classification_schema, [
    backend: HTTP,
    backend_opts: [
      api_key: api_key,
      model: "gpt-4o-mini",
      messages: [
        %{role: "system", content: "Classify messages."},
        %{role: "user", content: "Classify: #{msg}"}
      ]
    ]
  ]}
end)

results = ExOutlines.generate_batch(tasks, max_concurrency: 3)
# [
#   {:ok, %{category: "spam", confidence: 0.95}},
#   {:ok, %{category: "important", confidence: 0.85}},
#   {:ok, %{category: "normal", confidence: 0.90}}
# ]
```

---

## Next Steps

Congratulations! You now know the basics of Ex Outlines. Here's where to go next:

### Core Documentation

- **[Core Concepts](core_concepts.md)** - Deep dive into schemas, validation, and the retry-repair loop
- **[Architecture](architecture.md)** - System design and internals
- **[API Reference](https://hexdocs.pm/ex_outlines)** - Complete function documentation

### Integration Guides

- **[Phoenix Integration](phoenix_integration.md)** - Use Ex Outlines in controllers, LiveView, and Oban jobs
- **[Ecto Integration](ecto_schema_adapter.md)** - Convert Ecto schemas to Ex Outlines schemas automatically
- **[Testing Strategies](testing_strategies.md)** - Testing patterns with Mock backend
- **[Error Handling](error_handling.md)** - Robust error handling in production

### Examples

Browse `examples/` directory for production-ready examples:
- **Classification** - Customer support triage
- **E-commerce Categorization** - Product classification
- **Document Metadata Extraction** - Extract structured data from documents
- **Customer Support Triage** - Automated ticket routing

### Interactive Tutorials

Check out `livebooks/` for hands-on Livebook tutorials:
- **Getting Started** - Interactive introduction
- **Advanced Patterns** - Complex schemas and techniques

### Community

- **GitHub**: [https://github.com/thanos/ex_outlines](https://github.com/thanos/ex_outlines)
- **Issues**: Report bugs or request features
- **Discussions**: Ask questions and share patterns

---

## Quick Reference

### Common Patterns

**Simple classification:**
```elixir
schema = Schema.new(%{
  category: %{type: {:enum, ["A", "B", "C"]}}
})
```

**Data extraction:**
```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true},
  price: %{type: :number, min: 0},
  in_stock: %{type: :boolean}
})
```

**Nullable field:**
```elixir
field: %{type: {:union, [%{type: :string}, %{type: :null}]}}
```

**List of strings:**
```elixir
tags: %{type: {:array, %{type: :string}}, unique_items: true}
```

### Error Handling

```elixir
case ExOutlines.generate(schema, opts) do
  {:ok, result} ->
    # Use result

  {:error, :max_retries_exceeded} ->
    # All retry attempts failed

  {:error, {:backend_error, reason}} ->
    # Backend (API) error

  {:error, :no_backend} ->
    # Configuration error
end
```

---
