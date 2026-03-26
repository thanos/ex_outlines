defmodule ExOutlines.Stream do
  @moduledoc """
  Stream accumulation and validation for streaming generation.

  Accumulates text chunks from a streaming backend and runs full
  validation when the backend signals completion via a `{:done, text}` event.
  """

  @type chunk_event :: {:chunk, String.t()} | {:done, String.t()} | {:error, term()}

  @doc """
  Wraps a backend stream into a validated generation stream.

  Takes a stream of `{:chunk, text}`, `{:done, full_text}`, and `{:error, reason}`
  events from a backend and produces a stream that:

  1. Emits `{:chunk, text}` for each incremental chunk of text as it arrives
  2. On `{:done, full_text}`, validates the full response against the spec
  3. Emits `{:ok, validated_result}` on success
  4. Emits `{:error, reason}` on validation failure or backend error

  The stream halts after a terminal event (`:done` or `:error`), ensuring
  consumers receive exactly one terminal result.

  ## Parameters

  - `backend_stream` - Enumerable of `ExOutlines.Backend.stream_event()` tuples
  - `spec` - The spec to validate against on completion
  """
  @spec validated_stream(Enumerable.t(), ExOutlines.Spec.t()) :: Enumerable.t()
  def validated_stream(backend_stream, spec) do
    Stream.transform(backend_stream, :streaming, fn
      _event, :halted ->
        {:halt, :halted}

      {:chunk, text}, :streaming ->
        {[{:chunk, text}], :streaming}

      {:done, full_text}, :streaming ->
        result = validate_complete(full_text, spec)
        {[result], :halted}

      {:error, {:stream_error, _} = reason}, :streaming ->
        {[{:error, reason}], :halted}

      {:error, reason}, :streaming ->
        {[{:error, {:stream_error, reason}}], :halted}
    end)
  end

  @doc """
  Converts a non-streaming (buffered) backend response into a stream format.

  Used as a fallback when a backend doesn't implement `call_llm_stream/2`.
  Emits the full response as a single `{:done, text}` event.
  """
  @spec from_buffered({:ok, String.t()} | {:error, term()}) :: Enumerable.t()
  def from_buffered({:ok, text}) do
    [{:done, text}]
  end

  def from_buffered({:error, reason}) do
    [{:error, reason}]
  end

  defp validate_complete(full_text, spec) do
    case Jason.decode(full_text) do
      {:ok, decoded} ->
        case ExOutlines.Spec.validate(spec, decoded) do
          {:ok, validated} -> {:ok, validated}
          {:error, diagnostics} -> {:error, {:validation_failed, diagnostics}}
        end

      {:error, json_error} ->
        {:error, {:json_decode_error, json_error}}
    end
  end
end
