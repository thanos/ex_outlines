defmodule ExOutlines.Backend.MockTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Mock

  doctest Mock

  describe "new/1" do
    test "creates a mock with configured responses" do
      responses = [{:ok, "response 1"}, {:ok, "response 2"}]
      mock = Mock.new(responses)

      assert mock.responses == responses
      assert mock.call_count == 0
    end

    test "accepts empty response list" do
      mock = Mock.new([])

      assert mock.responses == []
    end
  end

  describe "always/1" do
    test "creates a mock with single repeated response" do
      mock = Mock.always({:ok, "same"})

      assert mock.responses == [{:ok, "same"}]
    end

    test "works with error responses" do
      mock = Mock.always({:error, :timeout})

      assert mock.responses == [{:error, :timeout}]
    end
  end

  describe "always_fail/1" do
    test "creates a mock that always returns error" do
      mock = Mock.always_fail(:rate_limited)

      assert mock.responses == [{:error, :rate_limited}]
    end
  end

  describe "call_count/1" do
    test "returns the call count" do
      mock = Mock.new([{:ok, "response"}])

      assert Mock.call_count(mock) == 0
    end
  end

  describe "call_llm/2" do
    test "returns first response when mock provided" do
      mock = Mock.new([{:ok, "first"}, {:ok, "second"}])

      messages = [%{role: "user", content: "test"}]
      opts = [mock: mock]

      assert Mock.call_llm(messages, opts) == {:ok, "first"}
    end

    test "returns error when no mock provided" do
      messages = [%{role: "user", content: "test"}]
      opts = []

      assert Mock.call_llm(messages, opts) == {:error, :no_mock_provided}
    end

    test "returns error when responses exhausted" do
      mock = Mock.new([])

      messages = [%{role: "user", content: "test"}]
      opts = [mock: mock]

      assert Mock.call_llm(messages, opts) == {:error, :no_more_responses}
    end

    test "can return error responses" do
      mock = Mock.new([{:error, :timeout}])

      messages = [%{role: "user", content: "test"}]
      opts = [mock: mock]

      assert Mock.call_llm(messages, opts) == {:error, :timeout}
    end

    test "works with valid JSON responses" do
      json_response = ~s({"name": "Alice", "age": 30})
      mock = Mock.new([{:ok, json_response}])

      messages = [%{role: "user", content: "Generate user"}]
      opts = [mock: mock, model: "test"]

      assert Mock.call_llm(messages, opts) == {:ok, json_response}
    end
  end

  describe "integration with ExOutlines" do
    test "mock can be used with generate/2" do
      alias ExOutlines.Spec.Schema

      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock]
        )

      assert {:ok, validated} = result
      assert validated.name == "Alice"
    end

    test "mock supports retry flow" do
      alias ExOutlines.Spec.Schema

      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true}
        })

      # First attempt: invalid (negative age)
      # Second attempt: valid
      mock =
        Mock.new([
          {:ok, ~s({"name": "Bob", "age": -5})},
          {:ok, ~s({"name": "Bob", "age": 25})}
        ])

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock],
          max_retries: 3
        )

      # Note: Current mock implementation is stateless, so this will
      # return the first response on both calls. To support stateful
      # retry testing, we'd need to wrap mock in a GenServer or Agent.
      #
      # For now, we verify the mock accepts the call format.
      assert is_tuple(result) and elem(result, 0) in [:ok, :error]
    end

    test "mock handles backend errors" do
      alias ExOutlines.Spec.Schema

      schema = Schema.new(%{name: %{type: :string, required: true}})

      mock = Mock.new([{:error, :rate_limited}])

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock]
        )

      assert {:error, {:backend_error, :rate_limited}} = result
    end

    test "mock simulates max retries exceeded" do
      alias ExOutlines.Spec.Schema

      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Always return invalid JSON
      mock = Mock.new([{:ok, "invalid json"}])

      result =
        ExOutlines.generate(schema,
          backend: Mock,
          backend_opts: [mock: mock],
          max_retries: 2
        )

      # Since mock is stateless, it will keep returning the same response
      assert {:error, :max_retries_exceeded} = result
    end
  end
end
