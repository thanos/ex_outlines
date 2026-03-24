defmodule ExOutlines.Prompt do
  @moduledoc """
  Prompt construction for generation and repair cycles.

  Builds structured prompts from specs and diagnostics.
  """

  @type message :: %{role: String.t(), content: String.t()}

  @doc """
  Build initial generation prompt from a spec.

  Converts the spec to a schema representation and constructs
  a prompt instructing the LLM to generate conforming JSON output.

  An optional `preamble` string can be prepended to the user message
  (used by `ExOutlines.Template` for custom prompt content).
  """
  @spec build_initial(ExOutlines.Spec.t(), String.t() | nil) :: [message()]
  def build_initial(spec, preamble \\ nil) do
    schema_json =
      spec
      |> ExOutlines.Spec.to_schema()
      |> Jason.encode!(pretty: true)

    user_content =
      case preamble do
        nil ->
          """
          Generate JSON output conforming to this schema:

          #{schema_json}

          Respond with valid JSON only.
          """

        text when is_binary(text) ->
          """
          #{text}

          Generate JSON output conforming to this schema:

          #{schema_json}

          Respond with valid JSON only.
          """
      end

    [
      %{role: "system", content: String.trim(system_content())},
      %{role: "user", content: String.trim(user_content)}
    ]
  end

  defp system_content do
    """
    You are a structured data generator. You must produce valid JSON that conforms to the provided schema.

    Requirements:
    - Output ONLY valid JSON, no additional text or markdown
    - Follow all field constraints exactly
    - Include all required fields
    - Use correct types for all fields
    """
  end

  @doc """
  Build repair prompt from previous attempt and diagnostics.

  Creates messages showing the validation failure and requesting correction.
  Returns messages to append to the conversation history.
  """
  @spec build_repair(String.t(), ExOutlines.Diagnostics.t()) :: [message()]
  def build_repair(previous_output, diagnostics) do
    assistant_message = %{
      role: "assistant",
      content: previous_output
    }

    error_details = format_errors(diagnostics.errors)

    user_content = """
    Your previous output had validation errors:

    #{error_details}

    #{diagnostics.repair_instructions}

    Please provide corrected JSON output that addresses all errors.
    """

    user_message = %{
      role: "user",
      content: String.trim(user_content)
    }

    [assistant_message, user_message]
  end

  defp format_errors(errors) when is_list(errors) do
    Enum.map_join(errors, "\n", &format_error/1)
  end

  defp format_error(%{field: nil, message: message}) do
    "- #{message}"
  end

  defp format_error(%{field: field, expected: expected, got: got, message: message}) do
    """
    - Field: #{field}
      Expected: #{expected}
      Got: #{inspect(got)}
      Issue: #{message}
    """
    |> String.trim()
  end

  defp format_error(%{message: message}) do
    "- #{message}"
  end

  defp format_error(error) do
    "- #{inspect(error)}"
  end
end
