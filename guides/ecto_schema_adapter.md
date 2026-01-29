# Ecto Schema Adapter Guide

The Ecto Schema Adapter allows you to reuse existing Ecto schemas with ExOutlines, eliminating the need for duplicate schema definitions.

## Overview

When you already have Ecto schemas defined for your database models, you can automatically convert them to ExOutlines schemas using `ExOutlines.Ecto.from_ecto_schema/2`. This provides:

- **Zero duplication** - Reuse existing schema definitions
- **Automatic validation extraction** - Pull validation rules from changesets
- **Type safety** - Leverage Ecto's type system
- **Seamless integration** - Works with all ExOutlines features

## Basic Usage

### Simple Conversion

```elixir
defmodule MyApp.User do
  use Ecto.Schema

  schema "users" do
    field :email, :string
    field :age, :integer
    field :active, :boolean
  end
end

# Convert to ExOutlines schema
alias ExOutlines.Ecto
schema = Ecto.from_ecto_schema(MyApp.User)

# Use with generate/2
ExOutlines.generate(schema,
  backend: MyBackend,
  backend_opts: [...]
)
```

### With Changeset Validations

The adapter can extract validation rules from your changeset functions:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :age, :integer
    field :bio, :string
  end

  def changeset(user, params) do
    user
    |> cast(params, [:email, :username, :age, :bio])
    |> validate_required([:email, :username])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:username, min: 3, max: 20)
    |> validate_number(:age, greater_than: 0, less_than: 150)
    |> validate_length(:bio, max: 500)
  end
end

# Conversion automatically extracts validation rules
schema = Ecto.from_ecto_schema(MyApp.User)

# Resulting schema has:
# - email: required, pattern: ~r/@/
# - username: required, min_length: 3, max_length: 20
# - age: min: 1, max: 149
# - bio: max_length: 500
```

## Supported Ecto Types

The adapter maps Ecto types to ExOutlines types:

| Ecto Type | ExOutlines Type | Notes |
|-----------|----------------|-------|
| `:string` | `:string` | Direct mapping |
| `:integer` | `:integer` | Direct mapping |
| `:boolean` | `:boolean` | Direct mapping |
| `:float`, `:decimal` | `:number` | Numeric types |
| `{:array, type}` | `{:array, spec}` | Arrays of any type |
| `Ecto.Enum` | `{:enum, values}` | Enum values extracted |
| Embedded schema | `{:object, schema}` | Nested objects |
| Custom types | `:string` | Fallback with description |

## Advanced Features

### Custom Changeset Functions

Specify a different changeset function:

```elixir
defmodule User do
  def registration_changeset(user, params) do
    # Different validation rules
  end
end

schema = Ecto.from_ecto_schema(User,
  changeset: :registration_changeset
)
```

### Explicit Required Fields

Override required field detection:

```elixir
schema = Ecto.from_ecto_schema(User,
  required: [:email, :username, :age]
)
```

### Field Descriptions

Add descriptions for better LLM guidance:

```elixir
schema = Ecto.from_ecto_schema(User,
  descriptions: %{
    email: "User's email address for authentication",
    username: "Unique username for display (3-20 characters)",
    age: "User's age in years (must be 0-150)",
    bio: "Short biography (max 500 characters)"
  }
)
```

## Embedded Schemas

The adapter handles embedded schemas automatically:

```elixir
defmodule User do
  use Ecto.Schema

  defmodule Address do
    use Ecto.Schema

    embedded_schema do
      field :street, :string
      field :city, :string
      field :zip, :string
    end
  end

  schema "users" do
    field :name, :string
    embeds_one :address, Address
    embeds_many :phone_numbers, PhoneNumber
  end
end

# Conversion includes nested schemas
schema = Ecto.from_ecto_schema(User)

# address field becomes {:object, nested_schema}
# phone_numbers becomes {:array, {:object, nested_schema}}
```

## Ecto.Enum Support

Enum fields are converted to ExOutlines enum types:

```elixir
defmodule User do
  use Ecto.Schema

  schema "users" do
    field :role, Ecto.Enum, values: [:admin, :user, :guest]
    field :status, Ecto.Enum, values: [:active, :inactive]
  end
end

schema = Ecto.from_ecto_schema(User)

# role becomes {:enum, [:admin, :user, :guest]}
# status becomes {:enum, [:active, :inactive]}
```

## Integration Patterns

### Pattern 1: Direct Generation

```elixir
defmodule MyApp.AIService do
  alias ExOutlines.{Ecto, Backend.Anthropic}

  def generate_user(prompt) do
    schema = Ecto.from_ecto_schema(MyApp.User)

    ExOutlines.generate(schema,
      backend: Anthropic,
      backend_opts: [
        api_key: System.get_env("ANTHROPIC_API_KEY")
      ],
      prompt: prompt
    )
  end
