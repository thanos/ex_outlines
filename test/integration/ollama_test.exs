Code.require_file("test_helper.exs", __DIR__)

defmodule ExOutlines.Integration.OllamaTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias ExOutlines.{Backend.Ollama, IntegrationTestHelper}
  alias ExOutlines.Spec.Schema

  @default_url "http://localhost:11434"
  @preferred_models [
    "llama3.2",
    "llama3.1",
    "llama3",
    "llama2",
    "mistral",
    "mistral:latest",
    "gemma2",
    "gemma",
    "phi3",
    "qwen2"
  ]

  setup_all do
    IntegrationTestHelper.skip_without_ollama(@default_url)
    :ok
  end

  defp get_available_models do
    :inets.start()

    url = String.to_charlist("#{@default_url}/api/tags")

    case :httpc.request(:get, {url, []}, [timeout: 2000], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        parse_models_response(body)

      _ ->
        []
    end
  end

  defp parse_models_response(body) do
    case Jason.decode(to_string(body)) do
      {:ok, %{"models" => models}} ->
        Enum.map(models, fn m -> m["name"] end)

      _ ->
        []
    end
  end

  defp find_available_model do
    available = get_available_models()

    cond do
      env_model = System.get_env("OLLAMA_MODEL") ->
        if Enum.any?(available, &String.starts_with?(&1, env_model)) do
          env_model
        else
          nil
        end

      model = find_preferred_model(available) ->
        model

      available != [] ->
        hd(available)

      true ->
        nil
    end
  end

  defp find_preferred_model(available) do
    Enum.find(@preferred_models, fn preferred ->
      Enum.any?(available, &String.starts_with?(&1, preferred))
    end)
  end

  defp skip_without_available_model do
    case find_available_model() do
      nil ->
        available = get_available_models()

        message =
          if available == [] do
            "No models found in Ollama - run: ollama pull llama3"
          else
            "No suitable model found. Available: #{inspect(available)}"
          end

        throw({:skip_test, message})

      model ->
        model
    end
  end

  describe "generate/2 with Ollama backend" do
    test "returns valid output with simple schema" do
      model = skip_without_available_model()

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

    test "validates complex schema correctly" do
      model = skip_without_available_model()

      schema = IntegrationTestHelper.complex_schema()

      assert {:ok, result} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model],
                 max_retries: 2
               )

      assert is_binary(result.username)
      assert is_integer(result.age)
      assert result.age >= 0
      assert result.status in ["active", "inactive"]
    end
  end

  describe "call_llm_stream/2 streaming" do
    test "returns streaming events" do
      model = skip_without_available_model()

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
      model = skip_without_available_model()

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
      model = skip_without_available_model()

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
      model = skip_without_available_model()

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
      model = skip_without_available_model()

      schema = IntegrationTestHelper.simple_schema()

      assert {:ok, _} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: model, temperature: 0.0],
                 max_retries: 2
               )
    end
  end

  describe "model detection" do
    test "lists available models" do
      models = get_available_models()
      refute models == [], "No models found in Ollama"
    end
  end
end
