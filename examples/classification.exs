#!/usr/bin/env elixir
#
# Classification Example: Customer Support Triage
#
# This example demonstrates how to use Ex Outlines for automated classification
# of customer support requests. It shows:
# - Schema definition for classification tasks
# - Multiple schema approaches (simple vs. structured)
# - Testing with Mock backend
# - Phoenix integration patterns
# - Batch processing for multiple requests
# - Telemetry monitoring
#
# Run with: elixir examples/classification.exs

Mix.install([{:ex_outlines, path: ".."}])

defmodule Examples.Classification do
  @moduledoc """
  Customer support triage using Ex Outlines structured generation.

  Automatically classifies incoming support requests into:
  - Priority levels (low, medium, high, critical)
  - Categories (technical, billing, account, feature_request, general)
  - Escalation needs (boolean)
  - Customer sentiment (positive, neutral, negative, angry)
  """

  alias ExOutlines.{Spec.Schema, Backend.Mock, Backend.HTTP}

  # ============================================================================
  # Schema Definitions
  # ============================================================================

  @doc """
  Comprehensive triage schema with all classification fields.
  """
  def triage_schema do
    Schema.new(%{
      priority: %{
        type: {:enum, ["low", "medium", "high", "critical"]},
        required: true,
        description: "Urgency level of support request"
      },
      category: %{
        type: {:enum, ["technical", "billing", "account", "feature_request", "general"]},
        required: true,
        description: "Request category for routing to correct team"
      },
      requires_escalation: %{
        type: :boolean,
        required: true,
        description: "Whether request needs manager or senior support attention"
      },
      sentiment: %{
        type: {:enum, ["positive", "neutral", "negative", "angry"]},
        required: false,
        description: "Customer sentiment and emotional tone"
      },
      summary: %{
        type: :string,
        required: true,
        min_length: 10,
        max_length: 200,
        description: "Brief summary of the customer's issue"
      }
    })
  end

  @doc """
  Simple classification schema (priority and category only).
  Use this for basic triage when full analysis isn't needed.
  """
  def simple_schema do
    Schema.new(%{
      priority: %{type: {:enum, ["low", "medium", "high", "critical"]}},
      category: %{type: {:enum, ["technical", "billing", "account", "feature_request", "general"]}}
    })
  end

  # ============================================================================
  # Classification Functions
  # ============================================================================

  @doc """
  Classify a support request message.

  ## Options

    * `:backend` - Backend module (default: HTTP)
    * `:backend_opts` - Backend options (api_key, model, etc.)
    * `:schema` - Schema to use (default: triage_schema)
    * `:max_retries` - Maximum retry attempts (default: 3)

  ## Examples

      # With OpenAI
      {:ok, classification} = classify_request(
        "URGENT: Payment processing is down!",
        backend: HTTP,
        backend_opts: [api_key: "sk-...", model: "gpt-4o-mini"]
      )

      # With Mock backend for testing
      mock = Mock.new([{:ok, ~s({"priority": "critical", "category": "technical", ...})}])
      {:ok, classification} = classify_request(
        "Test message",
        backend: Mock,
        backend_opts: [mock: mock]
      )

  """
  def classify_request(message, opts \\ []) do
    backend = Keyword.get(opts, :backend, HTTP)
    backend_opts = Keyword.get(opts, :backend_opts, [])
    schema = Keyword.get(opts, :schema, triage_schema())
    max_retries = Keyword.get(opts, :max_retries, 3)

    # Build messages for LLM
    messages = [
      %{
        role: "system",
        content: """
        You are a customer support triage specialist. Analyze support requests and classify them accurately.

        Guidelines:
        - CRITICAL: System down, data loss, security breach, revenue impact
        - HIGH: Cannot use key features, multiple users affected
        - MEDIUM: Feature not working as expected, workarounds available
        - LOW: Questions, feature requests, minor issues

        Escalate when: customer is very angry, legal threats, security concerns, or high-value accounts.
        """
      },
      %{
        role: "user",
        content: """
        Classify this support request:

        #{message}

        Provide structured JSON output matching the schema.
        """
      }
    ]

    # Generate with structured output
    ExOutlines.generate(schema,
      backend: backend,
      backend_opts: Keyword.put(backend_opts, :messages, messages),
      max_retries: max_retries
    )
  end

  @doc """
  Classify multiple requests concurrently using batch processing.

  Returns results in the same order as input messages.

  ## Examples

      messages = [
        "Can't login to my account",
        "Feature request: dark mode",
        "URGENT: Payment system down!"
      ]

      results = classify_batch(messages, max_concurrency: 3)
      # => [{:ok, classification1}, {:ok, classification2}, {:ok, classification3}]

  """
  def classify_batch(messages, opts \\ []) do
    backend = Keyword.get(opts, :backend, HTTP)
    backend_opts = Keyword.get(opts, :backend_opts, [])
    schema = Keyword.get(opts, :schema, triage_schema())
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

    # Build tasks for each message
    tasks =
      Enum.map(messages, fn msg ->
        # Build messages for this specific request
        messages = [
          %{role: "system", content: get_system_prompt()},
          %{role: "user", content: "Classify this support request:\n\n#{msg}"}
        ]

        {schema, [
          backend: backend,
          backend_opts: Keyword.put(backend_opts, :messages, messages)
        ]}
      end)

    # Process concurrently
    ExOutlines.generate_batch(tasks, max_concurrency: max_concurrency)
  end

  # ============================================================================
  # Example Requests
  # ============================================================================

  @doc """
  Example support requests for testing and demonstration.
  """
  def example_requests do
    [
      %{
        id: 1,
        label: "Critical - System Down",
        message: """
        URGENT: Payment processing is completely down! We've been losing revenue for the past 2 hours.
        Multiple customers are calling us. This needs to be fixed IMMEDIATELY!!!
        """,
        expected: %{priority: "critical", category: "technical", requires_escalation: true}
      },
      %{
        id: 2,
        label: "High - Cannot Login",
        message: """
        I can't login to my account for the past 2 hours. I've tried password reset 3 times but
        the reset email never arrives. I have an important presentation at 3pm and need access NOW.
        """,
        expected: %{priority: "high", category: "technical", requires_escalation: false}
      },
      %{
        id: 3,
        label: "Medium - Feature Request",
        message: """
        Would love to see dark mode support in the dashboard. Working late at night and the bright
        white background is hard on the eyes. Not urgent but would be a nice improvement!
        """,
        expected: %{priority: "low", category: "feature_request", requires_escalation: false}
      },
      %{
        id: 4,
        label: "Low - Simple Question",
        message: """
        Hi, quick question - how do I change my email address in the account settings? I looked
        through the settings but couldn't find it. Thanks!
        """,
        expected: %{priority: "low", category: "account", requires_escalation: false}
      },
      %{
        id: 5,
        label: "High - Billing Issue",
        message: """
        I was charged twice this month! I see two charges of $99 on my credit card from your company.
        This is unacceptable. I want a refund immediately or I'm disputing with my bank.
        """,
        expected: %{priority: "high", category: "billing", requires_escalation: true}
      }
    ]
  end

  # ============================================================================
  # Testing with Mock Backend
  # ============================================================================

  @doc """
  Test classification with Mock backend (no API calls).
  """
  def test_with_mock do
    IO.puts("\n=== Testing Classification with Mock Backend ===\n")

    # Get first example request
    request = hd(example_requests())

    # Create mock with expected response
    mock =
      Mock.new([
        {:ok,
         ~s({
        "priority": "critical",
        "category": "technical",
        "requires_escalation": true,
        "sentiment": "angry",
        "summary": "Payment system completely down causing revenue loss for 2 hours"
      })}
      ])

    # Classify
    case classify_request(request.message,
           backend: Mock,
           backend_opts: [mock: mock]
         ) do
      {:ok, classification} ->
        IO.puts("Request: #{request.label}")
        IO.puts("Classification successful!")
        IO.inspect(classification, label: "Result", pretty: true)

      {:error, reason} ->
        IO.puts("Classification failed: #{inspect(reason)}")
    end
  end

  # ============================================================================
  # Phoenix Integration Patterns
  # ============================================================================

  @doc """
  Example Phoenix controller action for classifying support tickets.

  In your controller:

      def create(conn, %{"message" => message}) do
        case Examples.Classification.classify_and_save(message) do
          {:ok, ticket} ->
            conn
            |> put_flash(:info, "Ticket created with \#{ticket.priority} priority")
            |> redirect(to: ~p"/tickets/\#{ticket.id}")

          {:error, reason} ->
            conn
            |> put_flash(:error, "Failed to process request: \#{inspect(reason)}")
            |> render("new.html")
        end
      end

  """
  def classify_and_save(message, opts \\ []) do
    with {:ok, classification} <- classify_request(message, opts),
         {:ok, ticket} <- save_ticket(classification, message) do
      {:ok, ticket}
    end
  end

  # Simulated database save
  defp save_ticket(classification, message) do
    ticket = %{
      id: :rand.uniform(10000),
      message: message,
      priority: classification.priority,
      category: classification.category,
      requires_escalation: classification.requires_escalation,
      summary: classification.summary,
      created_at: DateTime.utc_now()
    }

    {:ok, ticket}
  end

  # ============================================================================
  # Telemetry Monitoring
  # ============================================================================

  @doc """
  Setup telemetry handlers for monitoring classification performance.

  Call this in your application supervision tree:

      Examples.Classification.setup_telemetry()

  """
  def setup_telemetry do
    :telemetry.attach(
      "classification-monitor",
      [:ex_outlines, :generate, :stop],
      fn _event, measurements, metadata, _config ->
        duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

        IO.puts("""
        [Telemetry] Classification completed:
          Duration: #{duration_ms}ms
          Attempts: #{measurements.attempt_count}
          Status: #{metadata.status}
          Backend: #{inspect(metadata.backend)}
        """)
      end,
      nil
    )

    IO.puts("Telemetry monitoring enabled for classification")
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp get_system_prompt do
    """
    You are a customer support triage specialist. Analyze support requests and classify them accurately.

    Guidelines:
    - CRITICAL: System down, data loss, security breach, revenue impact
    - HIGH: Cannot use key features, multiple users affected
    - MEDIUM: Feature not working as expected, workarounds available
    - LOW: Questions, feature requests, minor issues

    Escalate when: customer is very angry, legal threats, security concerns, or high-value accounts.
    """
  end
