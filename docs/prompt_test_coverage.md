# ExOutlines.Prompt Test Coverage

## Summary

Added comprehensive unit tests for `ExOutlines.Prompt` module to catch prompt regressions and ensure correct message construction for LLM interactions.

**Test File:** `test/prompt_test.exs`
**Total Tests:** 36
**Status:** All passing ✅

---

## Test Coverage Breakdown

### build_initial/1 (13 tests)

Tests for initial prompt generation from spec:

1. **Message Structure**
   - Returns list of messages
   - First message is system role
   - Second message is user role
   - Messages have correct structure (role + content keys)

2. **System Message Content**
   - Contains role: "system"
   - Includes "structured data generator" instruction
   - Specifies "valid JSON" requirement
   - Mentions "required fields"
   - All instructions present and clear

3. **User Message Content**
   - Contains role: "user"
   - Includes "Generate JSON output" instruction
   - Contains schema keyword
   - Requests "valid JSON only" response
   - JSON schema is included and pretty-printed

4. **Content Quality**
   - Content is trimmed (no leading/trailing whitespace)
   - System message is concise (< 500 chars)
   - No redundant phrases
   - Clear and direct language

5. **Schema Integration**
   - Handles field descriptions
   - Handles enum types
   - Handles positive integer constraints
   - Handles complex multi-field schemas
   - JSON schema is pretty-printed with newlines and indentation

---

### build_repair/2 (14 tests)

Tests for repair prompt generation from diagnostics:

1. **Message Structure**
   - Returns list of 2 messages
   - First message is assistant role with previous output
   - Second message is user role with error feedback
   - Messages have correct structure

2. **Assistant Message**
   - Contains role: "assistant"
   - Content is exactly the previous output
   - Previous output preserved exactly (including whitespace)
   - Handles empty previous output

3. **User Message Content**
   - Contains role: "user"
   - Mentions "validation errors"
   - Requests "corrected JSON"
   - Includes "addresses all errors"
   - Content is trimmed

4. **Error Formatting**
   - Includes error details in message
   - Shows field name for field-level errors
   - Omits field prefix for top-level errors
   - Formats single error with field details
   - Formats multiple errors (each on separate line)
   - Shows Expected, Got, and Issue for each error
   - Uses inspector output for complex values

5. **Repair Instructions**
   - Includes repair instructions from diagnostics
   - Instructions mention specific fields
   - Instructions are actionable

---

### Integration Tests (9 tests)

Tests for Schema integration and message compatibility:

1. **Schema Integration**
   - Works with complex schemas (6+ fields)
   - Includes all field types in JSON schema
   - Includes field descriptions
   - Handles validation failures from Schema
   - Mentions all failing fields in repair messages

2. **Message Format Compatibility**
   - Conforms to common LLM API format (OpenAI/Anthropic)
   - Messages are maps with :role and :content keys
   - Roles are "system", "user", or "assistant"
   - Content is non-empty strings
   - Repair messages extend conversation history correctly
   - Forms valid 4-message conversation (system, user, assistant, user)

3. **Content Quality**
   - System message is concise and clear
   - Not excessively long
   - No redundant phrases
   - Clear and direct
   - Repair message is actionable
   - No apologetic or conversational language
   - No markdown formatting in prompts

---

## Error Formatting Tests (3 tests)

Detailed tests for error detail formatting:

1. **Field-Level Errors**
   - Shows "- Field: {name}"
   - Shows "Expected: {constraint}"
   - Shows "Got: {value}"
   - Shows "Issue: {message}"

2. **Top-Level Errors**
   - No "Field:" prefix
   - Shows error message directly

3. **Multiple Errors**
   - Each error on separate line
   - Each with bullet point prefix (-)
   - Minimum 3 error lines for 3 errors

---

## Test Examples

### Example 1: Initial Prompt Structure

```elixir
schema = Schema.new(%{name: %{type: :string, required: true}})
messages = Prompt.build_initial(schema)

# Expected structure:
[
  %{role: "system", content: "You are a structured data generator..."},
  %{role: "user", content: "Generate JSON output conforming to this schema:\n{...}"}
]
```

### Example 2: Repair Prompt Structure

```elixir
previous_output = ~s({"age": -5})
diag = Diagnostics.new("positive integer (> 0)", -5, "age")
messages = Prompt.build_repair(previous_output, diag)

# Expected structure:
[
  %{role: "assistant", content: ~s({"age": -5})},
  %{role: "user", content: "Your previous output had validation errors:\n- Field: age\n..."}
]
```

### Example 3: Conversation Flow

```elixir
# Initial prompt
initial = Prompt.build_initial(schema)
# => [system, user]

# After LLM response fails validation
repair = Prompt.build_repair(llm_output, diagnostics)
# => [assistant, user]

# Full conversation
conversation = initial ++ repair
# => [system, user, assistant, user]
```

---

