Code.require_file("test_helper.exs", __DIR__)

defmodule ExOutlines.Integration.AnthropicTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias ExOutlines.{Backend.Anthropic, IntegrationTestHelper}
  alias ExOutlines.Spec.Schema

  setup_all do
    IntegrationTestHelper.skip_without_api_key("ANTHROPIC_API_KEY")
    :ok
  end

  describe "generate/2 with Anthropic backend" do
    test "returns valid output with basic schema" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )

      assert is_binary(result.name)
      assert String.length(result.name) > 0
    end

    test "validates complex nested schema correctly" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema = IntegrationTestHelper.complex_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )

      assert is_binary(result.user.name)
      assert is_integer(result.user.age)
      assert result.user.age > 0
      assert is_binary(result.user.email)
      assert result.status in ["active", "inactive"]
    end

    test "system message is correctly extracted and sent separately" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema =
        Schema.new(%{
          greeting: %{type: :string, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )

      assert is_binary(result.greeting)
    end
  end

  describe "model selection" do
    test "uses default model claude-sonnet-4-5-20250929" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )
    end

    test "accepts custom model override" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key, model: "claude-sonnet-4-5-20250929"],
                 max_retries: 2
               )
    end
  end

  describe "generate_stream/2 fallback" do
    test "falls back to buffered mode since Anthropic backend lacks streaming" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, stream} =
               ExOutlines.generate_stream(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key]
               )

      events = Enum.to_list(stream)

      refute events == []

      assert Enum.any?(events, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end

  describe "error handling" do
    test "invalid API key returns appropriate error" do
      schema = IntegrationTestHelper.simple_schema()

      result =
        ExOutlines.generate(schema,
          backend: Anthropic,
          backend_opts: [api_key: "sk-ant-invalid-key-12345"],
          max_retries: 1
        )

      assert {:error, _} = result
    end
  end

  describe "temperature and max_tokens configuration" do
    test "respects max_tokens configuration" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema =
        Schema.new(%{
          word: %{type: :string, required: true}
        })

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key, max_tokens: 100],
                 max_retries: 2
               )
    end

    test "respects temperature configuration" do
      api_key = IntegrationTestHelper.get_api_key("ANTHROPIC_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Anthropic,
                 backend_opts: [api_key: api_key, temperature: 0.0],
                 max_retries: 2
               )
    end
  end
end
