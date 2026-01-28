# Ecto Integration Analysis for ExOutlines Schema DSL

## Executive Summary

**Recommendation: Hybrid approach** - Use Ecto.Changeset for validation, keep current DSL for schema definition, add optional Ecto schema support.

**Key Benefits:**
- Leverage battle-tested validation logic
- Add powerful constraint system (length, format, number ranges)
- Keep zero-dependency core option
- Maintain current API compatibility

---

## 1. Current Implementation Analysis

### What We Have

```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true, description: "User's full name"},
  age: %{type: :integer, required: true, positive: true},
  role: %{type: {:enum, ["admin", "user"]}, required: false}
})
```

**Strengths:**
- Simple, explicit API
- No dependencies beyond Jason/Telemetry
- Full control over validation logic
- Direct JSON Schema generation
- Maps cleanly to JSON Schema spec

**Limitations:**
- Custom validation logic (maintenance burden)
- Limited constraint types (only positive integer)
- No string format validation (email, URL, etc.)
- No numeric ranges (min/max)
- No string length constraints
- No pattern matching (regex)
- Manual type coercion

---

## 2. What Ecto Provides

### Ecto.Schema

Defines data structures with types:

```elixir
defmodule User do
  use Ecto.Schema

  embedded_schema do
    field :name, :string
    field :age, :integer
    field :email, :string
    field :role, Ecto.Enum, values: [:admin, :user]
    field :active, :boolean, default: false
  end
end
```

**Pros:**
- Familiar to Elixir developers
- Type system built-in
- Enum support via `Ecto.Enum`
- Default values
- Virtual fields
- Embedded schemas (nested objects)

**Cons:**
- Requires module definition per schema (not data-driven)
- More boilerplate than our current API
- Tied to Ecto dependency
- Less flexible for dynamic schemas

### Ecto.Changeset

Powerful validation and casting:

```elixir
def changeset(params) do
  %User{}
  |> cast(params, [:name, :age, :email, :role, :active])
  |> validate_required([:name, :age, :email])
  |> validate_number(:age, greater_than: 0, less_than: 150)
  |> validate_length(:name, min: 1, max: 100)
  |> validate_format(:email, ~r/@/)
  |> validate_inclusion(:role, [:admin, :user])
end
```

**Pros:**
- Rich validation functions out-of-the-box
- Type casting/coercion
- Composable validations
- Error accumulation (like our Diagnostics)
- Well-tested (10+ years of production use)
- Extensive built-in validators:
  - `validate_required/3`
  - `validate_length/3` (min, max, is)
  - `validate_number/3` (greater_than, less_than, equal_to, etc.)
  - `validate_format/3` (regex patterns)
  - `validate_inclusion/3` (enum)
  - `validate_exclusion/3`
  - `validate_acceptance/3`
  - `validate_confirmation/3`
  - `validate_change/3` (custom)

**Cons:**
- Requires Ecto dependency (~2MB)
- API differs from our current design
- More verbose for simple cases
- Changeset errors format differs from our Diagnostics

---

## 3. Integration Strategies

### Option A: Full Ecto Replacement

Replace our Schema with Ecto schemas + changesets.

**Before (current):**
```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true},
  age: %{type: :integer, positive: true}
})

Spec.validate(schema, input)
```

**After (full Ecto):**
```elixir
defmodule MySchema do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :age, :integer
  end

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, [:name, :age])
    |> validate_required([:name, :age])
    |> validate_number(:age, greater_than: 0)
  end
end

Spec.validate(MySchema, input)
```

**Pros:**
- Full Ecto power
- Familiar to Elixir developers
- Built-in type coercion
- Extensive validation library

**Cons:**
- 🔴 MAJOR: Requires module definition (not data-driven)
- 🔴 Breaking change to API
- 🔴 Forces Ecto dependency on all users
- Verbose for simple schemas
- Loses our simple DSL

**Verdict: ❌ Rejected** - Breaks core design principles (data-driven, zero dependencies)

---

### Option B: Hybrid with Ecto.Changeset Only

Keep our Schema DSL, use Ecto.Changeset internally for validation.

**API stays the same:**
```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true, length: [min: 1, max: 100]},
  age: %{type: :integer, required: true, greater_than: 0, less_than: 150},
  email: %{type: :string, required: true, format: ~r/@/}
})

Spec.validate(schema, input)  # Same API
```

