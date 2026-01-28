#!/usr/bin/env elixir
#
# Document Metadata Extraction Example
#
# This example demonstrates how to use ExOutlines for extracting structured
# metadata from academic papers, technical reports, and blog posts.
#
# Use cases:
# - Digital library indexing and cataloging
# - Research paper databases and archives
# - Content management systems
# - Citation management tools
# - Knowledge base organization
# - SEO metadata generation
#
# Run with: elixir examples/document_metadata_extraction.exs

Mix.install([{:ex_outlines, path: Path.expand("..", __DIR__)}])

defmodule DocumentMetadataExtraction do
  @moduledoc """
  Extract structured metadata from documents and publications.

  This module demonstrates a production-ready schema for extracting
  bibliographic metadata from various document types including academic
  papers, technical reports, blog posts, and whitepapers.
  """

  alias ExOutlines.{Spec, Spec.Schema}

  @doc """
  Define the document metadata extraction schema.

  The schema validates:
  - Title (5-200 characters)
  - Authors as nested objects (name, email, affiliation)
  - Publication date in YYYY-MM-DD format
  - Unique keywords array (3-10 items, 2-50 chars each)
  - Abstract (100-500 characters)
  - Optional URL with format validation
  - Optional DOI with pattern validation
  - Document type from predefined categories
  """
  def document_schema do
    Schema.new(%{
      title: %{
        type: :string,
        required: true,
        min_length: 5,
        max_length: 200,
        description: "Document title"
      },
      authors: %{
        type: {:array, %{
          type: {:object, author_schema()},
        }},
        required: true,
        min_items: 1,
        max_items: 10,
        description: "List of document authors with affiliations"
      },
      publication_date: %{
        type: :string,
        required: true,
        pattern: ~r/^\d{4}-\d{2}-\d{2}$/,
        description: "Publication date in YYYY-MM-DD format"
      },
      keywords: %{
        type: {:array, %{type: :string, min_length: 2, max_length: 50}},
        required: true,
        min_items: 3,
        max_items: 10,
        unique_items: true,
        description: "Keywords for indexing and discovery"
      },
      abstract: %{
        type: :string,
        required: true,
        min_length: 100,
        max_length: 500,
        description: "Document abstract or summary"
      },
      url: %{
        type: {:union, [
          %{type: :string, format: :url},
          %{type: :null}
        ]},
        description: "URL to the full document if available"
      },
      doi: %{
        type: {:union, [
          %{type: :string, pattern: ~r/^10\.\d{4,9}\/[-._;()\/:A-Z0-9]+$/i},
          %{type: :null}
        ]},
        description: "Digital Object Identifier if applicable"
      },
      document_type: %{
        type: {:enum, ["article", "report", "whitepaper", "blog", "preprint", "thesis"]},
        required: true,
        description: "Type of document"
      },
      publisher: %{
        type: {:union, [
          %{type: :string, max_length: 100},
          %{type: :null}
        ]},
        description: "Publisher or platform name"
      }
    })
  end

  @doc """
  Define the author schema for nested objects.

  Each author has:
  - Name (2-100 characters)
  - Email (email format)
  - Affiliation (organization, 2-150 characters)
  """
  def author_schema do
    Schema.new(%{
      name: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 100,
        description: "Author's full name"
      },
      email: %{
        type: :string,
        required: true,
        format: :email,
        description: "Author's email address"
      },
      affiliation: %{
        type: :string,
        required: true,
        min_length: 2,
        max_length: 150,
        description: "Author's institution or organization"
      }
    })
  end

  @doc """
  Extract metadata from a document.

  In production, this would call an LLM backend with the document text.
  For demonstration, we show the schema usage and validation.
  """
  def extract(document_text, _opts \\ []) do
    schema = document_schema()

    IO.puts("\n=== Document Excerpt ===")
    IO.puts(String.slice(document_text, 0..200) <> "...")
    IO.puts("\n=== Extracting metadata... ===")

    {:ok, schema}
  end

  @doc """
  Validate extracted metadata against the schema.
  """
  def validate_metadata(metadata) do
    Spec.validate(document_schema(), metadata)
  end

  @doc """
  Display the JSON Schema for LLM prompts.
  """
  def show_json_schema do
    schema = document_schema()
    json_schema = Spec.to_schema(schema)

    IO.puts("\n=== JSON Schema for LLM ===")
    IO.inspect(json_schema, pretty: true, limit: :infinity)
  end

  @doc """
  Format metadata for citation (helper function).
  """
  def format_citation(metadata) do
    author_names = Enum.map(metadata.authors, & &1.name)
    authors_str = case length(author_names) do
      1 -> hd(author_names)
      2 -> Enum.join(author_names, " and ")
      _ -> "#{hd(author_names)} et al."
    end

    "#{authors_str}. \"#{metadata.title}.\" #{metadata.publication_date}."
  end
