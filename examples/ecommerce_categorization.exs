#!/usr/bin/env elixir
#
# E-commerce Product Categorization Example
#
# This example demonstrates how to use ExOutlines for extracting structured
# product information from natural language descriptions.
#
# Use cases:
# - Automated product data entry from supplier descriptions
# - Inventory management and catalog enrichment
# - Search engine optimization with structured metadata
# - Product recommendation systems
# - Marketplace categorization and tagging
#
# Run with: elixir examples/ecommerce_categorization.exs

Mix.install([{:ex_outlines, path: Path.expand("..", __DIR__)}])

defmodule EcommerceCategorization do
  @moduledoc """
  Extract structured product data from unstructured descriptions.

  This module demonstrates a production-ready schema for categorizing
  e-commerce products using LLM-powered extraction with validation.
  """

  alias ExOutlines.{Spec, Spec.Schema}

  @doc """
  Define the product categorization schema.

  The schema validates:
  - Product name (3-100 characters)
  - Primary category from predefined taxonomy
  - Specific subcategory within the primary category
  - Optional brand identification
  - Key features as an array (1-10 items, max 50 chars each)
  - Price tier estimation
  - Searchable tags (unique, 2-20 chars each, max 8 tags)
  """
  def product_schema do
    Schema.new(%{
      name: %{
        type: :string,
        required: true,
        min_length: 3,
        max_length: 100,
        description: "Product name extracted from description"
      },
      category: %{
        type: {:enum, ["electronics", "clothing", "home", "sports", "toys"]},
        required: true,
        description: "Primary product category from taxonomy"
      },
      subcategory: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 50,
        description: "Specific subcategory within primary category"
      },
      brand: %{
        type: {:union, [%{type: :string, max_length: 50}, %{type: :null}]},
        description: "Brand name if identifiable from description"
      },
      features: %{
        type: {:array, %{type: :string, max_length: 50}},
        required: true,
        min_items: 1,
        max_items: 10,
        description: "Key product features and specifications"
      },
      price_range: %{
        type: {:enum, ["budget", "mid-range", "premium", "luxury"]},
        required: true,
        description: "Estimated price tier based on description"
      },
      tags: %{
        type: {:array, %{type: :string, min_length: 2, max_length: 20}},
        unique_items: true,
        max_items: 8,
        description: "Searchable tags for product discovery"
      }
    })
  end

  @doc """
  Categorize a product description.

  This would typically call an LLM backend, but for demonstration
  purposes we'll show the schema usage and validation.

  Options:
  - :backend - Backend module to use (default: Mock for testing)
  - :backend_opts - Options to pass to the backend
  """
  def categorize(description, _opts \\ []) do
    schema = product_schema()

    # In a real implementation, you would build a prompt like:
    # "Analyze this product description and extract structured data: #{description}"
    # Then call: ExOutlines.generate(schema, backend: backend, backend_opts: backend_opts)

    # For this example, we'll demonstrate with mock data
    IO.puts("\n=== Product Description ===")
    IO.puts(description)
    IO.puts("\n=== Extracting structured data... ===")

    # Return the schema for inspection or pass to ExOutlines.generate/2
    {:ok, schema}
  end

  @doc """
  Validate extracted product data against the schema.

  This is useful for testing and validation of LLM outputs.
  """
  def validate_product(product_data) do
    Spec.validate(product_schema(), product_data)
  end

  @doc """
  Display the JSON Schema for LLM prompts.

  This shows what schema would be sent to the LLM for structured output.
  """
  def show_json_schema do
    schema = product_schema()
    json_schema = Spec.to_schema(schema)

    IO.puts("\n=== JSON Schema for LLM ===")
    IO.inspect(json_schema, pretty: true, limit: :infinity)
  end
end

# ============================================================================
# Example Usage and Testing
# ============================================================================

IO.puts("=" |> String.duplicate(70))
IO.puts("E-commerce Product Categorization Example")
IO.puts("=" |> String.duplicate(70))

# Display the JSON Schema
EcommerceCategorization.show_json_schema()

# ============================================================================
# Example 1: High-end Electronics (MacBook)
# ============================================================================

