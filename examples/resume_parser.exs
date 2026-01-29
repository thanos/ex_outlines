#!/usr/bin/env elixir
#
# Resume Parser Example
#
# This example demonstrates how to use ExOutlines to extract structured
# information from unstructured resume text.
#
# Use cases:
# - Automated resume screening
# - Applicant tracking systems (ATS)
# - Candidate database enrichment
# - Skills matching and recommendations
# - Recruitment pipeline automation
#
# Run with: elixir examples/resume_parser.exs

Mix.install([{:ex_outlines, path: Path.expand("..", __DIR__)}])

defmodule ResumeParser do
  @moduledoc """
  Extract structured data from resume text using LLM-powered parsing.

  This module demonstrates a production-ready schema for parsing resumes
  into structured data suitable for database storage and analysis.
  """

  alias ExOutlines.{Spec, Spec.Schema}

  @doc """
  Define the resume parsing schema.

  The schema validates:
  - Personal information (name, email, phone, location)
  - Work experience entries (title, company, dates, responsibilities)
  - Education entries (degree, institution, dates)
  - Skills (categorized and validated)
  - Certifications (optional)
  - Languages (with proficiency levels)
  """
  def resume_schema do
    Schema.new(%{
      personal_info: %{
        type: {:object, personal_info_schema()},
        required: true,
        description: "Candidate's personal information"
      },
      work_experience: %{
        type: {:array, %{type: {:object, experience_schema()}}},
        required: true,
        min_items: 1,
        max_items: 20,
        description: "Work history entries"
      },
      education: %{
        type: {:array, %{type: {:object, education_schema()}}},
        required: true,
        min_items: 1,
        max_items: 10,
        description: "Educational background"
      },
      skills: %{
        type: {:array, %{type: :string, min_length: 2, max_length: 50}},
        required: true,
        unique_items: true,
        min_items: 1,
        max_items: 30,
        description: "Technical and professional skills"
      },
      certifications: %{
        type: {:array, %{type: :string, max_length: 100}},
        required: false,
        unique_items: true,
        max_items: 15,
        description: "Professional certifications and licenses"
      },
      languages: %{
        type: {:array, %{type: {:object, language_schema()}}},
        required: false,
        max_items: 10,
        description: "Language proficiencies"
      },
      summary: %{
        type: :string,
        required: false,
        min_length: 50,
        max_length: 500,
        description: "Professional summary or objective"
      }
    })
  end

  defp personal_info_schema do
    Schema.new(%{
      name: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 100,
        description: "Full name"
      },
      email: %{
        type: :string,
        required: true,
        format: :email,
        description: "Email address"
      },
      phone: %{
        type: {:union, [
          %{type: :string, format: :phone},
          %{type: :null}
        ]},
        required: false,
        description: "Phone number (optional)"
      },
      location: %{
        type: :string,
        required: false,
        max_length: 100,
        description: "City, State or full address"
      },
      linkedin: %{
        type: {:union, [
          %{type: :string, format: :url},
          %{type: :null}
        ]},
        required: false,
        description: "LinkedIn profile URL"
      },
      website: %{
        type: {:union, [
          %{type: :string, format: :url},
          %{type: :null}
        ]},
        required: false,
        description: "Personal website or portfolio"
      }
    })
  end

  defp experience_schema do
    Schema.new(%{
      title: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 100,
        description: "Job title or position"
      },
      company: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 100,
        description: "Company or organization name"
      },
      location: %{
        type: :string,
        required: false,
        max_length: 100,
        description: "Job location"
      },
      start_date: %{
        type: :string,
        required: true,
        pattern: ~r/^\d{4}-\d{2}$/,
        description: "Start date (YYYY-MM format)"
      },
      end_date: %{
        type: {:union, [
          %{type: :string, pattern: ~r/^\d{4}-\d{2}$/},
          %{type: :string, pattern: ~r/^present$/i},
          %{type: :null}
        ]},
        required: false,
        description: "End date (YYYY-MM) or 'present' for current position"
      },
      responsibilities: %{
        type: {:array, %{type: :string, min_length: 10, max_length: 300}},
        required: false,
        min_items: 1,
        max_items: 10,
        description: "Key responsibilities and achievements"
      }
    })
  end

  defp education_schema do
    Schema.new(%{
      degree: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 100,
        description: "Degree or certificate name"
      },
      field_of_study: %{
        type: :string,
        required: false,
        max_length: 100,
        description: "Major or field of study"
      },
      institution: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 150,
        description: "School or institution name"
      },
      location: %{
        type: :string,
        required: false,
        max_length: 100,
        description: "Institution location"
      },
      graduation_date: %{
        type: {:union, [
          %{type: :string, pattern: ~r/^\d{4}$/},
          %{type: :string, pattern: ~r/^\d{4}-\d{2}$/}
        ]},
        required: false,
        description: "Graduation year (YYYY) or year-month (YYYY-MM)"
      },
      gpa: %{
        type: {:union, [
          %{type: :number, min: 0.0, max: 4.0},
          %{type: :null}
        ]},
        required: false,
        description: "GPA (0.0-4.0 scale)"
      }
    })
  end

  defp language_schema do
    Schema.new(%{
      language: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 50,
        description: "Language name"
      },
      proficiency: %{
        type: {:enum, ["native", "fluent", "professional", "intermediate", "basic"]},
        required: true,
        description: "Proficiency level"
      }
    })
  end

  @doc """
  Parse a resume from text.

  In a real implementation, this would call an LLM backend.
  For demonstration, we'll show schema usage and validation.
  """
  def parse(resume_text, _opts \\ []) do
    IO.puts("\n=== Resume Text ===")
    IO.puts(resume_text)
    IO.puts("\n=== Parsing with ExOutlines... ===")

    # In production, you would call:
    # ExOutlines.generate(resume_schema(), backend: backend, backend_opts: backend_opts)

    {:ok, resume_schema()}
  end

  @doc """
  Validate parsed resume data.
  """
  def validate(resume_data) do
    Spec.validate(resume_schema(), resume_data)
  end

  @doc """
  Display JSON Schema for LLM prompts.
  """
  def show_json_schema do
    schema = resume_schema()
    json_schema = Spec.to_schema(schema)

    IO.puts("\n=== JSON Schema for LLM ===")
    IO.inspect(json_schema, pretty: true, limit: :infinity)
  end