**Implementation:**
```elixir
defimpl ExOutlines.Spec do
  def validate(%Schema{fields: fields}, value) do
    # Convert our Schema to Changeset
    types = build_types_map(fields)
    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(value, Map.keys(types))
      |> apply_validations(fields)

    case changeset do
      %{valid?: true} -> {:ok, Ecto.Changeset.apply_changes(changeset)}
      %{valid?: false} -> {:error, changeset_to_diagnostics(changeset)}
    end
  end
end
```

**Pros:**
- ✅ Keep our simple DSL API
- ✅ Leverage Ecto's validation logic
- ✅ Add powerful constraints (length, format, ranges)
- ✅ Type coercion built-in
- ✅ Battle-tested validation
- ✅ Can extend with custom validators

**Cons:**
- ⚠️ Adds Ecto dependency (~2MB, but optional)
- ⚠️ Need to map Changeset errors to Diagnostics
- ⚠️ Learning curve for contributors
- ⚠️ Slightly slower than pure validation

**Verdict: ✅ Strong candidate** - Best balance of power and simplicity

---

### Option C: Optional Ecto Schema Support

Add optional support for Ecto schemas alongside our DSL.

**Both APIs work:**
```elixir
# Current DSL (zero dependencies)
schema1 = Schema.new(%{name: %{type: :string, required: true}})

# Ecto schema (requires Ecto)
defmodule MySchema do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
  end

  def changeset(params), do: ...
end

schema2 = Schema.from_ecto_schema(MySchema)
```

**Implementation:**
```elixir
defmodule ExOutlines.Spec.Schema do
  # Existing implementation...

  @doc """
  Create schema from Ecto schema module.
  Requires Ecto to be available.
  """
  if Code.ensure_loaded?(Ecto) do
    def from_ecto_schema(module) do
      # Introspect Ecto schema
      # Convert to our Schema format
    end
  end
end
```

**Pros:**
- ✅ Backward compatible
- ✅ Users choose dependency
- ✅ Best of both worlds
- ✅ Gradual migration path

**Cons:**
- ⚠️ Two code paths to maintain
- ⚠️ More complex implementation
- ⚠️ Need to document both approaches

**Verdict: ✅ Good for v0.2+** - Allows choice, maintains compatibility

---

### Option D: Ecto-Inspired DSL (No Dependency)

Copy Ecto's validation API patterns without the dependency.

```elixir
schema = Schema.new(%{
  name: %{type: :string, required: true},
  age: %{type: :integer, required: true}
})
|> Schema.validate_length(:name, min: 1, max: 100)
|> Schema.validate_number(:age, greater_than: 0, less_than: 150)
|> Schema.validate_format(:email, ~r/@/)
```

**Pros:**
- ✅ Familiar API (Ecto-like)
- ✅ Zero dependencies
- ✅ Composable validations
- ✅ Full control

**Cons:**
- 🔴 Reimplementing Ecto (why?)
- 🔴 Maintenance burden
- 🔴 Not battle-tested
- 🔴 Likely buggier than Ecto

**Verdict: ❌ Rejected** - Reinventing the wheel poorly

---

## 4. Detailed Comparison

### Feature Matrix

| Feature | Current | Option A (Full Ecto) | Option B (Hybrid) | Option C (Optional) | Option D (Copy) |
|---------|---------|---------------------|-------------------|-------------------|-----------------|
| Zero dependencies | ✅ | ❌ | ❌ (opt) | ✅ | ✅ |
| Data-driven schemas | ✅ | ❌ | ✅ | ✅ | ✅ |
| Simple API | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| Type coercion | ⚠️ | ✅ | ✅ | ✅ | ⚠️ |
| Rich validators | ❌ | ✅ | ✅ | ✅ | ⚠️ |
| String length | ❌ | ✅ | ✅ | ✅ | ⚠️ |
| Regex patterns | ❌ | ✅ | ✅ | ✅ | ⚠️ |
| Number ranges | ❌ | ✅ | ✅ | ✅ | ⚠️ |
| Nested schemas | ❌ | ✅ | ⚠️ | ✅ | ❌ |
| Battle-tested | ⚠️ | ✅ | ✅ | ✅ | ❌ |
| Maintenance | ✅ | ✅ | ✅ | ⚠️ | 🔴 |

