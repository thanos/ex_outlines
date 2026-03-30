Code.require_file("test_helper.exs", __DIR__)

defmodule ExOutlines.Integration.OllamaTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias ExOutlines.{Backend.Ollama, IntegrationTestHelper}
  alias ExOutlines.Spec.Schema

  @default_url "http://localhost:11434"
  @default_model "llama3"

  setup_all do
    IntegrationTestHelper.skip_without_ollama(@default_url)
    :ok
  end

  defp default_model do
    System.get_env("OLLAMA_MODEL") || @default_model
  end

  defp model_available?(model) do
    :inets.start()

    url = String.to_charlist("#{@default_url}/api/tags")

    case :httpc.request(:get, {url, []}, [timeout: 2000], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        check_model_in_response(body, model)

      _ ->
        false
    end
  end

  defp check_model_in_response(body, model) do
    case Jason.decode(to_string(body)) do
      {:ok, %{"models" => models}} ->
        Enum.any?(models, fn m -> String.starts_with?(m["name"], model) end)

      _ ->
        false
    end
  end

  defp skip_without_model(model) do
    unless model_available?(model) do
      throw({:skip_test, "Model '#{model}' not pulled in Ollama - run: ollama pull #{model}"})
    end
  end

  describe "generate/2 with Ollama backend" do
    test "returns valid output with simple schema" do
      model = default_model()
      skip_without_model(model)

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model],
                 max_retries: 2
               )

      assert is_binary(result.name)
      assert String.length(result.name) > 0
    end

    test "validates complex nested schema correctly" do
      model = default_model()
      skip_without_model(model)

      schema = IntegrationTestHelper.complex_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model],
                 max_retries: 2
               )

      assert is_binary(result.user.name)
      assert is_integer(result.user.age)
      assert result.user.age > 0
      assert is_binary(result.user.email)
      assert result.status in ["active", "inactive"]
    end
  end

  describe "call_llm_stream/2 streaming" do
    test "returns streaming events" do
      model = default_model()
      skip_without_model(model)

      messages = [%{role: "user", content: "Respond with just: {\"word\": \"hello\"}"}]

      assert {:ok, events} =
               Ollama.call_llm_stream(messages, model: model)

      assert is_list(events)
      refute events == []

      assert Enum.any?(events, fn
               {:chunk, _} -> true
               {:done, _} -> true
               _ -> false
             end)
    end

    test "accumulates chunks into final result" do
      model = default_model()
      skip_without_model(model)

      messages = [%{role: "user", content: "Respond with JSON: {\"num\": 42}"}]

      assert {:ok, events} =
               Ollama.call_llm_stream(messages, model: model)

      done_event =
        Enum.find(events, fn
          {:done, _} -> true
          _ -> false
        end)

      assert {:done, final_text} = done_event
      assert final_text != ""
    end
  end

  describe "JSON mode" do
    test "forces valid JSON output" do
      model = default_model()
      skip_without_model(model)

      schema =
        Schema.new(%{
          value: %{type: :integer, required: true}
        })

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model],
                 max_retries: 2
               )

      assert is_integer(result.value)
    end
  end

  describe "custom URL configuration" do
    test "accepts custom URL" do
      model = default_model()
      skip_without_model(model)

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model, url: @default_url <> "/api/chat"],
                 max_retries: 2
               )
    end
  end

  describe "error handling" do
    test "model not found returns appropriate error" do
      schema = IntegrationTestHelper.simple_schema()

      result =
        ExOutlines.generate(schema,
          backend: Ollama,
          backend_opts: [model: "nonexistent-model-xyz123"],
          max_retries: 1
        )

      assert {:error, _} = result
    end
  end

  describe "temperature configuration" do
    test "respects temperature configuration" do
      model = default_model()
      skip_without_model(model)

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model, temperature: 0.0],
                 max_retries: 2
               )
    end
  end
end
