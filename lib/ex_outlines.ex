defmodule ExOutlines do
  @moduledoc """
  ExOutlines — Deterministic structured output from LLMs.

  Main entry point for generating constrained outputs using retry-repair loops.
  """

  @type generate_opts :: [
          backend: module(),
          backend_opts: keyword(),
          max_retries: pos_integer(),
          telemetry_metadata: map(),
          template: nil | {String.t(), keyword()},
          content: nil | [ExOutlines.Backend.content_part()]
        ]

  @type generate_result :: {:ok, any()} | {:error, term()}

  @type batch_opts :: [
          max_concurrency: pos_integer(),
          timeout: pos_integer(),
          on_timeout: :kill_task | :continue,
          ordered: boolean(),
          telemetry_metadata: map()
        ]

  @type batch_result :: [generate_result()]

  @doc """
  Generate structured output conforming to a spec.

  ## Options

  - `:backend` - Backend module implementing `ExOutlines.Backend`
  - `:backend_opts` - Options passed to backend (model, temperature, etc.)
  - `:max_retries` - Maximum retry attempts (default: 3)
  - `:telemetry_metadata` - Additional telemetry context
  - `:template` - Optional `{template_string, assigns}` tuple where `template_string`
    is an EEx template and `assigns` is a keyword list of variables. When provided,
    the rendered template is used as the user prompt instead of the default.
    See `ExOutlines.Template` for details.
  - `:content` - Optional list of `ExOutlines.Content` parts for multimodal input.
    When provided, content parts (images, text) are included in the user message.
    Cannot be combined with `:template`.

  ## Returns

  - `{:ok, result}` - Successfully generated and validated output
  - `{:error, :max_retries_exceeded}` - Exhausted all retry attempts
  - `{:error, {:backend_error, reason}}` - Backend communication failure
  - `{:error, {:backend_exception, error}}` - Backend raised an exception
  - `{:error, :no_backend}` - No backend specified
  - `{:error, {:invalid_backend, value}}` - Backend is not an atom
  - `{:error, {:invalid_template, value}}` - Template is not `{binary, keyword}` or `nil`
  - `{:error, {:template_error, exception}}` - Template rendering failed (syntax error, runtime error)
  - `{:error, {:invalid_content, value}}` - Content is not a list of valid content parts, or is empty
  - `{:error, :template_and_content_conflict}` - Both `:template` and `:content` were provided
  """
  @spec generate(ExOutlines.Spec.t(), generate_opts()) :: generate_result()
  def generate(spec, opts \\ []) do
    with {:ok, config} <- validate_config(opts) do
      execute_generation(spec, config)
    end
  end

  @doc """
  Generate structured output with streaming.

  Returns a stream that emits `{:chunk, text}` for each incremental piece of text
  as the LLM generates, followed by a final `{:ok, validated_result}` or
  `{:error, reason}`. The stream halts after the terminal event.

  If the backend implements `call_llm_stream/2`, true streaming is used.
  Otherwise, falls back to buffered mode (single `{:ok, result}` emission).

  Streaming does not support retry-repair loops -- if validation fails,
  the stream emits `{:error, {:validation_failed, diagnostics}}`.

  ## Options

  Same as `generate/2` except `:max_retries` is ignored.

  ## Returns

  - `{:ok, stream}` - A stream of events
  - `{:error, reason}` - Configuration, template, or backend initialization error
  """
  @spec generate_stream(ExOutlines.Spec.t(), generate_opts()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  def generate_stream(spec, opts \\ []) do
    with {:ok, config} <- validate_config(opts),
         {:ok, messages} <- resolve_messages(spec, config, 0, []),
         {:ok, stream} <- build_stream(spec, config.backend, messages, config.backend_opts) do
      {:ok, stream}
    end
  end

  defp build_stream(spec, backend, messages, backend_opts) do
    if function_exported?(backend, :call_llm_stream, 2) do
      case call_backend_stream(backend, messages, backend_opts) do
        {:ok, backend_stream} ->
          {:ok, ExOutlines.Stream.validated_stream(backend_stream, spec)}

        {:error, reason} ->
          {:error, {:backend_error, reason}}
      end
    else
      # Fallback: call synchronous backend and wrap as stream
      result = call_backend(backend, messages, backend_opts)
      buffered = ExOutlines.Stream.from_buffered(result)
      {:ok, ExOutlines.Stream.validated_stream(buffered, spec)}
    end
  end

  defp call_backend_stream(backend, messages, opts) do
    backend.call_llm_stream(messages, opts)
  rescue
    error ->
      {:error, {:backend_exception, error}}
  end

  @doc """
  Generate structured outputs for multiple specs concurrently.

  Leverages BEAM's concurrency model to process multiple generation requests
  in parallel. Each task is independent and runs in its own process.

  ## Options

  - `:max_concurrency` - Maximum concurrent tasks (default: System.schedulers_online())
  - `:timeout` - Timeout per task in milliseconds (default: 60_000)
  - `:on_timeout` - How to handle timeouts: `:kill_task` or `:continue` (default: :kill_task)
  - `:ordered` - Return results in input order (default: true)
  - `:telemetry_metadata` - Additional telemetry context

  ## Returns

  List of results in the same order as input (if ordered: true). Each result is:
  - `{:ok, result}` - Successfully generated and validated output
  - `{:error, reason}` - Task failed (timeout, validation, backend error, etc.)

  ## Examples

      # Process multiple schemas concurrently
      tasks = [
        {user_schema, [backend: HTTP, backend_opts: [...]]},
        {product_schema, [backend: HTTP, backend_opts: [...]]},
        {order_schema, [backend: HTTP, backend_opts: [...]]}
      ]

      results = ExOutlines.generate_batch(tasks, max_concurrency: 3)

      # Results match input order
      [user_result, product_result, order_result] = results

      # Handle mixed results
      Enum.each(results, fn
        {:ok, data} -> IO.inspect(data, label: "Success")
        {:error, reason} -> IO.inspect(reason, label: "Error")
      end)

  """
  @spec generate_batch([{ExOutlines.Spec.t(), generate_opts()}], batch_opts()) :: batch_result()
  def generate_batch(spec_opts_list, batch_opts \\ []) do
    max_concurrency =
      Keyword.get(batch_opts, :max_concurrency, System.schedulers_online())

    timeout = Keyword.get(batch_opts, :timeout, 60_000)
    on_timeout = Keyword.get(batch_opts, :on_timeout, :kill_task)
    ordered = Keyword.get(batch_opts, :ordered, true)
    telemetry_metadata = Keyword.get(batch_opts, :telemetry_metadata, %{})

    total_tasks = length(spec_opts_list)
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:ex_outlines, :batch, :start],
      %{system_time: System.system_time(), total_tasks: total_tasks},
      Map.merge(telemetry_metadata, %{max_concurrency: max_concurrency})
    )

    results =
      spec_opts_list
      |> Task.async_stream(
        fn {spec, opts} -> generate(spec, opts) end,
        max_concurrency: max_concurrency,
        timeout: timeout,
        on_timeout: on_timeout,
        ordered: ordered
      )
      |> Enum.map(fn
        {:ok, result} ->
          result

        {:exit, reason} ->
          {:error, {:task_exit, reason}}
      end)

    duration = System.monotonic_time() - start_time
    success_count = Enum.count(results, &match?({:ok, _}, &1))
    error_count = total_tasks - success_count

    :telemetry.execute(
      [:ex_outlines, :batch, :stop],
      %{
        duration: duration,
        total_tasks: total_tasks,
        success_count: success_count,
        error_count: error_count
      },
      telemetry_metadata
    )

    results
  end

  defp validate_config(opts) do
    backend = Keyword.get(opts, :backend)
    backend_opts = Keyword.get(opts, :backend_opts, [])
    max_retries = Keyword.get(opts, :max_retries, 3)
    telemetry_metadata = Keyword.get(opts, :telemetry_metadata, %{})
    template = Keyword.get(opts, :template)
    content = Keyword.get(opts, :content)

    with :ok <- validate_backend(backend),
         :ok <- validate_template(template),
         :ok <- validate_content(content),
         :ok <- validate_no_template_content_conflict(template, content) do
      {:ok,
       %{
         backend: backend,
         backend_opts: backend_opts,
         max_retries: max_retries,
         telemetry_metadata: telemetry_metadata,
         template: template,
         content: content
       }}
    end
  end

  defp validate_backend(nil), do: {:error, :no_backend}
  defp validate_backend(backend) when is_atom(backend), do: :ok
  defp validate_backend(other), do: {:error, {:invalid_backend, other}}

  defp validate_template(nil), do: :ok

  defp validate_template({template, assigns})
       when is_binary(template) and is_list(assigns) do
    if Keyword.keyword?(assigns) do
      :ok
    else
      {:error, {:invalid_template, {template, assigns}}}
    end
  end

  defp validate_template(other), do: {:error, {:invalid_template, other}}

  defp validate_content(nil), do: :ok
  defp validate_content([]), do: {:error, {:invalid_content, []}}

  defp validate_content(parts) when is_list(parts) do
    if Enum.all?(parts, &valid_content_part?/1) do
      :ok
    else
      {:error, {:invalid_content, parts}}
    end
  end

  defp validate_content(other), do: {:error, {:invalid_content, other}}

  defp valid_content_part?(%{type: :text, text: t}) when is_binary(t), do: true
  defp valid_content_part?(%{type: :image_url, url: u}) when is_binary(u), do: true

  defp valid_content_part?(%{type: :image_base64, data: d, media_type: m})
       when is_binary(d) and is_binary(m),
       do: true

  defp valid_content_part?(_), do: false

  defp validate_no_template_content_conflict(nil, _), do: :ok
  defp validate_no_template_content_conflict(_, nil), do: :ok

  defp validate_no_template_content_conflict(_template, _content),
    do: {:error, :template_and_content_conflict}

  defp execute_generation(spec, config) do
    %{
      backend: backend,
      backend_opts: backend_opts,
      max_retries: max_retries,
      telemetry_metadata: metadata,
      template: template
    } = config

    start_time = System.monotonic_time()

    :telemetry.execute(
      [:ex_outlines, :generate, :start],
      %{system_time: System.system_time()},
      Map.merge(metadata, %{spec: spec, backend: backend})
    )

    content = Map.get(config, :content)

    ctx = %{
      backend: backend,
      backend_opts: backend_opts,
      max_retries: max_retries,
      template: template,
      content: content
    }

    result = generation_loop(spec, ctx, 0, [])

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

  defp generation_loop(_spec, %{max_retries: max_retries}, attempt, _messages)
       when attempt >= max_retries do
    {:error, :max_retries_exceeded}
  end

  defp generation_loop(spec, ctx, attempt, previous_messages) do
    :telemetry.execute(
      [:ex_outlines, :attempt, :start],
      %{attempt: attempt},
      %{spec: spec}
    )

    with {:ok, messages} <- resolve_messages(spec, ctx, attempt, previous_messages) do
      case call_backend(ctx.backend, messages, ctx.backend_opts) do
        {:ok, response} ->
          process_response(spec, response, ctx, attempt, messages)

        {:error, reason} ->
          :telemetry.execute(
            [:ex_outlines, :attempt, :backend_error],
            %{attempt: attempt},
            %{reason: reason}
          )

          {:error, {:backend_error, reason}}
      end
    end
  end

  defp resolve_messages(_spec, _ctx, attempt, previous_messages) when attempt > 0 do
    {:ok, previous_messages}
  end

  defp resolve_messages(spec, ctx, 0, _previous_messages) do
    {:ok, build_initial_messages(spec, ctx.template, ctx.content)}
  rescue
    error -> {:error, {:template_error, error}}
  end

  defp build_initial_messages(spec, nil, nil), do: ExOutlines.Prompt.build_initial(spec)

  defp build_initial_messages(spec, {template, assigns}, nil)
       when is_binary(template) and is_list(assigns) do
    ExOutlines.Template.build_messages(template, assigns, spec)
  end

  defp build_initial_messages(spec, nil, content) when is_list(content) do
    ExOutlines.Prompt.build_initial_with_content(spec, content)
  end

  defp call_backend(backend, messages, opts) do
    backend.call_llm(messages, opts)
  rescue
    error ->
      {:error, {:backend_exception, error}}
  end

  defp process_response(spec, response, ctx, attempt, messages) do
    case decode_json(response) do
      {:ok, decoded} ->
        validate_and_complete(spec, decoded, response, ctx, attempt, messages)

      {:error, json_error} ->
        handle_decode_error(spec, response, json_error, ctx, attempt, messages)
    end
  end

  defp decode_json(response) do
    case Jason.decode(response) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, error} -> {:error, error}
    end
  end

  defp validate_and_complete(spec, decoded, raw_response, ctx, attempt, messages) do
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

        retry_with_repair(spec, raw_response, diagnostics, ctx, attempt, messages)
    end
  end

  defp handle_decode_error(spec, response, json_error, ctx, attempt, messages) do
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

    retry_with_repair(spec, response, diagnostics, ctx, attempt, messages)
  end

  defp retry_with_repair(spec, previous_output, diagnostics, ctx, attempt, previous_messages) do
    repair_messages = ExOutlines.Prompt.build_repair(previous_output, diagnostics)
    new_messages = previous_messages ++ repair_messages

    :telemetry.execute(
      [:ex_outlines, :retry, :initiated],
      %{attempt: attempt, next_attempt: attempt + 1},
      %{diagnostics: diagnostics}
    )

    generation_loop(spec, ctx, attempt + 1, new_messages)
  end
end