end

# ============================================================================
# Example Usage and Testing
# ============================================================================

IO.puts("=" |> String.duplicate(70))
IO.puts("Resume Parser Example")
IO.puts("=" |> String.duplicate(70))

# Display the JSON Schema
ResumeParser.show_json_schema()

# ============================================================================
# Example 1: Software Engineer Resume
# ============================================================================

resume_text_1 = """
JOHN DOE
Software Engineer

Email: john.doe@email.com
Phone: 555-123-4567
Location: San Francisco, CA
LinkedIn: linkedin.com/in/johndoe
GitHub: github.com/johndoe

SUMMARY
Experienced software engineer with 5+ years building scalable web applications.
Specializes in Elixir, Phoenix, and distributed systems. Passionate about
functional programming and clean architecture.

EXPERIENCE

Senior Software Engineer | TechCorp Inc. | San Francisco, CA
January 2021 - Present
- Led development of microservices architecture serving 10M+ users
- Reduced API response time by 60% through optimization and caching
- Mentored team of 5 junior engineers
- Implemented comprehensive test suite increasing coverage to 95%

Software Engineer | StartupXYZ | Remote
June 2018 - December 2020
- Built real-time messaging platform using Phoenix LiveView
- Designed and implemented RESTful APIs with authentication
- Collaborated with product team on feature specifications
- Deployed applications to AWS using Docker and Kubernetes

EDUCATION

Bachelor of Science in Computer Science | Stanford University | 2018
GPA: 3.8/4.0

SKILLS
Elixir, Phoenix, PostgreSQL, Redis, Docker, Kubernetes, AWS, Git, REST APIs,
GraphQL, WebSockets, TDD, Agile

CERTIFICATIONS
- AWS Certified Solutions Architect
- Elixir Certified Developer

LANGUAGES
- English (Native)
- Spanish (Professional)
- French (Basic)
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 1: Software Engineer Resume")
IO.puts("=" |> String.duplicate(70))

ResumeParser.parse(resume_text_1)

# Expected parsed structure
expected_data_1 = %{
  "personal_info" => %{
    "name" => "John Doe",
    "email" => "john.doe@email.com",
    "phone" => "555-123-4567",
    "location" => "San Francisco, CA",
    "linkedin" => "https://linkedin.com/in/johndoe",
    "website" => "https://github.com/johndoe"
  },
  "work_experience" => [
    %{
      "title" => "Senior Software Engineer",
      "company" => "TechCorp Inc.",
      "location" => "San Francisco, CA",
      "start_date" => "2021-01",
      "end_date" => "present",
      "responsibilities" => [
        "Led development of microservices architecture serving 10M+ users",
        "Reduced API response time by 60% through optimization and caching",
        "Mentored team of 5 junior engineers",
        "Implemented comprehensive test suite increasing coverage to 95%"
      ]
    },
    %{
      "title" => "Software Engineer",
      "company" => "StartupXYZ",
      "location" => "Remote",
      "start_date" => "2018-06",
      "end_date" => "2020-12",
      "responsibilities" => [
        "Built real-time messaging platform using Phoenix LiveView",
        "Designed and implemented RESTful APIs with authentication",
        "Collaborated with product team on feature specifications",
        "Deployed applications to AWS using Docker and Kubernetes"
      ]
    }
  ],
  "education" => [
    %{
      "degree" => "Bachelor of Science in Computer Science",
      "field_of_study" => "Computer Science",
      "institution" => "Stanford University",
      "graduation_date" => "2018",
      "gpa" => 3.8
    }
  ],
  "skills" => [
    "Elixir",
    "Phoenix",
    "PostgreSQL",
    "Redis",
    "Docker",
    "Kubernetes",
    "AWS",
    "Git",
    "REST APIs",
    "GraphQL",
    "WebSockets",
    "TDD",
    "Agile"
  ],
  "certifications" => [
    "AWS Certified Solutions Architect",
    "Elixir Certified Developer"
  ],
  "languages" => [
    %{"language" => "English", "proficiency" => "native"},
    %{"language" => "Spanish", "proficiency" => "professional"},
    %{"language" => "French", "proficiency" => "basic"}
  ],
  "summary" =>
    "Experienced software engineer with 5+ years building scalable web applications. Specializes in Elixir, Phoenix, and distributed systems."
}

IO.puts("\n=== Expected Parsed Data ===")
IO.inspect(expected_data_1, pretty: true, limit: :infinity)

# Validate the expected output
case ResumeParser.validate(expected_data_1) do
  {:ok, validated} ->
    IO.puts("\n[SUCCESS] Validation passed!")
    IO.puts("\nValidated data structure:")
    IO.inspect(validated, pretty: true)

  {:error, diagnostics} ->
    IO.puts("\n[FAILED] Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 2: Marketing Manager Resume
# ============================================================================

resume_text_2 = """
JANE SMITH
Marketing Manager

