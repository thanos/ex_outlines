defmodule ExOutlines.Backend.GeminiTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Gemini
  alias ExOutlines.Spec.Schema

  # A fake HTTP client that captures the request and returns a configured response.
  defp fake_client(response) do
    test_pid = self()

    fn url, body ->
      send(test_pid, {:http_request, url, body})
      response
    end
  end

  defp success_response(json) when is_binary(json), do: {:ok, json}

  defp gemini_response(text) do
    Jason.encode!(%{
      "candidates" => [
        %{
          "content" => %{"parts" => [%{"text" => text}], "role" => "model"},
          "finishReason" => "STOP"
        }
      ]
    })
  end

  describe "configuration validation" do
    test "requires api_key" do
      assert {:error, :missing_api_key} = Gemini.call_llm([], [])
    end

    test "validates api_key is a string" do
      assert {:error, {:invalid_api_key, 12_345}} = Gemini.call_llm([], api_key: 12_345)
    end

    test "validates model is a string" do
      assert {:error, {:invalid_model, 123}} =
               Gemini.call_llm([], api_key: "test", model: 123)
    end

    test "validates max_tokens is positive integer" do
      assert {:error, {:invalid_max_tokens, -1}} =
               Gemini.call_llm([], api_key: "test", max_tokens: -1)
    end

    test "validates max_tokens is integer" do
      assert {:error, {:invalid_max_tokens, "100"}} =
               Gemini.call_llm([], api_key: "test", max_tokens: "100")
    end

    test "validates temperature is in range 0.0-2.0" do
      assert {:error, {:invalid_temperature, 2.5}} =
               Gemini.call_llm([], api_key: "test", temperature: 2.5)
    end

    test "validates temperature is not negative" do
      assert {:error, {:invalid_temperature, -0.1}} =
               Gemini.call_llm([], api_key: "test", temperature: -0.1)
    end
  end

  describe "request building" do
    test "builds correct URL with API key and model" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      Gemini.call_llm(
        [%{role: "user", content: "hi"}],
        api_key: "AIza-test-key",
        model: "gemini-1.5-pro",
        http_client: client
      )

      assert_receive {:http_request, url, _body}
      assert url =~ "gemini-1.5-pro:generateContent"
      assert url =~ "key=AIza-test-key"
    end

    test "URL-encodes API key" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      Gemini.call_llm(
        [%{role: "user", content: "hi"}],
        api_key: "key+with/special=chars",
        http_client: client
      )

      assert_receive {:http_request, url, _body}
      assert url =~ "key%2Bwith%2Fspecial%3Dchars"
    end

    test "formats messages with system instruction" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      messages = [
        %{role: "system", content: "Be helpful."},
        %{role: "user", content: "Hello"}
      ]

      Gemini.call_llm(messages, api_key: "test", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      assert decoded["systemInstruction"] == %{"parts" => [%{"text" => "Be helpful."}]}
      assert [%{"role" => "user", "parts" => [%{"text" => "Hello"}]}] = decoded["contents"]
    end

    test "formats messages without system instruction" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      messages = [%{role: "user", content: "Hello"}]
      Gemini.call_llm(messages, api_key: "test", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      refute Map.has_key?(decoded, "systemInstruction")
    end

    test "maps assistant role to model" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      messages = [
        %{role: "user", content: "Hi"},
        %{role: "assistant", content: "Hello!"},
        %{role: "user", content: "Bye"}
      ]

      Gemini.call_llm(messages, api_key: "test", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      roles = Enum.map(decoded["contents"], & &1["role"])
      assert roles == ["user", "model", "user"]
    end

    test "includes generation config" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      Gemini.call_llm(
        [%{role: "user", content: "hi"}],
        api_key: "test",
        max_tokens: 512,
        temperature: 0.7,
        http_client: client
      )

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      assert decoded["generationConfig"]["maxOutputTokens"] == 512
      assert decoded["generationConfig"]["temperature"] == 0.7
    end

    test "formats multimodal content parts" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      messages = [
        %{
          role: "user",
          content: [
            %{type: :text, text: "Describe this"},
            %{type: :image_base64, data: "abc123", media_type: "image/png"},
            %{type: :image_url, url: "https://example.com/img.jpg"}
          ]
        }
      ]

      Gemini.call_llm(messages, api_key: "test", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      [msg] = decoded["contents"]
      parts = msg["parts"]
      assert Enum.at(parts, 0) == %{"text" => "Describe this"}

      assert Enum.at(parts, 1) == %{
               "inlineData" => %{"mimeType" => "image/png", "data" => "abc123"}
             }

      assert Enum.at(parts, 2) == %{"fileData" => %{"fileUri" => "https://example.com/img.jpg"}}
    end
  end

  describe "response parsing" do
    test "extracts text from successful response" do
      response_json = gemini_response(~s({"name": "Alice"}))
      client = fake_client(success_response(response_json))

      assert {:ok, ~s({"name": "Alice"})} =
               Gemini.call_llm([%{role: "user", content: "hi"}],
                 api_key: "test",
                 http_client: client
               )
    end

    test "returns error for non-STOP finish reason" do
      json =
        Jason.encode!(%{
          "candidates" => [
            %{"finishReason" => "SAFETY", "content" => %{"parts" => [%{"text" => "blocked"}]}}
          ]
        })

      client = fake_client(success_response(json))

      assert {:error, {:generation_stopped, "SAFETY"}} =
               Gemini.call_llm([%{role: "user", content: "hi"}],
                 api_key: "test",
                 http_client: client
               )
    end

    test "returns error for API error response" do
      json =
        Jason.encode!(%{"error" => %{"message" => "Invalid key", "status" => "INVALID_ARGUMENT"}})

      client = fake_client(success_response(json))

      assert {:error, {:api_error, "INVALID_ARGUMENT", "Invalid key"}} =
               Gemini.call_llm([%{role: "user", content: "hi"}],
                 api_key: "test",
                 http_client: client
               )
    end

    test "returns error for unexpected response format" do
      client = fake_client(success_response(Jason.encode!(%{"unexpected" => true})))

      assert {:error, {:unexpected_response_format, _}} =
               Gemini.call_llm([%{role: "user", content: "hi"}],
                 api_key: "test",
                 http_client: client
               )
    end

    test "returns error for HTTP failure" do
      client = fake_client({:error, {:http_error, 500, "Internal Server Error"}})

      assert {:error, {:http_error, 500, "Internal Server Error"}} =
               Gemini.call_llm([%{role: "user", content: "hi"}],
                 api_key: "test",
                 http_client: client
               )
    end
  end

  describe "integration behavior" do
    test "works with ExOutlines.generate when configured" do
      response_json = gemini_response(~s({"name": "Alice"}))
      client = fake_client(success_response(response_json))
      schema = Schema.new(%{name: %{type: :string, required: true}})

      result =
        ExOutlines.generate(schema,
          backend: Gemini,
          backend_opts: [api_key: "test", http_client: client],
          max_retries: 1
        )

      assert {:ok, %{name: "Alice"}} = result
    end
  end

  describe "default values" do
    test "uses default model gemini-2.0-flash" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      Gemini.call_llm([%{role: "user", content: "hi"}], api_key: "test", http_client: client)

      assert_receive {:http_request, url, _body}
      assert url =~ "gemini-2.0-flash:generateContent"
    end

    test "uses default max_tokens 1024 and temperature 0.0" do
      client = fake_client(success_response(gemini_response(~s({"x":1}))))

      Gemini.call_llm([%{role: "user", content: "hi"}], api_key: "test", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      assert decoded["generationConfig"]["maxOutputTokens"] == 1024
      assert decoded["generationConfig"]["temperature"] == 0.0
    end
  end
end