---

## 5. Recommended Approach

### Phase 1 (v0.1 - Current): Ship as-is

Keep current implementation:
- Zero dependencies
- Simple, working solution
- Complete for MVP
- No breaking changes needed

**Action: None** - Current implementation is good for v0.1

---

### Phase 2 (v0.2): Add Hybrid Ecto Support

Implement **Option B (Hybrid)** with optional dependency:

```elixir
# mix.exs
defp deps do
  [
    {:jason, "~> 1.4"},
    {:telemetry, "~> 1.2"},
    {:ecto, "~> 3.11", optional: true}  # ← Optional
  ]
end
```

**Enhanced Schema DSL:**
```elixir
schema = Schema.new(%{
  # Basic types (v0.1)
  name: %{type: :string, required: true},

  # Enhanced with Ecto-powered constraints (v0.2)
  email: %{
    type: :string,
    required: true,
    format: ~r/^[^\s]+@[^\s]+$/,  # Email pattern
    length: [min: 5, max: 255]
  },

  age: %{
    type: :integer,
    required: true,
    number: [greater_than: 0, less_than: 150]
  },

  bio: %{
    type: :string,
    length: [max: 500]
  }
})
```

**Implementation strategy:**

1. **Keep current validation as default** (no Ecto)
2. **Add Ecto validations when available**:

```elixir
defmodule ExOutlines.Spec.Schema do
  # Current implementation for basic types

  defp apply_extended_validations(value, field_spec) do
    if ecto_available?() do
      apply_ecto_validations(value, field_spec)
    else
      apply_basic_validations(value, field_spec)
    end
  end

  if Code.ensure_loaded?(Ecto.Changeset) do
    defp apply_ecto_validations(changeset, field, spec) do
      changeset
      |> maybe_validate_length(field, spec)
      |> maybe_validate_format(field, spec)
      |> maybe_validate_number(field, spec)
    end

    defp maybe_validate_length(changeset, field, %{length: opts}) do
      Ecto.Changeset.validate_length(changeset, field, opts)
    end
    defp maybe_validate_length(changeset, _field, _spec), do: changeset
  else
    defp apply_ecto_validations(value, _spec), do: value
  end
end
```

**Benefits:**
- ✅ Backward compatible (works without Ecto)
- ✅ Enhanced validation for users with Ecto
- ✅ Gradual adoption path
- ✅ Leverages ecosystem
- ✅ Still simple for basic use cases

---

### Phase 3 (v0.3+): Add Ecto Schema Adapter

Implement **Option C (Optional)** for advanced users:

```elixir
# For users who already have Ecto schemas
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :age, :integer
    field :email, :string
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :age, :email])
    |> validate_required([:name, :email])
    |> validate_number(:age, greater_than: 0)
  end
end

# Use with ExOutlines
schema = Schema.from_ecto_schema(MyApp.User)
Spec.validate(schema, input)
```

**Benefits:**
- ✅ Reuse existing Ecto schemas
- ✅ No duplication for Ecto users
- ✅ Full Ecto power for advanced use cases

---

## 6. Concrete Example Comparison

### Current (v0.1)

```elixir
schema = Schema.new(%{
  username: %{type: :string, required: true},
  age: %{type: :integer, required: true, positive: true},
  role: %{type: {:enum, ["admin", "user"]}, required: false}
})

# ✅ Simple, clear
# ❌ No length validation
# ❌ No format validation
# ❌ No number ranges
```

### Hybrid Approach (v0.2 - Recommended)

```elixir
schema = Schema.new(%{
  username: %{
    type: :string,
    required: true,
    length: [min: 3, max: 20],           # ← New with Ecto
    format: ~r/^[a-zA-Z0-9_]+$/          # ← New with Ecto
  },
  email: %{
    type: :string,
    required: true,
    format: ~r/@/,                        # ← New with Ecto
    length: [max: 255]                    # ← New with Ecto
  },
  age: %{
    type: :integer,
    required: true,
    number: [greater_than: 0, less_than: 150]  # ← Enhanced from just "positive"
  },
  role: %{
    type: {:enum, ["admin", "user"]},
    required: false
  }
})

# ✅ Same simple API
# ✅ Powerful validation when Ecto available
# ✅ Graceful degradation without Ecto
```

