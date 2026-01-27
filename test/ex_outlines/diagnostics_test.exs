defmodule ExOutlines.DiagnosticsTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Diagnostics

  doctest ExOutlines.Diagnostics

  describe "new/3" do
    test "creates diagnostics with field name" do
      diag = Diagnostics.new("integer", "hello", "age")

      assert diag.errors == [
               %{
                 field: "age",
                 expected: "integer",
                 got: "hello",
                 message: "Field 'age': Expected integer but got \"hello\""
               }
             ]

      assert diag.repair_instructions == "Field 'age' must be: integer"
    end

    test "creates diagnostics without field name" do
      diag = Diagnostics.new("valid JSON", "{invalid}")

      assert [error] = diag.errors
      assert error.field == nil
      assert error.expected == "valid JSON"
      assert error.got == "{invalid}"
      assert error.message =~ "Expected valid JSON"
      assert diag.repair_instructions == "Output must be: valid JSON"
    end

    test "handles atom field names" do
      diag = Diagnostics.new("string", 123, :email)

      assert [error] = diag.errors
      assert error.field == "email"
      assert error.expected == "string"
    end
  end

  describe "from_errors/1" do
    test "creates diagnostics from list of errors" do
      errors = [
        %{field: "age", expected: "integer", got: "42", message: "Field 'age': error"},
        %{field: "email", expected: "string", got: nil, message: "Field 'email': error"}
      ]

      diag = Diagnostics.from_errors(errors)

      assert length(diag.errors) == 2
      assert diag.repair_instructions =~ "Field 'age' must be"
      assert diag.repair_instructions =~ "Field 'email' must be"
    end

    test "normalizes errors with missing message" do
      errors = [
        %{field: "age", expected: "integer", got: 42}
      ]

      diag = Diagnostics.from_errors(errors)

      assert [error] = diag.errors
      assert error.message == "Field 'age': Expected integer but got 42"
    end

    test "handles empty list" do
      diag = Diagnostics.from_errors([])

      assert diag.errors == []
      assert diag.repair_instructions == ""
    end
  end

  describe "add_error/4" do
    test "adds error to existing diagnostics" do
      diag =
        Diagnostics.new("integer", "hello", "age")
        |> Diagnostics.add_error("email", "valid email", "not-an-email")

      assert length(diag.errors) == 2
      assert Enum.any?(diag.errors, &(&1.field == "age"))
      assert Enum.any?(diag.errors, &(&1.field == "email"))
      assert diag.repair_instructions =~ "age"
      assert diag.repair_instructions =~ "email"
    end
  end

  describe "merge/1" do
    test "merges multiple diagnostics" do
      diag1 = Diagnostics.new("integer", "hello", "age")
      diag2 = Diagnostics.new("email", "invalid", "email")
      diag3 = Diagnostics.new("positive", -5, "count")

      merged = Diagnostics.merge([diag1, diag2, diag3])

      assert length(merged.errors) == 3
      assert Enum.any?(merged.errors, &(&1.field == "age"))
      assert Enum.any?(merged.errors, &(&1.field == "email"))
      assert Enum.any?(merged.errors, &(&1.field == "count"))
    end

    test "removes duplicate errors" do
      diag1 = Diagnostics.new("integer", "hello", "age")
      diag2 = Diagnostics.new("integer", "hello", "age")

      merged = Diagnostics.merge([diag1, diag2])

      assert length(merged.errors) == 1
    end

    test "handles empty list" do
      merged = Diagnostics.merge([])

      assert merged.errors == []
      assert merged.repair_instructions == ""
    end
  end

  describe "has_errors?/1" do
    test "returns true when errors exist" do
      diag = Diagnostics.new("integer", "string", "age")
      assert Diagnostics.has_errors?(diag)
    end

    test "returns false when no errors" do
      diag = %Diagnostics{}
      refute Diagnostics.has_errors?(diag)
    end
  end

  describe "error_count/1" do
    test "returns number of errors" do
      diag =
        Diagnostics.new("integer", "string", "age")
        |> Diagnostics.add_error("email", "valid", "invalid")
        |> Diagnostics.add_error("name", "string", nil)

      assert Diagnostics.error_count(diag) == 3
    end

    test "returns zero for empty diagnostics" do
      assert Diagnostics.error_count(%Diagnostics{}) == 0
    end
  end

  describe "format/1" do
    test "formats single error" do
      diag = Diagnostics.new("integer", "hello", "age")
      formatted = Diagnostics.format(diag)

      assert formatted =~ "1 error"
      assert formatted =~ "[age]"
      assert formatted =~ "integer"
    end

    test "formats multiple errors" do
      diag =
        Diagnostics.new("integer", "hello", "age")
        |> Diagnostics.add_error("email", "valid email", "invalid")

      formatted = Diagnostics.format(diag)

      assert formatted =~ "2 errors"
      assert formatted =~ "[age]"
      assert formatted =~ "[email]"
    end

    test "formats top-level error without field" do
      diag = Diagnostics.new("valid JSON", "{invalid}")
      formatted = Diagnostics.format(diag)

      assert formatted =~ "1 error"
      refute formatted =~ "["
      assert formatted =~ "valid JSON"
    end
  end

  describe "value formatting" do
    test "formats different value types" do
      diag_string = Diagnostics.new("int", "hello", "field")
      assert hd(diag_string.errors).message =~ ~s("hello")

      diag_nil = Diagnostics.new("int", nil, "field")
      assert hd(diag_nil.errors).message =~ "null"

      diag_bool = Diagnostics.new("int", true, "field")
      assert hd(diag_bool.errors).message =~ "true"

      diag_num = Diagnostics.new("string", 42, "field")
      assert hd(diag_num.errors).message =~ "42"

      diag_atom = Diagnostics.new("string", :ok, "field")
      assert hd(diag_atom.errors).message =~ ":ok"

      diag_list = Diagnostics.new("string", [1, 2, 3], "field")
      assert hd(diag_list.errors).message =~ "list with 3 items"

      diag_map = Diagnostics.new("string", %{a: 1, b: 2}, "field")
      assert hd(diag_map.errors).message =~ "map with 2 keys"
    end
  end

  describe "repair instructions" do
    test "generates actionable instructions for field errors" do
      diag = Diagnostics.new("positive integer greater than 0", -5, "age")

      assert diag.repair_instructions ==
               "Field 'age' must be: positive integer greater than 0"
    end

    test "generates instructions for top-level errors" do
      diag = Diagnostics.new("valid JSON with no trailing commas", "{invalid,}")

      assert diag.repair_instructions == "Output must be: valid JSON with no trailing commas"
    end

    test "generates multiple instructions" do
      diag =
        Diagnostics.new("integer", "string", "age")
        |> Diagnostics.add_error("email", "valid email format", "not-email")

      assert diag.repair_instructions =~ "Field 'age' must be: integer"
      assert diag.repair_instructions =~ "Field 'email' must be: valid email format"
    end

    test "provides default instruction for empty errors" do
      diag = %Diagnostics{}
      assert diag.repair_instructions == ""

      # When building from incomplete error maps
      diag_from_empty = Diagnostics.from_errors([])
      assert diag_from_empty.repair_instructions == ""
    end
  end
end