Contact: jane.smith@email.com | (555) 987-6543
San Diego, California
Portfolio: janesmith.com

PROFESSIONAL SUMMARY
Results-driven marketing professional with 8 years of experience in digital
marketing, brand strategy, and team leadership. Proven track record of
increasing brand awareness and driving revenue growth.

EXPERIENCE

Marketing Manager | Global Brands Co. | San Diego, CA | Mar 2020 - Present
• Manage $2M annual marketing budget across digital and traditional channels
• Increased website traffic by 150% through SEO and content marketing
• Led rebranding initiative that improved brand perception by 40%
• Built and managed team of 6 marketing specialists

Digital Marketing Specialist | MediaWorks | Los Angeles, CA | 2016 - 2020
• Executed social media campaigns reaching 5M+ impressions monthly
• Managed Google Ads campaigns with average ROI of 300%
• Collaborated with design team on creative assets

Marketing Coordinator | SmallBiz Inc. | 2014 - 2016
• Coordinated marketing events and trade shows
• Managed company blog and social media accounts

EDUCATION

MBA in Marketing | UCLA Anderson School of Management | 2020

Bachelor of Arts in Communications | UC Berkeley | 2014
Major: Communications, Minor: Business Administration

SKILLS
Digital Marketing, SEO, SEM, Google Analytics, HubSpot, Salesforce,
Social Media Marketing, Content Strategy, Brand Management, Email Marketing,
Adobe Creative Suite, Project Management

