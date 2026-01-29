# Schema Patterns and Validation

This guide covers common schema patterns, validation techniques, and best practices for using ExOutlines schemas effectively.

## Table of Contents

- [Basic Schema Patterns](#basic-schema-patterns)
- [String Validation Patterns](#string-validation-patterns)
- [Numeric Constraints](#numeric-constraints)
- [Array Patterns](#array-patterns)
- [Nested Object Patterns](#nested-object-patterns)
- [Union Types for Flexibility](#union-types-for-flexibility)
- [Enum Patterns](#enum-patterns)
- [Common Validation Scenarios](#common-validation-scenarios)
- [Schema Composition](#schema-composition)
- [Best Practices](#best-practices)

## Basic Schema Patterns

### Required vs Optional Fields

```elixir
alias ExOutlines.Spec.Schema

# All fields required
strict_schema = Schema.new(%{
  name: %{type: :string, required: true},
  email: %{type: :string, required: true},
  age: %{type: :integer, required: true}
})

# Mix of required and optional
flexible_schema = Schema.new(%{
  name: %{type: :string, required: true},
  email: %{type: :string, required: true},
  nickname: %{type: :string, required: false},  # Optional
  bio: %{type: :string, required: false}        # Optional
})
```

**Rule**: Only mark fields as required if they are absolutely necessary. Optional fields provide flexibility for incomplete or varied data.

### Field Descriptions

Field descriptions guide the LLM in generating appropriate content.

```elixir
schema = Schema.new(%{
  title: %{
    type: :string,
    required: true,
    min_length: 5,
    max_length: 100,
    description: "A clear, concise title that summarizes the content"
  },
  summary: %{
    type: :string,
    required: true,
    min_length: 50,
    max_length: 300,
    description: "A detailed summary providing context and key points"
  }
})
```

**Best Practice**: Write descriptions that explain **purpose** and **constraints**, not just field names.

## String Validation Patterns

### Length Constraints

```elixir
# Username constraints
username_schema = Schema.new(%{
  username: %{
    type: :string,
    required: true,
    min_length: 3,
    max_length: 20,
    description: "Alphanumeric username"
  }
})

# Tweet-like content
tweet_schema = Schema.new(%{
  content: %{
    type: :string,
    required: true,
    max_length: 280,
    description: "Tweet content"
  }
})

# Article with minimum content
article_schema = Schema.new(%{
  body: %{
    type: :string,
    required: true,
    min_length: 500,
    max_length: 5000,
    description: "Article body text"
  }
})
```

### Pattern Matching with Regex

```elixir
# Email validation
email_schema = Schema.new(%{
  email: %{
    type: :string,
    required: true,
    pattern: ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
    description: "Valid email address"
  }
})

# Phone number (US format)
phone_schema = Schema.new(%{
  phone: %{
    type: :string,
    required: true,
    pattern: ~r/^\d{3}-\d{3}-\d{4}$/,
    description: "Phone number in format XXX-XXX-XXXX"
  }
})

# Product SKU
sku_schema = Schema.new(%{
  sku: %{
    type: :string,
    required: true,
    pattern: ~r/^[A-Z]{3}\d{6}$/,
    description: "Product SKU (3 letters + 6 digits)"
  }
})

# ISO Date
date_schema = Schema.new(%{
  date: %{
    type: :string,
    required: true,
    pattern: ~r/^\d{4}-\d{2}-\d{2}$/,
    description: "Date in YYYY-MM-DD format"
  }
})
```

### Built-in Format Validation

```elixir
# Using format shortcuts
contact_schema = Schema.new(%{
  email: %{type: :string, format: :email, required: true},
  website: %{type: :string, format: :url, required: false},
  id: %{type: :string, format: :uuid, required: true}
})
```

**Available formats**: `:email`, `:url`, `:uuid`, `:phone`, `:date`

## Numeric Constraints

### Integer Ranges

```elixir
# Age validation
age_schema = Schema.new(%{
  age: %{
    type: :integer,
    required: true,
    min: 0,
    max: 120,
    description: "Person's age in years"
  }
})

# Quantity (positive only)
quantity_schema = Schema.new(%{
  quantity: %{
    type: :integer,
    required: true,
    min: 1,
    max: 9999,
    description: "Order quantity"
  }
})

# Rating system
rating_schema = Schema.new(%{
  rating: %{
    type: :integer,
    required: true,
    min: 1,
    max: 5,
    description: "Star rating from 1 to 5"
  }
})
```

### Float/Decimal Validation

```elixir
# Price with reasonable bounds
price_schema = Schema.new(%{
  price: %{
    type: :number,
    required: true,
    min: 0.01,
    max: 999999.99,
    description: "Price in dollars"
  }
})

# Temperature (Celsius)
temperature_schema = Schema.new(%{
  temperature: %{
    type: :number,
    required: true,
    min: -273.15,  # Absolute zero
    max: 5778,     # Sun's surface temperature
    description: "Temperature in Celsius"
  }
})

# Percentage
percentage_schema = Schema.new(%{
  confidence: %{
    type: :number,
    required: true,
    min: 0,
    max: 100,
    description: "Confidence percentage"
  }
})
```

## Array Patterns

### Fixed-Length Arrays

```elixir
# RGB color (exactly 3 values)
rgb_schema = Schema.new(%{
  color: %{
    type: {:array, %{type: :integer, min: 0, max: 255}},
    required: true,
    min_items: 3,
    max_items: 3,
    description: "RGB color values [red, green, blue]"
  }
})
```

### Variable-Length Arrays

```elixir
# Tags (1-10 items)
tags_schema = Schema.new(%{
  tags: %{
    type: {:array, %{type: :string, min_length: 2, max_length: 20}},
    required: true,
    min_items: 1,
    max_items: 10,
    description: "Content tags"
  }
})

# Unlimited items (with item constraints)
comments_schema = Schema.new(%{
  comments: %{
    type: {:array, %{type: :string, max_length: 500}},
    required: false,
    description: "User comments"
  }
})
```

### Unique Items

```elixir
# Category selection (no duplicates)
categories_schema = Schema.new(%{
  categories: %{
    type: {:array, %{type: :string}},
    required: true,
    unique_items: true,
    min_items: 1,
    max_items: 5,
    description: "Selected categories (no duplicates)"
  }
})
```

### Arrays of Enums

```elixir
# Multiple choice selection
skills_schema = Schema.new(%{
  skills: %{
    type: {:array, %{type: {:enum, ["elixir", "python", "rust", "go", "javascript"]}}},
    required: true,
    unique_items: true,
    min_items: 1,
    max_items: 5,
    description: "Programming skills"
  }
})
```

## Nested Object Patterns

### Simple Nesting

```elixir
# Address as nested object
address_schema = Schema.new(%{
  street: %{type: :string, required: true},
  city: %{type: :string, required: true},
  state: %{type: :string, required: true, min_length: 2, max_length: 2},
  zip_code: %{type: :string, required: true, pattern: ~r/^\d{5}$/}
})

user_schema = Schema.new(%{
  name: %{type: :string, required: true},
  email: %{type: :string, required: true, format: :email},
  address: %{type: {:object, address_schema}, required: true}
})
```

### Deep Nesting

```elixir
# Location -> Address -> User
location_schema = Schema.new(%{
  latitude: %{type: :number, required: true, min: -90, max: 90},
  longitude: %{type: :number, required: true, min: -180, max: 180}
})

full_address_schema = Schema.new(%{
  street: %{type: :string, required: true},
  city: %{type: :string, required: true},
  state: %{type: :string, required: true},
  zip_code: %{type: :string, required: true},
  location: %{type: {:object, location_schema}, required: false}
})

complete_user_schema = Schema.new(%{
  name: %{type: :string, required: true},
  email: %{type: :string, required: true},
  address: %{type: {:object, full_address_schema}, required: true}
})
```

**Access Pattern**: Nested validation errors include full path (e.g., `address.location.latitude`).

### Optional Nested Objects

```elixir
profile_schema = Schema.new(%{
  bio: %{type: :string, required: false, max_length: 500}
})

user_schema = Schema.new(%{
  username: %{type: :string, required: true},
  # Profile is optional - can be nil
  profile: %{type: {:object, profile_schema}, required: false}
})
```

### Arrays of Objects

```elixir
# Product reviews
review_schema = Schema.new(%{
  rating: %{type: :integer, required: true, min: 1, max: 5},
  comment: %{type: :string, required: true, min_length: 10, max_length: 500},
  reviewer: %{type: :string, required: true}
})

product_schema = Schema.new(%{
  name: %{type: :string, required: true},
  reviews: %{
    type: {:array, %{type: {:object, review_schema}}},
    required: false,
    max_items: 50
  }
})
```

## Union Types for Flexibility

### Basic Union Types

```elixir
# ID can be string or integer
flexible_id_schema = Schema.new(%{
  id: %{
    type: {:union, [
      %{type: :string, pattern: ~r/^[A-Z]{3}\d{6}$/},
      %{type: :integer, positive: true}
    ]},
    required: true,
    description: "Product ID (string SKU or numeric ID)"
  }
})
```

### Nullable Fields

```elixir
# Middle name is optional - can be string or null
name_schema = Schema.new(%{
  first_name: %{type: :string, required: true},
  middle_name: %{
    type: {:union, [
      %{type: :string, max_length: 50},
      %{type: :null}
    ]},
    required: false,
    description: "Middle name (optional)"
  },
  last_name: %{type: :string, required: true}
})
```

### Multiple Type Options

```elixir
# Contact can be email or phone
contact_schema = Schema.new(%{
  contact_method: %{
    type: {:union, [
      %{type: :string, format: :email},
      %{type: :string, format: :phone}
    ]},
    required: true,
    description: "Email address or phone number"
  }
})
```

### Complex Union Types

```elixir
# Response can be success with data or error with message
response_schema = Schema.new(%{
  status: %{type: {:enum, ["success", "error"]}, required: true},
  result: %{
    type: {:union, [
      %{type: :string},  # Error message
      %{type: :integer}, # Success result
      %{type: :null}     # No result
    ]},
    required: true
  }
})
```

## Enum Patterns

### Simple Enums

```elixir
# Status field
status_schema = Schema.new(%{
  status: %{
    type: {:enum, ["pending", "approved", "rejected"]},
    required: true,
    description: "Application status"
  }
})

# Priority levels
priority_schema = Schema.new(%{
  priority: %{
    type: {:enum, ["low", "medium", "high", "critical"]},
    required: true,
    description: "Task priority"
  }
})
```

### Enums with Descriptions

```elixir
# Category taxonomy
category_schema = Schema.new(%{
  category: %{
    type: {:enum, [
      "electronics",
      "clothing",
      "home",
      "sports",
      "toys",
      "books"
    ]},
    required: true,
    description: """
    Primary product category:
    - electronics: Computers, phones, gadgets
    - clothing: Apparel, footwear, accessories
    - home: Furniture, appliances, decor
    - sports: Equipment, fitness, outdoor
    - toys: Games, educational, collectibles
    - books: Physical and digital books
    """
  }
})
```

### Multiple Enums

```elixir
# Task management
task_schema = Schema.new(%{
  status: %{
    type: {:enum, ["todo", "in_progress", "done", "blocked"]},
    required: true
  },
  priority: %{
    type: {:enum, ["low", "medium", "high"]},
    required: true
  },
  category: %{
    type: {:enum, ["bug", "feature", "docs", "test"]},
    required: true
  }
})
```

## Common Validation Scenarios

### User Registration

```elixir
registration_schema = Schema.new(%{
  username: %{
    type: :string,
    required: true,
    min_length: 3,
    max_length: 20,
    pattern: ~r/^[a-zA-Z0-9_]+$/,
    description: "Alphanumeric username with underscores"
  },
  email: %{
    type: :string,
    required: true,
    format: :email,
    description: "Valid email address"
  },
  password: %{
    type: :string,
    required: true,
    min_length: 8,
    description: "Password (minimum 8 characters)"
  },
  age: %{
    type: :integer,
    required: true,
    min: 13,
    max: 120,
    description: "Age (must be 13 or older)"
  }
})
```

### Product Catalog Entry

```elixir
product_schema = Schema.new(%{
  name: %{
    type: :string,
    required: true,
    min_length: 3,
    max_length: 100,
    description: "Product name"
  },
  sku: %{
    type: :string,
    required: true,
    pattern: ~r/^[A-Z]{3}\d{6}$/,
    description: "Stock keeping unit (SKU)"
  },
  price: %{
    type: :number,
    required: true,
    min: 0.01,
    description: "Price in USD"
  },
  category: %{
    type: {:enum, ["electronics", "clothing", "home", "sports"]},
    required: true
  },
  tags: %{
    type: {:array, %{type: :string, min_length: 2, max_length: 20}},
    required: false,
    unique_items: true,
    max_items: 10
  },
  in_stock: %{
    type: :boolean,
    required: true,
    description: "Whether product is currently in stock"
  }
})
```

### Blog Post Metadata

```elixir
blog_post_schema = Schema.new(%{
  title: %{
    type: :string,
    required: true,
    min_length: 10,
    max_length: 100,
    description: "Post title"
  },
  slug: %{
    type: :string,
    required: true,
    pattern: ~r/^[a-z0-9-]+$/,
    description: "URL-safe slug"
  },
  excerpt: %{
    type: :string,
    required: true,
    min_length: 50,
    max_length: 300,
    description: "Brief summary for previews"
  },
  content: %{
    type: :string,
    required: true,
    min_length: 500,
    description: "Full post content"
  },
  published_date: %{
    type: :string,
    required: true,
    pattern: ~r/^\d{4}-\d{2}-\d{2}$/,
    description: "Publication date (YYYY-MM-DD)"
  },
  tags: %{
    type: {:array, %{type: :string}},
    required: true,
    min_items: 1,
    max_items: 5,
    unique_items: true
  },
  author: %{
    type: :string,
    required: true,
    description: "Author name"
  }
})
```

### API Error Response

```elixir
error_schema = Schema.new(%{
  error_code: %{
    type: :string,
    required: true,
    pattern: ~r/^[A-Z_]+$/,
    description: "Error code (uppercase with underscores)"
  },
  message: %{
    type: :string,
    required: true,
    min_length: 10,
    max_length: 200,
    description: "Human-readable error message"
  },
  details: %{
    type: {:union, [
      %{type: :string},
      %{type: :null}
    ]},
    required: false,
    description: "Additional error details"
  },
  timestamp: %{
    type: :string,
    required: true,
    description: "ISO 8601 timestamp"
  }
})
```

## Schema Composition

### Building Complex Schemas from Simple Ones

```elixir
# Define reusable schemas
name_schema = Schema.new(%{
  first_name: %{type: :string, required: true},
  last_name: %{type: :string, required: true}
})

contact_schema = Schema.new(%{
  email: %{type: :string, required: true, format: :email},
  phone: %{type: :string, required: false, format: :phone}
})

address_schema = Schema.new(%{
  street: %{type: :string, required: true},
  city: %{type: :string, required: true},
  state: %{type: :string, required: true},
  zip: %{type: :string, required: true}
})

# Compose into complete schema
customer_schema = Schema.new(%{
  name: %{type: {:object, name_schema}, required: true},
  contact: %{type: {:object, contact_schema}, required: true},
  billing_address: %{type: {:object, address_schema}, required: true},
  shipping_address: %{type: {:object, address_schema}, required: false}
})
```

### Reusable Patterns Module

```elixir
defmodule MyApp.Schemas do
  alias ExOutlines.Spec.Schema

  def email_field do
    %{type: :string, required: true, format: :email}
  end

  def phone_field do
    %{type: :string, required: false, format: :phone}
  end

  def username_field do
    %{
      type: :string,
      required: true,
      min_length: 3,
      max_length: 20,
      pattern: ~r/^[a-zA-Z0-9_]+$/
    }
  end

  def date_field do
    %{
      type: :string,
      required: true,
      pattern: ~r/^\d{4}-\d{2}-\d{2}$/
    }
  end

  def tags_field(max_items \\ 10) do
    %{
      type: {:array, %{type: :string, min_length: 2, max_length: 20}},
      required: false,
      unique_items: true,
      max_items: max_items
    }
  end

  # Use in schemas
  def user_schema do
    Schema.new(%{
      username: username_field(),
      email: email_field(),
      phone: phone_field()
    })
  end
end
```

## Best Practices

### 1. Start Simple, Add Constraints Gradually

```elixir
# Start with basic schema
basic = Schema.new(%{
  title: %{type: :string, required: true}
})

# Add constraints as needed
constrained = Schema.new(%{
  title: %{
    type: :string,
    required: true,
    min_length: 5,
    max_length: 100,
    description: "Article title"
  }
})
```

### 2. Use Descriptive Field Names

```elixir
# Good - clear and specific
good_schema = Schema.new(%{
  user_email: %{type: :string, format: :email, required: true},
  registration_date: %{type: :string, pattern: ~r/^\d{4}-\d{2}-\d{2}$/}
})

# Avoid - too generic
bad_schema = Schema.new(%{
  data: %{type: :string},
  value: %{type: :string}
})
```

### 3. Provide Meaningful Descriptions

```elixir
# Good - explains purpose and format
schema = Schema.new(%{
  api_key: %{
    type: :string,
    required: true,
    pattern: ~r/^sk-[a-zA-Z0-9]{48}$/,
    description: "OpenAI API key starting with 'sk-' followed by 48 alphanumeric characters"
  }
})
```

### 4. Balance Constraints with Flexibility

```elixir
# Too strict - may cause unnecessary retries
too_strict = Schema.new(%{
  comment: %{
    type: :string,
    required: true,
    min_length: 50,
    max_length: 50  # Exactly 50 characters - too rigid
  }
})

# Better - allows reasonable range
better = Schema.new(%{
  comment: %{
    type: :string,
    required: true,
    min_length: 20,
    max_length: 500  # Flexible range
  }
})
```

### 5. Use Enums for Known Sets

```elixir
# Good - predefined categories
good = Schema.new(%{
  status: %{type: {:enum, ["draft", "published", "archived"]}, required: true}
})

# Avoid - free text for categorical data
avoid = Schema.new(%{
  status: %{type: :string, required: true}  # Could be any string
})
```

### 6. Validate Format Early

```elixir
# Use regex/format to prevent invalid data
validated = Schema.new(%{
  email: %{type: :string, format: :email, required: true},
  phone: %{type: :string, format: :phone, required: false},
  url: %{type: :string, format: :url, required: false}
})
```

### 7. Consider Optional Fields for Graceful Degradation

```elixir
# Required core fields, optional metadata
schema = Schema.new(%{
  # Core data (required)
  name: %{type: :string, required: true},
  email: %{type: :string, required: true},

  # Metadata (optional - system can function without these)
  bio: %{type: :string, required: false},
  avatar_url: %{type: :string, required: false},
  preferences: %{type: {:object, preferences_schema}, required: false}
})
```

### 8. Document Complex Schemas

```elixir
defmodule MyApp.OrderSchema do
  @moduledoc """
  Schema for e-commerce order processing.

  Required fields:
  - order_id: Unique identifier
  - customer: Nested customer object
  - items: Array of order items (minimum 1)
  - total: Order total in USD

  Optional fields:
  - discount_code: Promotional code
  - notes: Customer notes
  """

  alias ExOutlines.Spec.Schema

  def schema do
    Schema.new(%{
      order_id: %{type: :string, required: true, format: :uuid},
      customer: %{type: {:object, customer_schema()}, required: true},
      items: %{
        type: {:array, %{type: {:object, item_schema()}}},
        required: true,
        min_items: 1
      },
      total: %{type: :number, required: true, min: 0.01},
      discount_code: %{type: :string, required: false},
      notes: %{type: :string, required: false, max_length: 500}
    })
  end

  defp customer_schema do
    # Customer schema definition
  end

  defp item_schema do
    # Item schema definition
  end
end
```

## Next Steps

- Read the **Core Concepts** guide for understanding validation mechanics
- Explore **Error Handling** guide for dealing with validation failures
- See **Phoenix Integration** guide for using schemas in web applications
- Review production examples in the `examples/` directory

## Further Reading

- [JSON Schema Specification](https://json-schema.org/)
- [Regular Expressions in Elixir](https://hexdocs.pm/elixir/Regex.html)
- [Ecto Schema Adapter](ecto_schema_adapter.md) for database integration
