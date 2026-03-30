Code.require_file("test_helper.exs", __DIR__)

defmodule ExOutlines.Integration.GeminiTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias ExOutlines.{Backend.Gemini, IntegrationTestHelper}
  alias ExOutlines.Spec.Schema

  setup_all do
    IntegrationTestHelper.skip_without_api_key("GEMINI_API_KEY")
    :ok
  end

  describe "generate/2 with Gemini backend" do
    test "returns valid output with basic schema" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )

      assert is_binary(result.name)
      assert String.length(result.name) > 0
    end

    test "validates complex schema correctly" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema = IntegrationTestHelper.complex_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )

      assert is_binary(result.username)
      assert is_integer(result.age)
      assert result.age >= 0
      assert result.status in ["active", "inactive"]
    end

    test "system instruction is correctly formatted" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema =
        Schema.new(%{
          response: %{type: :string, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )

      assert is_binary(result.response)
    end
  end

  describe "model selection" do
    test "uses default model gemini-2.0-flash" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )
    end

    test "accepts custom model override" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key, model: "gemini-2.0-flash"],
                 max_retries: 2
               )
    end
  end

  describe "role conversion" do
    test "assistant role is converted to model for Gemini API" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema =
        Schema.new(%{
          answer: %{type: :string, required: true}
        })

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key],
                 max_retries: 2
               )
    end
  end

  describe "error handling" do
    test "invalid API key returns appropriate error" do
      schema = IntegrationTestHelper.simple_schema()

      result =
        ExOutlines.generate(schema,
          backend: Gemini,
          backend_opts: [api_key: "invalid-gemini-key-12345"],
          max_retries: 1
        )

      assert {:error, _} = result
    end
  end

  describe "temperature and max_tokens configuration" do
    test "respects max_tokens configuration" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema =
        Schema.new(%{
          word: %{type: :string, required: true}
        })

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key, max_tokens: 100],
                 max_retries: 2
               )
    end

    test "respects temperature configuration" do
      api_key = IntegrationTestHelper.get_api_key("GEMINI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Gemini,
                 backend_opts: [api_key: api_key, temperature: 0.0],
                 max_retries: 2
               )
    end
  end
end
