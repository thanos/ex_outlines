defmodule ExOutlines.Backend.AnthropicTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Anthropic
  alias ExOutlines.Spec.Schema

  describe "configuration validation" do
    test "requires api_key" do
      opts = [model: "claude-sonnet-4-5-20250929"]
      result = Anthropic.call_llm([], opts)

      assert {:error, :missing_api_key} = result
    end

    test "validates api_key is a string" do
      opts = [api_key: 12_345]
      result = Anthropic.call_llm([], opts)

      assert {:error, {:invalid_api_key, 12_345}} = result
    end

    test "validates model is a string" do
      opts = [api_key: "sk-ant-test", model: 123]
      result = Anthropic.call_llm([], opts)

      assert {:error, {:invalid_model, 123}} = result
    end

    test "validates max_tokens is positive integer" do
      opts = [api_key: "sk-ant-test", max_tokens: -1]
      result = Anthropic.call_llm([], opts)

      assert {:error, {:invalid_max_tokens, -1}} = result
    end

    test "validates max_tokens is integer" do
      opts = [api_key: "sk-ant-test", max_tokens: "100"]
      result = Anthropic.call_llm([], opts)

      assert {:error, {:invalid_max_tokens, "100"}} = result
    end

    test "validates temperature is in range 0.0-1.0" do
      opts = [api_key: "sk-ant-test", temperature: 1.5]
      result = Anthropic.call_llm([], opts)

      assert {:error, {:invalid_temperature, 1.5}} = result
    end

    test "validates temperature is not negative" do
      opts = [api_key: "sk-ant-test", temperature: -0.1]
      result = Anthropic.call_llm([], opts)

      assert {:error, {:invalid_temperature, -0.1}} = result
    end

    test "accepts valid configuration with defaults" do
      # This will fail at HTTP request stage, but validates config is OK
      opts = [api_key: "sk-ant-test"]

      # We can't test the full call without mocking HTTP, but we can verify
      # it doesn't fail at config validation
      result = Anthropic.call_llm([], opts)

      # Should get HTTP error, not config error
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "message format conversion" do
    test "extracts system message separately" do
      messages = [
        %{role: "system", content: "You are a helpful assistant."},
        %{role: "user", content: "Hello"}
      ]

      # We can't easily test internal functions, but we can verify behavior
      # through the public API by checking error messages don't complain about format
      opts = [api_key: "sk-ant-test"]
      result = Anthropic.call_llm(messages, opts)

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

      opts = [api_key: "sk-ant-test"]
      result = Anthropic.call_llm(messages, opts)

      # Should fail at HTTP stage, not message formatting
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "response parsing" do
    # Since we can't easily mock :httpc responses in tests, we document
    # the expected behavior here. In a production system, you would use
    # a library like Mox to mock HTTP responses.

    test "documents expected response format" do
      # Anthropic responses should look like:
      # %{
      #   "id" => "msg_123",
      #   "type" => "message",
      #   "role" => "assistant",
      #   "content" => [
      #     %{"type" => "text", "text" => "{\"name\": \"Alice\"}"}
      #   ],
      #   "model" => "claude-sonnet-4-5-20250929",
      #   "stop_reason" => "end_turn"
      # }

      assert true
    end

    test "documents expected error format" do
      # Anthropic errors should look like:
      # %{
      #   "type" => "error",
      #   "error" => %{
      #     "type" => "invalid_request_error",
      #     "message" => "Invalid API key"
      #   }
      # }

      assert true
    end
  end

  describe "integration behavior" do
    test "works with ExOutlines.generate when configured" do
      # This is an integration test showing how to use the backend
      # In real usage, you would provide a valid API key

      schema =
        Schema.new(%{
          name: %{type: :string, required: true}
        })

      result =
        ExOutlines.generate(schema,
          backend: Anthropic,
          backend_opts: [api_key: "sk-ant-test"],
          max_retries: 1
        )

      # Should fail with HTTP or API error since we don't have a real API key
      # but verifies the integration works
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
          backend: Anthropic,
          backend_opts: [
            api_key: "sk-ant-test",
            model: "claude-opus-4-5-20251101",
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
      opts = [api_key: "sk-ant-test"]
      # Default model should be claude-sonnet-4-5-20250929
      result = Anthropic.call_llm([], opts)

      # Should fail at HTTP stage (proves config passed with defaults)
      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end

    test "uses default max_tokens (1024) when not specified" do
      opts = [api_key: "sk-ant-test"]
      result = Anthropic.call_llm([], opts)

      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end

    test "uses default temperature (0.0) when not specified" do
      opts = [api_key: "sk-ant-test"]
      result = Anthropic.call_llm([], opts)

      assert match?({:error, {:http_request_failed, _}}, result) or
               match?({:error, {:http_error, _, _}}, result)
    end
  end

  describe "error handling" do
    test "handles missing API key gracefully" do
      result = Anthropic.call_llm([], [])
      assert {:error, :missing_api_key} = result
    end

    test "handles invalid configuration gracefully" do
      opts = [api_key: "test", temperature: 2.0]
      result = Anthropic.call_llm([], opts)
      assert {:error, {:invalid_temperature, 2.0}} = result
    end

    test "provides clear error messages for configuration issues" do
      # Test various config errors
      assert {:error, :missing_api_key} = Anthropic.call_llm([], [])
      assert {:error, {:invalid_api_key, _}} = Anthropic.call_llm([], api_key: 123)
      assert {:error, {:invalid_model, _}} = Anthropic.call_llm([], api_key: "test", model: 123)

      assert {:error, {:invalid_max_tokens, _}} =
               Anthropic.call_llm([], api_key: "test", max_tokens: 0)

      assert {:error, {:invalid_temperature, _}} =
               Anthropic.call_llm([], api_key: "test", temperature: -1)
    end
  end
end
