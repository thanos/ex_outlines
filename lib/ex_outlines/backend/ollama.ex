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
    with {:ok, model} <- validate_model(opts),
         {:ok, url} <- validate_url(opts),
         {:ok, temperature} <- validate_temperature(opts),
         {:ok, max_tokens} <- validate_max_tokens(opts) do
      {:ok, %{model: model, url: url, temperature: temperature, max_tokens: max_tokens}}
    end
  end

  defp validate_model(opts) do
    case Keyword.get(opts, :model) do
      nil -> {:error, :missing_model}
      m when is_binary(m) -> {:ok, m}
      other -> {:error, {:invalid_model, other}}
    end
  end

  defp validate_url(opts) do
    url = Keyword.get(opts, :url, @default_url)
    if is_binary(url), do: {:ok, url}, else: {:error, {:invalid_url, url}}
  end

  defp validate_temperature(opts) do
    t = Keyword.get(opts, :temperature, @default_temperature)

    if is_number(t) and t >= 0.0 and t <= 2.0,
      do: {:ok, t},
      else: {:error, {:invalid_temperature, t}}
  end

  defp validate_max_tokens(opts) do
    case Keyword.get(opts, :max_tokens) do
      nil -> {:ok, nil}
      mt when is_integer(mt) and mt > 0 -> {:ok, mt}
      other -> {:error, {:invalid_max_tokens, other}}
    end
  end

  defp build_request_body(messages, config, opts) do
    with {:ok, formatted} <- format_messages(messages) do
      options = %{temperature: config.temperature}

      options =
        if config.max_tokens do
          Map.put(options, :num_predict, config.max_tokens)
        else
          options
        end

      body = %{
        model: config.model,
        messages: formatted,
        format: "json",
        stream: Keyword.get(opts, :stream, false),
        options: options
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
      types =
        Enum.map(unsupported, fn
          %{type: t} -> t
          _ -> :unknown
        end)

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
    {texts, images, unsupported} =
      Enum.reduce(parts, {[], [], []}, fn part, {texts, images, unsupported} ->
        case part do
          %{type: :text} -> {[part | texts], images, unsupported}
          %{type: :image_base64} -> {texts, [part | images], unsupported}
          other -> {texts, images, [other | unsupported]}
        end
      end)

    {Enum.reverse(texts), Enum.reverse(images), Enum.reverse(unsupported)}
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
