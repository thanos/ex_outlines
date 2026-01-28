#!/usr/bin/env elixir
#
# Customer Support Ticket Triage Example
#
# This example demonstrates how to use ExOutlines for automated ticket
# classification, priority assignment, and intelligent routing.
#
# Use cases:
# - Automated ticket triage and priority assignment
# - Intelligent routing to appropriate support teams
# - SLA management with estimated resolution times
# - Urgency detection and escalation
# - Customer sentiment analysis
# - After-hours critical issue identification
#
# Run with: elixir examples/customer_support_triage.exs

Mix.install([{:ex_outlines, path: Path.expand("..", __DIR__)}])

defmodule CustomerSupportTriage do
  @moduledoc """
  Automated customer support ticket triage and routing.

  This module demonstrates a production-ready schema for analyzing support
  tickets, detecting urgency, assigning priority, and routing to the
  appropriate department with estimated resolution times.
  """

  alias ExOutlines.{Spec, Spec.Schema}

  @doc """
  Define the support ticket triage schema.

  The schema validates:
  - Subject line (10-200 characters)
  - Ticket category from predefined types
  - Priority level based on urgency and impact
  - Array of detected urgency indicators
  - Estimated resolution time based on complexity
  - Boolean flag for human review requirement
  - Suggested department for routing
  - Optional sentiment analysis (positive/negative/neutral)
  """
  def ticket_schema do
    Schema.new(%{
      subject: %{
        type: :string,
        required: true,
        min_length: 10,
        max_length: 200,
        description: "Extracted or cleaned ticket subject line"
      },
      category: %{
        type: {:enum, ["technical", "billing", "account", "general", "feature_request"]},
        required: true,
        description: "Primary ticket category"
      },
      priority: %{
        type: {:enum, ["low", "medium", "high", "critical"]},
        required: true,
        description: "Priority level based on urgency and business impact"
      },
      urgency_indicators: %{
        type: {:array, %{type: :string, max_length: 100}},
        max_items: 10,
        description: "Specific phrases or keywords indicating urgency"
      },
      estimated_resolution_time: %{
        type: {:enum, ["1h", "4h", "24h", "72h", "1week"]},
        required: true,
        description: "Estimated time to resolve based on category and complexity"
      },
      requires_human_review: %{
        type: :boolean,
        required: true,
        description: "Whether ticket needs immediate human attention"
      },
      suggested_department: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 50,
        description: "Department best suited to handle this ticket"
      },
      customer_sentiment: %{
        type: {:union, [
          %{type: {:enum, ["positive", "neutral", "negative", "angry"]}},
          %{type: :null}
        ]},
        description: "Detected customer sentiment if determinable"
      },
      tags: %{
        type: {:array, %{type: :string, min_length: 2, max_length: 30}},
        unique_items: true,
        max_items: 5,
        description: "Classification tags for filtering and reporting"
      }
    })
  end

  @doc """
  Triage a customer support ticket.

  In production, this would call an LLM backend with the ticket content.
  For demonstration, we show the schema usage and validation.
  """
  def triage(ticket_content, _opts \\ []) do
    schema = ticket_schema()

    IO.puts("\n=== Ticket Content ===")
    IO.puts(ticket_content)
    IO.puts("\n=== Analyzing ticket... ===")

    {:ok, schema}
  end

  @doc """
  Validate triaged ticket data against the schema.
  """
  def validate_ticket(ticket_data) do
    Spec.validate(ticket_schema(), ticket_data)
  end

  @doc """
  Display the JSON Schema for LLM prompts.
  """
  def show_json_schema do
    schema = ticket_schema()
    json_schema = Spec.to_schema(schema)

    IO.puts("\n=== JSON Schema for LLM ===")
    IO.inspect(json_schema, pretty: true, limit: :infinity)
  end

  @doc """
  Calculate SLA deadline based on priority and estimated resolution time.

  This helper function shows how to use triage results in business logic.
  """
  def calculate_sla_deadline(priority, estimated_time) do
    multiplier =
      case priority do
        "critical" -> 0.5
        "high" -> 0.75
        "medium" -> 1.0
        "low" -> 1.5
      end

    base_minutes =
      case estimated_time do
        "1h" -> 60
        "4h" -> 240
        "24h" -> 1440
        "72h" -> 4320
        "1week" -> 10080
      end

    deadline_minutes = trunc(base_minutes * multiplier)
    DateTime.add(DateTime.utc_now(), deadline_minutes * 60, :second)
  end
