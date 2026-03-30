defmodule ExOutlines.IntegrationTestHelper do
  @moduledoc false

  alias ExOutlines.Spec.Schema

  def skip_without_api_key(env_var) do
    unless System.get_env(env_var) do
      throw({:skip_test, "#{env_var} not set - skipping integration test"})
    end
  end

  def get_api_key(env_var) do
    System.get_env(env_var) ||
      throw({:skip_test, "#{env_var} not set"})
  end

  def ollama_available?(url \\ "http://localhost:11434") do
    :inets.start()

    case :httpc.request(
           :get,
           {String.to_charlist(url), []},
           [timeout: 2000],
           []
         ) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def skip_without_ollama(url \\ "http://localhost:11434") do
    unless ollama_available?(url) do
      throw({:skip_test, "Ollama not running at #{url}"})
    end
  end

  def integration_timeout, do: 30_000

  def simple_schema do
    Schema.new(%{
      name: %{type: :string, required: true}
    })
  end

  def complex_schema do
    Schema.new(%{
      user: %{
        type: :object,
        required: true,
        properties: %{
          name: %{type: :string, required: true},
          age: %{type: :integer, required: true, positive: true},
          email: %{type: :string, required: true}
        }
      },
      status: %{type: {:enum, ["active", "inactive"]}, required: true},
      score: %{type: :number, required: false}
    })
  end

  def enum_schema do
    Schema.new(%{
      role: %{type: {:enum, ["admin", "user", "guest"]}, required: true}
    })
  end
end
