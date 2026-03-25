defmodule ExOutlines.Backend do
  @moduledoc """
  Behaviour for LLM backend adapters.

  Implementations handle communication with specific LLM providers.

  ## Required Callbacks

  - `call_llm/2` - Synchronous generation returning the full response.

  ## Optional Callbacks

  - `call_llm_stream/2` - Streaming generation returning a stream of chunks.
    Backends that implement this enable `ExOutlines.generate_stream/2`.
  """

  @type message :: %{role: String.t(), content: String.t() | [content_part()]}

  @type content_part ::
          %{type: :text, text: String.t()}
          | %{type: :image_url, url: String.t()}
          | %{type: :image_base64, data: String.t(), media_type: String.t()}

  @type call_opts :: [
          model: String.t(),
          temperature: float(),
          max_tokens: pos_integer()
        ]

  @type stream_event ::
          {:chunk, String.t()}
          | {:done, String.t()}
          | {:error, term()}

  @doc """
  Call the LLM with a list of messages.

  Returns the assistant's response content or an error.
  """
  @callback call_llm(messages :: [message()], opts :: call_opts()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Call the LLM with streaming, returning a stream of chunk events.

  The stream should emit `{:chunk, text}` for partial content,
  and `{:done, full_text}` when generation is complete.
  On error, emit `{:error, reason}`.

  This callback is optional. Backends that don't implement it
  will fall back to buffered mode in `ExOutlines.generate_stream/2`.
  """
  @callback call_llm_stream(messages :: [message()], opts :: call_opts()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @optional_callbacks [call_llm_stream: 2]
end