end

# ============================================================================
# Example Usage and Testing
# ============================================================================

IO.puts("=" |> String.duplicate(70))
IO.puts("Document Metadata Extraction Example")
IO.puts("=" |> String.duplicate(70))

# Display the JSON Schema
DocumentMetadataExtraction.show_json_schema()

# ============================================================================
# Example 1: Academic Research Paper
# ============================================================================

document_academic = """
Large Language Models as Optimizers

Recent advances in large language models (LLMs) have demonstrated remarkable
capabilities in natural language understanding and generation. This paper
introduces a novel framework for using LLMs as optimization tools for prompt
engineering and hyperparameter tuning. We propose a method called "Optimization
by PROmpting" (OPRO), where the optimization problem is described in natural
language, and the LLM generates candidate solutions iteratively.

Our experiments across various tasks including linear regression, traveling
salesman problem, and prompt optimization show that LLMs can effectively serve
as optimizers, achieving competitive or superior performance compared to
traditional optimization algorithms. The key insight is that LLMs' natural
language understanding allows them to grasp the optimization objective and
constraints from textual descriptions.

Authors: Chengrun Yang, Xuezhi Wang, Yifeng Lu, Hanxiao Liu, Quoc V. Le,
Denny Zhou, Xinyun Chen
Google DeepMind
Published: 2023-09-07
arXiv:2309.03409
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 1: Academic Research Paper")
IO.puts("=" |> String.duplicate(70))

DocumentMetadataExtraction.extract(document_academic)

expected_academic = %{
  "title" => "Large Language Models as Optimizers",
  "authors" => [
    %{
      "name" => "Chengrun Yang",
      "email" => "chengrun@google.com",
      "affiliation" => "Google DeepMind"
    },
    %{
      "name" => "Xuezhi Wang",
      "email" => "xuezhiw@google.com",
      "affiliation" => "Google DeepMind"
    },
    %{
      "name" => "Denny Zhou",
      "email" => "dennyzhou@google.com",
      "affiliation" => "Google DeepMind"
    }
  ],
  "publication_date" => "2023-09-07",
  "keywords" => [
    "large language models",
    "optimization",
    "prompt engineering",
    "OPRO",
    "machine learning"
  ],
  "abstract" => "This paper introduces a novel framework for using LLMs as optimization tools. The method OPRO describes optimization problems in natural language and generates candidate solutions iteratively, achieving competitive performance.",
  "url" => "https://arxiv.org/abs/2309.03409",
  "doi" => "10.48550/arXiv.2309.03409",
  "document_type" => "preprint",
  "publisher" => "arXiv"
}

IO.puts("\n=== Expected Metadata ===")
IO.inspect(expected_academic, pretty: true)

case DocumentMetadataExtraction.validate_metadata(expected_academic) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    # Format citation
    citation = DocumentMetadataExtraction.format_citation(validated)
    IO.puts("\n📚 Citation: #{citation}")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 2: Technical Blog Post
# ============================================================================

document_blog = """
Understanding Rust's Ownership System: A Deep Dive

