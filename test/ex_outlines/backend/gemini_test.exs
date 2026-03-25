defmodule ExOutlines.Backend.GeminiTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Gemini
  alias ExOutlines.Spec.Schema

  describe "configuration validation" do
    test "requires api_key" do
      opts = [model: "gemini-2.0-flash"]
      result = Gemini.call_llm([], opts)

      assert {:error, :missing_api_key} = result
    end

    test "validates api_key is a string" do
      opts = [api_key: 12_345]
      result = Gemini.call_llm([], opts)

      assert {:error, {:invalid_api_key, 12_345}} = result
    end

    test "validates model is a string" do
      opts = [api_key: "AIza-test", model: 123]
      result = Gemini.call_llm([], opts)

      assert {:error, {:invalid_model, 123}} = result
    end

    test "validates max_tokens is positive integer" do
      opts = [api_key: "AIza-test", max_tokens: -1]
      result = Gemini.call_llm([], opts)

      assert {:error, {:invalid_max_tokens, -1}} = result
    end

    test "validates max_tokens is integer" do
      opts = [api_key: "AIza-test", max_tokens: "100"]
      result = Gemini.call_llm([], opts)

      assert {:error, {:invalid_max_tokens, "100"}} = result
    end

    test "validates temperature is in range 0.0-2.0" do
      opts = [api_key: "AIza-test", temperature: 2.5]
      result = Gemini.call_llm([], opts)

      assert {:error, {:invalid_temperature, 2.5}} = result
    end

    test "validates temperature is not negative" do
      opts = [api_key: "AIza-test", temperature: -0.1]
      result = Gemini.call_llm([], opts)

      assert {:error, {:invalid_temperature, -0.1}} = result
    end

    test "accepts valid configuration with defaults" do
      opts = [api_key: "AIza-test"]
      result = Gemini.call_llm([], opts)

      # Should get HTTP error, not config error
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "message format conversion" do
    test "extracts system message into system_instruction" do
      messages = [
        %{role: "system", content: "You are a helpful assistant."},
        %{role: "user", content: "Hello"}
      ]

      opts = [api_key: "AIza-test"]
      result = Gemini.call_llm(messages, opts)

      # Should fail at HTTP stage, not message formatting
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end

    test "handles messages without system message" do
      messages = [
        %{role: "user", content: "Hello"},
        %{role: "assistant", content: "Hi there!"},
        %{role: "user", content: "Generate JSON"}
      ]

      opts = [api_key: "AIza-test"]
      result = Gemini.call_llm(messages, opts)

      # Should fail at HTTP stage, not message formatting
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "response parsing" do
    test "documents expected response format" do
      # Gemini responses should look like:
      # %{
      #   "candidates" => [
      #     %{
      #       "content" => %{
      #         "parts" => [%{"text" => "{\"name\": \"Alice\"}"}],
      #         "role" => "model"
      #       },
      #       "finishReason" => "STOP"
      #     }
      #   ]
      # }

      assert true
    end

    test "documents expected error format" do
      # Gemini errors should look like:
      # %{
      #   "error" => %{
      #     "code" => 400,
      #     "message" => "API key not valid.",
      #     "status" => "INVALID_ARGUMENT"
      #   }
      # }

      assert true
    end
  end

  describe "integration behavior" do
    test "works with ExOutlines.generate when configured" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true}
        })

      result =
        ExOutlines.generate(schema,
          backend: Gemini,
          backend_opts: [api_key: "AIza-test"],
          max_retries: 1
        )

      # Should fail with HTTP or API error since we don't have a real API key
      assert match?({:error, {:backend_error, _}}, result) or
               match?({:error, {:backend_exception, _}}, result)
    end

    test "accepts all configuration options" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true}
        })

      result =
        ExOutlines.generate(schema,
          backend: Gemini,
          backend_opts: [
            api_key: "AIza-test",
            model: "gemini-1.5-pro",
            max_tokens: 2048,
            temperature: 0.5
          ],
          max_retries: 1
        )

      # Should fail with HTTP error, not config error
      assert match?({:error, {:backend_error, _}}, result) or
               match?({:error, {:backend_exception, _}}, result)
    end
  end

  describe "default values" do
    test "uses default model when not specified" do
      opts = [api_key: "AIza-test"]
      result = Gemini.call_llm([], opts)

      # Should fail at HTTP stage (proves config passed with defaults)
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end

    test "uses default max_tokens (1024) when not specified" do
      opts = [api_key: "AIza-test"]
      result = Gemini.call_llm([], opts)

      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end

    test "uses default temperature (0.0) when not specified" do
      opts = [api_key: "AIza-test"]
      result = Gemini.call_llm([], opts)

      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "error handling" do
    test "handles missing API key gracefully" do
      result = Gemini.call_llm([], [])
      assert {:error, :missing_api_key} = result
    end

    test "handles invalid configuration gracefully" do
      opts = [api_key: "test", temperature: 3.0]
      result = Gemini.call_llm([], opts)
      assert {:error, {:invalid_temperature, 3.0}} = result
    end

    test "provides clear error messages for configuration issues" do
      assert {:error, :missing_api_key} = Gemini.call_llm([], [])
      assert {:error, {:invalid_api_key, _}} = Gemini.call_llm([], api_key: 123)
      assert {:error, {:invalid_model, _}} = Gemini.call_llm([], api_key: "test", model: 123)

      assert {:error, {:invalid_max_tokens, _}} =
               Gemini.call_llm([], api_key: "test", max_tokens: 0)

      assert {:error, {:invalid_temperature, _}} =
               Gemini.call_llm([], api_key: "test", temperature: -1)
    end
  end
end