### Validation Behavior

```elixir
# Without Ecto dependency
Spec.validate(schema, %{"username" => "ab", "age" => 5})
# => {:ok, %{username: "ab", age: 5}}  # length/range ignored

# With Ecto dependency
Spec.validate(schema, %{"username" => "ab", "age" => 5})
# => {:error, %Diagnostics{
#   errors: [
#     %{field: "username", expected: "length >= 3", ...},
#     %{field: "email", expected: "required field", ...}
#   ]
# }}
```

---

## 7. Implementation Roadmap

### v0.1 (Current) - Ship It
- ✅ Current implementation is solid
- ✅ Zero dependencies
- ✅ Meets MVP requirements
- ⏭️ No changes needed

### v0.2 - Add Ecto Support
1. Make Ecto optional dependency
2. Add extended validation DSL fields:
   - `length: [min: x, max: y]`
   - `format: regex`
   - `number: [greater_than: x, less_than: y, ...]`
3. Implement hybrid validation (Ecto when available)
4. Map Changeset errors to Diagnostics
5. Update tests for both modes
6. Document Ecto-enhanced features

**Estimated effort:** ~2-3 days

### v0.3 - Add Ecto Schema Adapter
1. Add `Schema.from_ecto_schema/1`
2. Introspect Ecto schema definitions
3. Convert to ExOutlines Schema format
4. Support custom changeset functions
5. Document integration patterns

**Estimated effort:** ~1-2 days

---

## 8. Pros/Cons Summary

### Keep Current (v0.1)
**Pros:**
- ✅ Zero dependencies
- ✅ Full control
- ✅ Simple implementation
- ✅ Works for MVP

**Cons:**
- ❌ Limited constraint types
- ❌ Need to implement new validators manually
- ❌ Missing common validations (length, format, ranges)

### Add Hybrid Ecto (v0.2 - Recommended)
**Pros:**
- ✅ Optional dependency (users choose)
- ✅ Leverage battle-tested validators
- ✅ Rich constraint system
- ✅ Backward compatible
- ✅ Same simple API
- ✅ Graceful degradation

**Cons:**
- ⚠️ Adds ~2MB dependency (when opted in)
- ⚠️ Need to map error formats
- ⚠️ Slightly more complex implementation

### Verdict
**Recommended: Hybrid approach for v0.2**
- Keep v0.1 as-is (zero dependencies)
- Add optional Ecto support in v0.2
- Add Ecto schema adapter in v0.3

---

## 9. Code Size Comparison

### Current implementation
- ~370 lines (schema.ex)
- ~100 lines validation logic

### Hybrid with Ecto
- ~450 lines total (+80 lines)
- Ecto handles complex validation
- Net reduction in future validator code

### Full Ecto replacement
- ~200 lines (simpler, but...)
- 🔴 Requires module-per-schema
- 🔴 Breaking API change

---

## 10. Final Recommendation

### For v0.1 (NOW)
**Keep current implementation - SHIP IT**

Reasons:
- Works perfectly for MVP
- Zero dependencies
- Simple and maintainable
- No blockers

### For v0.2 (FUTURE)
**Add optional Ecto.Changeset support**

Implementation:
```elixir
# mix.exs
{:ecto, "~> 3.11", optional: true}

# Enhanced DSL
schema = Schema.new(%{
  email: %{
    type: :string,
    required: true,
    format: ~r/@/,      # Requires Ecto
    length: [max: 255]  # Requires Ecto
  }
})
```

Benefits:
- Users without Ecto: works as before
- Users with Ecto: enhanced validation
- No breaking changes
- Best of both worlds

### For v0.3 (FUTURE)
**Add Ecto schema adapter**

Allows reuse of existing Ecto schemas:
```elixir
schema = Schema.from_ecto_schema(MyExistingSchema)
```

---

## Conclusion

**Decision: Proceed with current implementation for v0.1, plan Ecto integration for v0.2**

The current zero-dependency implementation is solid for MVP. Adding optional Ecto support in v0.2 provides the best balance of:
- Simplicity (keep our DSL)
- Power (leverage Ecto's validators)
- Flexibility (users choose dependency)
- Compatibility (no breaking changes)

The hybrid approach respects both "zero dependencies" and "battle-tested validation" principles, letting users decide based on their needs.