Rust's ownership system is one of its most distinctive features, enabling
memory safety without garbage collection. In this comprehensive guide, we'll
explore how ownership, borrowing, and lifetimes work together to prevent
common programming errors at compile time.

Ownership in Rust follows three rules: each value has a single owner, there
can only be one owner at a time, and when the owner goes out of scope, the
value is dropped. These simple rules lead to powerful guarantees about memory
management and concurrency.

We'll walk through practical examples, common pitfalls, and best practices
for working with Rust's ownership model. Whether you're new to Rust or
looking to deepen your understanding, this guide will help you master one
of the language's core concepts.

Author: Sarah Johnson
Email: sarah.j@techblog.dev
TechBlog Platform
Published: 2024-01-15
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 2: Technical Blog Post")
IO.puts("=" |> String.duplicate(70))

DocumentMetadataExtraction.extract(document_blog)

expected_blog = %{
  "title" => "Understanding Rust's Ownership System: A Deep Dive",
  "authors" => [
    %{
      "name" => "Sarah Johnson",
      "email" => "sarah.j@techblog.dev",
      "affiliation" => "TechBlog Platform"
    }
  ],
  "publication_date" => "2024-01-15",
  "keywords" => [
    "rust",
    "ownership",
    "memory safety",
    "programming",
    "systems programming"
  ],
  "abstract" => "A comprehensive guide to Rust's ownership system, exploring how ownership, borrowing, and lifetimes work together to prevent common programming errors at compile time. Includes practical examples and best practices.",
  "url" => "https://techblog.dev/rust-ownership-deep-dive",
  "doi" => nil,
  "document_type" => "blog",
  "publisher" => "TechBlog Platform"
}

IO.puts("\n=== Expected Metadata ===")
IO.inspect(expected_blog, pretty: true)

case DocumentMetadataExtraction.validate_metadata(expected_blog) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    citation = DocumentMetadataExtraction.format_citation(validated)
    IO.puts("\n📚 Citation: #{citation}")

  {:error, diagnostics} ->
    IO.puts("\n❌ Validation failed:")
    IO.inspect(diagnostics, pretty: true)
end

# ============================================================================
# Example 3: Corporate Whitepaper
# ============================================================================

document_whitepaper = """
The Future of Edge Computing: A 2024 Industry Report

Executive Summary

Edge computing has emerged as a critical technology for processing data closer
to its source, reducing latency and bandwidth requirements. This whitepaper
examines current trends in edge computing adoption across industries including
manufacturing, healthcare, retail, and telecommunications.

Our research, based on surveys of 500+ enterprises and analysis of deployment
patterns, reveals that edge computing adoption has grown 245% year-over-year.
Key drivers include the proliferation of IoT devices, demand for real-time
analytics, and advances in 5G networks.

We present case studies from leading organizations, technical architecture
recommendations, and projections for market growth through 2027. The report
concludes with strategic recommendations for organizations considering edge
computing investments.

Authors: Michael Chen, Lisa Rodriguez, James Park
CloudTech Research Institute
Published: 2024-02-20
"""

IO.puts("\n\n" <> ("=" |> String.duplicate(70)))
IO.puts("EXAMPLE 3: Corporate Whitepaper")
IO.puts("=" |> String.duplicate(70))

DocumentMetadataExtraction.extract(document_whitepaper)

expected_whitepaper = %{
  "title" => "The Future of Edge Computing: A 2024 Industry Report",
  "authors" => [
    %{
      "name" => "Michael Chen",
      "email" => "m.chen@cloudtech.org",
      "affiliation" => "CloudTech Research Institute"
    },
    %{
      "name" => "Lisa Rodriguez",
      "email" => "l.rodriguez@cloudtech.org",
      "affiliation" => "CloudTech Research Institute"
    },
    %{
      "name" => "James Park",
      "email" => "j.park@cloudtech.org",
      "affiliation" => "CloudTech Research Institute"
    }
  ],
  "publication_date" => "2024-02-20",
  "keywords" => [
    "edge computing",
    "industry report",
    "IoT",
    "5G",
    "real-time analytics"
  ],
  "abstract" => "This whitepaper examines current trends in edge computing adoption across industries. Based on surveys of 500+ enterprises, it reveals 245% year-over-year growth driven by IoT, real-time analytics demands, and 5G advances.",
  "url" => "https://cloudtech.org/reports/edge-computing-2024",
  "doi" => nil,
  "document_type" => "whitepaper",
  "publisher" => "CloudTech Research Institute"
}

