defmodule ExOutlines.Backend do
  @moduledoc """
  Behaviour for LLM backend adapters.

  Implementations handle communication with specific LLM providers.
  """

  @type message :: %{role: String.t(), content: String.t()}
  @type call_opts :: [
          model: String.t(),
          temperature: float(),
          max_tokens: pos_integer()
        ]

  @doc """
  Call the LLM with a list of messages.

  Returns the assistant's response content or an error.
  """
  @callback call_llm(messages :: [message()], opts :: call_opts()) ::
              {:ok, String.t()} | {:error, term()}
end
