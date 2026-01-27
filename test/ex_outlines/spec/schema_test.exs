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
end