CERTIFICATIONS
- Google Analytics Certified
- HubSpot Inbound Marketing Certification
- Facebook Blueprint Certified
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 2: Marketing Manager Resume")
IO.puts("=" |> String.duplicate(70))

ResumeParser.parse(resume_text_2)

expected_data_2 = %{
  "personal_info" => %{
    "name" => "Jane Smith",
    "email" => "jane.smith@email.com",
    "phone" => "555-987-6543",
    "location" => "San Diego, California",
    "website" => "https://janesmith.com"
  },
  "work_experience" => [
    %{
      "title" => "Marketing Manager",
      "company" => "Global Brands Co.",
      "location" => "San Diego, CA",
      "start_date" => "2020-03",
      "end_date" => "present",
      "responsibilities" => [
        "Manage $2M annual marketing budget",
        "Increased website traffic by 150% through SEO",
        "Led rebranding initiative improving brand perception by 40%",
        "Built and managed team of 6 marketing specialists"
      ]
    },
    %{
      "title" => "Digital Marketing Specialist",
      "company" => "MediaWorks",
      "location" => "Los Angeles, CA",
      "start_date" => "2016-01",
      "end_date" => "2020-02"
    },
    %{
      "title" => "Marketing Coordinator",
      "company" => "SmallBiz Inc.",
      "start_date" => "2014-01",
      "end_date" => "2015-12"
    }
  ],
  "education" => [
    %{
      "degree" => "MBA in Marketing",
      "field_of_study" => "Marketing",
      "institution" => "UCLA Anderson School of Management",
      "graduation_date" => "2020"
    },
    %{
      "degree" => "Bachelor of Arts in Communications",
      "field_of_study" => "Communications",
      "institution" => "UC Berkeley",
      "graduation_date" => "2014"
    }
  ],
  "skills" => [
    "Digital Marketing",
    "SEO",
    "SEM",
    "Google Analytics",
    "HubSpot",
    "Salesforce",
    "Social Media Marketing",
    "Content Strategy",
    "Brand Management",
    "Email Marketing",
    "Project Management"
  ],
  "certifications" => [
    "Google Analytics Certified",
    "HubSpot Inbound Marketing Certification",
    "Facebook Blueprint Certified"
  ],
  "summary" =>
    "Results-driven marketing professional with 8 years of experience in digital marketing, brand strategy, and team leadership."
}

IO.puts("\n=== Expected Parsed Data ===")
IO.inspect(expected_data_2, pretty: true, limit: :infinity)

