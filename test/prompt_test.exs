defmodule ExOutlines.PromptTest do
  use ExUnit.Case, async: true

  alias ExOutlines.{Diagnostics, Prompt, Spec}
  alias ExOutlines.Spec.Schema

  describe "build_initial/1" do
    test "returns a list of messages" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      messages = Prompt.build_initial(schema)

      assert is_list(messages)
      assert length(messages) == 2
    end

    test "first message is system role with instructions" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      [system_message | _] = Prompt.build_initial(schema)

      assert system_message.role == "system"
      assert is_binary(system_message.content)
      assert system_message.content =~ "structured data generator"
      assert system_message.content =~ "valid JSON"
      assert system_message.content =~ "required fields"
    end

    test "second message is user role with schema" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      [_system, user_message] = Prompt.build_initial(schema)

      assert user_message.role == "user"
      assert is_binary(user_message.content)
      assert user_message.content =~ "Generate JSON output"
      assert user_message.content =~ "schema"
    end

    test "user message includes JSON Schema representation" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true}
        })

      [_system, user_message] = Prompt.build_initial(schema)

      # Should include the JSON schema
      assert user_message.content =~ ~s("type")
      assert user_message.content =~ ~s("object")
      assert user_message.content =~ ~s("properties")
      assert user_message.content =~ ~s("name")
      assert user_message.content =~ ~s("age")
      assert user_message.content =~ ~s("required")
    end

    test "content is trimmed of leading/trailing whitespace" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      [system_message, user_message] = Prompt.build_initial(schema)

      # No leading whitespace
      refute String.starts_with?(system_message.content, " ")
      refute String.starts_with?(system_message.content, "\n")
      refute String.starts_with?(user_message.content, " ")
      refute String.starts_with?(user_message.content, "\n")

      # No trailing whitespace
      refute String.ends_with?(system_message.content, " ")
      refute String.ends_with?(system_message.content, "\n")
      refute String.ends_with?(user_message.content, " ")
      refute String.ends_with?(user_message.content, "\n")
    end

    test "system message contains all required instructions" do
      schema = Schema.new(%{name: %{type: :string}})
      [system_message | _] = Prompt.build_initial(schema)

      content = system_message.content

      # Key requirements
      assert content =~ "Output ONLY valid JSON"
      assert content =~ "no additional text"
      assert content =~ "Follow all field constraints"
      assert content =~ "Include all required fields"
      assert content =~ "Use correct types"
    end

    test "user message requests JSON output explicitly" do
      schema = Schema.new(%{name: %{type: :string}})
      [_system, user_message] = Prompt.build_initial(schema)

      assert user_message.content =~ "Respond with valid JSON only"
    end

    test "JSON schema is pretty-printed" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer}
        })

      [_system, user_message] = Prompt.build_initial(schema)

      # Pretty printed JSON has newlines and indentation
      assert user_message.content =~ "\n"
      assert user_message.content =~ "  "
    end

    test "handles schema with description fields" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true, description: "User's full name"}
        })

      [_system, user_message] = Prompt.build_initial(schema)

      assert user_message.content =~ "User's full name"
    end

    test "handles schema with enum types" do
      schema =
        Schema.new(%{
          role: %{type: {:enum, ["admin", "user"]}, required: true}
        })

      [_system, user_message] = Prompt.build_initial(schema)

      assert user_message.content =~ "admin"
      assert user_message.content =~ "user"
    end

    test "handles schema with positive integer constraint" do
      schema =
        Schema.new(%{
          age: %{type: :integer, required: true, positive: true}
        })

      [_system, user_message] = Prompt.build_initial(schema)

      # Positive integer should have minimum: 1 in schema
      assert user_message.content =~ "minimum"
    end

    test "messages have correct structure" do
      schema = Schema.new(%{name: %{type: :string}})
      messages = Prompt.build_initial(schema)

      Enum.each(messages, fn message ->
        assert Map.has_key?(message, :role)
        assert Map.has_key?(message, :content)
        assert is_binary(message.role)
        assert is_binary(message.content)
        assert message.role in ["system", "user"]
      end)
    end
  end

  describe "build_repair/2" do
    test "returns a list of messages" do
      previous_output = ~s({"name": "Alice"})
      diag = Diagnostics.new("integer", "string", "age")

      messages = Prompt.build_repair(previous_output, diag)

      assert is_list(messages)
      assert length(messages) == 2
    end

    test "first message is assistant role with previous output" do
      previous_output = ~s({"name": "Alice", "age": "thirty"})
      diag = Diagnostics.new("integer", "thirty", "age")

      [assistant_message | _] = Prompt.build_repair(previous_output, diag)

      assert assistant_message.role == "assistant"
      assert assistant_message.content == previous_output
    end

    test "second message is user role with error feedback" do
      previous_output = ~s({"invalid": "json"})
      diag = Diagnostics.new("integer", "string", "age")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      assert user_message.role == "user"
      assert user_message.content =~ "validation errors"
      assert user_message.content =~ "corrected JSON"
    end

    test "user message includes error details" do
      previous_output = ~s({"age": -5})

      diag = Diagnostics.new("positive integer (> 0)", -5, "age")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      assert user_message.content =~ "age"
      assert user_message.content =~ "positive integer"
    end

    test "user message includes repair instructions" do
      previous_output = ~s({"age": -5})
      diag = Diagnostics.new("positive integer (> 0)", -5, "age")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      assert user_message.content =~ diag.repair_instructions
      assert user_message.content =~ "Field 'age' must be"
    end

    test "content is trimmed of leading/trailing whitespace" do
      previous_output = ~s({"name": "Alice"})
      diag = Diagnostics.new("integer", "string", "age")

      [_assistant_message, user_message] = Prompt.build_repair(previous_output, diag)

      # Assistant message content is not trimmed (it's the raw output)
      # User message should be trimmed
      refute String.starts_with?(user_message.content, " ")
      refute String.starts_with?(user_message.content, "\n")
      refute String.ends_with?(user_message.content, " ")
      refute String.ends_with?(user_message.content, "\n")
    end

    test "formats single error with field details" do
      previous_output = ~s({"age": "invalid"})

      diag = Diagnostics.new("integer", "invalid", "age")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      # Should show field, expected, got, and message
      assert user_message.content =~ "Field: age"
      assert user_message.content =~ "Expected: integer"
      assert user_message.content =~ ~s(Got: "invalid")
    end

    test "formats multiple errors" do
      diag =
        Diagnostics.new("integer", "string", "age")
        |> Diagnostics.add_error("email", "valid email", "invalid")

      previous_output = ~s({"age": "string", "email": "invalid"})

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      # Should include both errors
      assert user_message.content =~ "age"
      assert user_message.content =~ "email"
      assert user_message.content =~ "integer"
      assert user_message.content =~ "valid email"
    end

    test "formats top-level errors without field name" do
      previous_output = ~s({invalid json})
      diag = Diagnostics.new("valid JSON", previous_output)

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      # Should not show "Field:" for top-level errors
      refute user_message.content =~ "Field: nil"
      # But should show the error message
      assert user_message.content =~ "valid JSON"
    end

    test "handles empty previous output" do
      previous_output = ""
      diag = Diagnostics.new("object (map)", nil)

      [assistant_message, user_message] = Prompt.build_repair(previous_output, diag)

      assert assistant_message.content == ""
      assert user_message.content =~ "validation errors"
    end

    test "preserves previous output exactly" do
      previous_output = ~s(  {"name": "Alice", "extra": "whitespace"}  )
      diag = Diagnostics.new("integer", "string", "age")

      [assistant_message, _user_message] = Prompt.build_repair(previous_output, diag)

      # Previous output should be preserved exactly (including whitespace)
      assert assistant_message.content == previous_output
    end

    test "includes clear call to action" do
      previous_output = ~s({"age": -5})
      diag = Diagnostics.new("positive integer", -5, "age")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      assert user_message.content =~ "Please provide corrected JSON"
      assert user_message.content =~ "addresses all errors"
    end

    test "messages have correct structure" do
      previous_output = ~s({"name": "Alice"})
      diag = Diagnostics.new("integer", "string", "age")

      messages = Prompt.build_repair(previous_output, diag)

      Enum.each(messages, fn message ->
        assert Map.has_key?(message, :role)
        assert Map.has_key?(message, :content)
        assert is_binary(message.role)
        assert is_binary(message.content)
        assert message.role in ["assistant", "user"]
      end)
    end

    test "error formatting shows inspector output for complex values" do
      previous_output = ~s({"data": {"nested": "object"}})

      diag = Diagnostics.new("string", %{"nested" => "object"}, "data")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      # Complex values should be inspected
      assert user_message.content =~ "Got:"
      assert user_message.content =~ "nested"
    end
  end

  describe "error formatting" do
    test "formats field-level error with all details" do
      diag = Diagnostics.new("positive integer (> 0)", -5, "age")

      [_assistant, user_message] = Prompt.build_repair("{}", diag)

      content = user_message.content

      assert content =~ "- Field: age"
      assert content =~ "Expected: positive integer (> 0)"
      assert content =~ "Got: -5"
      assert content =~ "Issue:"
    end

    test "formats top-level error without field prefix" do
      diag = Diagnostics.new("valid JSON", "{invalid}")

      [_assistant, user_message] = Prompt.build_repair("{invalid}", diag)

      content = user_message.content

      # Top-level errors don't have "Field:" prefix
      refute content =~ "Field:"
      assert content =~ "- Expected valid JSON"
    end

    test "formats multiple errors each on separate lines" do
      diag =
        Diagnostics.new("integer", "string", "age")
        |> Diagnostics.add_error("email", "string", 123)
        |> Diagnostics.add_error("name", "string", nil)

      [_assistant, user_message] = Prompt.build_repair("{}", diag)

      content = user_message.content

      # Each error should have its own bullet point
      error_lines = content |> String.split("\n") |> Enum.filter(&String.starts_with?(&1, "- "))
      assert length(error_lines) >= 3
    end
  end

  describe "integration with Schema" do
    test "build_initial works with complex schema" do
      schema =
        Schema.new(%{
          id: %{type: :integer, required: true, positive: true, description: "User ID"},
          username: %{type: :string, required: true, description: "Unique username"},
          email: %{type: :string, required: true},
          age: %{type: :integer, positive: true},
          role: %{type: {:enum, ["admin", "user"]}, required: false},
          active: %{type: :boolean, required: false}
        })

      [_system, user_message] = Prompt.build_initial(schema)

      # Should include all fields
      assert user_message.content =~ "id"
      assert user_message.content =~ "username"
      assert user_message.content =~ "email"
      assert user_message.content =~ "age"
      assert user_message.content =~ "role"
      assert user_message.content =~ "active"

      # Should include descriptions
      assert user_message.content =~ "User ID"
      assert user_message.content =~ "Unique username"
    end

    test "build_repair works with validation failures from Schema" do
      schema =
        Schema.new(%{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true}
        })

      invalid_input = %{"name" => 123, "age" => -5}

      {:error, diag} = Spec.validate(schema, invalid_input)

      previous_output = Jason.encode!(invalid_input)
      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      # Should mention both validation failures
      assert user_message.content =~ "name"
      assert user_message.content =~ "age"
      assert user_message.content =~ "string"
      assert user_message.content =~ "positive integer"
    end
  end

  describe "message format compatibility" do
    test "messages conform to common LLM API format" do
      schema = Schema.new(%{name: %{type: :string}})
      messages = Prompt.build_initial(schema)

      # Should be compatible with OpenAI/Anthropic message format
      Enum.each(messages, fn message ->
        assert is_map(message)
        assert Map.keys(message) |> Enum.sort() == [:content, :role]
        assert message.role in ["system", "user", "assistant"]
        assert is_binary(message.content)
        assert String.length(message.content) > 0
      end)
    end

    test "repair messages can extend conversation history" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Start conversation
      initial_messages = Prompt.build_initial(schema)

      # Simulate LLM response and validation failure
      previous_output = ~s({})
      {:error, diag} = Spec.validate(schema, Jason.decode!(previous_output))

      # Add repair messages
      repair_messages = Prompt.build_repair(previous_output, diag)
      full_conversation = initial_messages ++ repair_messages

      # Should form a valid conversation
      assert length(full_conversation) == 4
      assert Enum.at(full_conversation, 0).role == "system"
      assert Enum.at(full_conversation, 1).role == "user"
      assert Enum.at(full_conversation, 2).role == "assistant"
      assert Enum.at(full_conversation, 3).role == "user"
    end
  end

  describe "prompt content quality" do
    test "system message is concise and clear" do
      schema = Schema.new(%{name: %{type: :string}})
      [system_message | _] = Prompt.build_initial(schema)

      content = system_message.content

      # Not excessively long
      assert String.length(content) < 500

      # No redundant phrases
      refute content =~ ~r/please|kindly/i

      # Clear and direct
      assert content =~ "You are"
      assert content =~ "must"
    end

    test "repair message is actionable" do
      previous_output = ~s({"age": -5})
      diag = Diagnostics.new("positive integer (> 0)", -5, "age")

      [_assistant, user_message] = Prompt.build_repair(previous_output, diag)

      content = user_message.content

      # Contains clear instruction
      assert content =~ "provide corrected"
      assert content =~ "addresses all errors"

      # Not apologetic or conversational
      refute content =~ ~r/sorry|unfortunately/i
    end

    test "no markdown formatting in prompts" do
      schema = Schema.new(%{name: %{type: :string}})
      messages = Prompt.build_initial(schema)

      Enum.each(messages, fn message ->
        # No markdown code blocks
        refute message.content =~ "```"
        # No markdown headers (except possibly in schema JSON)
        # We allow # in JSON but not as markdown headers
      end)
    end
  end
end
