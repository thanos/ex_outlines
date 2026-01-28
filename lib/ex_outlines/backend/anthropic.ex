defmodule ExOutlines.Backend.Anthropic do
  @moduledoc """
  Native Anthropic Claude API backend.

  Implements the ExOutlines.Backend behavior for direct integration with
  Anthropic's Messages API.

  ## Configuration

  - `:api_key` (required) - Anthropic API key
  - `:model` (optional) - Model to use (default: "claude-sonnet-4-5-20250929")
  - `:max_tokens` (optional) - Maximum tokens to generate (default: 1024)
  - `:temperature` (optional) - Temperature for generation (default: 0.0)

  ## Example

      ExOutlines.generate(schema,
        backend: ExOutlines.Backend.Anthropic,
        backend_opts: [
          api_key: "sk-ant-...",
          model: "claude-sonnet-4-5-20250929",
          max_tokens: 2048,
          temperature: 0.0
        ]
      )
  """

  @behaviour ExOutlines.Backend

  @default_model "claude-sonnet-4-5-20250929"
  @default_max_tokens 1024
  @default_temperature 0.0
  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"

  @impl true
  def call_llm(messages, opts) do
    with {:ok, config} <- validate_config(opts),
         {:ok, body} <- build_request_body(messages, config),
         {:ok, response} <- make_request(config.api_key, body) do
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

      not is_number(temperature) or temperature < 0.0 or temperature > 1.0 ->
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
    {system_message, conversation_messages} = extract_system_message(messages)

    body_map = %{
      model: config.model,
      max_tokens: config.max_tokens,
      temperature: config.temperature,
      messages: format_messages(conversation_messages)
    }

    # Add system message if present
    body_map =
      if system_message do
        Map.put(body_map, :system, system_message)
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

  defp format_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        role: msg.role,
        content: msg.content
      }
    end)
  end

  defp make_request(api_key, body) do
    # Start inets and ssl
    :inets.start()
    :ssl.start()

    headers = [
      {~c"content-type", ~c"application/json"},
      {~c"x-api-key", String.to_charlist(api_key)},
      {~c"anthropic-version", ~c"#{@api_version}"}
    ]

    http_options = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]
    ]

    request = {
      String.to_charlist(@api_url),
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
      {:ok, %{"content" => [%{"type" => "text", "text" => text} | _]}} ->
        {:ok, text}

      {:ok, %{"content" => [%{"text" => text} | _]}} ->
        {:ok, text}

      {:ok, %{"error" => error}} ->
        error_type = Map.get(error, "type", "unknown")
        error_message = Map.get(error, "message", "Unknown error")
        {:error, {:api_error, error_type, error_message}}

      {:ok, %{"type" => "error"} = error_response} ->
        error = Map.get(error_response, "error", %{})
        error_type = Map.get(error, "type", "unknown")
        error_message = Map.get(error, "message", "Unknown error")
        {:error, {:api_error, error_type, error_message}}

      {:ok, unexpected} ->
        {:error, {:unexpected_response_format, unexpected}}

      {:error, error} ->
        {:error, {:json_decode_error, error}}
    end
  end
end
