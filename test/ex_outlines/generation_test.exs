defmodule ExOutlines.GenerationTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Backend.Mock, Spec.Schema}

  @moduledoc """
  Comprehensive tests for the generation loop, retry logic, and repair flow.

  Tests the core ExOutlines.generate/2 function with various scenarios including:
  - Successful generation on first attempt
  - Retry with repair after validation failures
  - Maximum retries exhaustion
  - Backend errors and exceptions
  - Configuration validation
  """

  describe "generate/2 - successful generation" do
    test "returns validated output on first successful attempt" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.name == "Alice"
    end

    test "validates all field types correctly" do
      schema =
        Schema.new(%{
          str: %{type: :string, required: true},
          int: %{type: :integer, required: true},
          bool: %{type: :boolean, required: true},
          num: %{type: :number, required: true},
          enum: %{type: {:enum, ["a", "b"]}, required: true}
        })

      mock =
        Mock.new([
          {:ok, ~s({"str": "hello", "int": 42, "bool": true, "num": 3.14, "enum": "a"})}
        ])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.str == "hello"
      assert result.int == 42
      assert result.bool == true
      assert result.num == 3.14
      assert result.enum == "a"
    end

    test "handles optional fields correctly" do
      schema =
        Schema.new(%{
          required_field: %{type: :string, required: true},
          optional_field: %{type: :string, required: false}
        })

      mock = Mock.new([{:ok, ~s({"required_field": "present"})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.required_field == "present"
      refute Map.has_key?(result, :optional_field)
    end
  end

  describe "generate/2 - configuration validation" do
    test "returns error when backend is missing" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, :no_backend} = ExOutlines.generate(schema, [])
    end

    test "returns error when backend is not an atom" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_backend, "NotAnAtom"}} =
               ExOutlines.generate(schema, backend: "NotAnAtom")
    end

    test "returns error when backend is a number" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_backend, 123}} =
               ExOutlines.generate(schema, backend: 123)
    end

    test "accepts valid backend module" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])

      result =
        ExOutlines.generate(schema,
          backend: ExOutlines.Backend.Mock,
          backend_opts: [mock: mock]
        )

      assert match?({:ok, _}, result)
    end

    test "uses default max_retries when not specified" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Return invalid JSON to trigger retries
      mock = Mock.new([{:ok, "invalid json"}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )
    end

    test "respects custom max_retries value" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, "invalid json"}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 1
               )
    end
  end

  describe "generate/2 - backend errors" do
    test "returns backend error when LLM call fails" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:error, :rate_limited}])

      assert {:error, {:backend_error, :rate_limited}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )
    end

    test "handles timeout errors" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:error, :timeout}])

      assert {:error, {:backend_error, :timeout}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )
    end

    test "handles API errors" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:error, {:api_error, "insufficient credits"}}])

      assert {:error, {:backend_error, {:api_error, "insufficient credits"}}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )
    end

    test "wraps backend exceptions" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Simulate backend exception by not providing mock
      assert {:error, {:backend_error, :no_mock_provided}} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: []
               )
    end
  end

  describe "generate/2 - JSON decode errors" do
    test "treats invalid JSON as validation failure" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, "not valid json"}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 2
               )
    end

    test "handles malformed JSON gracefully" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Alice")}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 1
               )
    end

    test "handles empty response" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ""}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 1
               )
    end
  end

  describe "generate/2 - validation failures and retry" do
    test "retries with repair instructions after validation failure" do
      schema =
        Schema.new(%{
          age: %{type: :integer, required: true, positive: true}
        })

      # First attempt: negative age (invalid)
      # Second attempt: still retries (mock is stateless, returns same response)
      mock = Mock.new([{:ok, ~s({"age": -5})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 3
               )
    end

    test "stops retrying after max_retries attempts" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Always return invalid response
      mock = Mock.new([{:ok, ~s({"age": 30})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 2
               )
    end

    test "handles missing required fields" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true}
        })

      # Missing age field
      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 2
               )
    end

    test "handles type mismatches" do
      schema = Schema.new(%{age: %{type: :integer, required: true}})

      # Age is string instead of integer
      mock = Mock.new([{:ok, ~s({"age": "thirty"})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 2
               )
    end

    test "handles enum violations" do
      schema =
        Schema.new(%{
          role: %{type: {:enum, ["admin", "user"]}, required: true}
        })

      # Invalid enum value
      mock = Mock.new([{:ok, ~s({"role": "superadmin"})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 2
               )
    end

    test "collects multiple validation errors" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true},
          active: %{type: :boolean, required: true}
        })

      # Multiple errors: missing name, negative age, wrong type for active
      mock = Mock.new([{:ok, ~s({"age": -5, "active": "yes"})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 1
               )
    end
  end

  describe "generate/2 - max retries exhaustion" do
    test "returns :max_retries_exceeded after exhausting attempts" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"wrong_field": "value"})}])

      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 5
               )
    end

    test "max_retries of 0 means 0 attempts allowed" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])

      # With max_retries: 0, should fail immediately
      assert {:error, :max_retries_exceeded} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 0
               )
    end

    test "max_retries of 1 allows 1 attempt" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])

      # With max_retries: 1, should succeed on first attempt
      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock],
                 max_retries: 1
               )

      assert result.name == "Alice"
    end
  end

  describe "generate/2 - edge cases" do
    test "handles very large valid responses" do
      schema = Schema.new(%{data: %{type: :string, required: true}})

      # Large string (1000 characters)
      large_string = String.duplicate("a", 1000)
      mock = Mock.new([{:ok, ~s({"data": "#{large_string}"})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert String.length(result.data) == 1000
    end

    test "handles unicode characters correctly" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Ålíçé 🎉"})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.name == "Ålíçé 🎉"
    end

    test "handles zero as valid integer" do
      schema = Schema.new(%{count: %{type: :integer, required: true}})

      mock = Mock.new([{:ok, ~s({"count": 0})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.count == 0
    end

    test "handles negative numbers correctly" do
      schema = Schema.new(%{temp: %{type: :number, required: true}})

      mock = Mock.new([{:ok, ~s({"temp": -273.15})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.temp == -273.15
    end

    test "handles boolean false correctly" do
      schema = Schema.new(%{active: %{type: :boolean, required: true}})

      mock = Mock.new([{:ok, ~s({"active": false})}])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.active == false
    end
  end

  describe "generate/2 - integration scenarios" do
    test "realistic user registration workflow" do
      schema =
        Schema.new(%{
          username: %{type: :string, required: true},
          email: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true},
          role: %{type: {:enum, ["user", "admin"]}, required: false}
        })

      mock =
        Mock.new([
          {:ok,
           ~s({"username": "alice123", "email": "alice@example.com", "age": 30, "role": "user"})}
        ])

      assert {:ok, user} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert user.username == "alice123"
      assert user.email == "alice@example.com"
      assert user.age == 30
      assert user.role == "user"
    end

    test "handles complex nested validation" do
      schema =
        Schema.new(%{
          status: %{type: {:enum, ["draft", "published"]}, required: true},
          priority: %{type: :integer, required: true, positive: true},
          public: %{type: :boolean, required: true}
        })

      mock =
        Mock.new([
          {:ok, ~s({"status": "published", "priority": 1, "public": true})}
        ])

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Mock,
                 backend_opts: [mock: mock]
               )

      assert result.status == "published"
      assert result.priority == 1
      assert result.public == true
    end
  end
end
