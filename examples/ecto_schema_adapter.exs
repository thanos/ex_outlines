#!/usr/bin/env elixir
#
# Ecto Schema Adapter Example
#
# This example demonstrates how to use ExOutlines.Ecto.from_ecto_schema/2
# to automatically convert existing Ecto schemas to ExOutlines schemas.
#
# Benefits:
# - Reuse existing Ecto schema definitions
# - Automatic validation rule extraction from changesets
# - Seamless integration with LLM-powered data generation
# - No duplicate schema definitions needed
#
# Run with: elixir examples/ecto_schema_adapter.exs

Mix.install([{:ex_outlines, path: "."}, {:ecto, "~> 3.11"}])

defmodule Example do
  @moduledoc """
  Example showing Ecto Schema Adapter usage.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ExOutlines.{Ecto, Backend.Mock, Spec}

  # Define an Ecto schema with validations
  defmodule User do
    use Elixir.Ecto.Schema
    import Elixir.Ecto.Changeset

    schema "users" do
      field(:email, :string)
      field(:username, :string)
      field(:age, :integer)
      field(:bio, :string)

      field(:role, Ecto.Enum, values: [:admin, :user, :guest])
    end

    @doc """
    Standard Ecto changeset with validations.
    """
    def changeset(user, params) do
      user
      |> cast(params, [:email, :username, :age, :bio, :role])
      |> validate_required([:email, :username])
      |> validate_format(:email, ~r/@/)
      |> validate_length(:username, min: 3, max: 20)
      |> validate_number(:age, greater_than: 0, less_than: 150)
      |> validate_length(:bio, max: 500)
    end
  end

  defmodule Product do
    use Elixir.Ecto.Schema
    import Elixir.Ecto.Changeset

    defmodule Price do
      use Elixir.Ecto.Schema

      embedded_schema do
        field(:amount, :decimal)
        field(:currency, :string)
      end
    end

    schema "products" do
      field(:name, :string)
      field(:description, :string)
      field(:tags, {:array, :string})
      embeds_one(:price, Price)
    end

    def changeset(product, params) do
      product
      |> cast(params, [:name, :description, :tags])
      |> validate_required([:name])
      |> validate_length(:name, min: 3, max: 100)
    end
  end

  def run do
    IO.puts("=" |> String.duplicate(70))
    IO.puts("Ecto Schema Adapter Example")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("")

    # Example 1: Basic schema conversion
    IO.puts("## Example 1: Basic Schema Conversion\n")
    user_schema = Ecto.from_ecto_schema(User)

    IO.puts("Converted User schema:")
    IO.inspect(user_schema.fields, pretty: true, width: 80)
    IO.puts("")

    # Example 2: Use converted schema with Mock backend
    IO.puts("## Example 2: Generate Data with Converted Schema\n")

    mock =
      Mock.new([
        {:ok,
         ~s({"email": "alice@example.com", "username": "alice", "age": 30, "bio": "Software engineer", "role": "user"})}
      ])

    result =
      ExOutlines.generate(user_schema,
        backend: Mock,
        backend_opts: [mock: mock]
      )

    case result do
      {:ok, data} ->
        IO.puts("[SUCCESS] Successfully generated user data:")
        IO.inspect(data, pretty: true)

      {:error, reason} ->
        IO.puts("[FAILED] Generation failed: #{inspect(reason)}")
    end

    IO.puts("")

    # Example 3: Validation with converted schema
    IO.puts("## Example 3: Validation with Converted Schema\n")

    valid_data = %{
      "email" => "bob@example.com",
      "username" => "bobby",
      "age" => 25,
      "bio" => "Data scientist",
      "role" => "admin"
    }

    case Spec.validate(user_schema, valid_data) do
      {:ok, validated} ->
        IO.puts("[SUCCESS] Valid data passed validation:")
        IO.inspect(validated, pretty: true)

      {:error, diagnostics} ->
        IO.puts("[FAILED] Validation failed:")
        IO.puts(diagnostics.repair_instructions)
    end

    IO.puts("")

    # Example 4: Validation failure example
    IO.puts("## Example 4: Validation Failure\n")

    invalid_data = %{
      "email" => "invalid-email",
      "username" => "ab",
      "age" => 200
    }

    case Spec.validate(user_schema, invalid_data) do
      {:ok, _validated} ->
        IO.puts("[SUCCESS] Validation passed (unexpected)")

      {:error, diagnostics} ->
        IO.puts("[FAILED] Validation failed as expected:")
        IO.puts(diagnostics.repair_instructions)
    end

    IO.puts("")

    # Example 5: Schema with embedded objects
    IO.puts("## Example 5: Nested Schema Conversion\n")
    product_schema = Ecto.from_ecto_schema(Product)

    IO.puts("Converted Product schema with embedded Price:")
    IO.inspect(product_schema.fields, pretty: true, width: 80)
    IO.puts("")

    # Example 6: Custom descriptions
    IO.puts("## Example 6: Schema with Custom Descriptions\n")

    described_schema =
      Ecto.from_ecto_schema(User,
        descriptions: %{
          email: "User's email address for authentication",
          username: "Unique username for display",
          age: "User's age in years",
          bio: "Short biography (max 500 characters)"
        }
      )

    IO.puts("Schema with descriptions:")

    Enum.each(described_schema.fields, fn {name, spec} ->
      if spec.description do
        IO.puts("  #{name}: #{spec.description}")
      end
    end)

    IO.puts("")

    # Example 7: Integration pattern
    IO.puts("## Example 7: Integration Pattern\n")
    IO.puts("""
    # In your application:

    defmodule MyApp.AIService do
      alias ExOutlines.{Ecto, Backend.Anthropic}
      alias MyApp.Accounts.User

      def generate_user_profile(prompt) do
        # Convert Ecto schema to ExOutlines schema
        schema = Ecto.from_ecto_schema(User)

        # Generate structured output from LLM
        ExOutlines.generate(schema,
          backend: Anthropic,
          backend_opts: [
            api_key: System.get_env("ANTHROPIC_API_KEY"),
            model: "claude-sonnet-4-5-20250929"
          ],
          prompt: prompt
        )
      end

      def create_user_from_ai(prompt) do
        case generate_user_profile(prompt) do
          {:ok, user_data} ->
            # Use standard Ecto changeset for database insertion
            %User{}
            |> User.changeset(user_data)
            |> MyApp.Repo.insert()

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
    """)

    IO.puts("")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("Key Takeaways:")
    IO.puts("=" |> String.duplicate(70))
    IO.puts("""
    1. [SUCCESS] No duplicate schema definitions - reuse existing Ecto schemas
    2. [SUCCESS] Automatic validation extraction from changesets
    3. [SUCCESS] Seamless integration with ExOutlines.generate/2
    4. [SUCCESS] Support for embedded schemas, enums, and arrays
    5. [SUCCESS] Custom descriptions for better LLM guidance
    6. [SUCCESS] Type-safe validation and data generation
    """)
  end
end

# Run the example
Example.run()