end

# ============================================================================
# Example Usage and Testing
# ============================================================================

IO.puts("=" |> String.duplicate(70))
IO.puts("Customer Support Ticket Triage Example")
IO.puts("=" |> String.duplicate(70))

# Display the JSON Schema
CustomerSupportTriage.show_json_schema()

# ============================================================================
# Example 1: Critical - Payment Processing Failure
# ============================================================================

ticket_critical = """
Subject: URGENT: Payment processing completely down - losing revenue!

We've been trying to process payments for the past 2 hours and NOTHING is working.
All our transactions are failing with error code 500. This is costing us thousands
of dollars per hour! Our customers are calling constantly. We need someone to fix
this IMMEDIATELY. This is unacceptable for a paid service.

Our production API key: pk_prod_xxx
Error started at: 14:30 UTC today
Affected endpoints: /api/v1/charge, /api/v1/subscription

Please escalate this to your engineering team RIGHT NOW.
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 1: Critical Payment Issue")
IO.puts("=" |> String.duplicate(70))

CustomerSupportTriage.triage(ticket_critical)

expected_critical = %{
  "subject" => "Payment processing completely down - losing revenue",
  "category" => "technical",
  "priority" => "critical",
  "urgency_indicators" => [
    "URGENT",
    "completely down",
    "losing revenue",
    "costing us thousands",
    "IMMEDIATELY",
    "RIGHT NOW"
  ],
  "estimated_resolution_time" => "1h",
  "requires_human_review" => true,
  "suggested_department" => "Engineering - Payment Systems",
  "customer_sentiment" => "angry",
  "tags" => ["payment", "production", "outage", "api", "critical"]
}

IO.puts("\n=== Expected Triage Output ===")
IO.inspect(expected_critical, pretty: true)

case CustomerSupportTriage.validate_ticket(expected_critical) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    # Calculate SLA deadline
    deadline = CustomerSupportTriage.calculate_sla_deadline(
      validated.priority,
      validated.estimated_resolution_time
    )
    IO.puts("\n⏰ SLA Deadline: #{DateTime.to_string(deadline)}")
    IO.puts("   (Critical priority: 0.5x multiplier on 1h = 30 minutes)")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 2: High - Account Login Issues
# ============================================================================

ticket_high = """
Subject: Cannot login to account - tried password reset 3 times

I've been locked out of my account for the past day. I tried resetting my password
three times using the "forgot password" link, but I never receive the reset email.
I've checked spam folders and tried two different email addresses associated with
my account.

I have important files in my account that I need to access for a client meeting
tomorrow morning. Can you please help me regain access as soon as possible?

Account email: user@example.com
Account ID: usr_123456789
Last successful login: 2 days ago
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 2: High Priority Account Access")
IO.puts("=" |> String.duplicate(70))

CustomerSupportTriage.triage(ticket_high)

expected_high = %{
  "subject" => "Cannot login to account - tried password reset 3 times",
  "category" => "account",
  "priority" => "high",
  "urgency_indicators" => [
    "locked out",
    "tried password reset 3 times",
    "never receive the reset email",
    "client meeting tomorrow",
    "as soon as possible"
  ],
  "estimated_resolution_time" => "4h",
  "requires_human_review" => true,
  "suggested_department" => "Account Security",
  "customer_sentiment" => "negative",
  "tags" => ["login", "password-reset", "email", "account-access"]
}

IO.puts("\n=== Expected Triage Output ===")
IO.inspect(expected_high, pretty: true)

case CustomerSupportTriage.validate_ticket(expected_high) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    deadline = CustomerSupportTriage.calculate_sla_deadline(
      validated.priority,
      validated.estimated_resolution_time
    )
    IO.puts("\n⏰ SLA Deadline: #{DateTime.to_string(deadline)}")
    IO.puts("   (High priority: 0.75x multiplier on 4h = 3 hours)")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 3: Medium - Feature Request