end
```

### Pattern 2: Generation + Database Insert

```elixir
defmodule MyApp.UserService do
  alias MyApp.{User, Repo}
  alias ExOutlines.Ecto

  def create_from_ai(prompt) do
    schema = Ecto.from_ecto_schema(User)

    with {:ok, user_data} <- ExOutlines.generate(schema, ...),
         {:ok, user} <- create_user(user_data) do
      {:ok, user}
    end
  end

  defp create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```

### Pattern 3: Cached Schema Conversion

```elixir
defmodule MyApp.Schemas do
  alias ExOutlines.Ecto

  def user_schema do
    # Cache the converted schema
    :persistent_term.get({__MODULE__, :user}, fn ->
      schema = Ecto.from_ecto_schema(MyApp.User)
      :persistent_term.put({__MODULE__, :user}, schema)
      schema
    end)
  end
end
```

## Validation Extraction

The adapter extracts these validations from changesets:

### Required Fields

```elixir
|> validate_required([:email, :name])
# → fields marked as required: true
```

### Length Constraints

```elixir
|> validate_length(:username, min: 3, max: 20)
# → min_length: 3, max_length: 20

|> validate_length(:bio, max: 500)
# → max_length: 500
```

### Number Constraints

```elixir
|> validate_number(:age, greater_than: 0)
# → min: 1

|> validate_number(:age, greater_than_or_equal_to: 0)
# → min: 0

|> validate_number(:age, less_than: 150)
# → max: 149

|> validate_number(:age, less_than_or_equal_to: 150)
# → max: 150
```

### Format Constraints

```elixir
|> validate_format(:email, ~r/@/)
# → pattern: ~r/@/
```

### Inclusion (Enum) Constraints

```elixir
|> validate_inclusion(:status, ["active", "inactive"])
# → type: {:enum, ["active", "inactive"]}
```

## Limitations

### Not Extracted

The following validations are NOT automatically extracted:

- Custom validations
- Database-level constraints (unique, foreign keys)
- `validate_acceptance/3`
- `validate_confirmation/3`
- `validate_exclusion/3`
- `validate_subset/3`
- Complex conditional validations

For these cases, either:
1. Add explicit constraints to the converted schema
2. Use changeset validation for database operations
3. Define a separate ExOutlines schema with full control

### Schema Definition Requirements

- Must be an Ecto schema (with `use Ecto.Schema`)
- Changeset function must accept 2 arguments: `(struct, params)`
- Validations must be in the main changeset function

## Best Practices

### 1. Use Descriptive Field Names

```elixir
# Good
field :email_address, :string

# Less clear
field :em, :string
```

### 2. Add Descriptions for LLM Guidance

```elixir
schema = Ecto.from_ecto_schema(User,
  descriptions: %{
    age: "Age in years (must be positive, typically 0-120)"
  }
)
```

### 3. Keep Changesets Simple

For best extraction results, keep validation logic straightforward:

```elixir
# Good - clear validation rules
def changeset(user, params) do
  user
  |> cast(params, [:email, :age])
  |> validate_required([:email])
  |> validate_number(:age, greater_than: 0)
end

# Complex - harder to extract
def changeset(user, params) do
  if user.admin? do
    # conditional validation
  end
end
```

### 4. Cache Schema Conversion

Convert schemas once and reuse:

```elixir
@user_schema Ecto.from_ecto_schema(User)

def generate_user do
  ExOutlines.generate(@user_schema, ...)
end
```

### 5. Combine with Manual Adjustments

```elixir
base_schema = Ecto.from_ecto_schema(User)

# Add custom constraints not in changeset
enhanced_schema = %{base_schema |
  fields: Map.update!(base_schema.fields, :bio, fn spec ->
    Map.put(spec, :min_length, 10)
  end)
}
```

## Troubleshooting

### Schema Not Recognized

**Error:** `ArgumentError: module is not an Ecto schema`

**Solution:** Ensure the module uses `Ecto.Schema`:

```elixir
defmodule User do
  use Ecto.Schema  # Required

  schema "users" do
    # ...
  end
end
```

### Validations Not Extracted

**Issue:** Converted schema doesn't include expected validations

**Solutions:**
1. Check changeset function is named correctly (default: `:changeset`)
2. Specify custom function: `changeset: :custom_changeset`
3. Ensure validations are in the main changeset function
4. Add explicit required: `required: [:field1, :field2]`

### Type Conversion Issues

**Issue:** Ecto type not supported

**Solution:** The adapter falls back to `:string` with a description. You can:

1. Cast to a supported type in Ecto
2. Manually adjust the converted schema
3. Define a custom ExOutlines schema for that field

## Examples

See `examples/ecto_schema_adapter.exs` for a complete working example.

## Further Reading

- [Ecto Schema Documentation](https://hexdocs.pm/ecto/Ecto.Schema.html)
- [Ecto Changeset Documentation](https://hexdocs.pm/ecto/Ecto.Changeset.html)
- [ExOutlines Schema Guide](schema_patterns.md)
- [Phoenix Integration Guide](phoenix_integration.md)
