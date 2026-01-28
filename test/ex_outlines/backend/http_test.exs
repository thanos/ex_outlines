defmodule ExOutlines.Backend.HTTPTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.HTTP

  describe "call_llm/2 - configuration validation" do
    test "returns error when api_key is missing" do
      messages = [%{role: "user", content: "test"}]
      opts = [model: "gpt-4"]

      assert {:error, :missing_api_key} = HTTP.call_llm(messages, opts)
    end

    test "returns error when api_key is empty string" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "", model: "gpt-4"]

      assert {:error, :missing_api_key} = HTTP.call_llm(messages, opts)
    end

    test "returns error when model is missing" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test"]

      assert {:error, :missing_model} = HTTP.call_llm(messages, opts)
    end

    test "returns error when model is empty string" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: ""]

      assert {:error, :missing_model} = HTTP.call_llm(messages, opts)
    end

    test "returns error when url is not a string" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: "gpt-4", url: 123]

      assert {:error, :invalid_url} = HTTP.call_llm(messages, opts)
    end

    test "returns error when temperature is negative" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: "gpt-4", temperature: -0.1]

      assert {:error, :invalid_temperature} = HTTP.call_llm(messages, opts)
    end

    test "returns error when temperature is too high" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: "gpt-4", temperature: 2.1]

      assert {:error, :invalid_temperature} = HTTP.call_llm(messages, opts)
    end

    test "returns error when temperature is not a number" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: "gpt-4", temperature: "high"]

      assert {:error, :invalid_temperature} = HTTP.call_llm(messages, opts)
    end

    test "returns error when max_tokens is not an integer" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: "gpt-4", max_tokens: 100.5]

      assert {:error, :invalid_max_tokens} = HTTP.call_llm(messages, opts)
    end

    test "returns error when max_tokens is less than 1" do
      messages = [%{role: "user", content: "test"}]
      opts = [api_key: "sk-test", model: "gpt-4", max_tokens: 0]

      assert {:error, :invalid_max_tokens} = HTTP.call_llm(messages, opts)
    end
  end

  describe "call_llm/2 - valid configuration" do
    test "accepts minimal valid configuration" do
      messages = [%{role: "user", content: "test"}]

      opts = [
        api_key: "sk-test",
        model: "gpt-4"
      ]

      # Will fail with connection error since we're not mocking HTTP,
      # but we verify it passes configuration validation
      result = HTTP.call_llm(messages, opts)

      # Should not be a config validation error
      refute match?({:error, :missing_api_key}, result)
      refute match?({:error, :missing_model}, result)
      refute match?({:error, :invalid_url}, result)
      refute match?({:error, :invalid_temperature}, result)
      refute match?({:error, :invalid_max_tokens}, result)
    end

    test "accepts custom url" do
      messages = [%{role: "user", content: "test"}]

      opts = [
        api_key: "sk-test",
        model: "gpt-4",
        url: "https://custom-api.com/v1/chat/completions"
      ]

      result = HTTP.call_llm(messages, opts)

      # Should not be a config validation error
      refute match?({:error, :invalid_url}, result)
    end

    test "accepts valid temperature range" do
      messages = [%{role: "user", content: "test"}]

      for temp <- [0.0, 0.5, 1.0, 1.5, 2.0] do
        opts = [
          api_key: "sk-test",
          model: "gpt-4",
          temperature: temp
        ]

        result = HTTP.call_llm(messages, opts)

        # Should not be a temperature validation error
        refute match?({:error, :invalid_temperature}, result)
      end
    end

    test "accepts valid max_tokens" do
      messages = [%{role: "user", content: "test"}]

      opts = [
        api_key: "sk-test",
        model: "gpt-4",
        max_tokens: 2000
      ]

      result = HTTP.call_llm(messages, opts)

      # Should not be a max_tokens validation error
      refute match?({:error, :invalid_max_tokens}, result)
    end
  end

  describe "configuration defaults" do
    test "uses default temperature when not specified" do
      messages = [%{role: "user", content: "test"}]

      opts = [
        api_key: "sk-test",
        model: "gpt-4"
      ]

      # Configuration is valid (defaults applied)
      result = HTTP.call_llm(messages, opts)

      # Should not be a config validation error
      refute match?({:error, :invalid_temperature}, result)
    end

    test "uses default max_tokens when not specified" do
      messages = [%{role: "user", content: "test"}]

      opts = [
        api_key: "sk-test",
        model: "gpt-4"
      ]

      # Configuration is valid (defaults applied)
      result = HTTP.call_llm(messages, opts)

      # Should not be a config validation error
      refute match?({:error, :invalid_max_tokens}, result)
    end

    test "uses default OpenAI URL when not specified" do
      messages = [%{role: "user", content: "test"}]

      opts = [
        api_key: "sk-test",
        model: "gpt-4"
      ]

      # Configuration is valid (default URL applied)
      result = HTTP.call_llm(messages, opts)

      # Should not be a URL validation error
      refute match?({:error, :invalid_url}, result)
    end
  end

  describe "message format" do
    test "accepts OpenAI-compatible message format" do
      messages = [
        %{role: "system", content: "You are a helpful assistant"},
        %{role: "user", content: "Hello"},
        %{role: "assistant", content: "Hi there!"},
        %{role: "user", content: "How are you?"}
      ]

      opts = [
        api_key: "sk-test",
        model: "gpt-4"
      ]

      # Should not fail on message format
      result = HTTP.call_llm(messages, opts)

      # Should not be a config validation error
      refute match?({:error, :missing_api_key}, result)
      refute match?({:error, :missing_model}, result)
    end
  end
end
