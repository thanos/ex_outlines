defmodule ExOutlines.Backend.HTTP do
  @moduledoc """
  Minimal HTTP backend using Erlang's :httpc.

  Supports OpenAI-compatible chat completion endpoints.

  ## Configuration

  Required options:
  - `:api_key` - API key for authentication
  - `:url` - API endpoint URL (default: OpenAI)
  - `:model` - Model identifier (e.g., "gpt-4", "gpt-3.5-turbo")

  Optional:
  - `:temperature` - Sampling temperature (default: 0.0 for determinism)
  - `:max_tokens` - Maximum tokens in response (default: 1000)

  ## Example

      ExOutlines.generate(schema,
        backend: ExOutlines.Backend.HTTP,
        backend_opts: [
          api_key: System.get_env("OPENAI_API_KEY"),
          url: "https://api.openai.com/v1/chat/completions",
          model: "gpt-4",
          temperature: 0.0
        ]
      )

  ## Custom Endpoints

  Works with any OpenAI-compatible endpoint:

      backend_opts: [
        api_key: "sk-...",
        url: "https://your-proxy.com/v1/chat/completions",
        model: "custom-model"
      ]
  """

  @behaviour ExOutlines.Backend

  @default_url "https://api.openai.com/v1/chat/completions"
  @default_temperature 0.0
  @default_max_tokens 1000

  @impl ExOutlines.Backend
  def call_llm(messages, opts) do
    with {:ok, config} <- validate_config(opts),
         {:ok, body} <- build_request_body(messages, config),
         {:ok, response} <- make_request(config.url, config.api_key, body) do
      parse_response(response)
    end
  end

  # Private helpers

  defp validate_config(opts) do
    with {:ok, api_key} <- validate_api_key(opts),
         {:ok, model} <- validate_model(opts),
         {:ok, url} <- validate_url(opts),
         {:ok, temperature} <- validate_temperature(opts),
         {:ok, max_tokens} <- validate_max_tokens(opts) do
      {:ok,
       %{
         api_key: api_key,
         url: url,
         model: model,
         temperature: temperature,
         max_tokens: max_tokens
       }}
    end
  end

  defp validate_api_key(opts) do
    case Keyword.get(opts, :api_key) do
      nil -> {:error, :missing_api_key}
      "" -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp validate_model(opts) do
    case Keyword.get(opts, :model) do
      nil -> {:error, :missing_model}
      "" -> {:error, :missing_model}
      model -> {:ok, model}
    end
  end

  defp validate_url(opts) do
    url = Keyword.get(opts, :url, @default_url)

    if is_binary(url) do
      {:ok, url}
    else
      {:error, :invalid_url}
    end
  end

  defp validate_temperature(opts) do
    temperature = Keyword.get(opts, :temperature, @default_temperature)

    if is_number(temperature) and temperature >= 0 and temperature <= 2 do
      {:ok, temperature}
    else
      {:error, :invalid_temperature}
    end
  end

  defp validate_max_tokens(opts) do
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)

    if is_integer(max_tokens) and max_tokens >= 1 do
      {:ok, max_tokens}
    else
      {:error, :invalid_max_tokens}
    end
  end

  defp build_request_body(messages, config) do
    body = %{
      model: config.model,
      messages: messages,
      temperature: config.temperature,
      max_tokens: config.max_tokens
    }

    case Jason.encode(body) do
      {:ok, json} -> {:ok, json}
      {:error, error} -> {:error, {:json_encode_error, error}}
    end
  end

  defp make_request(url, api_key, body) do
    # Start inets application if not already started
    :inets.start()
    :ssl.start()

    headers = [
      {~c"Content-Type", ~c"application/json"},
      {~c"Authorization", ~c"Bearer #{api_key}"}
    ]

    request = {
      String.to_charlist(url),
      headers,
      ~c"application/json",
      String.to_charlist(body)
    }

    http_opts = [
      ssl: [
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ],
      timeout: 60_000
    ]

    case :httpc.request(:post, request, http_opts, []) do
      {:ok, {{_, 200, _}, _headers, response_body}} ->
        {:ok, List.to_string(response_body)}

      {:ok, {{_, status_code, _}, _headers, response_body}} ->
        {:error, {:http_error, status_code, List.to_string(response_body)}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}

      {:ok, %{"error" => error}} ->
        {:error, {:api_error, error}}

      {:ok, unexpected} ->
        {:error, {:unexpected_response, unexpected}}

      {:error, error} ->
        {:error, {:json_decode_error, error}}
    end
  end
end
