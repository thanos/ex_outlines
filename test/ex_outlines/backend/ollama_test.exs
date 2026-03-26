defmodule ExOutlines.Backend.OllamaTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Ollama
  alias ExOutlines.Spec.Schema

  defp fake_client(response) do
    test_pid = self()

    fn url, body ->
      send(test_pid, {:http_request, url, body})
      response
    end
  end

  defp success_response(json), do: {:ok, json}

  defp ollama_response(content) do
    Jason.encode!(%{
      "model" => "llama3",
      "message" => %{"role" => "assistant", "content" => content},
      "done" => true
    })
  end

  describe "configuration validation" do
    test "requires model" do
      assert {:error, :missing_model} = Ollama.call_llm([], [])
    end

    test "validates model is a string" do
      assert {:error, {:invalid_model, 123}} = Ollama.call_llm([], model: 123)
    end

    test "validates url is a string" do
      assert {:error, {:invalid_url, 123}} =
               Ollama.call_llm([], model: "llama3", url: 123)
    end

    test "validates temperature range" do
      assert {:error, {:invalid_temperature, 3.0}} =
               Ollama.call_llm([], model: "llama3", temperature: 3.0)

      assert {:error, {:invalid_temperature, -1.0}} =
               Ollama.call_llm([], model: "llama3", temperature: -1.0)
    end

    test "does not require api_key" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      result =
        Ollama.call_llm(
          [%{role: "user", content: "hi"}],
          model: "llama3",
          http_client: client
        )

      assert {:ok, _} = result
    end
  end

  describe "request building" do
    test "sends to default localhost URL" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      Ollama.call_llm([%{role: "user", content: "hi"}], model: "llama3", http_client: client)

      assert_receive {:http_request, url, _body}
      assert url == "http://localhost:11434/api/chat"
    end

    test "uses custom URL" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      Ollama.call_llm(
        [%{role: "user", content: "hi"}],
        model: "llama3",
        url: "http://gpu-server:11434/api/chat",
        http_client: client
      )

      assert_receive {:http_request, url, _body}
      assert url == "http://gpu-server:11434/api/chat"
    end

    test "includes model and format json in body" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      Ollama.call_llm([%{role: "user", content: "hi"}], model: "mistral", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      assert decoded["model"] == "mistral"
      assert decoded["format"] == "json"
      assert decoded["stream"] == false
    end

    test "includes temperature in options" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      Ollama.call_llm(
        [%{role: "user", content: "hi"}],
        model: "llama3",
        temperature: 0.8,
        http_client: client
      )

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      assert decoded["options"]["temperature"] == 0.8
    end

    test "formats messages correctly" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      messages = [
        %{role: "system", content: "Be helpful."},
        %{role: "user", content: "Hello"},
        %{role: "assistant", content: "Hi!"},
        %{role: "user", content: "Bye"}
      ]

      Ollama.call_llm(messages, model: "llama3", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)

      assert [
               %{"role" => "system", "content" => "Be helpful."},
               %{"role" => "user", "content" => "Hello"},
               %{"role" => "assistant", "content" => "Hi!"},
               %{"role" => "user", "content" => "Bye"}
             ] = decoded["messages"]
    end
  end

  describe "response parsing" do
    test "extracts content from successful response" do
      client = fake_client(success_response(ollama_response(~s({"name": "Alice"}))))

      assert {:ok, ~s({"name": "Alice"})} =
               Ollama.call_llm([%{role: "user", content: "hi"}],
                 model: "llama3",
                 http_client: client
               )
    end

    test "returns error for API error response" do
      json = Jason.encode!(%{"error" => "model 'bad' not found"})
      client = fake_client(success_response(json))

      assert {:error, {:api_error, "model 'bad' not found"}} =
               Ollama.call_llm([%{role: "user", content: "hi"}],
                 model: "bad",
                 http_client: client
               )
    end

    test "returns error for unexpected format" do
      client = fake_client(success_response(Jason.encode!(%{"unexpected" => true})))

      assert {:error, {:unexpected_response_format, _}} =
               Ollama.call_llm([%{role: "user", content: "hi"}],
                 model: "llama3",
                 http_client: client
               )
    end

    test "returns error for HTTP failure" do
      client = fake_client({:error, {:http_error, 500, "Internal Server Error"}})

      assert {:error, {:http_error, 500, "Internal Server Error"}} =
               Ollama.call_llm([%{role: "user", content: "hi"}],
                 model: "llama3",
                 http_client: client
               )
    end
  end

  describe "streaming" do
    test "parses newline-delimited stream response" do
      stream_response =
        [
          Jason.encode!(%{"message" => %{"content" => "{"}, "done" => false}),
          Jason.encode!(%{"message" => %{"content" => "\"name\":"}, "done" => false}),
          Jason.encode!(%{"message" => %{"content" => " \"Bob\"}"}, "done" => true})
        ]
        |> Enum.join("\n")

      client = fake_client(success_response(stream_response))

      {:ok, events} =
        Ollama.call_llm_stream([%{role: "user", content: "hi"}],
          model: "llama3",
          http_client: client
        )

      assert [
               {:chunk, "{"},
               {:chunk, "\"name\":"},
               {:done, "{\"name\": \"Bob\"}"}
             ] = events
    end

    test "sets stream: true in request body" do
      stream_response =
        Jason.encode!(%{"message" => %{"content" => "{}"}, "done" => true})

      client = fake_client(success_response(stream_response))

      Ollama.call_llm_stream([%{role: "user", content: "hi"}],
        model: "llama3",
        http_client: client
      )

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      assert decoded["stream"] == true
    end

    test "returns backend error on stream initialization failure" do
      client = fake_client({:error, {:http_request_failed, :econnrefused}})

      assert {:error, {:http_request_failed, :econnrefused}} =
               Ollama.call_llm_stream([%{role: "user", content: "hi"}],
                 model: "llama3",
                 http_client: client
               )
    end
  end

  describe "multimodal content" do
    test "passes base64 images in the images field" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      messages = [
        %{
          role: "user",
          content: [
            %{type: :text, text: "Describe this"},
            %{type: :image_base64, data: "abc123", media_type: "image/png"}
          ]
        }
      ]

      Ollama.call_llm(messages, model: "llava", http_client: client)

      assert_receive {:http_request, _url, body}
      decoded = Jason.decode!(body)
      [msg] = decoded["messages"]
      assert msg["content"] == "Describe this"
      assert msg["images"] == ["abc123"]
    end

    test "rejects unsupported content types" do
      client = fake_client(success_response(ollama_response(~s({"x":1}))))

      messages = [
        %{
          role: "user",
          content: [
            %{type: :text, text: "hi"},
            %{type: :image_url, url: "https://example.com/img.jpg"}
          ]
        }
      ]

      assert {:error, {:unsupported_content_types, [:image_url]}} =
               Ollama.call_llm(messages, model: "llama3", http_client: client)
    end
  end

  describe "stream error handling" do
    test "emits error for malformed JSON lines in stream" do
      stream_response =
        [
          Jason.encode!(%{"message" => %{"content" => "{"}, "done" => false}),
          "this is not json",
          Jason.encode!(%{"message" => %{"content" => "}"}, "done" => true})
        ]
        |> Enum.join("\n")

      client = fake_client(success_response(stream_response))

      {:ok, events} =
        Ollama.call_llm_stream([%{role: "user", content: "hi"}],
          model: "llama3",
          http_client: client
        )

      assert [{:chunk, "{"}, {:error, {:json_decode_error, _}}, {:done, _}] = events
    end
  end

  describe "integration" do
    test "works with ExOutlines.generate" do
      client = fake_client(success_response(ollama_response(~s({"name": "Alice"}))))
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:ok, %{name: "Alice"}} =
               ExOutlines.generate(schema,
                 backend: Ollama,
                 backend_opts: [model: "llama3", http_client: client],
                 max_retries: 1
               )
    end
  end
end
