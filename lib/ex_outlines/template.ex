defmodule ExOutlines.Template do
  @moduledoc """
  EEx-based prompt template system.

  Provides reusable, parameterized prompt templates using Elixir's built-in
  EEx templating engine. Templates can be defined as strings or loaded from files.

  ## Security

  EEx templates execute arbitrary Elixir code at render time. **Never pass
  untrusted or user-supplied strings as the template itself.** Only the
  `assigns` values are safe to populate from external input -- the template
  source must always come from your own codebase (inline strings, checked-in
  `.eex` files, or application config you control).

  If you need to interpolate untrusted text into a prompt, pass it as an
  assign and reference it with `<%= @variable %>` inside a trusted template.

  ## Examples

  ### Inline templates

      template = \"\"\"
      Extract the following information from the text:
      Domain: <%= @domain %>
      Focus on: <%= Enum.join(@focus_areas, ", ") %>
      \"\"\"

      rendered = ExOutlines.Template.render(template, domain: "medical", focus_areas: ["diagnosis", "treatment"])

  ### File-based templates

      rendered = ExOutlines.Template.render_file("prompts/extract.eex", domain: "legal")

  ### Integration with generate/2

      ExOutlines.generate(schema,
        backend: backend,
        backend_opts: backend_opts,
        template: {template_string, [domain: "medical"]}
      )
  """

  @doc """
  Render an EEx template string with the given assigns.

  ## Parameters

  - `template` - An EEx template string
  - `assigns` - Keyword list of variables available in the template as `@key`

  ## Returns

  The rendered string.

  ## Examples

      iex> ExOutlines.Template.render("Hello, <%= @name %>!", name: "World")
      "Hello, World!"

      iex> ExOutlines.Template.render(~s(Items: <%= Enum.join(@items, ", ") %>), items: ["a", "b"])
      "Items: a, b"
  """
  @spec render(String.t(), keyword()) :: String.t()
  def render(template, assigns \\ []) when is_binary(template) do
    validate_assigns!(assigns)
    EEx.eval_string(template, assigns: assigns)
  end

  @doc """
  Render an EEx template file with the given assigns.

  ## Parameters

  - `path` - Path to an EEx template file
  - `assigns` - Keyword list of variables available in the template as `@key`

  ## Returns

  The rendered string.
  """
  @spec render_file(Path.t(), keyword()) :: String.t()
  def render_file(path, assigns \\ []) when is_binary(path) do
    validate_assigns!(assigns)
    EEx.eval_file(path, assigns: assigns)
  end

  defp validate_assigns!(assigns) do
    unless is_list(assigns) and Keyword.keyword?(assigns) do
      raise ArgumentError,
            "assigns must be a keyword list, got: #{inspect(assigns)}"
    end
  end

  @doc """
  Build prompt messages from a template, suitable for passing to a backend.

  Renders the template and wraps it as the user message in the standard
  prompt format with the structured data generation system message.

  ## Parameters

  - `template` - An EEx template string
  - `assigns` - Keyword list of variables available in the template
  - `spec` - The spec to include schema information from

  ## Returns

  A list of messages suitable for the generation loop.
  """
  @spec build_messages(String.t(), keyword(), ExOutlines.Spec.t()) :: [ExOutlines.Prompt.message()]
  def build_messages(template, assigns, spec) do
    rendered = render(template, assigns)
    ExOutlines.Prompt.build_initial(spec, rendered)
  end
end