case ResumeParser.validate(expected_data_2) do
  {:ok, _validated} ->
    IO.puts("\n[SUCCESS] Validation passed!")

  {:error, diagnostics} ->
    IO.puts("\n[FAILED] Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Error Handling Examples
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("ERROR HANDLING EXAMPLES")
IO.puts("=" |> String.duplicate(70))

IO.puts("\n--- Example: Missing required field ---")

invalid_missing = %{
  "personal_info" => %{
    "name" => "John Doe"
    # Missing required email field
  },
  "work_experience" => [],
  "education" => [],
  "skills" => ["Programming"]
}

case ResumeParser.validate(invalid_missing) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")

    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Invalid date format ---")

invalid_date = %{
  "personal_info" => %{
    "name" => "John Doe",
    "email" => "john@example.com"
  },
  "work_experience" => [
    %{
      "title" => "Engineer",
      "company" => "TechCo",
      "start_date" => "Jan 2020",
      # Invalid format - should be YYYY-MM
      "end_date" => "present"
    }
  ],
  "education" => [
    %{
      "degree" => "BS Computer Science",
      "institution" => "University"
    }
  ],
  "skills" => ["Elixir"]
}

case ResumeParser.validate(invalid_date) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")

    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Invalid email format ---")

invalid_email = %{
  "personal_info" => %{
    "name" => "John Doe",
    "email" => "not-an-email"
    # Invalid email format
  },
  "work_experience" => [
    %{
      "title" => "Engineer",
      "company" => "TechCo",
      "start_date" => "2020-01"
    }
  ],
  "education" => [
    %{
      "degree" => "BS",
      "institution" => "University"
    }
  ],
  "skills" => ["Programming"]
}

case ResumeParser.validate(invalid_email) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")

    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

# ============================================================================
# Integration Guidance
# ============================================================================

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("INTEGRATION GUIDANCE")
IO.puts("=" |> String.duplicate(70))

IO.puts("""

## Phoenix Controller Integration

defmodule MyAppWeb.ResumeController do
  use MyAppWeb, :controller
  alias ResumeParser
  alias MyApp.Candidates

  def parse(conn, %{"resume_text" => text}) do
    case ExOutlines.generate(
      ResumeParser.resume_schema(),
      backend: MyApp.LLM.Backend,
      backend_opts: [timeout: 30_000]
    ) do
      {:ok, resume_data} ->
        # Save to database
        {:ok, candidate} = Candidates.create_from_resume(resume_data)
        json(conn, candidate)

      {:error, %{validation_errors: errors}} ->
        # Handle validation errors
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Parsing failed", reason: inspect(reason)})
    end
  end
end

## Batch Processing for Multiple Resumes

defmodule MyApp.Workers.ResumeParser do
  use Oban.Worker, queue: :resume_parsing, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"resumes" => resume_texts}}) do
    schema = ResumeParser.resume_schema()

    tasks = Enum.map(resume_texts, fn text ->
      {schema, [
        backend: MyApp.LLM.Backend,
        backend_opts: [messages: build_messages(text)]
      ]}
    end)

    results = ExOutlines.generate_batch(tasks, max_concurrency: 5)

    # Save successful parses
    Enum.each(results, fn
      {:ok, resume_data} ->
        MyApp.Candidates.create_from_resume(resume_data)

      {:error, _reason} ->
        # Log failure, potentially retry
        :ok
    end)

    :ok
  end

  defp build_messages(resume_text) do
    [
      %{role: "system", content: "Extract structured data from resume."},
      %{role: "user", content: resume_text}
    ]
  end
end

## Database Schema (Ecto)

defmodule MyApp.Candidates.Resume do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resumes" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :location, :string

    embeds_many :work_experience, Experience do
      field :title, :string
      field :company, :string
      field :start_date, :string
      field :end_date, :string
      field :responsibilities, {:array, :string}
    end

    embeds_many :education, Education do
      field :degree, :string
      field :institution, :string
      field :graduation_date, :string
    end

    field :skills, {:array, :string}
    field :certifications, {:array, :string}
    field :summary, :string

    timestamps()
  end

  def changeset(resume, attrs) do
    resume
    |> cast(attrs, [:name, :email, :phone, :location, :skills, :summary])
    |> cast_embed(:work_experience)
    |> cast_embed(:education)
    |> validate_required([:name, :email])
  end
end

## Testing with Mock Backend

defmodule MyApp.ResumeParserTest do
  use MyApp.DataCase
  alias ExOutlines.Backend.Mock

  test "parses resume successfully" do
    mock_response = Jason.encode!(%{
      personal_info: %{
        name: "John Doe",
        email: "john@example.com"
      },
      work_experience: [],
      education: [],
      skills: ["Elixir"]
    })

    mock = Mock.new([{:ok, mock_response}])

    {:ok, result} = ExOutlines.generate(
      ResumeParser.resume_schema(),
      backend: Mock,
      backend_opts: [mock: mock]
    )

    assert result.personal_info.name == "John Doe"
  end
end
""")

IO.puts("\n" <> ("=" |> String.duplicate(70)))
IO.puts("Example complete. All validations passed.")
IO.puts("=" |> String.duplicate(70)))
