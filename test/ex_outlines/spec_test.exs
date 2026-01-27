defmodule ExOutlines.SpecTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Diagnostics, Spec}

  # Test implementation of Spec protocol for testing
  defmodule SimpleSpec do
    @moduledoc """
    A simple test spec that requires an integer value.
    """
    defstruct min: nil, max: nil

    defimpl Spec do
      def to_schema(%SimpleSpec{min: min, max: max}) do
        schema = %{type: "integer"}

        schema =
          if min, do: Map.put(schema, :minimum, min), else: schema

        schema =
          if max, do: Map.put(schema, :maximum, max), else: schema

        schema
      end

      def validate(%SimpleSpec{min: min, max: max}, value) when is_integer(value) do
        cond do
          min && value < min ->
            {:error, Diagnostics.new("integer >= #{min}", value)}

          max && value > max ->
            {:error, Diagnostics.new("integer <= #{max}", value)}

          true ->
            {:ok, value}
        end
      end

      def validate(%SimpleSpec{}, value) do
        {:error, Diagnostics.new("integer", value)}
      end
    end
  end

  defmodule MapSpec do
    @moduledoc """
    A test spec that requires a map with specific keys.
    """
    defstruct required_keys: []

    defimpl Spec do
      def to_schema(%MapSpec{required_keys: keys}) do
        properties =
          keys
          |> Enum.map(&{&1, %{type: "string"}})
          |> Enum.into(%{})

        %{
          type: "object",
          properties: properties,
          required: keys
        }
      end

      def validate(%MapSpec{required_keys: keys}, value) when is_map(value) do
        missing_keys = keys -- Map.keys(value)

        if missing_keys == [] do
          {:ok, value}
        else
          errors =
            Enum.map(missing_keys, fn key ->
              %{
                field: to_string(key),
                expected: "required key",
                got: nil,
                message: "Missing required key: #{key}"
              }
            end)

          {:error, Diagnostics.from_errors(errors)}
        end
      end

      def validate(%MapSpec{}, value) do
        {:error, Diagnostics.new("map", value)}
      end
    end
  end

  describe "Spec protocol - SimpleSpec" do
    test "to_schema/1 returns basic integer schema" do
      spec = %SimpleSpec{}
      schema = Spec.to_schema(spec)

      assert schema.type == "integer"
      refute Map.has_key?(schema, :minimum)
      refute Map.has_key?(schema, :maximum)
    end

    test "to_schema/1 includes min/max constraints" do
      spec = %SimpleSpec{min: 0, max: 100}
      schema = Spec.to_schema(spec)

      assert schema.type == "integer"
      assert schema.minimum == 0
      assert schema.maximum == 100
    end

    test "validate/2 accepts valid integer" do
      spec = %SimpleSpec{}
      assert {:ok, 42} = Spec.validate(spec, 42)
    end

    test "validate/2 rejects non-integer" do
      spec = %SimpleSpec{}
      assert {:error, diag} = Spec.validate(spec, "hello")
      assert Diagnostics.has_errors?(diag)
      assert hd(diag.errors).expected == "integer"
    end

    test "validate/2 enforces minimum constraint" do
      spec = %SimpleSpec{min: 0}
      assert {:ok, 5} = Spec.validate(spec, 5)
      assert {:error, diag} = Spec.validate(spec, -1)
      assert hd(diag.errors).expected =~ ">= 0"
    end

    test "validate/2 enforces maximum constraint" do
      spec = %SimpleSpec{max: 100}
      assert {:ok, 50} = Spec.validate(spec, 50)
      assert {:error, diag} = Spec.validate(spec, 101)
      assert hd(diag.errors).expected =~ "<= 100"
    end

    test "validate/2 enforces both min and max" do
      spec = %SimpleSpec{min: 0, max: 100}
      assert {:ok, 50} = Spec.validate(spec, 50)
      assert {:error, _} = Spec.validate(spec, -1)
      assert {:error, _} = Spec.validate(spec, 101)
    end
  end

  describe "Spec protocol - MapSpec" do
    test "to_schema/1 returns object schema with properties" do
      spec = %MapSpec{required_keys: [:name, :email]}
      schema = Spec.to_schema(spec)

      assert schema.type == "object"
      assert schema.properties.name == %{type: "string"}
      assert schema.properties.email == %{type: "string"}
      assert schema.required == [:name, :email]
    end

    test "validate/2 accepts map with all required keys" do
      spec = %MapSpec{required_keys: [:name, :email]}
      value = %{name: "Alice", email: "alice@example.com"}

      assert {:ok, ^value} = Spec.validate(spec, value)
    end

    test "validate/2 rejects map missing required keys" do
      spec = %MapSpec{required_keys: [:name, :email]}
      value = %{name: "Alice"}

      assert {:error, diag} = Spec.validate(spec, value)
      assert Diagnostics.has_errors?(diag)
      assert Diagnostics.error_count(diag) == 1
      assert hd(diag.errors).field == "email"
    end

    test "validate/2 rejects non-map" do
      spec = %MapSpec{required_keys: [:name]}
      assert {:error, diag} = Spec.validate(spec, "not a map")
      assert hd(diag.errors).expected == "map"
    end

    test "validate/2 collects multiple missing keys" do
      spec = %MapSpec{required_keys: [:name, :email, :age]}
      value = %{name: "Alice"}

      assert {:error, diag} = Spec.validate(spec, value)
      assert Diagnostics.error_count(diag) == 2
      fields = Enum.map(diag.errors, & &1.field)
      assert "email" in fields
      assert "age" in fields
    end
  end

  describe "Spec protocol - integration" do
    test "diagnostics from validation contain repair instructions" do
      spec = %SimpleSpec{min: 0}
      assert {:error, diag} = Spec.validate(spec, -5)

      assert diag.repair_instructions != ""
      assert diag.repair_instructions =~ "integer >= 0"
    end

    test "works with multiple validation failures" do
      spec = %MapSpec{required_keys: [:name, :email, :age]}
      value = %{}

      assert {:error, diag} = Spec.validate(spec, value)
      assert Diagnostics.error_count(diag) == 3
      assert diag.repair_instructions =~ "name"
      assert diag.repair_instructions =~ "email"
      assert diag.repair_instructions =~ "age"
    end

    test "schema can be JSON encoded" do
      spec = %MapSpec{required_keys: [:name, :email]}
      schema = Spec.to_schema(spec)

      assert {:ok, _json} = Jason.encode(schema)
    end
  end
end