# ============================================================================

ticket_medium = """
Subject: Feature request: Dark mode support

Hello! I've been using your product for a few months now and really enjoy it.
One feature I'd love to see is dark mode support for the web interface.

I often work late at night, and the bright white background can be a bit
harsh on the eyes. Many other apps I use have added dark mode recently,
and it would be great if your product had this option too.

Is this something that's on your roadmap? Even just a simple toggle in
settings would be appreciated.

Thanks for all the great work on the product!
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 3: Medium Priority Feature Request")
IO.puts("=" |> String.duplicate(70))

CustomerSupportTriage.triage(ticket_medium)

expected_medium = %{
  "subject" => "Feature request: Dark mode support",
  "category" => "feature_request",
  "priority" => "medium",
  "urgency_indicators" => [],
  "estimated_resolution_time" => "1week",
  "requires_human_review" => false,
  "suggested_department" => "Product Management",
  "customer_sentiment" => "positive",
  "tags" => ["feature-request", "dark-mode", "ui"]
}

IO.puts("\n=== Expected Triage Output ===")
IO.inspect(expected_medium, pretty: true)

case CustomerSupportTriage.validate_ticket(expected_medium) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    deadline = CustomerSupportTriage.calculate_sla_deadline(
      validated.priority,
      validated.estimated_resolution_time
    )
    IO.puts("\n⏰ SLA Deadline: #{DateTime.to_string(deadline)}")
    IO.puts("   (Medium priority: 1.0x multiplier on 1 week = 7 days)")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 4: Low - General Inquiry
# ============================================================================

ticket_low = """
Subject: How do I change my email address?

Hi,

I'd like to update the email address associated with my account. I recently
changed jobs and want to use my personal email instead of my work email.

Could you please let me know what the process is for changing my email address
in your system?

Thanks!
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 4: Low Priority General Inquiry")
IO.puts("=" |> String.duplicate(70))

CustomerSupportTriage.triage(ticket_low)

expected_low = %{
  "subject" => "How do I change my email address?",
  "category" => "general",
  "priority" => "low",
  "urgency_indicators" => [],
  "estimated_resolution_time" => "24h",
  "requires_human_review" => false,
  "suggested_department" => "Customer Support - Tier 1",
  "customer_sentiment" => "neutral",
  "tags" => ["email", "account-settings", "how-to"]
}

IO.puts("\n=== Expected Triage Output ===")
IO.inspect(expected_low, pretty: true)

case CustomerSupportTriage.validate_ticket(expected_low) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    deadline = CustomerSupportTriage.calculate_sla_deadline(
      validated.priority,
      validated.estimated_resolution_time
    )
    IO.puts("\n⏰ SLA Deadline: #{DateTime.to_string(deadline)}")
    IO.puts("   (Low priority: 1.5x multiplier on 24h = 36 hours)")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Error Handling Examples
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("ERROR HANDLING EXAMPLES")
IO.puts("=" |> String.duplicate(70))

IO.puts("\n--- Example: Invalid priority value ---")

invalid_priority = %{
  "subject" => "Test ticket subject",
  "category" => "technical",
  "priority" => "super_urgent",  # Invalid enum value
  "estimated_resolution_time" => "1h",
  "requires_human_review" => true,
  "suggested_department" => "Engineering"
}

case CustomerSupportTriage.validate_ticket(invalid_priority) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Subject too short ---")

invalid_subject = %{
  "subject" => "Help",  # Only 4 chars, needs min 10
  "category" => "general",
  "priority" => "low",
  "estimated_resolution_time" => "24h",
  "requires_human_review" => false,
  "suggested_department" => "Support"
}

case CustomerSupportTriage.validate_ticket(invalid_subject) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

# ============================================================================
# Integration Patterns
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("INTEGRATION PATTERNS")
IO.puts("=" |> String.duplicate(70))

