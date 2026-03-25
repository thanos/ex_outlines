defmodule ExOutlines.StreamTest do
  use ExUnit.Case, async: true

  alias ExOutlines.Backend.Mock
  alias ExOutlines.Spec.Schema
  alias ExOutlines.Stream, as: S

  describe "validated_stream/2" do
    test "accumulates chunks and validates on done" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      events = [
        {:chunk, ~s({"na)},
        {:chunk, ~s(me": "Alice"})},
        {:done, ~s({"name": "Alice"})}
      ]

      results = S.validated_stream(events, schema) |> Enum.to_list()

      assert [{:chunk, ~s({"na)}, {:chunk, ~s({"name": "Alice"})}, {:ok, %{name: "Alice"}}] =
               results
    end

    test "returns validation error on done when JSON is invalid" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      events = [{:done, "not json"}]

      results = S.validated_stream(events, schema) |> Enum.to_list()

      assert [{:error, {:json_decode_error, _}}] = results
    end

    test "returns validation error on done when schema fails" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      events = [{:done, ~s({"age": 30})}]

      results = S.validated_stream(events, schema) |> Enum.to_list()

      assert [{:error, {:validation_failed, _}}] = results
    end

    test "propagates stream errors" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      events = [
        {:chunk, "partial"},
        {:error, :connection_reset}
      ]

      results = S.validated_stream(events, schema) |> Enum.to_list()

      assert [{:chunk, "partial"}, {:error, {:stream_error, :connection_reset}}] = results
    end
  end

  describe "from_buffered/1" do
    test "wraps ok response as done event" do
      events = S.from_buffered({:ok, ~s({"x": 1})})
      assert [{:done, ~s({"x": 1})}] = events
    end

    test "wraps error response as error event" do
      events = S.from_buffered({:error, :timeout})
      assert [{:error, :timeout}] = events
    end
  end

  describe "generate_stream/2 with streaming mock" do
    test "streams chunks and validates" do
      mock = Mock.new([])
      schema = Schema.new(%{name: %{type: :string, required: true}})

      chunks = [
        {:chunk, ~s({"na)},
        {:chunk, ~s(me": "Bob"})},
        {:done, ~s({"name": "Bob"})}
      ]

      {:ok, stream} =
        ExOutlines.generate_stream(schema,
          backend: Mock,
          backend_opts: [mock: mock, stream_chunks: chunks]
        )

      results = Enum.to_list(stream)

      assert [{:chunk, _}, {:chunk, _}, {:ok, %{name: "Bob"}}] = results
    end

    test "streams with fallback from non-streaming response" do
      mock = Mock.new([{:ok, ~s({"name": "Alice"})}])
      schema = Schema.new(%{name: %{type: :string, required: true}})

      {:ok, stream} =
        ExOutlines.generate_stream(schema,
          backend: Mock,
          backend_opts: [mock: mock]
        )

      results = Enum.to_list(stream)

      assert [{:ok, %{name: "Alice"}}] = results
    end

    test "returns config error before creating stream" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, :no_backend} =
               ExOutlines.generate_stream(schema, [])
    end

    test "returns template error before creating stream" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      assert {:error, {:invalid_template, _}} =
               ExOutlines.generate_stream(schema,
                 backend: Mock,
                 backend_opts: [mock: Mock.new([])],
                 template: "bad"
               )
    end

    test "emits validation error for invalid JSON in stream" do
      mock = Mock.new([])
      schema = Schema.new(%{name: %{type: :string, required: true}})

      chunks = [{:done, "not json at all"}]

      {:ok, stream} =
        ExOutlines.generate_stream(schema,
          backend: Mock,
          backend_opts: [mock: mock, stream_chunks: chunks]
        )

      results = Enum.to_list(stream)

      assert [{:error, {:json_decode_error, _}}] = results
    end

    test "emits validation error for schema mismatch in stream" do
      mock = Mock.new([])
      schema = Schema.new(%{name: %{type: :string, required: true}})

      chunks = [{:done, ~s({"age": 30})}]

      {:ok, stream} =
        ExOutlines.generate_stream(schema,
          backend: Mock,
          backend_opts: [mock: mock, stream_chunks: chunks]
        )

      results = Enum.to_list(stream)

      assert [{:error, {:validation_failed, _}}] = results
    end
  end

  describe "generate_stream/2 with non-streaming backend fallback" do
    test "falls back to buffered mode for backends without call_llm_stream" do
      # HTTP backend doesn't implement call_llm_stream yet
      # We test fallback by using a backend that only has call_llm
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Mock with only a regular response (no stream_chunks)
      mock = Mock.new([{:ok, ~s({"name": "Fallback"})}])

      {:ok, stream} =
        ExOutlines.generate_stream(schema,
          backend: Mock,
          backend_opts: [mock: mock]
        )

      results = Enum.to_list(stream)

      assert [{:ok, %{name: "Fallback"}}] = results
    end
  end
end