## Key Assertions

### Message Structure Assertions

```elixir
# All messages have correct keys
assert Map.keys(message) |> Enum.sort() == [:content, :role]

# Role is valid
assert message.role in ["system", "user", "assistant"]

# Content is non-empty string
assert is_binary(message.content)
assert String.length(message.content) > 0
```

### Content Assertions

```elixir
# System message requirements
assert content =~ "structured data generator"
assert content =~ "valid JSON"
assert content =~ "required fields"
assert content =~ "correct types"

# User message requirements
assert content =~ "Generate JSON output"
assert content =~ "schema"
assert content =~ "Respond with valid JSON only"

# Repair message requirements
assert content =~ "validation errors"
assert content =~ "corrected JSON"
assert content =~ diag.repair_instructions
```

### Trimming Assertions

```elixir
# No leading whitespace
refute String.starts_with?(content, " ")
refute String.starts_with?(content, "\n")

# No trailing whitespace
refute String.ends_with?(content, " ")
refute String.ends_with?(content, "\n")
```

### Error Formatting Assertions

```elixir
# Field-level error
assert content =~ "- Field: age"
assert content =~ "Expected: positive integer"
assert content =~ "Got: -5"

# Top-level error
refute content =~ "Field: nil"
assert content =~ "- Expected valid JSON"
```

---

## Regression Prevention

These tests catch regressions in:

1. **Message Structure**
   - Role changes (system → user)
   - Missing messages
   - Extra messages
   - Key name changes

2. **Content Format**
   - Missing instructions
   - Whitespace issues
   - Markdown leakage
   - Missing schema in prompts

3. **Error Formatting**
   - Field name formatting changes
   - Missing error details
   - Incorrect error aggregation

4. **Integration**
   - Schema → JSON Schema conversion
   - Diagnostics → Error messages
   - Conversation flow

---

## Coverage Metrics

**Lines of test code:** ~500 lines
**Public functions covered:** 2/2 (100%)
- `build_initial/1` ✅
- `build_repair/2` ✅

**Private functions tested indirectly:** 2/2 (100%)
- `format_errors/1` ✅
- `format_error/1` ✅

**Edge cases covered:**
- Empty previous output ✅
- Top-level errors (no field) ✅
- Multiple errors ✅
- Complex nested values ✅
- All schema field types ✅
- Whitespace preservation/trimming ✅

---

## Related Documentation Issues Fixed

### Issue 1: Error Return Type Mismatch

**Problem:** Documentation said `{:error, :backend_error}` but implementation returns `{:error, {:backend_error, reason}}`

**Fix:** Updated `lib/ex_outlines.ex` documentation to match implementation:

```elixir
## Returns

- `{:ok, result}` - Successfully generated and validated output
- `{:error, :max_retries_exceeded}` - Exhausted all retry attempts
- `{:error, {:backend_error, reason}}` - Backend communication failure  ← Fixed
- `{:error, {:backend_exception, error}}` - Backend raised an exception  ← Added
- `{:error, :no_backend}` - No backend specified
- `{:error, {:invalid_backend, value}}` - Backend is not an atom  ← Added
```

### Issue 2: Spec.Schema Documentation Accuracy

**Problem:** Documentation said Schema was "in development" but it's fully implemented

**Current State:**
- 367 lines of implementation ✅
- 53 passing tests ✅
- Full validation for all field types ✅
- JSON Schema generation ✅

**Documentation:** Correctly states "JSON schema-based validation (v0.1)"

---

## Running the Tests

```bash
# Run all Prompt tests
mix test test/prompt_test.exs

# Run with seed for reproducibility
mix test test/prompt_test.exs --seed 0

# Run specific test
mix test test/prompt_test.exs:8

# Run all tests
mix test
```

---

## Test Output Example

```
Running ExUnit with seed: 0, max_cases: 20

....................................
Finished in 0.1 seconds (0.1s async, 0.00s sync)
36 tests, 0 failures
```

---

## Future Enhancements

Potential areas for additional testing:

1. **Prompt Templates**
   - Configurable system messages
   - Custom instruction sets
   - Multi-language support

2. **Advanced Error Formatting**
   - Nested error paths (e.g., "user.address.city")
   - Error grouping by type
   - Severity levels

3. **Message Optimization**
   - Token counting
   - Message compression
   - Schema simplification

4. **Provider-Specific Formats**
   - OpenAI message format
   - Anthropic message format
   - Custom backend formats

---

## Conclusion

The Prompt module now has comprehensive test coverage ensuring:
- ✅ Correct message structure for LLM APIs
- ✅ Proper JSON Schema inclusion
- ✅ Accurate error formatting
- ✅ Trimmed content without whitespace issues
- ✅ Integration with Schema and Diagnostics
- ✅ Regression prevention for prompt construction

All 136 tests pass (8 doctests + 128 unit tests including 36 Prompt tests).
