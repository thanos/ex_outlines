#!/usr/bin/env elixir

# Schema Validation Benchmarks
#
# Measures validation performance across different schema complexities:
# - Simple type validation (string, integer, boolean)
# - Constrained validation (length, min/max, pattern)
# - Array validation (small, medium, large arrays)
# - Nested object validation (1 level, 3 levels, 5 levels)
# - Union type validation
#
# Run with: mix run benchmarks/schema_validation.exs

alias ExOutlines.{Spec, Spec.Schema}

# Setup test data
IO.puts("Setting up benchmark data...")

# Simple schemas
simple_string_schema = Schema.new(%{
  name: %{type: :string, required: true}
})

simple_integer_schema = Schema.new(%{
  count: %{type: :integer, required: true}
})

simple_boolean_schema = Schema.new(%{
  active: %{type: :boolean, required: true}
})

# Constrained schemas
constrained_string_schema = Schema.new(%{
  username: %{
    type: :string,
    required: true,
    min_length: 3,
    max_length: 20,
    pattern: ~r/^[a-z0-9_]+$/i
  }
})

constrained_integer_schema = Schema.new(%{
  age: %{type: :integer, required: true, min: 0, max: 120}
})

# Array schemas
small_array_schema = Schema.new(%{
  tags: %{
    type: {:array, %{type: :string, max_length: 20}},
    max_items: 5
  }
})

medium_array_schema = Schema.new(%{
  items: %{
    type: {:array, %{type: :integer, min: 0}},
    max_items: 50
  }
})

large_array_schema = Schema.new(%{
  data: %{
    type: {:array, %{type: :integer}},
    max_items: 500
  }
})

# Nested object schemas
address_schema = Schema.new(%{
  street: %{type: :string, required: true},
  city: %{type: :string, required: true},
  zip: %{type: :string, required: true, pattern: ~r/^\d{5}$/}
})

nested_1_level = Schema.new(%{
  name: %{type: :string, required: true},
  address: %{type: {:object, address_schema}, required: true}
})

company_schema = Schema.new(%{
  name: %{type: :string, required: true},
  address: %{type: {:object, address_schema}, required: true}
})

nested_3_levels = Schema.new(%{
  name: %{type: :string, required: true},
  company: %{type: {:object, company_schema}, required: true}
})

location_schema = Schema.new(%{
  city: %{type: :string, required: true},
  country: %{type: :string, required: true}
})

office_schema = Schema.new(%{
  name: %{type: :string, required: true},
  location: %{type: {:object, location_schema}, required: true}
})

branch_schema = Schema.new(%{
  office: %{type: {:object, office_schema}, required: true}
})

org_schema = Schema.new(%{
  branch: %{type: {:object, branch_schema}, required: true}
})

nested_5_levels = Schema.new(%{
  organization: %{type: {:object, org_schema}, required: true}
})

# Union type schema
union_schema = Schema.new(%{
  value: %{
    type: {:union, [
      %{type: :string, max_length: 50},
      %{type: :integer, min: 0}
    ]},
    required: true
  }
})

# Test data
simple_string_data = %{"name" => "Alice"}
simple_integer_data = %{"count" => 42}
simple_boolean_data = %{"active" => true}

constrained_string_data = %{"username" => "alice_123"}
constrained_integer_data = %{"age" => 30}

small_array_data = %{"tags" => ["elixir", "phoenix", "llm"]}
medium_array_data = %{"items" => Enum.to_list(1..50)}
large_array_data = %{"data" => Enum.to_list(1..500)}

nested_1_data = %{
  "name" => "Alice",
  "address" => %{
    "street" => "123 Main St",
    "city" => "Springfield",
    "zip" => "12345"
  }
}

nested_3_data = %{
  "name" => "Alice",
  "company" => %{
    "name" => "Acme Corp",
    "address" => %{
      "street" => "456 Corp Blvd",
      "city" => "Business City",
      "zip" => "54321"
    }
  }
}

nested_5_data = %{
  "organization" => %{
    "branch" => %{
      "office" => %{
        "name" => "HQ",
        "location" => %{
          "city" => "New York",
          "country" => "USA"
        }
      }
    }
  }
}

union_string_data = %{"value" => "hello"}
union_integer_data = %{"value" => 42}

IO.puts("Running benchmarks...")
IO.puts("")

Benchee.run(
  %{
    # Simple type validation
    "simple string validation" => fn ->
      Spec.validate(simple_string_schema, simple_string_data)
    end,
    "simple integer validation" => fn ->
      Spec.validate(simple_integer_schema, simple_integer_data)
    end,
    "simple boolean validation" => fn ->
      Spec.validate(simple_boolean_schema, simple_boolean_data)
    end,

    # Constrained validation
    "constrained string validation" => fn ->
      Spec.validate(constrained_string_schema, constrained_string_data)
    end,
    "constrained integer validation" => fn ->
      Spec.validate(constrained_integer_schema, constrained_integer_data)
    end,

    # Array validation
    "small array (5 items)" => fn ->
      Spec.validate(small_array_schema, small_array_data)
    end,
    "medium array (50 items)" => fn ->
      Spec.validate(medium_array_schema, medium_array_data)
    end,
    "large array (500 items)" => fn ->
      Spec.validate(large_array_schema, large_array_data)
    end,

    # Nested object validation
    "nested 1 level" => fn ->
      Spec.validate(nested_1_level, nested_1_data)
    end,
    "nested 3 levels" => fn ->
      Spec.validate(nested_3_levels, nested_3_data)
    end,
    "nested 5 levels" => fn ->
      Spec.validate(nested_5_levels, nested_5_data)
    end,

    # Union type validation
    "union type (string match)" => fn ->
      Spec.validate(union_schema, union_string_data)
    end,
    "union type (integer match)" => fn ->
      Spec.validate(union_schema, union_integer_data)
    end
  },
  time: 5,
  memory_time: 2,
  warmup: 2,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "benchmarks/output/schema_validation.html"}
  ],
  print: [
    fast_warning: false
  ]
)

IO.puts("")
IO.puts("✓ Benchmark complete!")
IO.puts("  HTML report: benchmarks/output/schema_validation.html")
