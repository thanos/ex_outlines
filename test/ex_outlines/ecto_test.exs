if Code.ensure_loaded?(Ecto) do
  defmodule ExOutlines.EctoTest do
    use ExUnit.Case, async: true

    alias ExOutlines.{Diagnostics, Ecto, Spec.Schema}

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
        assert Enum.empty?(diag.errors) == false

        # Check that errors are properly formatted
        assert Enum.any?(diag.errors, fn error -> String.contains?(error.message, "email") end)
        assert diag.repair_instructions =~ "Validation failed"
      end

      test "handles missing required fields" do
        changeset = TestSchema.changeset(%TestSchema{}, %{})

        assert {:error, %Diagnostics{} = diag} = Ecto.changeset_to_diagnostics(changeset)
        # email and username required
        assert length(diag.errors) >= 2
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

    describe "from_ecto_schema/2" do
      # Define test schemas
      defmodule SimpleUser do
        use Elixir.Ecto.Schema

        schema "users" do
          field(:email, :string)
          field(:age, :integer)
          field(:active, :boolean)
        end
      end

      defmodule UserWithValidations do
        use Elixir.Ecto.Schema
        import Elixir.Ecto.Changeset

        schema "users" do
          field(:email, :string)
          field(:username, :string)
          field(:age, :integer)
          field(:bio, :string)
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

      defmodule UserWithEnum do
        use Elixir.Ecto.Schema

        schema "users" do
          field(:role, Elixir.Ecto.Enum, values: [:admin, :user, :guest])
          field(:status, Elixir.Ecto.Enum, values: [:active, :inactive, :banned])
        end
      end

      defmodule UserWithEmbeds do
        use Elixir.Ecto.Schema

        defmodule Address do
          use Elixir.Ecto.Schema

          embedded_schema do
            field(:street, :string)
            field(:city, :string)
            field(:zip, :string)
          end
        end

        schema "users" do
          field(:name, :string)
          embeds_one(:address, Address)
        end
      end

      defmodule UserWithArrays do
        use Elixir.Ecto.Schema

        schema "users" do
          field(:tags, {:array, :string})
          field(:scores, {:array, :integer})
        end
      end

      test "converts simple Ecto schema to ExOutlines schema" do
        schema = Ecto.from_ecto_schema(SimpleUser)

        assert Map.has_key?(schema.fields, :email)
        assert Map.has_key?(schema.fields, :age)
        assert Map.has_key?(schema.fields, :active)

        assert schema.fields.email.type == :string
        assert schema.fields.age.type == :integer
        assert schema.fields.active.type == :boolean
      end

      test "extracts validation rules from changeset" do
        schema = Ecto.from_ecto_schema(UserWithValidations)

        # Required fields
        assert schema.fields.email.required == true
        assert schema.fields.username.required == true
        assert schema.fields.age.required == false
        assert schema.fields.bio.required == false

        # Length constraints
        assert schema.fields.username.min_length == 3
        assert schema.fields.username.max_length == 20
        assert schema.fields.bio.max_length == 500

        # Number constraints
        assert schema.fields.age.min == 1
        assert schema.fields.age.max == 149

        # Format constraints
        assert match?(%Regex{}, schema.fields.email.pattern)
        assert Regex.match?(schema.fields.email.pattern, "test@example.com")
      end

      test "handles explicit required fields option" do
        schema = Ecto.from_ecto_schema(SimpleUser, required: [:email, :age])

        assert schema.fields.email.required == true
        assert schema.fields.age.required == true
        assert schema.fields.active.required == false
      end

      test "handles field descriptions" do
        descriptions = %{
          email: "User's email address",
          age: "User's age in years"
        }

        schema = Ecto.from_ecto_schema(SimpleUser, descriptions: descriptions)

        assert schema.fields.email.description == "User's email address"
        assert schema.fields.age.description == "User's age in years"
        assert schema.fields.active.description == nil
      end

      test "converts Ecto.Enum to enum type" do
        schema = Ecto.from_ecto_schema(UserWithEnum)

        assert schema.fields.role.type == {:enum, [:admin, :user, :guest]}
        assert schema.fields.status.type == {:enum, [:active, :inactive, :banned]}
      end

      test "converts embedded schemas to nested objects" do
        schema = Ecto.from_ecto_schema(UserWithEmbeds)

        assert schema.fields.name.type == :string
        assert match?({:object, %Schema{}}, schema.fields.address.type)

        {:object, address_schema} = schema.fields.address.type
        assert Map.has_key?(address_schema.fields, :street)
        assert Map.has_key?(address_schema.fields, :city)
        assert Map.has_key?(address_schema.fields, :zip)
      end

      test "converts array fields to array type" do
        schema = Ecto.from_ecto_schema(UserWithArrays)

        assert match?({:array, %{type: :string}}, schema.fields.tags.type)
        assert match?({:array, %{type: :integer}}, schema.fields.scores.type)
      end

      test "excludes :id field" do
        schema = Ecto.from_ecto_schema(SimpleUser)

        refute Map.has_key?(schema.fields, :id)
      end

      test "handles custom changeset function name" do
        defmodule UserWithCustomChangeset do
          use Elixir.Ecto.Schema
          import Elixir.Ecto.Changeset

          schema "users" do
            field(:email, :string)
            field(:password, :string)
          end

          def registration_changeset(user, params) do
            user
            |> cast(params, [:email, :password])
            |> validate_required([:email, :password])
            |> validate_length(:password, min: 8)
          end
        end

        schema = Ecto.from_ecto_schema(UserWithCustomChangeset, changeset: :registration_changeset)

        assert schema.fields.email.required == true
        assert schema.fields.password.required == true
        assert schema.fields.password.min_length == 8
      end

      test "raises error for non-Ecto schema" do
        defmodule NotAnEctoSchema do
          defstruct [:name]
        end

        assert_raise ArgumentError, ~r/is not an Ecto schema/, fn ->
          Ecto.from_ecto_schema(NotAnEctoSchema)
        end
      end

      test "validates converted schema with data" do
        schema = Ecto.from_ecto_schema(UserWithValidations)

        valid_data = %{
          "email" => "alice@example.com",
          "username" => "alice",
          "age" => 30,
          "bio" => "Software engineer"
        }

        assert {:ok, result} = ExOutlines.Spec.validate(schema, valid_data)
        assert result.email == "alice@example.com"
        assert result.username == "alice"
        assert result.age == 30
      end

      test "validates and catches errors with converted schema" do
        schema = Ecto.from_ecto_schema(UserWithValidations)

        invalid_data = %{
          "email" => "invalid-email",
          "username" => "ab",
          "age" => 200
        }

        assert {:error, diagnostics} = ExOutlines.Spec.validate(schema, invalid_data)
        assert Enum.empty?(diagnostics.errors) == false
      end
    end
  end
end