end

# ============================================================================
# Demo Execution
# ============================================================================

IO.puts("=" |> String.duplicate(80))
IO.puts("Customer Support Classification Example")
IO.puts("=" |> String.duplicate(80))

# Setup telemetry
Examples.Classification.setup_telemetry()

# Run mock test
Examples.Classification.test_with_mock()

# Show example requests
IO.puts("\n=== Example Support Requests ===\n")

Examples.Classification.example_requests()
|> Enum.each(fn request ->
  IO.puts("#{request.id}. #{request.label}")
  IO.puts("   Message: #{String.slice(request.message, 0, 80)}...")
  IO.puts("   Expected: priority=#{request.expected.priority}, category=#{request.expected.category}")
  IO.puts("")
end)

IO.puts("\n=== Usage Instructions ===\n")

IO.puts("""
To classify with a real LLM (requires API key):

  # Set your API key
  System.put_env("OPENAI_API_KEY", "sk-...")

  # Classify a message
  message = "URGENT: Payment system is down!"

  {:ok, result} = Examples.Classification.classify_request(message,
    backend: ExOutlines.Backend.HTTP,
    backend_opts: [
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4o-mini"
    ]
  )

  IO.inspect(result, label: "Classification")

Batch processing:

  messages = [
    "Can't login",
    "Feature request: dark mode",
    "Billing issue"
  ]

  results = Examples.Classification.classify_batch(messages,
    backend: ExOutlines.Backend.HTTP,
    backend_opts: [
      api_key: System.get_env("OPENAI_API_KEY"),
      model: "gpt-4o-mini"
    ],
    max_concurrency: 3
  )

Phoenix Integration:

  # In your controller
  def create(conn, %{"message" => message}) do
    case Examples.Classification.classify_and_save(message,
           backend: HTTP,
           backend_opts: get_backend_opts()) do
      {:ok, ticket} ->
        redirect(conn, to: ~p"/tickets/\#{ticket.id}")

      {:error, reason} ->
        put_flash(conn, :error, "Classification failed")
        |> render("new.html")
    end
  end
""")

IO.puts("\nExample complete!")