description_macbook = """
Apple MacBook Pro 16-inch with M3 Max chip, 36GB RAM, 1TB SSD.
Features stunning Liquid Retina XDR display with 3456x2234 resolution,
advanced thermal design for sustained performance, and up to 22 hours
of battery life. Professional-grade performance for developers, video
editors, and creative professionals. Space Black finish with backlit
Magic Keyboard and Force Touch trackpad.
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 1: High-End Electronics")
IO.puts("=" |> String.duplicate(70))

EcommerceCategorization.categorize(description_macbook)

# Expected output structure (for testing/validation)
expected_macbook = %{
  "name" => "Apple MacBook Pro 16-inch M3 Max",
  "category" => "electronics",
  "subcategory" => "laptops",
  "brand" => "Apple",
  "features" => [
    "M3 Max chip",
    "36GB RAM",
    "1TB SSD",
    "Liquid Retina XDR display",
    "22-hour battery life",
    "Space Black finish"
  ],
  "price_range" => "luxury",
  "tags" => ["laptop", "apple", "macbook", "professional", "creative"]
}

IO.puts("\n=== Expected Structured Output ===")
IO.inspect(expected_macbook, pretty: true)

# Validate the expected output
case EcommerceCategorization.validate_product(expected_macbook) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")
    IO.puts("Validated data:")
    IO.inspect(validated, pretty: true)

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 2: Athletic Footwear (Nike Running Shoes)
# ============================================================================

description_shoes = """
Nike Air Zoom Pegasus 40 running shoes. Breathable engineered mesh upper
provides lightweight support and ventilation. Responsive Zoom Air cushioning
in forefoot and heel for smooth transitions. Durable rubber outsole with
waffle pattern for traction on road and track. Available in multiple
colorways including black, white, and university blue. Ideal for daily
training runs and long-distance running. Men's and women's sizes available.
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 2: Athletic Footwear")
IO.puts("=" |> String.duplicate(70))

EcommerceCategorization.categorize(description_shoes)

expected_shoes = %{
  "name" => "Nike Air Zoom Pegasus 40",
  "category" => "sports",
  "subcategory" => "running shoes",
  "brand" => "Nike",
  "features" => [
    "Breathable mesh upper",
    "Zoom Air cushioning",
    "Durable rubber outsole",
    "Multiple colorways",
    "Road and track traction"
  ],
  "price_range" => "mid-range",
  "tags" => ["running", "nike", "athletic", "footwear", "training"]
}

IO.puts("\n=== Expected Structured Output ===")
IO.inspect(expected_shoes, pretty: true)

case EcommerceCategorization.validate_product(expected_shoes) do
  {:ok, _validated} ->
    IO.puts("\n✅ Validation successful!")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 3: Home Appliance (Instant Pot)
# ============================================================================

description_instantpot = """
Instant Pot Duo 7-in-1 Electric Pressure Cooker, 6 Quart capacity.
Combines pressure cooker, slow cooker, rice cooker, steamer, sauté pan,
yogurt maker, and warmer in one appliance. Stainless steel inner pot
is dishwasher safe. 14 smart programs for soup, meat, bean, rice, poultry,
yogurt, and more. Safety features include overheat protection and
steam release valve. Energy efficient and saves up to 70% cooking time.
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 3: Home Appliance")
IO.puts("=" |> String.duplicate(70))

EcommerceCategorization.categorize(description_instantpot)

expected_instantpot = %{
  "name" => "Instant Pot Duo 7-in-1 Electric Pressure Cooker",
  "category" => "home",
  "subcategory" => "kitchen appliances",
  "brand" => "Instant Pot",
  "features" => [
    "7-in-1 functionality",
    "6 quart capacity",
    "Stainless steel pot",
    "14 smart programs",
    "Safety features",
    "Energy efficient"
  ],
  "price_range" => "mid-range",
  "tags" => ["cooking", "appliance", "kitchen", "pressure-cooker"]
}

IO.puts("\n=== Expected Structured Output ===")
IO.inspect(expected_instantpot, pretty: true)

case EcommerceCategorization.validate_product(expected_instantpot) do
  {:ok, _validated} ->
    IO.puts("\n✅ Validation successful!")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Testing with Mock Backend
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("TESTING WITH MOCK BACKEND")
IO.puts("=" |> String.duplicate(70))

IO.puts("""

In a real application, you would use ExOutlines.generate/2 with a real LLM backend:

  alias ExOutlines.Backend.HTTP

  result = ExOutlines.generate(
    EcommerceCategorization.product_schema(),
    backend: HTTP,
    backend_opts: [
      api_url: "https://api.openai.com/v1/chat/completions",
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4"
    ]
  )

