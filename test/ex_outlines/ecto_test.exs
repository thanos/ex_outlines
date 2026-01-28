if Code.ensure_loaded?(Ecto) do
  defmodule ExOutlines.EctoTest do
    use ExUnit.Case, async: true

    alias ExOutlines.{Spec.Schema, Ecto, Diagnostics}

    describe "normalize_field_spec/1 - length" do
      test "normalizes length with min and max" do
        spec = %{type: :string, length: [min: 3, max: 10]}
        result = Ecto.normalize_field_spec(spec)

        assert result.min_length == 3
        assert result.max_length == 10
        refute Map.has_key?(result, :length)
      end

      test "normalizes length with only min" do
        spec = %{type: :string, length: [min: 5]}
        result = Ecto.normalize_field_spec(spec)

        assert result.min_length == 5
        assert result.max_length == nil
      end

      test "normalizes exact length as integer" do
        spec = %{type: :string, length: 10}
        result = Ecto.normalize_field_spec(spec)

        assert result.min_length == 10
        assert result.max_length == 10
      end

      test "leaves spec unchanged if no length" do
        spec = %{type: :string, min_length: 3}
        result = Ecto.normalize_field_spec(spec)

        assert result == spec
      end
    end

    describe "normalize_field_spec/1 - number" do
      test "normalizes greater_than (exclusive)" do
        spec = %{type: :integer, number: [greater_than: 0]}
        result = Ecto.normalize_field_spec(spec)

        assert result.min == 1
        refute Map.has_key?(result, :number)
      end

      test "normalizes greater_than_or_equal_to (inclusive)" do
        spec = %{type: :integer, number: [greater_than_or_equal_to: 0]}
        result = Ecto.normalize_field_spec(spec)

        assert result.min == 0
      end

      test "normalizes less_than (exclusive)" do
        spec = %{type: :integer, number: [less_than: 100]}
        result = Ecto.normalize_field_spec(spec)

        assert result.max == 99
      end

      test "normalizes less_than_or_equal_to (inclusive)" do
        spec = %{type: :integer, number: [less_than_or_equal_to: 100]}
        result = Ecto.normalize_field_spec(spec)

        assert result.max == 100
      end

      test "normalizes equal_to" do
        spec = %{type: :integer, number: [equal_to: 42]}
        result = Ecto.normalize_field_spec(spec)

        assert result.min == 42
        assert result.max == 42
      end

      test "normalizes range with multiple constraints" do
        spec = %{
          type: :integer,
          number: [greater_than_or_equal_to: 0, less_than: 150]
        }

        result = Ecto.normalize_field_spec(spec)

        assert result.min == 0
        assert result.max == 149
      end
    end

    describe "normalize_field_spec/1 - format" do
      test "normalizes regex format to pattern" do
        regex = ~r/^[a-z]+$/
        spec = %{type: :string, format: regex}
        result = Ecto.normalize_field_spec(spec)

        assert result.pattern == regex
        refute Map.has_key?(result, :format) or Map.get(result, :format) in [:email, :url, :uuid]
      end

      test "keeps built-in formats unchanged" do
        for format <- [:email, :url, :uuid, :phone, :date] do
          spec = %{type: :string, format: format}
          result = Ecto.normalize_field_spec(spec)

          assert result.format == format
        end
      end
    end

    describe "validate/2 with Ecto-style DSL" do
      test "validates with length constraints" do
        schema =
          Schema.new(%{
            username: %{type: :string, required: true, length: [min: 3, max: 10]}
          })

        assert {:ok, %{username: "alice"}} =
                 Ecto.validate(schema, %{"username" => "alice"})

        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"username" => "ab"})
        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"username" => "verylongname"})
      end

      test "validates with number constraints (greater_than)" do
        schema =
          Schema.new(%{
            age: %{type: :integer, required: true, number: [greater_than: 0]}
          })

        assert {:ok, %{age: 1}} = Ecto.validate(schema, %{"age" => 1})
        assert {:ok, %{age: 100}} = Ecto.validate(schema, %{"age" => 100})

        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"age" => 0})
        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"age" => -1})
      end

      test "validates with number constraints (greater_than_or_equal_to)" do
        schema =
          Schema.new(%{
            score: %{type: :integer, required: true, number: [greater_than_or_equal_to: 0]}
          })

        assert {:ok, %{score: 0}} = Ecto.validate(schema, %{"score" => 0})
        assert {:ok, %{score: 50}} = Ecto.validate(schema, %{"score" => 50})

        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"score" => -1})
      end

      test "validates with number constraints (less_than)" do
        schema =
          Schema.new(%{
            age: %{type: :integer, required: true, number: [less_than: 150]}
          })

        assert {:ok, %{age: 149}} = Ecto.validate(schema, %{"age" => 149})
        assert {:ok, %{age: 0}} = Ecto.validate(schema, %{"age" => 0})

        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"age" => 150})
        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"age" => 200})
      end

      test "validates with number range" do
        schema =
          Schema.new(%{
            percentage: %{
              type: :integer,
              required: true,
              number: [greater_than_or_equal_to: 0, less_than_or_equal_to: 100]
            }
          })

        assert {:ok, %{percentage: 0}} = Ecto.validate(schema, %{"percentage" => 0})
        assert {:ok, %{percentage: 50}} = Ecto.validate(schema, %{"percentage" => 50})
        assert {:ok, %{percentage: 100}} = Ecto.validate(schema, %{"percentage" => 100})

        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"percentage" => -1})
        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"percentage" => 101})
      end

      test "validates with regex format" do
        schema =
          Schema.new(%{
            code: %{type: :string, required: true, format: ~r/^[A-Z]{3}\d{3}$/}
          })

        assert {:ok, %{code: "ABC123"}} = Ecto.validate(schema, %{"code" => "ABC123"})

        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"code" => "abc123"})
        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"code" => "AB123"})
      end

      test "validates complex schema with multiple Ecto-style constraints" do
        schema =
          Schema.new(%{
            username: %{type: :string, required: true, length: [min: 3, max: 20]},
            age: %{
              type: :integer,
              required: true,
              number: [greater_than_or_equal_to: 0, less_than: 150]
            },
            bio: %{type: :string, required: false, length: [max: 500]}
          })

        valid_data = %{
          "username" => "alice",
          "age" => 30,
          "bio" => "Software engineer"
        }

        assert {:ok, result} = Ecto.validate(schema, valid_data)
        assert result.username == "alice"
        assert result.age == 30
        assert result.bio == "Software engineer"

        # Test various invalid scenarios
        assert {:error, %Diagnostics{}} =
                 Ecto.validate(schema, %{"username" => "ab", "age" => 30})

        assert {:error, %Diagnostics{}} =
                 Ecto.validate(schema, %{"username" => "alice", "age" => -1})

        assert {:error, %Diagnostics{}} =
                 Ecto.validate(schema, %{"username" => "alice", "age" => 150})
      end
    end

    describe "validate/2 fallback to standard validation" do
      test "uses standard validation for non-Ecto DSL" do
        schema =
          Schema.new(%{
            name: %{type: :string, required: true, min_length: 3}
          })

        assert {:ok, %{name: "Alice"}} = Ecto.validate(schema, %{"name" => "Alice"})
        assert {:error, %Diagnostics{}} = Ecto.validate(schema, %{"name" => "ab"})
      end
    end

    describe "changeset_to_diagnostics/1" do
      # Define a simple embedded schema for testing
      defmodule TestSchema do
        # Use fully qualified module names to avoid namespace conflicts with ExOutlines.Ecto
        use Elixir.Ecto.Schema
        import Elixir.Ecto.Changeset

        embedded_schema do
          field(:email, :string)
          field(:age, :integer)
          field(:username, :string)
        end

        def changeset(schema, params) do
          schema
          |> cast(params, [:email, :age, :username])
          |> validate_required([:email, :username])
          |> validate_format(:email, ~r/@/)
          |> validate_number(:age, greater_than_or_equal_to: 0, less_than: 150)
          |> validate_length(:username, min: 3, max: 20)
        end
      end

      test "converts valid changeset to {:ok, data}" do
        changeset =
          TestSchema.changeset(%TestSchema{}, %{
            email: "alice@example.com",
            age: 30,
            username: "alice"
          })

        assert {:ok, data} = Ecto.changeset_to_diagnostics(changeset)
        assert data.email == "alice@example.com"
        assert data.age == 30
        assert data.username == "alice"
      end

      test "converts invalid changeset to {:error, diagnostics}" do
        changeset =
          TestSchema.changeset(%TestSchema{}, %{
            email: "invalid-email",
            age: -5,
            username: "ab"
          })

        assert {:error, %Diagnostics{} = diag} = Ecto.changeset_to_diagnostics(changeset)

        # Should have multiple errors
        assert length(diag.errors) > 0

        # Check that errors are properly formatted
        assert Enum.any?(diag.errors, fn error -> String.contains?(error.message, "email") end)
        assert diag.repair_instructions =~ "Validation failed"
      end

      test "handles missing required fields" do
        changeset = TestSchema.changeset(%TestSchema{}, %{})

        assert {:error, %Diagnostics{} = diag} = Ecto.changeset_to_diagnostics(changeset)
        assert length(diag.errors) >= 2 # email and username required
      end

      test "includes field names in error messages" do
        changeset = TestSchema.changeset(%TestSchema{}, %{email: "bad", username: "x"})

        assert {:error, %Diagnostics{} = diag} = Ecto.changeset_to_diagnostics(changeset)

        errors_text = Enum.map_join(diag.errors, ", ", & &1.message)
        assert errors_text =~ "email"
        assert errors_text =~ "username"
      end
    end

    describe "integration with ExOutlines.generate/2" do
      test "can use Ecto-style DSL in generation workflow" do
        alias ExOutlines.Backend.Mock

        schema =
          Schema.new(%{
            age: %{
              type: :integer,
              required: true,
              number: [greater_than_or_equal_to: 0, less_than: 150]
            }
          })

        # Valid response
        mock = Mock.new([{:ok, ~s({"age": 30})}])

        result =
          ExOutlines.generate(schema,
            backend: Mock,
            backend_opts: [mock: mock]
          )

        assert {:ok, %{age: 30}} = result
      end

      test "validates with Ecto constraints during retry-repair loop" do
        alias ExOutlines.Backend.Mock

        schema =
          Schema.new(%{
            count: %{type: :integer, required: true, number: [greater_than: 0, less_than: 100]}
          })

        # First response fails (out of range), second succeeds
        mock =
          Mock.new([
            {:ok, ~s({"count": 150})},
            # Too high
            {:ok, ~s({"count": 50})}
            # Valid
          ])

        result =
          ExOutlines.generate(schema,
            backend: Mock,
            backend_opts: [mock: mock],
            max_retries: 2
          )

        assert {:ok, %{count: 50}} = result
      end
    end
  end
end
