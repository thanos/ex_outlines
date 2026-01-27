defmodule ExOutlines.Diagnostics do
  @moduledoc """
  Structured error representation with repair instructions.

  Used to communicate validation failures and guide LLM correction.
  """

  @type error_detail :: %{
          field: String.t() | nil,
          expected: String.t(),
          got: any(),
          message: String.t()
        }

  @type t :: %__MODULE__{
          errors: [error_detail()],
          repair_instructions: String.t()
        }

  defstruct errors: [], repair_instructions: ""
end
