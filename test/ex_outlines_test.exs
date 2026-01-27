defmodule ExOutlinesTest do
  use ExUnit.Case
  doctest ExOutlines

  test "returns error when no backend specified" do
    assert ExOutlines.generate(%{}) == {:error, :no_backend}
  end

  test "returns error for invalid backend" do
    assert ExOutlines.generate(%{}, backend: "not_an_atom") ==
             {:error, {:invalid_backend, "not_an_atom"}}
  end
end
