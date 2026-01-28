defmodule ExOutlines.Backend.Mock do
  @moduledoc """
  Deterministic mock backend for testing.

  Returns pre-configured responses in sequence, allowing tests to simulate
  LLM behavior without external dependencies.

  ## Example

      # Configure responses
      mock = Mock.new([
        {:ok, ~s({"name": "Alice", "age": 30})},
        {:ok, ~s({"name": "Alice", "age": 25})}
      ])

      # Use in tests
      {:ok, response} = Mock.call_llm(mock, messages, opts)
      # => {:ok, ~s({"name": "Alice", "age": 30})}

  ## Error Simulation

      mock = Mock.new([
        {:error, :rate_limited},
        {:ok, ~s({"valid": "json"})}
      ])

      {:error, reason} = Mock.call_llm(mock, messages, opts)
      # => {:error, :rate_limited}
  """

  @behaviour ExOutlines.Backend

  @type response :: {:ok, String.t()} | {:error, term()}
  @type t :: %__MODULE__{
          agent_pid: pid(),
          call_count: non_neg_integer()
        }

  defstruct [:agent_pid, call_count: 0]

  @doc """
  Create a new mock backend with pre-configured responses.

  Responses are returned in order. After exhausting all responses,
  returns `{:error, :no_more_responses}`.

  ## Examples

      iex> mock = ExOutlines.Backend.Mock.new([
      ...>   {:ok, "response 1"},
      ...>   {:ok, "response 2"}
      ...> ])
      iex> is_struct(mock, ExOutlines.Backend.Mock)
      true
  """
  @dialyzer {:nowarn_function, new: 1}
  @spec new([response()]) :: t()
  def new(responses) when is_list(responses) do
    {:ok, agent_pid} = Agent.start_link(fn -> {responses, 0} end)
    %__MODULE__{agent_pid: agent_pid, call_count: 0}
  end

  @doc """
  Create a mock that always returns the same response.

  ## Examples

      iex> mock = ExOutlines.Backend.Mock.always({:ok, "same response"})
      iex> is_struct(mock, ExOutlines.Backend.Mock)
      true
  """
  @dialyzer {:nowarn_function, always: 1}
  @spec always(response()) :: t()
  def always(response) do
    # For always, we use an infinite list (repeat the response)
    {:ok, agent_pid} = Agent.start_link(fn -> {Stream.cycle([response]) |> Enum.take(1000), 0} end)
    %__MODULE__{agent_pid: agent_pid, call_count: 0}
  end

  @doc """
  Create a mock that always fails with the given error.

  ## Examples

      iex> mock = ExOutlines.Backend.Mock.always_fail(:timeout)
      iex> is_struct(mock, ExOutlines.Backend.Mock)
      true
  """
  @dialyzer {:nowarn_function, always_fail: 1}
  @spec always_fail(term()) :: t()
  def always_fail(error) do
    always({:error, error})
  end

  @doc """
  Get the number of times this mock has been called.

  ## Examples

      iex> mock = ExOutlines.Backend.Mock.new([{:ok, "response"}])
      iex> ExOutlines.Backend.Mock.call_count(mock)
      0
  """
  @spec call_count(t()) :: non_neg_integer()
  def call_count(%__MODULE__{agent_pid: agent_pid}) do
    Agent.get(agent_pid, fn {_responses, count} -> count end)
  end

  @doc """
  Call the mock backend.

  Returns the next response in sequence. This implementation is stateless,
  so you need to pass the mock instance with state if using in a process.

  For use with ExOutlines.generate/2, pass the mock struct in backend_opts:

      ExOutlines.generate(spec,
        backend: ExOutlines.Backend.Mock,
        backend_opts: [mock: mock]
      )
  """
  @impl ExOutlines.Backend
  def call_llm(messages, opts) when is_list(messages) and is_list(opts) do
    # Extract mock from opts
    mock = Keyword.get(opts, :mock)

    if is_nil(mock) do
      {:error, :no_mock_provided}
    else
      get_next_response(mock)
    end
  end

  # Private helpers

  defp get_next_response(%__MODULE__{agent_pid: agent_pid}) do
    Agent.get_and_update(agent_pid, fn {responses, count} ->
      case responses do
        [] ->
          # No more responses configured
          {{:error, :no_more_responses}, {[], count + 1}}

        [response | rest] ->
          # Return the next response and update state
          {response, {rest, count + 1}}
      end
    end)
  end
end