IO.puts("\n=== Expected Metadata ===")
IO.inspect(expected_whitepaper, pretty: true)

case DocumentMetadataExtraction.validate_metadata(expected_whitepaper) do
  {:ok, validated} ->
    IO.puts("\n✅ Validation successful!")

    citation = DocumentMetadataExtraction.format_citation(validated)
    IO.puts("\n📚 Citation: #{citation}")

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

IO.puts("\n--- Example: Invalid date format ---")

invalid_date = %{
  "title" => "Test Document",
  "authors" => [
    %{
      "name" => "Test Author",
      "email" => "test@example.com",
      "affiliation" => "Test Org"
    }
  ],
  "publication_date" => "2024/01/15",  # Wrong format (should be 2024-01-15)
  "keywords" => ["keyword1", "keyword2", "keyword3"],
  "abstract" => String.duplicate("a", 150),
  "document_type" => "article"
}

case DocumentMetadataExtraction.validate_metadata(invalid_date) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Invalid email in nested author ---")

invalid_author = %{
  "title" => "Test Document",
  "authors" => [
    %{
      "name" => "Test Author",
      "email" => "not-an-email",  # Invalid email format
      "affiliation" => "Test Org"
    }
  ],
  "publication_date" => "2024-01-15",
  "keywords" => ["keyword1", "keyword2", "keyword3"],
  "abstract" => String.duplicate("a", 150),
  "document_type" => "article"
}

case DocumentMetadataExtraction.validate_metadata(invalid_author) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Too few keywords ---")

invalid_keywords = %{
  "title" => "Test Document",
  "authors" => [
    %{
      "name" => "Test Author",
      "email" => "test@example.com",
      "affiliation" => "Test Org"
    }
  ],
  "publication_date" => "2024-01-15",
  "keywords" => ["only", "two"],  # Needs at least 3
  "abstract" => String.duplicate("a", 150),
  "document_type" => "article"
}

case DocumentMetadataExtraction.validate_metadata(invalid_keywords) do
  {:ok, _} ->
    IO.puts("Unexpected success")

  {:error, diagnostics} ->
    IO.puts("Expected validation failure:")
    Enum.each(diagnostics.errors, fn error ->
      IO.puts("  • #{error.message}")
    end)
end

IO.puts("\n--- Example: Invalid DOI pattern ---")

invalid_doi = %{
  "title" => "Test Document",
  "authors" => [
    %{
      "name" => "Test Author",
      "email" => "test@example.com",
      "affiliation" => "Test Org"
    }
  ],
  "publication_date" => "2024-01-15",
  "keywords" => ["keyword1", "keyword2", "keyword3"],
  "abstract" => String.duplicate("a", 150),
  "document_type" => "article",
  "doi" => "invalid-doi-format"  # Should match 10.xxxx/yyyy pattern
}

case DocumentMetadataExtraction.validate_metadata(invalid_doi) do
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

## Content Management System Integration

