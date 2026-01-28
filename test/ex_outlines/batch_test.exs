defmodule ExOutlines.BatchTest do
  use ExUnit.Case, async: false

  alias ExOutlines.Spec.Schema
  alias ExOutlines.Backend.Mock

  setup do
    # Attach telemetry handler to capture events
    telemetry_events = [
      [:ex_outlines, :batch, :start],
      [:ex_outlines, :batch, :stop]
    ]

    test_pid = self()

    :telemetry.attach_many(
      "batch-test-handler",
      telemetry_events,
      fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn ->
      :telemetry.detach("batch-test-handler")
    end)

    :ok
  end

  describe "generate_batch/2" do
    test "processes multiple schemas concurrently" do
      schema1 = Schema.new(%{name: %{type: :string, required: true}})
      schema2 = Schema.new(%{age: %{type: :integer, required: true}})
      schema3 = Schema.new(%{active: %{type: :boolean, required: true}})

      mock1 = Mock.new([{:ok, ~s({"name": "Alice"})}])
      mock2 = Mock.new([{:ok, ~s({"age": 30})}])
      mock3 = Mock.new([{:ok, ~s({"active": true})}])

      tasks = [
        {schema1, [backend: Mock, backend_opts: [mock: mock1]]},
        {schema2, [backend: Mock, backend_opts: [mock: mock2]]},
        {schema3, [backend: Mock, backend_opts: [mock: mock3]]}
      ]

      results = ExOutlines.generate_batch(tasks)

      assert length(results) == 3
      assert {:ok, %{name: "Alice"}} = Enum.at(results, 0)
      assert {:ok, %{age: 30}} = Enum.at(results, 1)
      assert {:ok, %{active: true}} = Enum.at(results, 2)
    end

    test "handles mixed success and failure" do
      success_schema = Schema.new(%{name: %{type: :string, required: true}})
      fail_schema = Schema.new(%{age: %{type: :integer, required: true}})

      success_mock = Mock.new([{:ok, ~s({"name": "Bob"})}])
      fail_mock = Mock.new([{:ok, ~s({"age": "invalid"})}])

      tasks = [
        {success_schema, [backend: Mock, backend_opts: [mock: success_mock]]},
        {fail_schema, [backend: Mock, backend_opts: [mock: fail_mock], max_retries: 1]}
      ]

      results = ExOutlines.generate_batch(tasks)

      assert length(results) == 2
      assert {:ok, %{name: "Bob"}} = Enum.at(results, 0)
      assert {:error, :max_retries_exceeded} = Enum.at(results, 1)
    end

    test "respects max_concurrency option" do
      schema = Schema.new(%{value: %{type: :integer, required: true}})

      tasks =
        for i <- 1..5 do
          mock = Mock.new([{:ok, ~s({"value": #{i}})}])
          {schema, [backend: Mock, backend_opts: [mock: mock]]}
        end

      results = ExOutlines.generate_batch(tasks, max_concurrency: 2)

      assert length(results) == 5
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end

    test "returns results in order when ordered: true (default)" do
      schema = Schema.new(%{id: %{type: :integer, required: true}})

      tasks =
        for i <- 1..10 do
          mock = Mock.new([{:ok, ~s({"id": #{i}})}])
          {schema, [backend: Mock, backend_opts: [mock: mock]]}
        end

      results = ExOutlines.generate_batch(tasks, ordered: true)

      assert length(results) == 10

      # Verify order is preserved
      ids = Enum.map(results, fn {:ok, %{id: id}} -> id end)
      assert ids == Enum.to_list(1..10)
    end

    test "accepts timeout and on_timeout options" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      mock = Mock.new([{:ok, ~s({"name": "Test"})}])

      tasks = [
        {schema, [backend: Mock, backend_opts: [mock: mock]]}
      ]

      # Should complete successfully with these options set
      # (actual timeout behavior is hard to test reliably with fast Mock backend)
      results = ExOutlines.generate_batch(tasks, timeout: 10_000, on_timeout: :kill_task)

      assert length(results) == 1
      assert {:ok, %{name: "Test"}} = hd(results)
    end

    test "emits telemetry events for batch start" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      mock = Mock.new([{:ok, ~s({"name": "Test"})}])

      tasks = [{schema, [backend: Mock, backend_opts: [mock: mock]]}]

      ExOutlines.generate_batch(tasks)

      # Check for batch start event
      assert_receive {:telemetry, [:ex_outlines, :batch, :start], measurements, metadata}
      assert measurements.total_tasks == 1
      assert metadata.max_concurrency == System.schedulers_online()
    end

    test "emits telemetry events for batch stop" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      mock = Mock.new([{:ok, ~s({"name": "Test"})}])

      tasks = [{schema, [backend: Mock, backend_opts: [mock: mock]]}]

      ExOutlines.generate_batch(tasks)

      # Check for batch stop event
      assert_receive {:telemetry, [:ex_outlines, :batch, :stop], measurements, _metadata}
      assert measurements.total_tasks == 1
      assert measurements.success_count == 1
      assert measurements.error_count == 0
      assert is_integer(measurements.duration)
    end

    test "tracks success and error counts in telemetry" do
      success_schema = Schema.new(%{name: %{type: :string, required: true}})
      fail_schema = Schema.new(%{age: %{type: :integer, required: true}})

      success_mock = Mock.new([{:ok, ~s({"name": "Alice"})}])
      fail_mock = Mock.new([{:ok, ~s({"age": "invalid"})}])

      tasks = [
        {success_schema, [backend: Mock, backend_opts: [mock: success_mock]]},
        {success_schema, [backend: Mock, backend_opts: [mock: success_mock]]},
        {fail_schema, [backend: Mock, backend_opts: [mock: fail_mock], max_retries: 1]}
      ]

      ExOutlines.generate_batch(tasks)

      # Check telemetry counts
      assert_receive {:telemetry, [:ex_outlines, :batch, :stop], measurements, _metadata}
      assert measurements.total_tasks == 3
      assert measurements.success_count == 2
      assert measurements.error_count == 1
    end

    test "handles empty batch" do
      results = ExOutlines.generate_batch([])

      assert results == []

      # Should still emit telemetry
      assert_receive {:telemetry, [:ex_outlines, :batch, :start], measurements, _metadata}
      assert measurements.total_tasks == 0

      assert_receive {:telemetry, [:ex_outlines, :batch, :stop], measurements, _metadata}
      assert measurements.total_tasks == 0
      assert measurements.success_count == 0
      assert measurements.error_count == 0
    end

    test "processes large batch efficiently" do
      schema = Schema.new(%{id: %{type: :integer, required: true}})

      tasks =
        for i <- 1..50 do
          mock = Mock.new([{:ok, ~s({"id": #{i}})}])
          {schema, [backend: Mock, backend_opts: [mock: mock]]}
        end

      results = ExOutlines.generate_batch(tasks, max_concurrency: 10)

      assert length(results) == 50
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Check telemetry for performance
      assert_receive {:telemetry, [:ex_outlines, :batch, :stop], measurements, _metadata}
      assert measurements.total_tasks == 50
      assert measurements.success_count == 50
      assert measurements.error_count == 0
      # Duration should be reasonable (not timing out)
      assert measurements.duration > 0
    end

    test "supports custom telemetry metadata" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      mock = Mock.new([{:ok, ~s({"name": "Test"})}])

      tasks = [{schema, [backend: Mock, backend_opts: [mock: mock]]}]

      custom_metadata = %{batch_id: "test-123", user_id: "user-456"}

      ExOutlines.generate_batch(tasks, telemetry_metadata: custom_metadata)

      # Check custom metadata is included
      assert_receive {:telemetry, [:ex_outlines, :batch, :start], _measurements, metadata}
      assert metadata.batch_id == "test-123"
      assert metadata.user_id == "user-456"

      assert_receive {:telemetry, [:ex_outlines, :batch, :stop], _measurements, metadata}
      assert metadata.batch_id == "test-123"
      assert metadata.user_id == "user-456"
    end

    test "handles backend errors gracefully" do
      schema = Schema.new(%{name: %{type: :string, required: true}})

      # Task with no backend specified (should error)
      tasks = [
        {schema, []}
      ]

      results = ExOutlines.generate_batch(tasks)

      assert length(results) == 1
      assert {:error, :no_backend} = hd(results)
    end

    test "each task is independent" do
      schema = Schema.new(%{value: %{type: :integer, required: true}})

      success_mock = Mock.new([{:ok, ~s({"value": 1})}])
      fail_mock = Mock.new([{:ok, ~s({"value": "bad"})}])

      tasks = [
        {schema, [backend: Mock, backend_opts: [mock: success_mock]]},
        {schema, [backend: Mock, backend_opts: [mock: fail_mock], max_retries: 1]},
        {schema, [backend: Mock, backend_opts: [mock: success_mock]]},
        {schema, [backend: Mock, backend_opts: [mock: fail_mock], max_retries: 1]},
        {schema, [backend: Mock, backend_opts: [mock: success_mock]]}
      ]

      results = ExOutlines.generate_batch(tasks)

      assert length(results) == 5

      # Check that failures don't affect other tasks
      assert {:ok, %{value: 1}} = Enum.at(results, 0)
      assert {:error, :max_retries_exceeded} = Enum.at(results, 1)
      assert {:ok, %{value: 1}} = Enum.at(results, 2)
      assert {:error, :max_retries_exceeded} = Enum.at(results, 3)
      assert {:ok, %{value: 1}} = Enum.at(results, 4)
    end

    test "supports different schemas in same batch" do
      user_schema = Schema.new(%{
        name: %{type: :string, required: true},
        age: %{type: :integer, required: true}
      })

      product_schema = Schema.new(%{
        title: %{type: :string, required: true},
        price: %{type: :number, required: true}
      })

      user_mock = Mock.new([{:ok, ~s({"name": "Alice", "age": 30})}])
      product_mock = Mock.new([{:ok, ~s({"title": "Book", "price": 19.99})}])

      tasks = [
        {user_schema, [backend: Mock, backend_opts: [mock: user_mock]]},
        {product_schema, [backend: Mock, backend_opts: [mock: product_mock]]}
      ]

      results = ExOutlines.generate_batch(tasks)

      assert length(results) == 2
      assert {:ok, %{name: "Alice", age: 30}} = Enum.at(results, 0)
      assert {:ok, %{title: "Book", price: 19.99}} = Enum.at(results, 1)
    end
  end

  describe "batch options" do
    test "validates max_concurrency is used" do
      schema = Schema.new(%{id: %{type: :integer, required: true}})

      tasks =
        for i <- 1..3 do
          mock = Mock.new([{:ok, ~s({"id": #{i}})}])
          {schema, [backend: Mock, backend_opts: [mock: mock]]}
        end

      # Should work with custom concurrency
      results = ExOutlines.generate_batch(tasks, max_concurrency: 1)

      assert length(results) == 3
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Check telemetry includes max_concurrency
      assert_receive {:telemetry, [:ex_outlines, :batch, :start], _measurements, metadata}
      assert metadata.max_concurrency == 1
    end

    test "uses default max_concurrency when not specified" do
      schema = Schema.new(%{id: %{type: :integer, required: true}})
      mock = Mock.new([{:ok, ~s({"id": 1})}])

      tasks = [{schema, [backend: Mock, backend_opts: [mock: mock]]}]

      ExOutlines.generate_batch(tasks)

      # Should use System.schedulers_online() by default
      assert_receive {:telemetry, [:ex_outlines, :batch, :start], _measurements, metadata}
      assert metadata.max_concurrency == System.schedulers_online()
    end

    test "respects timeout option" do
      schema = Schema.new(%{name: %{type: :string, required: true}})
      mock = Mock.new([{:ok, ~s({"name": "Test"})}])

      tasks = [{schema, [backend: Mock, backend_opts: [mock: mock]]}]

      # Should complete successfully with reasonable timeout
      results = ExOutlines.generate_batch(tasks, timeout: 10_000)

      assert [{:ok, %{name: "Test"}}] = results
    end

    test "ordered: false returns results (order may vary)" do
      schema = Schema.new(%{id: %{type: :integer, required: true}})

      tasks =
        for i <- 1..5 do
          mock = Mock.new([{:ok, ~s({"id": #{i}})}])
          {schema, [backend: Mock, backend_opts: [mock: mock]]}
        end

      results = ExOutlines.generate_batch(tasks, ordered: false)

      # All results should be present
      assert length(results) == 5
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All IDs should be present (order may vary)
      ids = Enum.map(results, fn {:ok, %{id: id}} -> id end)
      assert Enum.sort(ids) == [1, 2, 3, 4, 5]
    end
  end
end
