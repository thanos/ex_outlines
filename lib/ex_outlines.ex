defmodule ExOutlines do
  @moduledoc """
  ExOutlines — Deterministic structured output from LLMs.

  Main entry point for generating constrained outputs using retry-repair loops.
  """

  @type generate_opts :: [
          backend: module(),
          backend_opts: keyword(),
          max_retries: pos_integer(),
          telemetry_metadata: map()
        ]

  @type generate_result :: {:ok, any()} | {:error, term()}

  @doc """
  Generate structured output conforming to a spec.

  ## Options

  - `:backend` - Backend module implementing `ExOutlines.Backend`
  - `:backend_opts` - Options passed to backend (model, temperature, etc.)
  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:telemetry_metadata` - Additional telemetry context

  ## Returns

  - `{:ok, result}` - Successfully generated and validated output
  - `{:error, :max_retries_exceeded}` - Exhausted all retry attempts
  - `{:error, {:backend_error, reason}}` - Backend communication failure
  - `{:error, {:backend_exception, error}}` - Backend raised an exception
  - `{:error, :no_backend}` - No backend specified
  - `{:error, {:invalid_backend, value}}` - Backend is not an atom
  """
  @spec generate(ExOutlines.Spec.t(), generate_opts()) :: generate_result()
  def generate(spec, opts \\ []) do
    with {:ok, config} <- validate_config(opts) do
      execute_generation(spec, config)
    end
  end

  defp validate_config(opts) do
    backend = Keyword.get(opts, :backend)
    backend_opts = Keyword.get(opts, :backend_opts, [])
    max_retries = Keyword.get(opts, :max_retries, 3)
    telemetry_metadata = Keyword.get(opts, :telemetry_metadata, %{})

    case backend do
      nil ->
        {:error, :no_backend}

      backend when is_atom(backend) ->
        {:ok,
         %{
           backend: backend,
           backend_opts: backend_opts,
           max_retries: max_retries,
           telemetry_metadata: telemetry_metadata
         }}

      _ ->
        {:error, {:invalid_backend, backend}}
    end
  end

  defp execute_generation(spec, config) do
    %{
      backend: backend,
      backend_opts: backend_opts,
      max_retries: max_retries,
      telemetry_metadata: metadata
    } = config

    start_time = System.monotonic_time()

    :telemetry.execute(
      [:ex_outlines, :generate, :start],
      %{system_time: System.system_time()},
      Map.merge(metadata, %{spec: spec, backend: backend})
    )

    result = generation_loop(spec, backend, backend_opts, max_retries, 0, [])

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, value} ->
        :telemetry.execute(
          [:ex_outlines, :generate, :stop],
          %{duration: duration},
          Map.merge(metadata, %{result: :success})
        )

        {:ok, value}

      {:error, reason} = error ->
        :telemetry.execute(
          [:ex_outlines, :generate, :stop],
          %{duration: duration},
          Map.merge(metadata, %{result: :error, reason: reason})
        )

        error
    end
  end

  defp generation_loop(_spec, _backend, _backend_opts, max_retries, attempt, _messages)
       when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp generation_loop(spec, backend, backend_opts, max_retries, attempt, previous_messages) do
    :telemetry.execute(
      [:ex_outlines, :attempt, :start],
      %{attempt: attempt},
      %{spec: spec}
    )

    messages =
      if attempt == 0 do
        ExOutlines.Prompt.build_initial(spec)
      else
        previous_messages
      end

    case call_backend(backend, messages, backend_opts) do
      {:ok, response} ->
        process_response(spec, response, backend, backend_opts, max_retries, attempt, messages)

      {:error, reason} ->
        :telemetry.execute(
          [:ex_outlines, :attempt, :backend_error],
          %{attempt: attempt},
          %{reason: reason}
        )

        {:error, {:backend_error, reason}}
    end
  end

  defp call_backend(backend, messages, opts) do
    backend.call_llm(messages, opts)
  rescue
    error ->
      {:error, {:backend_exception, error}}
  end

  defp process_response(spec, response, backend, backend_opts, max_retries, attempt, messages) do
    case decode_json(response) do
      {:ok, decoded} ->
        validate_and_complete(
          spec,
          decoded,
          response,
          backend,
          backend_opts,
          max_retries,
          attempt,
          messages
        )

      {:error, json_error} ->
        handle_decode_error(
          spec,
          response,
          json_error,
          backend,
          backend_opts,
          max_retries,
          attempt,
          messages
        )
    end
  end

  defp decode_json(response) do
    case Jason.decode(response) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, error} -> {:error, error}
    end
  end

  defp validate_and_complete(
         spec,
         decoded,
         raw_response,
         backend,
         backend_opts,
         max_retries,
         attempt,
         messages
       ) do
    case ExOutlines.Spec.validate(spec, decoded) do
      {:ok, validated} ->
        :telemetry.execute(
          [:ex_outlines, :attempt, :success],
          %{attempt: attempt},
          %{spec: spec}
        )

        {:ok, validated}

      {:error, diagnostics} ->
        :telemetry.execute(
          [:ex_outlines, :attempt, :validation_failed],
          %{attempt: attempt},
          %{diagnostics: diagnostics}
        )

        retry_with_repair(
          spec,
          raw_response,
          diagnostics,
          backend,
          backend_opts,
          max_retries,
          attempt,
          messages
        )
    end
  end

  defp handle_decode_error(
         spec,
         response,
         json_error,
         backend,
         backend_opts,
         max_retries,
         attempt,
         messages
       ) do
    :telemetry.execute(
      [:ex_outlines, :attempt, :decode_failed],
      %{attempt: attempt},
      %{error: json_error}
    )

    diagnostics = %ExOutlines.Diagnostics{
      errors: [
        %{
          field: nil,
          expected: "valid JSON",
          got: response,
          message: "Failed to decode JSON: #{inspect(json_error)}"
        }
      ],
      repair_instructions: "Output must be valid JSON. Error: #{Exception.message(json_error)}"
    }

    retry_with_repair(
      spec,
      response,
      diagnostics,
      backend,
      backend_opts,
      max_retries,
      attempt,
      messages
    )
  end

  defp retry_with_repair(
         spec,
         previous_output,
         diagnostics,
         backend,
         backend_opts,
         max_retries,
         attempt,
         previous_messages
       ) do
    repair_messages = ExOutlines.Prompt.build_repair(previous_output, diagnostics)
    new_messages = previous_messages ++ repair_messages

    :telemetry.execute(
      [:ex_outlines, :retry, :initiated],
      %{attempt: attempt, next_attempt: attempt + 1},
      %{diagnostics: diagnostics}
    )

    generation_loop(spec, backend, backend_opts, max_retries, attempt + 1, new_messages)
  end
end