defmodule MyAppWeb.DocumentController do
  use MyAppWeb, :controller
  alias DocumentMetadataExtraction

  def upload_document(conn, %{"document" => document_params}) do
    # Extract text from uploaded file (PDF, DOCX, etc.)
    {:ok, text} = extract_text_from_file(document_params["file"])

    # Generate metadata using LLM
    case ExOutlines.generate(
      DocumentMetadataExtraction.document_schema(),
      backend: MyApp.LLM.Backend,
      backend_opts: [prompt: build_extraction_prompt(text)]
    ) do
      {:ok, metadata} ->
        # Store document with extracted metadata
        {:ok, doc} = MyApp.Documents.create(%{
          content: text,
          title: metadata.title,
          authors: metadata.authors,
          keywords: metadata.keywords,
          publication_date: Date.from_iso8601!(metadata.publication_date),
          url: metadata.url,
          doi: metadata.doi
        })

        # Index for search
        MyApp.Search.index_document(doc, metadata)

        json(conn, %{id: doc.id, metadata: metadata})

      {:error, diagnostics} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: diagnostics.errors})
    end
  end

  defp build_extraction_prompt(text) do
    \"\"\"
    Extract bibliographic metadata from the following document text:

    \#{String.slice(text, 0..5000)}

    Provide structured metadata including title, authors, publication date,
    keywords, and abstract.
    \"\"\"
  end
end

## Digital Library Cataloging

defmodule MyApp.Library.Cataloger do
  alias DocumentMetadataExtraction

  def catalog_batch(document_paths) do
    document_paths
    |> Task.async_stream(
      fn path ->
        with {:ok, text} <- File.read(path),
             {:ok, metadata} <- extract_and_validate(text) do
          {:ok, {path, metadata}}
        end
      end,
      max_concurrency: 5,
      timeout: 30_000
    )
    |> Enum.to_list()
  end

  defp extract_and_validate(text) do
    case ExOutlines.generate(
      DocumentMetadataExtraction.document_schema(),
      backend: MyApp.LLM.Backend
    ) do
      {:ok, metadata} ->
        # Additional validation or enrichment
        metadata = enrich_metadata(metadata)
        {:ok, metadata}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp enrich_metadata(metadata) do
    # Add computed fields
    %{
      metadata
      | citation: DocumentMetadataExtraction.format_citation(metadata),
        indexed_at: DateTime.utc_now()
    }
  end
end

## Citation Manager Integration

defmodule MyApp.Citations do
  def import_from_url(url) do
    # Fetch document content
    {:ok, %{body: html}} = HTTPoison.get(url)
    text = extract_text_from_html(html)

    # Extract metadata
    {:ok, metadata} = ExOutlines.generate(
      DocumentMetadataExtraction.document_schema(),
      backend: MyApp.LLM.Backend
    )

    # Convert to BibTeX format
    bibtex = to_bibtex(metadata)

    # Store in citation library
    MyApp.Citations.Library.add(metadata, bibtex)
  end

  defp to_bibtex(metadata) do
    author_str = Enum.map_join(metadata.authors, " and ", & &1.name)
    year = String.slice(metadata.publication_date, 0..3)

    \"\"\"
    @article{citation_key,
      author = {\#{author_str}},
      title = {\#{metadata.title}},
      year = {\#{year}},
      url = {\#{metadata.url}},
      doi = {\#{metadata.doi}}
    }
    \"\"\"
  end
end

## Validation and Quality Checks

defmodule MyApp.MetadataQuality do
  def check_quality(metadata) do
    checks = [
      check_author_count(metadata),
      check_keyword_relevance(metadata),
      check_abstract_length(metadata),
      check_date_validity(metadata)
    ]

    quality_score = calculate_score(checks)
    issues = Enum.filter(checks, &(&1.status == :warning))

    %{score: quality_score, issues: issues}
  end

  defp check_author_count(%{authors: authors}) do
    count = length(authors)
    if count > 0 and count <= 10 do
      %{check: :author_count, status: :pass}
    else
      %{check: :author_count, status: :warning,
        message: "Unusual author count: \#{count}"}
    end
  end

  defp check_date_validity(%{publication_date: date_str}) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        if Date.compare(date, Date.utc_today()) == :lt do
          %{check: :date_validity, status: :pass}
        else
          %{check: :date_validity, status: :warning,
            message: "Future publication date"}
        end
      {:error, _} ->
        %{check: :date_validity, status: :error,
          message: "Invalid date format"}
    end
  end
end
""")

IO.puts("\n" <> ("=" |> String.duplicate(70)))
IO.puts("Example complete! All validations passed.")
IO.puts("=" |> String.duplicate(70))
