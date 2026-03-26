defmodule ExOutlines.Backend.Gemini do
  @moduledoc """
  Native Google Gemini API backend.

  Implements the ExOutlines.Backend behavior for direct integration with
  Google's Gemini API.

  ## Configuration

  - `:api_key` (required) - Google AI API key
  - `:model` (optional) - Model to use (default: "gemini-2.0-flash")
  - `:max_tokens` (optional) - Maximum tokens to generate (default: 1024)
  - `:temperature` (optional) - Temperature for generation (default: 0.0)

  ## Example

      ExOutlines.generate(schema,
        backend: ExOutlines.Backend.Gemini,
        backend_opts: [
          api_key: "AIza...",
          model: "gemini-2.0-flash",
          max_tokens: 2048,
          temperature: 0.0
        ]
      )
  """

  @behaviour ExOutlines.Backend

  @default_model "gemini-2.0-flash"
  @default_max_tokens 1024
  @default_temperature 0.0
  @api_base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @impl true
  def call_llm(messages, opts) do
    http_client = Keyword.get(opts, :http_client)

    with {:ok, config} <- validate_config(opts),
         {:ok, body} <- build_request_body(messages, config),
         {:ok, response} <- do_request(config, body, http_client) do
      parse_response(response)
    end
  end

  defp validate_config(opts) do
    api_key = Keyword.get(opts, :api_key)
    model = Keyword.get(opts, :model, @default_model)
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    temperature = Keyword.get(opts, :temperature, @default_temperature)

    cond do
      is_nil(api_key) ->
        {:error, :missing_api_key}

      not is_binary(api_key) ->
        {:error, {:invalid_api_key, api_key}}

      not is_binary(model) ->
        {:error, {:invalid_model, model}}

      not is_integer(max_tokens) or max_tokens <= 0 ->
        {:error, {:invalid_max_tokens, max_tokens}}

      not is_number(temperature) or temperature < 0.0 or temperature > 2.0 ->
        {:error, {:invalid_temperature, temperature}}

      true ->
        {:ok,
         %{
           api_key: api_key,
           model: model,
           max_tokens: max_tokens,
           temperature: temperature
         }}
    end
  end

  defp build_request_body(messages, config) do
    {system_instruction, conversation_messages} = extract_system_message(messages)

    body_map = %{
      contents: format_contents(conversation_messages),
      generationConfig: %{
        maxOutputTokens: config.max_tokens,
        temperature: config.temperature
      }
    }

    body_map =
      if system_instruction do
        Map.put(body_map, :systemInstruction, %{parts: [%{text: system_instruction}]})
      else
        body_map
      end

    Jason.encode(body_map)
  end

  defp extract_system_message(messages) do
    case Enum.find(messages, fn msg -> msg.role == "system" end) do
      nil ->
        {nil, messages}

      system_msg ->
        remaining = Enum.reject(messages, fn msg -> msg.role == "system" end)
        {system_msg.content, remaining}
    end
  end

  defp format_contents(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: gemini_role(msg.role),
        parts: format_parts(msg.content)
      }
    end)
  end

  defp format_parts(content) when is_binary(content) do
    [%{text: content}]
  end

  defp format_parts(parts) when is_list(parts) do
    Enum.map(parts, &format_content_part/1)
  end

  defp format_content_part(%{type: :text, text: text}), do: %{text: text}

  defp format_content_part(%{type: :image_base64, data: data, media_type: media_type}) do
    %{inlineData: %{mimeType: media_type, data: data}}
  end

  defp format_content_part(%{type: :image_url, url: url}) do
    %{fileData: %{fileUri: url}}
  end

  defp gemini_role("assistant"), do: "model"
  defp gemini_role(role), do: role

  defp do_request(config, body, nil), do: make_request(config, body)

  defp do_request(config, body, http_client) when is_function(http_client, 2) do
    query = URI.encode_query(%{"key" => config.api_key})
    url = "#{@api_base_url}/#{URI.encode(config.model)}:generateContent?#{query}"
    http_client.(url, body)
  end

  defp make_request(config, body) do
    :inets.start()
    :ssl.start()

    query = URI.encode_query(%{"key" => config.api_key})
    url = "#{@api_base_url}/#{URI.encode(config.model)}:generateContent?#{query}"

    headers = [
      {~c"content-type", ~c"application/json"}
    ]

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      timeout: 60_000,
      connect_timeout: 10_000
    ]

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
      {:ok, %{"candidates" => [%{"finishReason" => reason} | _]}} when reason != "STOP" ->
        {:error, {:generation_stopped, reason}}

      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => text} | _]}} | _]}} ->
        {:ok, text}

      {:ok, %{"error" => %{"message" => message, "status" => status}}} ->
        {:error, {:api_error, status, message}}

      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, {:api_error, "UNKNOWN", message}}

      {:ok, unexpected} ->
        {:error, {:unexpected_response_format, unexpected}}

      {:error, error} ->
        {:error, {:json_decode_error, error}}
    end
  end
end