For testing without an LLM, use the Mock backend:

  alias ExOutlines.Backend.Mock

  mock_response = Jason.encode!(%{
    name: "Product Name",
    category: "electronics",
    subcategory: "smartphones",
    brand: "Apple",
    features: ["Feature 1", "Feature 2"],
    price_range: "premium",
    tags: ["phone", "mobile"]
  })

  mock = Mock.new([{:ok, mock_response}])

  result = ExOutlines.generate(
    EcommerceCategorization.product_schema(),
    backend: Mock,
    backend_opts: [mock: mock]
  )
""")

# ============================================================================
# Error Handling and Validation Failures
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("ERROR HANDLING EXAMPLES")
IO.puts("=" |> String.duplicate(70))

IO.puts("\n--- Example: Missing required field ---")

invalid_missing = %{
  "name" => "Product Name",
  "category" => "electronics"
  # Missing required fields: subcategory, features, price_range
}

case EcommerceCategorization.validate_product(invalid_missing) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Invalid enum value ---")

invalid_enum = %{
  "name" => "Product Name",
  "category" => "invalid_category",
  "subcategory" => "sub",
  "features" => ["Feature 1"],
  "price_range" => "cheap"
}

case EcommerceCategorization.validate_product(invalid_enum) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Array constraints violation ---")

invalid_array = %{
  "name" => "Product Name",
  "category" => "electronics",
  "subcategory" => "smartphones",
  "features" => [],
  # Empty array violates min_items: 1
  "price_range" => "premium",
  "tags" => ["a", "b", "c", "d", "e", "f", "g", "h", "i"]
  # 9 tags violates max_items: 8
}

case EcommerceCategorization.validate_product(invalid_array) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

# ============================================================================
# Integration Guidance
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("INTEGRATION GUIDANCE")
IO.puts("=" |> String.duplicate(70))

IO.puts("""

## Phoenix Controller Integration

defmodule MyAppWeb.ProductController do
  use MyAppWeb, :controller
  alias EcommerceCategorization

  def categorize(conn, %{"description" => description}) do
    case ExOutlines.generate(
      EcommerceCategorization.product_schema(),
      backend: MyApp.LLM.Backend,
      backend_opts: [timeout: 30_000]
    ) do
      {:ok, product_data} ->
        # Save to database
        {:ok, product} = MyApp.Products.create_product(product_data)
        json(conn, product)

      {:error, %{validation_errors: errors}} ->
        # Retry with feedback
        retry_with_feedback(conn, description, errors)

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Categorization failed", reason: inspect(reason)})
    end
  end

  defp retry_with_feedback(conn, description, errors) do
    # Implement retry logic with error feedback to LLM
    # See ExOutlines documentation for retry strategies
  end
end

## Oban Background Job Integration

defmodule MyApp.Workers.ProductCategorization do
  use Oban.Worker, queue: :categorization, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_id" => id, "description" => desc}}) do
    case ExOutlines.generate(
      EcommerceCategorization.product_schema(),
      backend: MyApp.LLM.Backend
    ) do
      {:ok, product_data} ->
        MyApp.Products.update_categorization(id, product_data)
        :ok

      {:error, reason} ->
        {:error, reason}  # Will trigger Oban retry
    end
  end
end

## Testing Strategy

defmodule MyApp.ProductCategorizationTest do
  use MyApp.DataCase
  alias ExOutlines.Backend.Mock

  test "categorizes MacBook correctly" do
    mock_response = Jason.encode!(%{
      name: "MacBook Pro",
      category: "electronics",
      subcategory: "laptops",
      brand: "Apple",
      features: ["M3 chip", "16-inch display"],
      price_range: "luxury",
      tags: ["laptop", "apple"]
    })

    mock = Mock.new([{:ok, mock_response}])

    {:ok, result} = ExOutlines.generate(
      EcommerceCategorization.product_schema(),
      backend: Mock,
      backend_opts: [mock: mock]
    )

    assert result.category == "electronics"
    assert result.brand == "Apple"
  end
end
""")

IO.puts("\n" <> ("=" |> String.duplicate(70)))
IO.puts("Example complete! All validations passed.")
IO.puts("=" |> String.duplicate(70))
