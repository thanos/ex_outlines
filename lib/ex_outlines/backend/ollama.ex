defmodule ExOutlines.Backend.Ollama do
  @moduledoc """
  Native Ollama backend for local model inference.

  Implements the ExOutlines.Backend behavior for direct integration with
  Ollama's chat API. No API key required.

  ## Configuration

  - `:model` (required) - Model name (e.g., "llama3", "mistral", "codellama")
  - `:url` (optional) - Ollama API URL (default: "http://localhost:11434/api/chat")
  - `:temperature` (optional) - Temperature for generation (default: 0.0)

  ## Example

      ExOutlines.generate(schema,
        backend: ExOutlines.Backend.Ollama,
        backend_opts: [
          model: "llama3",
          temperature: 0.0
        ]
      )

  ## JSON Mode

  Ollama supports a `format: "json"` parameter that forces JSON output,
  improving first-attempt success rates for structured generation.
  This is enabled by default.

  ## Multimodal Support

  Ollama supports images via the `images` field for vision-capable models
  (e.g., llava). When content parts include `:image_base64`, the base64
  data is passed in the `images` array alongside the text content.
  `:image_url` parts are not supported by Ollama and will be rejected.
  """

  @behaviour ExOutlines.Backend

  @default_url "http://localhost:11434/api/chat"
  @default_temperature 0.0

  @impl true
  def call_llm(messages, opts) do
    http_client = Keyword.get(opts, :http_client)

    with {:ok, config} <- validate_config(opts),
         {:ok, body} <- build_request_body(messages, config, stream: false),
         {:ok, response} <- do_request(config.url, body, http_client) do
      parse_response(response)
    end
  end

  @impl true
  def call_llm_stream(messages, opts) do
    http_client = Keyword.get(opts, :http_client)

    with {:ok, config} <- validate_config(opts),
         {:ok, body} <- build_request_body(messages, config, stream: true),
         {:ok, response} <- do_request(config.url, body, http_client) do
      parse_stream_response(response)
    end
  end

  defp validate_config(opts) do
    model = Keyword.get(opts, :model)
    url = Keyword.get(opts, :url, @default_url)
    temperature = Keyword.get(opts, :temperature, @default_temperature)

    cond do
      is_nil(model) ->
        {:error, :missing_model}

      not is_binary(model) ->
        {:error, {:invalid_model, model}}

      not is_binary(url) ->
        {:error, {:invalid_url, url}}

      not is_number(temperature) or temperature < 0.0 or temperature > 2.0 ->
        {:error, {:invalid_temperature, temperature}}

      true ->
        {:ok, %{model: model, url: url, temperature: temperature}}
    end
  end

  defp build_request_body(messages, config, opts) do
    with {:ok, formatted} <- format_messages(messages) do
      body = %{
        model: config.model,
        messages: formatted,
        format: "json",
        stream: Keyword.get(opts, :stream, false),
        options: %{temperature: config.temperature}
      }

      Jason.encode(body)
    end
  end

  defp format_messages(messages) do
    results = Enum.map(messages, &format_message/1)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, msg} -> msg end)}
      error -> error
    end
  end

  defp format_message(%{role: role, content: content}) when is_binary(content) do
    {:ok, %{role: role, content: content}}
  end

  defp format_message(%{role: role, content: parts}) when is_list(parts) do
    {text_parts, image_parts, unsupported} = classify_parts(parts)

    if unsupported != [] do
      types = Enum.map(unsupported, & &1.type)
      {:error, {:unsupported_content_types, types}}
    else
      text = Enum.map_join(text_parts, "\n", fn %{text: t} -> t end)
      images = Enum.map(image_parts, fn %{data: data} -> data end)

      msg = %{role: role, content: text}
      msg = if images == [], do: msg, else: Map.put(msg, :images, images)
      {:ok, msg}
    end
  end

  defp classify_parts(parts) do
    Enum.reduce(parts, {[], [], []}, fn part, {texts, images, unsupported} ->
      case part do
        %{type: :text} -> {texts ++ [part], images, unsupported}
        %{type: :image_base64} -> {texts, images ++ [part], unsupported}
        other -> {texts, images, unsupported ++ [other]}
      end
    end)
  end

  defp do_request(url, body, nil), do: make_request(url, body)

  defp do_request(url, body, http_client) when is_function(http_client, 2) do
    http_client.(url, body)
  end

  defp make_request(url, body) do
    :inets.start()
    :ssl.start()

    headers = [{~c"content-type", ~c"application/json"}]

    http_options =
      if String.starts_with?(url, "https") do
        [
          ssl: [
            verify: :verify_peer,
            cacerts: :public_key.cacerts_get(),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ]
          ],
          timeout: 120_000,
          connect_timeout: 10_000
        ]
      else
        [timeout: 120_000, connect_timeout: 10_000]
      end

    request = {
      String.to_charlist(url),
      headers,
      ~c"application/json",
      body
    }

    case :httpc.request(:post, request, http_options, body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, response_body}} ->
        {:ok, response_body}

      {:ok, {{_version, status_code, _reason}, _headers, response_body}} ->
        {:error, {:http_error, status_code, response_body}}

      {:error, reason} ->
        {:error, {:http_request_failed, reason}}
    end
  end

  defp parse_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, %{"message" => %{"content" => content}}} ->
        {:ok, content}

      {:ok, %{"error" => error}} ->
        {:error, {:api_error, error}}

      {:ok, unexpected} ->
        {:error, {:unexpected_response_format, unexpected}}

      {:error, error} ->
        {:error, {:json_decode_error, error}}
    end
  end

  defp parse_stream_response(response_body) do
    {rev_events, _acc} =
      response_body
      |> String.split("\n", trim: true)
      |> Enum.reduce({[], ""}, fn line, {events, acc} ->
        case Jason.decode(line) do
          {:ok, %{"done" => true, "message" => %{"content" => content}}} ->
            full_text = acc <> content
            {[{:done, full_text} | events], full_text}

          {:ok, %{"done" => true}} ->
            {[{:done, acc} | events], acc}

          {:ok, %{"message" => %{"content" => content}}} ->
            {[{:chunk, content} | events], acc <> content}

          {:ok, %{"error" => error}} ->
            {[{:error, {:api_error, error}} | events], acc}

          {:error, decode_error} ->
            {[{:error, {:json_decode_error, decode_error}} | events], acc}
        end
      end)

    {:ok, Enum.reverse(rev_events)}
  end
end