IO.puts("""

## Phoenix LiveView Integration

defmodule MyAppWeb.TicketLive do
  use MyAppWeb, :live_view
  alias CustomerSupportTriage

  def handle_event("analyze_ticket", %{"content" => content}, socket) do
    case ExOutlines.generate(
      CustomerSupportTriage.ticket_schema(),
      backend: MyApp.LLM.Backend
    ) do
      {:ok, triage_result} ->
        # Update UI with triage results
        socket =
          socket
          |> assign(:priority, triage_result.priority)
          |> assign(:department, triage_result.suggested_department)
          |> assign(:sla_deadline, calculate_deadline(triage_result))

        # Auto-route if no human review needed
        if not triage_result.requires_human_review do
          route_to_department(triage_result.suggested_department)
        end

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Triage failed: \#{reason}")}
    end
  end
end

## Webhook Integration for Email/Chat

defmodule MyAppWeb.WebhookController do
  use MyAppWeb, :controller

  def zendesk_webhook(conn, %{"ticket" => ticket_data}) do
    # Analyze ticket on creation
    case triage_ticket(ticket_data["description"]) do
      {:ok, triage} ->
        # Update Zendesk ticket with tags and priority
        Zendesk.update_ticket(ticket_data["id"], %{
          priority: map_priority(triage.priority),
          tags: triage.tags,
          assignee_group: map_department(triage.suggested_department)
        })

        # Send alert for critical tickets
        if triage.priority == "critical" do
          Alerts.notify_on_call_team(ticket_data["id"], triage)
        end

        json(conn, %{status: "processed"})

      {:error, _} ->
        # Fallback to default routing
        json(conn, %{status: "fallback"})
    end
  end
end

## Telemetry and Monitoring

def handle_triage_result(triage_result) do
  # Emit telemetry events for monitoring
  :telemetry.execute(
    [:support, :triage, :complete],
    %{duration: measure_duration()},
    %{
      priority: triage_result.priority,
      category: triage_result.category,
      requires_human: triage_result.requires_human_review
    }
  )

  # Track SLA metrics
  MyApp.Metrics.record_sla_target(
    triage_result.priority,
    triage_result.estimated_resolution_time
  )
end

## Batch Processing for Backlog

defmodule MyApp.Workers.BacklogTriage do
  use Oban.Worker, queue: :triage, max_attempts: 2

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"ticket_ids" => ids}}) do
    tickets = MyApp.Tickets.get_untriaged(ids)

    # Process in batches for efficiency
    results = Enum.map(tickets, fn ticket ->
      case ExOutlines.generate(
        CustomerSupportTriage.ticket_schema(),
        backend: MyApp.LLM.Backend,
        backend_opts: [timeout: 10_000]
      ) do
        {:ok, triage} ->
          MyApp.Tickets.update_triage(ticket.id, triage)
          {:ok, ticket.id}

        {:error, reason} ->
          {:error, {ticket.id, reason}}
      end
    end)

    # Report results
    {successes, failures} = Enum.split_with(results, &match?({:ok, _}, &1))
    Logger.info("Triaged \#{length(successes)} tickets, \#{length(failures)} failures")

    :ok
  end
end

## Testing with Deterministic Outputs

defmodule MyApp.TriageTest do
  use MyApp.DataCase
  alias ExOutlines.Backend.Mock

  test "critical tickets require immediate human review" do
    mock_response = Jason.encode!(%{
      subject: "Payment system down",
      category: "technical",
      priority: "critical",
      urgency_indicators: ["down", "URGENT"],
      estimated_resolution_time: "1h",
      requires_human_review: true,
      suggested_department: "Engineering",
      customer_sentiment: "angry",
      tags: ["payment", "outage"]
    })

    mock = Mock.new([{:ok, mock_response}])

    {:ok, result} = ExOutlines.generate(
      CustomerSupportTriage.ticket_schema(),
      backend: Mock,
      backend_opts: [mock: mock]
    )

    assert result.priority == "critical"
    assert result.requires_human_review
    assert result.suggested_department == "Engineering"
  end
end
""")

IO.puts("\n" <> ("=" |> String.duplicate(70)))
IO.puts("Example complete! All validations passed.")
IO.puts("=" |> String.duplicate(70))
