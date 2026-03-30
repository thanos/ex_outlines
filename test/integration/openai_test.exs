Code.require_file("test_helper.exs", __DIR__)

defmodule ExOutlines.Integration.OpenAITest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias ExOutlines.{Backend.HTTP, IntegrationTestHelper}
  alias ExOutlines.Spec.Schema

  setup_all do
    IntegrationTestHelper.skip_without_api_key("OPENAI_API_KEY")
    :ok
  end

  describe "generate/2 with HTTP backend (OpenAI)" do
    test "returns valid output with simple string schema" do
      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"],
                 max_retries: 2
               )

      assert is_binary(result.name)
      assert String.length(result.name) > 0
    end

    test "validates complex schema correctly" do
      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema = IntegrationTestHelper.complex_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"],
                 max_retries: 2
               )

      assert is_binary(result.username)
      assert is_integer(result.age)
      assert result.age >= 0
      assert result.status in ["active", "inactive"]
    end

    test "enum constraint is respected" do
      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema = IntegrationTestHelper.enum_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"],
                 max_retries: 2
               )

      assert result.role in ["admin", "user", "guest"]
    end

    test "temperature 0.0 produces deterministic outputs" do
      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema =
        Schema.new(%{
          answer: %{type: :string, required: true}
        })

      opts = [
        backend: HTTP,
        backend_opts: [api_key: api_key, model: "gpt-4o-mini", temperature: 0.0],
        max_retries: 2
      ]

      assert {:ok, result1} = ExOutlines.generate(schema, opts)
      assert {:ok, result2} = ExOutlines.generate(schema, opts)

      assert result1.answer == result2.answer
    end
  end

  describe "generate_stream/2 with HTTP backend" do
    test "emits chunks and final validated result" do
      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, stream} =
               ExOutlines.generate_stream(schema,
                 backend: HTTP,
                 backend_opts: [api_key: api_key, model: "gpt-4o-mini"]
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
          backend: HTTP,
          backend_opts: [api_key: "sk-invalid-key-12345", model: "gpt-4o-mini"],
          max_retries: 1
        )

      assert {:error, _} = result
    end
  end

  describe "custom OpenAI-compatible endpoints" do
    test "accepts custom URL configuration" do
      api_key = IntegrationTestHelper.get_api_key("OPENAI_API_KEY")

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: HTTP,
                 backend_opts: [
                   api_key: api_key,
                   model: "gpt-4o-mini",
                   url: "https://api.openai.com/v1/chat/completions"
                 ],
                 max_retries: 2
               )
    end
  end
end
