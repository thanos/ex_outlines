defmodule ExOutlines.IntegrationTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Spec, Spec.Schema}

  @moduledoc """
  Integration tests demonstrating end-to-end schema validation workflows.
  """

  describe "complete validation workflow" do
    test "validates user registration schema" do
      # Define a realistic schema
      schema =
        Schema.new(%{
          username: %{type: :string, required: true, description: "Unique username"},
          email: %{type: :string, required: true, description: "Email address"},
          age: %{type: :integer, required: true, positive: true, description: "User age"},
          role: %{type: {:enum, ["user", "admin"]}, required: false},
          active: %{type: :boolean, required: false}
        })

      # Valid registration
      valid_input = %{
        "username" => "alice123",
        "email" => "alice@example.com",
        "age" => 25,
        "role" => "user",
        "active" => true
      }

      assert {:ok, validated} = Spec.validate(schema, valid_input)
      assert validated.username == "alice123"
      assert validated.email == "alice@example.com"
      assert validated.age == 25
      assert validated.role == "user"
      assert validated.active == true

      # Valid registration with minimal fields
      minimal_input = %{
        "username" => "bob",
        "email" => "bob@example.com",
        "age" => 30
      }

      assert {:ok, validated} = Spec.validate(schema, minimal_input)
      assert validated.username == "bob"
      refute Map.has_key?(validated, :role)
      refute Map.has_key?(validated, :active)

      # Invalid: missing required fields
      assert {:error, diag} = Spec.validate(schema, %{"username" => "charlie"})
      assert length(diag.errors) >= 2
      assert diag.repair_instructions =~ "email"
      assert diag.repair_instructions =~ "age"

      # Invalid: wrong types
      invalid_input = %{
        "username" => 123,
        "email" => false,
        "age" => "not a number"
      }

      assert {:error, diag} = Spec.validate(schema, invalid_input)
      assert length(diag.errors) == 3

      # Invalid: negative age
      assert {:error, diag} = Spec.validate(schema, %{
               "username" => "dave",
               "email" => "dave@example.com",
               "age" => -5
             })

      assert hd(diag.errors).field == "age"
      assert hd(diag.errors).expected =~ "positive"

      # Invalid: wrong enum value
      assert {:error, diag} = Spec.validate(schema, %{
               "username" => "eve",
               "email" => "eve@example.com",
               "age" => 28,
               "role" => "superadmin"
             })

      assert Enum.any?(diag.errors, &(&1.field == "role"))
    end

    test "generates JSON Schema for LLM consumption" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true, description: "Full name"},
          age: %{type: :integer, required: true, positive: true, description: "Age in years"},
          status: %{type: {:enum, ["active", "inactive"]}, required: false}
        })

      json_schema = Spec.to_schema(schema)

      # Verify structure
      assert json_schema.type == "object"
      assert Map.has_key?(json_schema, :properties)
      assert Map.has_key?(json_schema, :required)

      # Verify properties
      assert json_schema.properties.name.type == "string"
      assert json_schema.properties.name.description == "Full name"

      assert json_schema.properties.age.type == "integer"
      assert json_schema.properties.age.minimum == 1
      assert json_schema.properties.age.description == "Age in years"

      assert json_schema.properties.status.enum == ["active", "inactive"]

      # Verify required fields
      assert "name" in json_schema.required
      assert "age" in json_schema.required
      refute "status" in json_schema.required

      # Verify JSON encodability
      assert {:ok, json_string} = Jason.encode(json_schema)
      assert is_binary(json_string)
      assert json_string =~ "\"name\""
      assert json_string =~ "\"age\""
    end

    test "string key to atom key conversion" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Input with string keys
      assert {:ok, result} = Spec.validate(schema, %{"name" => "Alice"})

      # Output has atom keys
      assert is_map(result)
      assert Map.has_key?(result, :name)
      refute Map.has_key?(result, "name")
      assert result.name == "Alice"

      # Also works with atom keys as input
      assert {:ok, result} = Spec.validate(schema, %{name: "Bob"})
      assert result.name == "Bob"
    end

    test "all field types in single schema" do
      schema =
        Schema.new(%{
          string_field: %{type: :string, required: true},
          integer_field: %{type: :integer, required: true},
          positive_int_field: %{type: :integer, required: true, positive: true},
          boolean_field: %{type: :boolean, required: true},
          number_field: %{type: :number, required: true},
          enum_field: %{type: {:enum, ["a", "b", "c"]}, required: true}
        })

      valid_input = %{
        "string_field" => "hello",
        "integer_field" => -42,
        "positive_int_field" => 10,
        "boolean_field" => true,
        "number_field" => 3.14,
        "enum_field" => "b"
      }

      assert {:ok, validated} = Spec.validate(schema, valid_input)
      assert validated.string_field == "hello"
      assert validated.integer_field == -42
      assert validated.positive_int_field == 10
      assert validated.boolean_field == true
      assert validated.number_field == 3.14
      assert validated.enum_field == "b"
    end

    test "builder pattern with add_field" do
      schema =
        Schema.new(%{})
        |> Schema.add_field(:id, :integer, required: true, positive: true)
        |> Schema.add_field(:name, :string, required: true, description: "User name")
        |> Schema.add_field(:role, {:enum, ["admin", "user"]}, required: false)
        |> Schema.add_field(:score, :number, required: false)

      input = %{
        "id" => 1,
        "name" => "Alice",
        "role" => "admin",
        "score" => 98.5
      }

      assert {:ok, validated} = Spec.validate(schema, input)
      assert validated.id == 1
      assert validated.name == "Alice"
      assert validated.role == "admin"
      assert validated.score == 98.5
    end

    test "required_fields helper" do
      schema =
        Schema.new(%{
          field_a: %{type: :string, required: true},
          field_b: %{type: :string, required: false},
          field_c: %{type: :string, required: true},
          field_d: %{type: :string, required: false}
        })

      required = Schema.required_fields(schema)

      assert required == [:field_a, :field_c]
      assert length(required) == 2
    end
  end

  describe "error handling and diagnostics" do
    test "collects all errors for comprehensive feedback" do
      schema =
        Schema.new(%{
          field1: %{type: :string, required: true},
          field2: %{type: :integer, required: true, positive: true},
          field3: %{type: :boolean, required: true},
          field4: %{type: {:enum, ["x", "y"]}, required: true}
        })

      # Provide all fields with wrong types
      bad_input = %{
        "field1" => 123,
        "field2" => -5,
        "field3" => "not_bool",
        "field4" => "z"
      }

      assert {:error, diag} = Spec.validate(schema, bad_input)

      # Should have 4 errors, one for each field
      assert length(diag.errors) == 4

      # Each error should have proper structure
      Enum.each(diag.errors, fn error ->
        assert Map.has_key?(error, :field)
        assert Map.has_key?(error, :expected)
        assert Map.has_key?(error, :got)
        assert Map.has_key?(error, :message)
        assert is_binary(error.message)
      end)

      # Repair instructions should mention all fields
      assert diag.repair_instructions =~ "field1"
      assert diag.repair_instructions =~ "field2"
      assert diag.repair_instructions =~ "field3"
      assert diag.repair_instructions =~ "field4"
    end

    test "clear error messages for each type" do
      schema =
        Schema.new(%{
          str: %{type: :string, required: true},
          int: %{type: :integer, required: true},
          pos: %{type: :integer, required: true, positive: true},
          bool: %{type: :boolean, required: true},
          num: %{type: :number, required: true},
          enum: %{type: {:enum, ["a", "b"]}, required: true}
        })

      test_cases = [
        {"str", 123, "must be a string"},
        {"int", "hello", "must be an integer"},
        {"pos", -5, "must be a positive integer"},
        {"bool", "yes", "must be a boolean"},
        {"num", "3.14", "must be a number"},
        {"enum", "c", "must be one of"}
      ]

      for {field, value, expected_message} <- test_cases do
        input = Map.put(%{}, field, value)
        assert {:error, diag} = Spec.validate(schema, input)
        error = Enum.find(diag.errors, &(&1.field == field))
        assert error, "Expected error for field #{field}"
        assert error.message =~ expected_message
      end
    end
  end
end
