defmodule ExOutlines.Spec.SchemaTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Diagnostics, Spec}
  alias ExOutlines.Spec.Schema

  doctest ExOutlines.Spec.Schema

  describe "new/1" do
    test "creates schema with field specifications" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: false}
        })

      assert %Schema{fields: fields} = schema
      assert Map.has_key?(fields, :name)
      assert Map.has_key?(fields, :age)
    end

    test "normalizes field specs with defaults" do
      schema = Schema.new(%{name: %{type: :string}})

      assert schema.fields.name.type == :string
      assert schema.fields.name.required == false
      assert schema.fields.name.positive == false
      assert is_nil(schema.fields.name.description)
    end

    test "preserves all field spec options" do
      schema =
        Schema.new(%{
          age: %{type: :integer, required: true, positive: true, description: "User age"}
        })

      field = schema.fields.age
      assert field.type == :integer
      assert field.required == true
      assert field.positive == true
      assert field.description == "User age"
    end
  end

  describe "add_field/4" do
    test "adds field to empty schema" do
      schema = Schema.new(%{})
      schema = Schema.add_field(schema, :name, :string, required: true)

      assert Map.has_key?(schema.fields, :name)
      assert schema.fields.name.type == :string
      assert schema.fields.name.required == true
    end

    test "adds field with all options" do
      schema = Schema.new(%{})

      schema =
        Schema.add_field(schema, :age, :integer,
          required: true,
          positive: true,
          description: "User's age"
        )

      field = schema.fields.age
      assert field.type == :integer
      assert field.required == true
      assert field.positive == true
      assert field.description == "User's age"
    end

    test "adds multiple fields" do
      schema =
        Schema.new(%{})
        |> Schema.add_field(:name, :string, required: true)
        |> Schema.add_field(:age, :integer, positive: true)
        |> Schema.add_field(:active, :boolean)

      assert map_size(schema.fields) == 3
      assert Map.has_key?(schema.fields, :name)
      assert Map.has_key?(schema.fields, :age)
      assert Map.has_key?(schema.fields, :active)
    end
  end

  describe "required_fields/1" do
    test "returns empty list for schema with no required fields" do
      schema = Schema.new(%{name: %{type: :string}})
      assert Schema.required_fields(schema) == []
    end

    test "returns list of required field names" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: false},
          email: %{type: :string, required: true}
        })

      assert Schema.required_fields(schema) == [:email, :name]
    end

    test "returns sorted field names" do
      schema =
        Schema.new(%{
          z_field: %{type: :string, required: true},
          a_field: %{type: :string, required: true},
          m_field: %{type: :string, required: true}
        })

      assert Schema.required_fields(schema) == [:a_field, :m_field, :z_field]
    end
  end

  describe "to_schema/1 - JSON Schema generation" do
    test "generates basic JSON schema" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      json_schema = Spec.to_schema(schema)

      assert json_schema.type == "object"
      assert json_schema.properties.name.type == "string"
      assert json_schema.required == ["name"]
    end

    test "generates schema with multiple fields" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true},
          active: %{type: :boolean, required: false}
        })

      json_schema = Spec.to_schema(schema)

      assert json_schema.properties.name.type == "string"
      assert json_schema.properties.age.type == "integer"
      assert json_schema.properties.active.type == "boolean"
      assert Enum.sort(json_schema.required) == ["age", "name"]
    end

    test "includes field descriptions" do
      schema =
        Schema.new(%{
          name: %{type: :string, description: "User's full name"}
        })

      json_schema = Spec.to_schema(schema)
      assert json_schema.properties.name.description == "User's full name"
    end

    test "generates schema for positive integer" do
      schema = Schema.new(%{age: %{type: :integer, positive: true}})
      json_schema = Spec.to_schema(schema)

      assert json_schema.properties.age.type == "integer"
      assert json_schema.properties.age.minimum == 1
    end

    test "generates schema for enum type" do
      schema = Schema.new(%{role: %{type: {:enum, ["admin", "user", "guest"]}}})
      json_schema = Spec.to_schema(schema)

      assert json_schema.properties.role.enum == ["admin", "user", "guest"]
    end

    test "generates schema for number type" do
      schema = Schema.new(%{score: %{type: :number}})
      json_schema = Spec.to_schema(schema)

      assert json_schema.properties.score.type == "number"
    end

    test "omits required field when no fields are required" do
      schema = Schema.new(%{name: %{type: :string}})
      json_schema = Spec.to_schema(schema)

      refute Map.has_key?(json_schema, :required)
    end

    test "generated schema is JSON encodable" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, positive: true}
        })

      json_schema = Spec.to_schema(schema)
      assert {:ok, _json} = Jason.encode(json_schema)
    end
  end

  describe "validate/2 - string fields" do
    setup do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      {:ok, schema: schema}
    end

    test "accepts valid string value", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"name" => "Alice"})
      assert validated.name == "Alice"
    end

    test "converts string keys to atoms", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"name" => "Alice"})
      assert is_map(validated)
      assert Map.has_key?(validated, :name)
      refute Map.has_key?(validated, "name")
    end

    test "rejects non-string value", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"name" => 123})
      assert Diagnostics.has_errors?(diag)
      assert hd(diag.errors).field == "name"
      assert hd(diag.errors).expected == "string"
    end

    test "rejects missing required field", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{})
      assert Diagnostics.has_errors?(diag)
      assert hd(diag.errors).field == "name"
      assert hd(diag.errors).expected == "required field"
    end
  end

  describe "validate/2 - integer fields" do
    setup do
      schema = Schema.new(%{age: %{type: :integer, required: true}})
      {:ok, schema: schema}
    end

    test "accepts valid integer", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"age" => 30})
      assert validated.age == 30
    end

    test "accepts negative integers", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"age" => -5})
      assert validated.age == -5
    end

    test "accepts zero", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"age" => 0})
      assert validated.age == 0
    end

    test "rejects float values", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"age" => 30.5})
      assert hd(diag.errors).expected == "integer"
    end

    test "rejects string values", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"age" => "30"})
      assert hd(diag.errors).expected == "integer"
    end
  end

  describe "validate/2 - positive integer constraint" do
    setup do
      schema = Schema.new(%{age: %{type: :integer, required: true, positive: true}})
      {:ok, schema: schema}
    end

    test "accepts positive integers", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"age" => 1})
      assert validated.age == 1

      assert {:ok, validated} = Spec.validate(schema, %{"age" => 100})
      assert validated.age == 100
    end

    test "rejects zero", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"age" => 0})
      assert hd(diag.errors).expected == "positive integer (> 0)"
      assert hd(diag.errors).got == 0
    end

    test "rejects negative integers", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"age" => -5})
      assert hd(diag.errors).expected == "positive integer (> 0)"
      assert hd(diag.errors).got == -5
    end

    test "rejects non-integer values", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"age" => "42"})
      assert hd(diag.errors).expected == "positive integer (> 0)"
    end
  end

  describe "validate/2 - boolean fields" do
    setup do
      schema = Schema.new(%{active: %{type: :boolean, required: true}})
      {:ok, schema: schema}
    end

    test "accepts true", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"active" => true})
      assert validated.active == true
    end

    test "accepts false", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"active" => false})
      assert validated.active == false
    end

    test "rejects string boolean values", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"active" => "true"})
      assert hd(diag.errors).expected == "boolean"
    end

    test "rejects integer values", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"active" => 1})
      assert hd(diag.errors).expected == "boolean"
    end
  end

  describe "validate/2 - number fields" do
    setup do
      schema = Schema.new(%{score: %{type: :number, required: true}})
      {:ok, schema: schema}
    end

    test "accepts integers", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"score" => 42})
      assert validated.score == 42
    end

    test "accepts floats", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"score" => 3.14})
      assert validated.score == 3.14
    end

    test "rejects strings", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"score" => "42"})
      assert hd(diag.errors).expected == "number"
    end
  end

  describe "validate/2 - enum fields" do
    setup do
      schema = Schema.new(%{role: %{type: {:enum, ["admin", "user", "guest"]}, required: true}})
      {:ok, schema: schema}
    end

    test "accepts valid enum values", %{schema: schema} do
      assert {:ok, validated} = Spec.validate(schema, %{"role" => "admin"})
      assert validated.role == "admin"

      assert {:ok, validated} = Spec.validate(schema, %{"role" => "user"})
      assert validated.role == "user"

      assert {:ok, validated} = Spec.validate(schema, %{"role" => "guest"})
      assert validated.role == "guest"
    end

    test "rejects invalid enum values", %{schema: schema} do
      assert {:error, diag} = Spec.validate(schema, %{"role" => "superuser"})
      assert hd(diag.errors).field == "role"
      assert hd(diag.errors).expected =~ "admin"
      assert hd(diag.errors).expected =~ "user"
      assert hd(diag.errors).expected =~ "guest"
    end

    test "works with numeric enums" do
      schema = Schema.new(%{status: %{type: {:enum, [1, 2, 3]}, required: true}})

      assert {:ok, validated} = Spec.validate(schema, %{"status" => 2})
      assert validated.status == 2

      assert {:error, diag} = Spec.validate(schema, %{"status" => 5})
      assert hd(diag.errors).expected =~ "[1, 2, 3]"
    end
  end

  describe "validate/2 - optional fields" do
    test "allows missing optional fields" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          nickname: %{type: :string, required: false}
        })

      assert {:ok, validated} = Spec.validate(schema, %{"name" => "Alice"})
      assert validated.name == "Alice"
      refute Map.has_key?(validated, :nickname)
    end

    test "validates optional fields when present" do
      schema = Schema.new(%{nickname: %{type: :string, required: false}})

      assert {:ok, validated} = Spec.validate(schema, %{"nickname" => "Ali"})
      assert validated.nickname == "Ali"

      assert {:error, diag} = Spec.validate(schema, %{"nickname" => 123})
      assert hd(diag.errors).field == "nickname"
    end
  end

  describe "validate/2 - multiple fields" do
    setup do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true},
          email: %{type: :string, required: true},
          active: %{type: :boolean, required: false}
        })

      {:ok, schema: schema}
    end

    test "accepts valid input with all required fields", %{schema: schema} do
      input = %{
        "name" => "Alice",
        "age" => 30,
        "email" => "alice@example.com",
        "active" => true
      }

      assert {:ok, validated} = Spec.validate(schema, input)
      assert validated.name == "Alice"
      assert validated.age == 30
      assert validated.email == "alice@example.com"
      assert validated.active == true
    end

    test "accepts valid input without optional fields", %{schema: schema} do
      input = %{
        "name" => "Bob",
        "age" => 25,
        "email" => "bob@example.com"
      }

      assert {:ok, validated} = Spec.validate(schema, input)
      assert validated.name == "Bob"
      refute Map.has_key?(validated, :active)
    end

    test "collects multiple validation errors", %{schema: schema} do
      input = %{
        "name" => 123,
        "age" => -5,
        "email" => false
      }

      assert {:error, diag} = Spec.validate(schema, input)
      assert Diagnostics.error_count(diag) == 3

      fields = Enum.map(diag.errors, & &1.field)
      assert "name" in fields
      assert "age" in fields
      assert "email" in fields
    end

    test "reports missing required fields", %{schema: schema} do
      input = %{"name" => "Alice"}

      assert {:error, diag} = Spec.validate(schema, input)
      assert Diagnostics.error_count(diag) == 2

      fields = Enum.map(diag.errors, & &1.field)
      assert "age" in fields
      assert "email" in fields
    end
  end

  describe "validate/2 - non-map input" do
    test "rejects non-map values" do
      schema = Schema.new(%{name: %{type: :string}})

      assert {:error, diag} = Spec.validate(schema, "not a map")
      assert Diagnostics.has_errors?(diag)
      assert hd(diag.errors).expected == "object (map)"
    end

    test "rejects lists" do
      schema = Schema.new(%{name: %{type: :string}})

      assert {:error, diag} = Spec.validate(schema, [1, 2, 3])
      assert hd(diag.errors).expected == "object (map)"
    end

    test "rejects nil" do
      schema = Schema.new(%{name: %{type: :string}})

      assert {:error, diag} = Spec.validate(schema, nil)
      assert hd(diag.errors).expected == "object (map)"
    end
  end

  describe "validate/2 - error messages and repair instructions" do
    test "generates clear error messages" do
      schema = Schema.new(%{age: %{type: :integer, positive: true, required: true}})

      assert {:error, diag} = Spec.validate(schema, %{"age" => -5})
      error = hd(diag.errors)

      assert error.message =~ "must be a positive integer"
      assert error.field == "age"
      assert error.expected == "positive integer (> 0)"
      assert error.got == -5
    end

    test "generates repair instructions" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true}
        })

      assert {:error, diag} = Spec.validate(schema, %{})
      assert diag.repair_instructions =~ "name"
      assert diag.repair_instructions =~ "age"
      assert diag.repair_instructions =~ "must be"
    end
  end

  describe "integration - complex schema" do
    test "validates complex user schema" do
      schema =
        Schema.new(%{
          id: %{type: :integer, required: true, positive: true},
          username: %{type: :string, required: true},
          email: %{type: :string, required: true},
          age: %{type: :integer, required: false, positive: true},
          role: %{type: {:enum, ["admin", "user"]}, required: true},
          active: %{type: :boolean, required: false},
          score: %{type: :number, required: false}
        })

      valid_input = %{
        "id" => 1,
        "username" => "alice",
        "email" => "alice@example.com",
        "age" => 30,
        "role" => "admin",
        "active" => true,
        "score" => 95.5
      }

      assert {:ok, validated} = Spec.validate(schema, valid_input)
      assert validated.id == 1
      assert validated.username == "alice"
      assert validated.role == "admin"
      assert validated.score == 95.5
    end

    test "validates with some optional fields missing" do
      schema =
        Schema.new(%{
          id: %{type: :integer, required: true},
          name: %{type: :string, required: true},
          bio: %{type: :string, required: false}
        })

      input = %{"id" => 1, "name" => "Alice"}

      assert {:ok, validated} = Spec.validate(schema, input)
      assert validated.id == 1
      assert validated.name == "Alice"
      refute Map.has_key?(validated, :bio)
    end
  end

  describe "string length constraints" do
    test "validates minimum length" do
      schema = Schema.new(%{username: %{type: :string, required: true, min_length: 3}})

      assert {:ok, result} = Spec.validate(schema, %{"username" => "abc"})
      assert result.username == "abc"

      assert {:ok, result} = Spec.validate(schema, %{"username" => "alice"})
      assert result.username == "alice"
    end

    test "rejects string shorter than minimum length" do
      schema = Schema.new(%{username: %{type: :string, required: true, min_length: 3}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"username" => "ab"})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "username"
      assert error.message =~ "at least 3 characters"
    end

    test "validates maximum length" do
      schema = Schema.new(%{bio: %{type: :string, max_length: 10}})

      assert {:ok, result} = Spec.validate(schema, %{"bio" => "hello"})
      assert result.bio == "hello"

      assert {:ok, result} = Spec.validate(schema, %{"bio" => "1234567890"})
      assert result.bio == "1234567890"
    end

    test "rejects string longer than maximum length" do
      schema = Schema.new(%{bio: %{type: :string, max_length: 10}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"bio" => "12345678901"})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "bio"
      assert error.message =~ "at most 10 characters"
    end

    test "validates length range (min and max)" do
      schema =
        Schema.new(%{username: %{type: :string, required: true, min_length: 3, max_length: 20}})

      # Valid cases
      assert {:ok, _} = Spec.validate(schema, %{"username" => "abc"})
      assert {:ok, _} = Spec.validate(schema, %{"username" => "alice123"})
      assert {:ok, _} = Spec.validate(schema, %{"username" => "12345678901234567890"})

      # Too short
      assert {:error, diag} = Spec.validate(schema, %{"username" => "ab"})
      assert hd(diag.errors).message =~ "at least 3 characters"

      # Too long
      assert {:error, diag} = Spec.validate(schema, %{"username" => "123456789012345678901"})
      assert hd(diag.errors).message =~ "at most 20 characters"
    end

    test "handles empty string with minimum length" do
      schema = Schema.new(%{name: %{type: :string, min_length: 1}})

      assert {:error, diag} = Spec.validate(schema, %{"name" => ""})
      assert hd(diag.errors).message =~ "at least 1"
    end

    test "handles empty string with maximum length (valid)" do
      schema = Schema.new(%{name: %{type: :string, max_length: 10}})

      assert {:ok, result} = Spec.validate(schema, %{"name" => ""})
      assert result.name == ""
    end

    test "counts unicode characters correctly" do
      schema = Schema.new(%{emoji: %{type: :string, min_length: 1, max_length: 5}})

      # Single emoji (1 character, not 4 bytes)
      assert {:ok, result} = Spec.validate(schema, %{"emoji" => "🎉"})
      assert result.emoji == "🎉"

      # Multiple emojis
      assert {:ok, result} = Spec.validate(schema, %{"emoji" => "🎉🚀✨"})
      assert result.emoji == "🎉🚀✨"

      # Too many emojis
      assert {:error, diag} = Spec.validate(schema, %{"emoji" => "🎉🚀✨💡🔥⭐"})
      assert hd(diag.errors).message =~ "at most 5 characters"
    end

    test "length constraint with optional field (not provided)" do
      schema = Schema.new(%{bio: %{type: :string, required: false, max_length: 100}})

      # Not provided is OK
      assert {:ok, result} = Spec.validate(schema, %{})
      refute Map.has_key?(result, :bio)
    end

    test "JSON Schema includes minLength and maxLength" do
      schema =
        Schema.new(%{
          username: %{type: :string, min_length: 3, max_length: 20},
          bio: %{type: :string, max_length: 500}
        })

      json_schema = Spec.to_schema(schema)

      username_schema = json_schema.properties.username
      assert username_schema[:minLength] == 3
      assert username_schema[:maxLength] == 20

      bio_schema = json_schema.properties.bio
      refute Map.has_key?(bio_schema, :minLength)
      assert bio_schema[:maxLength] == 500
    end
  end

  describe "integer min/max constraints" do
    test "validates minimum value" do
      schema = Schema.new(%{age: %{type: :integer, required: true, min: 0}})

      assert {:ok, result} = Spec.validate(schema, %{"age" => 0})
      assert result.age == 0

      assert {:ok, result} = Spec.validate(schema, %{"age" => 50})
      assert result.age == 50

      assert {:ok, result} = Spec.validate(schema, %{"age" => 120})
      assert result.age == 120
    end

    test "rejects integer below minimum" do
      schema = Schema.new(%{age: %{type: :integer, min: 0}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"age" => -1})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "age"
      assert error.message =~ "at least 0"
    end

    test "validates maximum value" do
      schema = Schema.new(%{quantity: %{type: :integer, max: 999}})

      assert {:ok, result} = Spec.validate(schema, %{"quantity" => 1})
      assert result.quantity == 1

      assert {:ok, result} = Spec.validate(schema, %{"quantity" => 999})
      assert result.quantity == 999
    end

    test "rejects integer above maximum" do
      schema = Schema.new(%{quantity: %{type: :integer, max: 999}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"quantity" => 1000})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "quantity"
      assert error.message =~ "at most 999"
    end

    test "validates range (min and max)" do
      schema = Schema.new(%{score: %{type: :integer, required: true, min: 0, max: 100}})

      # Valid cases
      assert {:ok, _} = Spec.validate(schema, %{"score" => 0})
      assert {:ok, _} = Spec.validate(schema, %{"score" => 50})
      assert {:ok, _} = Spec.validate(schema, %{"score" => 100})

      # Below minimum
      assert {:error, diag} = Spec.validate(schema, %{"score" => -1})
      assert hd(diag.errors).message =~ "at least 0"

      # Above maximum
      assert {:error, diag} = Spec.validate(schema, %{"score" => 101})
      assert hd(diag.errors).message =~ "at most 100"
    end

    test "backward compatibility with positive: true" do
      schema = Schema.new(%{count: %{type: :integer, required: true, positive: true}})

      # Still works like before
      assert {:ok, result} = Spec.validate(schema, %{"count" => 1})
      assert result.count == 1

      assert {:ok, result} = Spec.validate(schema, %{"count" => 100})
      assert result.count == 100

      # Rejects 0 and negative - uses old error message format
      assert {:error, diag} = Spec.validate(schema, %{"count" => 0})
      assert hd(diag.errors).message =~ "positive integer"

      assert {:error, diag} = Spec.validate(schema, %{"count" => -5})
      assert hd(diag.errors).message =~ "positive integer"
    end

    test "min value takes precedence over positive: true" do
      schema = Schema.new(%{count: %{type: :integer, positive: true, min: 5}})

      # min: 5 is used, not min: 1 from positive
      assert {:ok, _} = Spec.validate(schema, %{"count" => 5})
      assert {:error, diag} = Spec.validate(schema, %{"count" => 1})
      assert hd(diag.errors).message =~ "at least 5"
    end

    test "handles negative numbers with negative minimum" do
      schema = Schema.new(%{temperature: %{type: :integer, min: -100, max: 100}})

      assert {:ok, result} = Spec.validate(schema, %{"temperature" => -100})
      assert result.temperature == -100

      assert {:ok, result} = Spec.validate(schema, %{"temperature" => -50})
      assert result.temperature == -50

      assert {:error, diag} = Spec.validate(schema, %{"temperature" => -101})
      assert hd(diag.errors).message =~ "at least -100"
    end

    test "value equals min is valid" do
      schema = Schema.new(%{value: %{type: :integer, min: 10}})
      assert {:ok, result} = Spec.validate(schema, %{"value" => 10})
      assert result.value == 10
    end

    test "value equals max is valid" do
      schema = Schema.new(%{value: %{type: :integer, max: 10}})
      assert {:ok, result} = Spec.validate(schema, %{"value" => 10})
      assert result.value == 10
    end

    test "JSON Schema includes minimum and maximum" do
      schema =
        Schema.new(%{
          age: %{type: :integer, min: 0, max: 120},
          count: %{type: :integer, positive: true},
          score: %{type: :integer, max: 100}
        })

      json_schema = Spec.to_schema(schema)

      age_schema = json_schema.properties.age
      assert age_schema[:minimum] == 0
      assert age_schema[:maximum] == 120

      # positive: true generates minimum: 1
      count_schema = json_schema.properties.count
      assert count_schema[:minimum] == 1
      refute Map.has_key?(count_schema, :maximum)

      score_schema = json_schema.properties.score
      refute Map.has_key?(score_schema, :minimum)
      assert score_schema[:maximum] == 100
    end
  end

  describe "number (float) min/max constraints" do
    test "validates minimum value for floats" do
      schema = Schema.new(%{temperature: %{type: :number, min: -273.15}})

      assert {:ok, result} = Spec.validate(schema, %{"temperature" => -273.15})
      assert result.temperature == -273.15

      assert {:ok, result} = Spec.validate(schema, %{"temperature" => 0.0})
      assert result.temperature == 0.0

      assert {:ok, result} = Spec.validate(schema, %{"temperature" => 100.5})
      assert result.temperature == 100.5
    end

    test "rejects number below minimum" do
      schema = Schema.new(%{temperature: %{type: :number, min: -273.15}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"temperature" => -300.0})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "temperature"
      assert error.message =~ "at least -273.15"
    end

    test "validates maximum value for floats" do
      schema = Schema.new(%{percentage: %{type: :number, max: 100.0}})

      assert {:ok, result} = Spec.validate(schema, %{"percentage" => 0.0})
      assert result.percentage == 0.0

      assert {:ok, result} = Spec.validate(schema, %{"percentage" => 99.99})
      assert result.percentage == 99.99

      assert {:ok, result} = Spec.validate(schema, %{"percentage" => 100.0})
      assert result.percentage == 100.0
    end

    test "rejects number above maximum" do
      schema = Schema.new(%{percentage: %{type: :number, max: 100.0}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"percentage" => 100.1})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "percentage"
      assert error.message =~ "at most 100.0"
    end

    test "validates range for floats" do
      schema = Schema.new(%{probability: %{type: :number, min: 0.0, max: 1.0}})

      # Valid cases
      assert {:ok, _} = Spec.validate(schema, %{"probability" => 0.0})
      assert {:ok, _} = Spec.validate(schema, %{"probability" => 0.5})
      assert {:ok, _} = Spec.validate(schema, %{"probability" => 1.0})

      # Out of range
      assert {:error, diag} = Spec.validate(schema, %{"probability" => -0.1})
      assert hd(diag.errors).message =~ "at least 0.0"

      assert {:error, diag} = Spec.validate(schema, %{"probability" => 1.1})
      assert hd(diag.errors).message =~ "at most 1.0"
    end

    test "accepts integers for number type with constraints" do
      schema = Schema.new(%{value: %{type: :number, min: 0, max: 100}})

      # Integers are valid for :number type
      assert {:ok, result} = Spec.validate(schema, %{"value" => 0})
      assert result.value == 0

      assert {:ok, result} = Spec.validate(schema, %{"value" => 50})
      assert result.value == 50
    end

    test "JSON Schema includes minimum and maximum for numbers" do
      schema =
        Schema.new(%{
          temperature: %{type: :number, min: -273.15, max: 1000.0},
          ratio: %{type: :number, min: 0.0}
        })

      json_schema = Spec.to_schema(schema)

      temp_schema = json_schema.properties.temperature
      assert temp_schema[:minimum] == -273.15
      assert temp_schema[:maximum] == 1000.0

      ratio_schema = json_schema.properties.ratio
      assert ratio_schema[:minimum] == 0.0
      refute Map.has_key?(ratio_schema, :maximum)
    end
  end

  describe "array validation" do
    test "validates array of strings" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string}}, required: true}
        })

      assert {:ok, result} = Spec.validate(schema, %{"tags" => ["elixir", "phoenix"]})
      assert result.tags == ["elixir", "phoenix"]
    end

    test "validates empty array" do
      schema = Schema.new(%{tags: %{type: {:array, %{type: :string}}}})

      assert {:ok, result} = Spec.validate(schema, %{"tags" => []})
      assert result.tags == []
    end

    test "validates array of integers" do
      schema =
        Schema.new(%{
          scores: %{type: {:array, %{type: :integer}}}
        })

      assert {:ok, result} = Spec.validate(schema, %{"scores" => [1, 2, 3, 100]})
      assert result.scores == [1, 2, 3, 100]
    end

    test "rejects non-array value" do
      schema = Schema.new(%{tags: %{type: {:array, %{type: :string}}}})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"tags" => "not-an-array"})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "tags"
      assert error.message =~ "must be an array"
    end

    test "validates min_items constraint" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string}}, min_items: 1}
        })

      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["one"]})
      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["one", "two"]})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"tags" => []})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "tags"
      assert error.message =~ "at least 1 item"
    end

    test "validates max_items constraint" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string}}, max_items: 3}
        })

      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["one"]})
      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["one", "two", "three"]})

      assert {:error, %Diagnostics{} = diag} =
               Spec.validate(schema, %{"tags" => ["one", "two", "three", "four"]})

      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "tags"
      assert error.message =~ "at most 3 items"
    end

    test "validates item count range (min and max)" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string}}, min_items: 2, max_items: 5}
        })

      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["one", "two"]})
      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["one", "two", "three"]})
      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["a", "b", "c", "d", "e"]})

      # Too few
      assert {:error, diag} = Spec.validate(schema, %{"tags" => ["one"]})
      assert hd(diag.errors).message =~ "at least 2 items"

      # Too many
      assert {:error, diag} = Spec.validate(schema, %{"tags" => ["a", "b", "c", "d", "e", "f"]})
      assert hd(diag.errors).message =~ "at most 5 items"
    end

    test "validates unique_items constraint" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string}}, unique_items: true}
        })

      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["a", "b", "c"]})

      assert {:error, %Diagnostics{} = diag} = Spec.validate(schema, %{"tags" => ["a", "b", "a"]})
      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "tags"
      assert error.message =~ "unique items"
      assert error.message =~ "duplicate"
    end

    test "validates item types" do
      schema =
        Schema.new(%{
          scores: %{type: {:array, %{type: :integer}}}
        })

      assert {:error, %Diagnostics{} = diag} =
               Spec.validate(schema, %{"scores" => [1, "two", 3]})

      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "scores[1]"
      assert error.message =~ "must be an integer"
    end

    test "validates item constraints (string length)" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string, min_length: 2, max_length: 10}}}
        })

      assert {:ok, _} = Spec.validate(schema, %{"tags" => ["ab", "hello", "1234567890"]})

      # Item too short
      assert {:error, diag} = Spec.validate(schema, %{"tags" => ["a", "hello"]})
      error = hd(diag.errors)
      assert error.field == "tags[0]"
      assert error.message =~ "at least 2 characters"

      # Item too long
      assert {:error, diag} = Spec.validate(schema, %{"tags" => ["hello", "12345678901"]})
      error = hd(diag.errors)
      assert error.field == "tags[1]"
      assert error.message =~ "at most 10 characters"
    end

    test "validates item constraints (integer range)" do
      schema =
        Schema.new(%{
          scores: %{type: {:array, %{type: :integer, min: 0, max: 100}}}
        })

      assert {:ok, _} = Spec.validate(schema, %{"scores" => [0, 50, 100]})

      # Item below minimum
      assert {:error, diag} = Spec.validate(schema, %{"scores" => [50, -1, 75]})
      error = hd(diag.errors)
      assert error.field == "scores[1]"
      assert error.message =~ "at least 0"

      # Item above maximum
      assert {:error, diag} = Spec.validate(schema, %{"scores" => [50, 101, 75]})
      error = hd(diag.errors)
      assert error.field == "scores[1]"
      assert error.message =~ "at most 100"
    end

    test "validates multiple invalid items (collects all errors)" do
      schema =
        Schema.new(%{
          scores: %{type: {:array, %{type: :integer, min: 0, max: 100}}}
        })

      assert {:error, %Diagnostics{} = diag} =
               Spec.validate(schema, %{"scores" => [-1, 50, 150]})

      assert length(diag.errors) == 2
      assert Enum.any?(diag.errors, fn e -> e.field == "scores[0]" end)
      assert Enum.any?(diag.errors, fn e -> e.field == "scores[2]" end)
    end

    test "validates array of enums" do
      schema =
        Schema.new(%{
          categories: %{type: {:array, %{type: {:enum, ["tech", "business", "health"]}}}}
        })

      assert {:ok, _} = Spec.validate(schema, %{"categories" => ["tech", "business"]})

      assert {:error, diag} = Spec.validate(schema, %{"categories" => ["tech", "invalid"]})
      error = hd(diag.errors)
      assert error.field == "categories[1]"
      assert error.message =~ "must be one of"
    end

    test "validates array of booleans" do
      schema =
        Schema.new(%{
          flags: %{type: {:array, %{type: :boolean}}}
        })

      assert {:ok, result} = Spec.validate(schema, %{"flags" => [true, false, true]})
      assert result.flags == [true, false, true]

      assert {:error, diag} = Spec.validate(schema, %{"flags" => [true, "not-bool"]})
      error = hd(diag.errors)
      assert error.field == "flags[1]"
      assert error.message =~ "must be a boolean"
    end

    test "validates array of numbers (floats)" do
      schema =
        Schema.new(%{
          values: %{type: {:array, %{type: :number, min: 0.0, max: 1.0}}}
        })

      assert {:ok, _} = Spec.validate(schema, %{"values" => [0.0, 0.5, 1.0]})

      assert {:error, diag} = Spec.validate(schema, %{"values" => [0.5, 1.5]})
      error = hd(diag.errors)
      assert error.field == "values[1]"
      assert error.message =~ "at most 1.0"
    end

    test "JSON Schema generation for arrays" do
      schema =
        Schema.new(%{
          tags: %{
            type: {:array, %{type: :string, min_length: 2, max_length: 20}},
            min_items: 1,
            max_items: 10,
            unique_items: true
          }
        })

      json_schema = Spec.to_schema(schema)
      array_schema = json_schema.properties.tags

      assert array_schema[:type] == "array"
      assert array_schema[:minItems] == 1
      assert array_schema[:maxItems] == 10
      assert array_schema[:uniqueItems] == true

      items = array_schema[:items]
      assert items[:type] == "string"
      assert items[:minLength] == 2
      assert items[:maxLength] == 20
    end

    test "JSON Schema generation for integer array" do
      schema =
        Schema.new(%{
          scores: %{type: {:array, %{type: :integer, min: 0, max: 100}}}
        })

      json_schema = Spec.to_schema(schema)
      array_schema = json_schema.properties.scores

      assert array_schema[:type] == "array"
      items = array_schema[:items]
      assert items[:type] == "integer"
      assert items[:minimum] == 0
      assert items[:maximum] == 100
    end

    test "optional array field (not provided)" do
      schema =
        Schema.new(%{
          tags: %{type: {:array, %{type: :string}}, required: false}
        })

      assert {:ok, result} = Spec.validate(schema, %{})
      refute Map.has_key?(result, :tags)
    end
  end

  describe "nested object validation" do
    test "validates nested object (1 level)" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true},
          zip_code: %{type: :string, required: true}
        })

      user_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: true}
        })

      input = %{
        "name" => "Alice",
        "address" => %{"city" => "NYC", "zip_code" => "10001"}
      }

      assert {:ok, result} = Spec.validate(user_schema, input)
      assert result.name == "Alice"
      assert result.address.city == "NYC"
      assert result.address.zip_code == "10001"
    end

    test "validates deeply nested objects (3 levels)" do
      location_schema =
        Schema.new(%{
          lat: %{type: :number, required: true},
          lng: %{type: :number, required: true}
        })

      address_schema =
        Schema.new(%{
          street: %{type: :string, required: true},
          location: %{type: {:object, location_schema}, required: true}
        })

      company_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: true}
        })

      input = %{
        "name" => "Acme Corp",
        "address" => %{
          "street" => "123 Main St",
          "location" => %{"lat" => 40.7128, "lng" => -74.0060}
        }
      }

      assert {:ok, result} = Spec.validate(company_schema, input)
      assert result.name == "Acme Corp"
      assert result.address.street == "123 Main St"
      assert result.address.location.lat == 40.7128
      assert result.address.location.lng == -74.0060
    end

    test "error messages include full path" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true},
          zip_code: %{type: :string, required: true, min_length: 5}
        })

      user_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: true}
        })

      input = %{
        "name" => "Alice",
        "address" => %{"zip_code" => "123"}
      }

      assert {:error, %Diagnostics{} = diag} = Spec.validate(user_schema, input)
      errors = diag.errors

      # Should have error for missing city
      assert Enum.any?(errors, fn e -> e.field == "address.city" end)
      missing_city = Enum.find(errors, fn e -> e.field == "address.city" end)
      assert missing_city.message =~ "address.city"

      # Should have error for zip_code too short
      assert Enum.any?(errors, fn e -> e.field == "address.zip_code" end)
      short_zip = Enum.find(errors, fn e -> e.field == "address.zip_code" end)
      assert short_zip.message =~ "address.zip_code"
      assert short_zip.message =~ "at least 5"
    end

    test "handles multiple errors in nested object" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true},
          zip_code: %{type: :string, required: true}
        })

      user_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: true}
        })

      input = %{
        "name" => "Alice",
        "address" => %{}
      }

      assert {:error, %Diagnostics{} = diag} = Spec.validate(user_schema, input)
      assert length(diag.errors) == 2

      fields = Enum.map(diag.errors, & &1.field)
      assert "address.city" in fields
      assert "address.zip_code" in fields
    end

    test "rejects non-map value for nested object" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true}
        })

      user_schema =
        Schema.new(%{
          address: %{type: {:object, address_schema}, required: true}
        })

      assert {:error, %Diagnostics{} = diag} =
               Spec.validate(user_schema, %{"address" => "not-a-map"})

      assert length(diag.errors) == 1
      error = hd(diag.errors)
      assert error.field == "address"
      assert error.message =~ "must be an object"
    end

    test "nested object with array field" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true},
          phone_numbers: %{type: {:array, %{type: :string}}, min_items: 1}
        })

      user_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: true}
        })

      input = %{
        "name" => "Alice",
        "address" => %{
          "city" => "NYC",
          "phone_numbers" => ["555-0100", "555-0200"]
        }
      }

      assert {:ok, result} = Spec.validate(user_schema, input)
      assert result.address.phone_numbers == ["555-0100", "555-0200"]
    end

    test "nested object with constrained strings" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true, min_length: 2, max_length: 50},
          state: %{type: :string, required: true, min_length: 2, max_length: 2}
        })

      user_schema =
        Schema.new(%{
          address: %{type: {:object, address_schema}, required: true}
        })

      # Valid
      assert {:ok, _} =
               Spec.validate(user_schema, %{
                 "address" => %{"city" => "NYC", "state" => "NY"}
               })

      # Invalid - state too long
      assert {:error, diag} =
               Spec.validate(user_schema, %{
                 "address" => %{"city" => "NYC", "state" => "NYY"}
               })

      error = hd(diag.errors)
      assert error.field == "address.state"
      assert error.message =~ "address.state"
      assert error.message =~ "at most 2"
    end

    test "optional nested object (when not provided)" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true}
        })

      user_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: false}
        })

      assert {:ok, result} = Spec.validate(user_schema, %{"name" => "Alice"})
      assert result.name == "Alice"
      refute Map.has_key?(result, :address)
    end

    test "empty nested object validates against schema" do
      address_schema =
        Schema.new(%{
          city: %{type: :string, required: false}
        })

      user_schema =
        Schema.new(%{
          address: %{type: {:object, address_schema}, required: true}
        })

      assert {:ok, result} = Spec.validate(user_schema, %{"address" => %{}})
      assert result.address == %{}
    end

    test "JSON Schema generation for nested objects" do
      address_schema =
        Schema.new(%{
          street: %{type: :string, required: true},
          city: %{type: :string, required: true},
          zip_code: %{type: :string, required: false}
        })

      user_schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          address: %{type: {:object, address_schema}, required: true}
        })

      json_schema = Spec.to_schema(user_schema)

      assert json_schema.type == "object"
      assert json_schema.required == ["address", "name"]

      address_json = json_schema.properties.address
      assert address_json[:type] == "object"
      assert address_json[:properties][:street][:type] == "string"
      assert address_json[:properties][:city][:type] == "string"
      assert address_json[:properties][:zip_code][:type] == "string"
      assert Enum.sort(address_json[:required]) == ["city", "street"]
    end

    test "deeply nested JSON Schema generation" do
      location_schema =
        Schema.new(%{
          lat: %{type: :number, required: true},
          lng: %{type: :number, required: true}
        })

      address_schema =
        Schema.new(%{
          city: %{type: :string, required: true},
          location: %{type: {:object, location_schema}, required: true}
        })

      user_schema =
        Schema.new(%{
          address: %{type: {:object, address_schema}, required: true}
        })

      json_schema = Spec.to_schema(user_schema)

      address_json = json_schema.properties.address
      assert address_json[:type] == "object"

      location_json = address_json[:properties][:location]
      assert location_json[:type] == "object"
      assert location_json[:properties][:lat][:type] == "number"
      assert location_json[:properties][:lng][:type] == "number"
      assert Enum.sort(location_json[:required]) == ["lat", "lng"]
    end

    test "nested object with integer constraints" do
      contact_schema =
        Schema.new(%{
          age: %{type: :integer, required: true, min: 0, max: 120}
        })

      user_schema =
        Schema.new(%{
          contact: %{type: {:object, contact_schema}, required: true}
        })

      # Valid
      assert {:ok, _} = Spec.validate(user_schema, %{"contact" => %{"age" => 30}})

      # Invalid - age too high
      assert {:error, diag} = Spec.validate(user_schema, %{"contact" => %{"age" => 150}})
      error = hd(diag.errors)
      assert error.field == "contact.age"
      assert error.message =~ "contact.age"
    end

    test "nested object with enum field" do
      profile_schema =
        Schema.new(%{
          role: %{type: {:enum, ["admin", "user", "guest"]}, required: true}
        })

      user_schema =
        Schema.new(%{
          profile: %{type: {:object, profile_schema}, required: true}
        })

      # Valid
      assert {:ok, result} = Spec.validate(user_schema, %{"profile" => %{"role" => "admin"}})
      assert result.profile.role == "admin"

      # Invalid
      assert {:error, diag} = Spec.validate(user_schema, %{"profile" => %{"role" => "invalid"}})
      error = hd(diag.errors)
      assert error.field == "profile.role"
    end
  end

  describe "regex pattern validation" do
    test "validates custom regex pattern" do
      schema =
        Schema.new(%{
          username: %{type: :string, pattern: ~r/^[a-z0-9_]+$/i}
        })

      assert {:ok, _} = Spec.validate(schema, %{"username" => "alice_123"})
      assert {:ok, _} = Spec.validate(schema, %{"username" => "USER_NAME"})

      assert {:error, %Diagnostics{} = diag} =
               Spec.validate(schema, %{"username" => "alice@123"})

      error = hd(diag.errors)
      assert error.field == "username"
      assert error.message =~ "must match pattern"
    end

    test "validates string pattern (compiles to Regex)" do
      schema =
        Schema.new(%{
          code: %{type: :string, pattern: "^[A-Z]{3}\\d{3}$"}
        })

      assert {:ok, _} = Spec.validate(schema, %{"code" => "ABC123"})

      assert {:error, diag} = Spec.validate(schema, %{"code" => "AB123"})
      error = hd(diag.errors)
      assert error.message =~ "must match pattern"
    end

    test "validates built-in email format" do
      schema = Schema.new(%{email: %{type: :string, format: :email}})

      assert {:ok, _} = Spec.validate(schema, %{"email" => "test@example.com"})
      assert {:ok, _} = Spec.validate(schema, %{"email" => "user.name+tag@domain.co.uk"})

      assert {:error, diag} = Spec.validate(schema, %{"email" => "invalid-email"})
      error = hd(diag.errors)
      assert error.field == "email"
      assert error.message =~ "valid email"
    end

    test "validates built-in url format" do
      schema = Schema.new(%{website: %{type: :string, format: :url}})

      assert {:ok, _} = Spec.validate(schema, %{"website" => "https://example.com"})
      assert {:ok, _} = Spec.validate(schema, %{"website" => "http://localhost:3000"})

      assert {:error, diag} = Spec.validate(schema, %{"website" => "not-a-url"})
      error = hd(diag.errors)
      assert error.message =~ "valid url"
    end

    test "validates built-in uuid format" do
      schema = Schema.new(%{id: %{type: :string, format: :uuid}})

      assert {:ok, _} =
               Spec.validate(schema, %{"id" => "550e8400-e29b-41d4-a716-446655440000"})

      assert {:error, diag} = Spec.validate(schema, %{"id" => "not-a-uuid"})
      error = hd(diag.errors)
      assert error.message =~ "valid uuid"
    end

    test "validates built-in phone format" do
      schema = Schema.new(%{phone: %{type: :string, format: :phone}})

      assert {:ok, _} = Spec.validate(schema, %{"phone" => "555-123-4567"})

      assert {:error, diag} = Spec.validate(schema, %{"phone" => "5551234567"})
      error = hd(diag.errors)
      assert error.message =~ "valid phone"
    end

    test "validates built-in date format (YYYY-MM-DD)" do
      schema = Schema.new(%{birth_date: %{type: :string, format: :date}})

      assert {:ok, _} = Spec.validate(schema, %{"birth_date" => "1990-01-15"})
      assert {:ok, _} = Spec.validate(schema, %{"birth_date" => "2024-12-31"})

      assert {:error, diag} = Spec.validate(schema, %{"birth_date" => "01/15/1990"})
      error = hd(diag.errors)
      assert error.message =~ "valid date"
    end

    test "combines pattern with length constraints" do
      schema =
        Schema.new(%{
          code: %{type: :string, pattern: ~r/^[A-Z]+$/, min_length: 2, max_length: 5}
        })

      assert {:ok, _} = Spec.validate(schema, %{"code" => "ABC"})

      # Too short (but matches pattern)
      assert {:error, diag} = Spec.validate(schema, %{"code" => "A"})
      error = hd(diag.errors)
      assert error.message =~ "at least 2 characters"

      # Too long (but matches pattern)
      assert {:error, diag} = Spec.validate(schema, %{"code" => "ABCDEF"})
      error = hd(diag.errors)
      assert error.message =~ "at most 5 characters"

      # Right length but doesn't match pattern
      assert {:error, diag} = Spec.validate(schema, %{"code" => "abc"})
      error = hd(diag.errors)
      assert error.message =~ "must match pattern"
    end

    test "combines format with length constraints" do
      schema =
        Schema.new(%{
          email: %{type: :string, format: :email, max_length: 50}
        })

      assert {:ok, _} = Spec.validate(schema, %{"email" => "test@example.com"})

      # Too long but valid email format
      long_email = "very.long.email.address.that.exceeds@fiftychars.com"
      assert {:error, diag} = Spec.validate(schema, %{"email" => long_email})
      error = hd(diag.errors)
      assert error.message =~ "at most 50 characters"
    end

    test "both pattern and format specified (both must match)" do
      # Custom pattern that's stricter than email format
      schema =
        Schema.new(%{
          email: %{
            type: :string,
            format: :email,
            pattern: ~r/^[a-z0-9]+@[a-z]+\.[a-z]+$/
          }
        })

      # Matches both
      assert {:ok, _} = Spec.validate(schema, %{"email" => "user@example.com"})

      # Matches email format but not custom pattern (has dots and plus)
      assert {:error, diag} =
               Spec.validate(schema, %{"email" => "user.name+tag@example.com"})

      # Should have error about pattern
      assert Enum.any?(diag.errors, fn e -> e.message =~ "must match pattern" end)
    end

    test "JSON Schema generation includes pattern" do
      schema =
        Schema.new(%{
          username: %{type: :string, pattern: ~r/^[a-z0-9_]+$/}
        })

      json_schema = Spec.to_schema(schema)
      username_schema = json_schema.properties.username

      assert username_schema[:type] == "string"
      assert username_schema[:pattern] == "^[a-z0-9_]+$"
    end

    test "JSON Schema generation includes format" do
      schema =
        Schema.new(%{
          email: %{type: :string, format: :email},
          website: %{type: :string, format: :url},
          id: %{type: :string, format: :uuid}
        })

      json_schema = Spec.to_schema(schema)

      assert json_schema.properties.email[:format] == "email"
      assert json_schema.properties.website[:format] == "uri"
      assert json_schema.properties.id[:format] == "uuid"
    end

    test "JSON Schema generation combines pattern and format" do
      schema =
        Schema.new(%{
          email: %{
            type: :string,
            format: :email,
            pattern: ~r/^[a-z]+@[a-z]+\.[a-z]+$/
          }
        })

      json_schema = Spec.to_schema(schema)
      email_schema = json_schema.properties.email

      assert email_schema[:type] == "string"
      assert email_schema[:format] == "email"
      assert email_schema[:pattern] == "^[a-z]+@[a-z]+\\.[a-z]+$"
    end

    test "empty string with pattern (should fail)" do
      schema =
        Schema.new(%{
          code: %{type: :string, pattern: ~r/^[A-Z]+$/}
        })

      assert {:error, diag} = Spec.validate(schema, %{"code" => ""})
      error = hd(diag.errors)
      assert error.message =~ "must match pattern"
    end

    test "pattern validation with nested object" do
      address_schema =
        Schema.new(%{
          zip_code: %{type: :string, required: true, pattern: ~r/^\d{5}(-\d{4})?$/}
        })

      user_schema =
        Schema.new(%{
          address: %{type: {:object, address_schema}, required: true}
        })

      # Valid zip codes
      assert {:ok, _} =
               Spec.validate(user_schema, %{"address" => %{"zip_code" => "12345"}})

      assert {:ok, _} =
               Spec.validate(user_schema, %{"address" => %{"zip_code" => "12345-6789"}})

      # Invalid zip code
      assert {:error, diag} =
               Spec.validate(user_schema, %{"address" => %{"zip_code" => "123"}})

      error = hd(diag.errors)
      assert error.field == "address.zip_code"
      assert error.message =~ "address.zip_code"
    end

    test "pattern validation in array items" do
      schema =
        Schema.new(%{
          codes: %{type: {:array, %{type: :string, pattern: ~r/^[A-Z]{3}$/}}}
        })

      assert {:ok, _} = Spec.validate(schema, %{"codes" => ["ABC", "XYZ", "FOO"]})

      assert {:error, diag} = Spec.validate(schema, %{"codes" => ["ABC", "ab", "XYZ"]})
      error = hd(diag.errors)
      assert error.field == "codes[1]"
      assert error.message =~ "must match pattern"
    end
  end
end
