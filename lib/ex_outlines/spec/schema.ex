defmodule ExOutlines.Spec.Schema do
  @moduledoc """
  JSON schema-based constraint specification.

  Defines field types, required fields, enums, and validation rules.
  """

  @type field_type :: :string | :integer | :boolean | :number | {:enum, [any()]}

  @type field_spec :: %{
          type: field_type(),
          required: boolean(),
          description: String.t() | nil
        }

  @type t :: %__MODULE__{
          fields: %{atom() => field_spec()}
        }

  defstruct fields: %{}

  defimpl ExOutlines.Spec do
    def to_schema(_schema) do
      %{}
    end

    def validate(_schema, _value) do
      {:error, %ExOutlines.Diagnostics{}}
    end
  end
end
