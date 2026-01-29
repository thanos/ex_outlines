# ExOutlines How-To Guides

Practical guides for building production applications with ExOutlines.

## Overview

These guides provide step-by-step instructions, code examples, and best practices for common ExOutlines use cases. Each guide is self-contained and focuses on a specific aspect of building LLM-powered Elixir applications.

## Available Guides

### Core Documentation

#### [Getting Started](getting_started.md)

Complete introduction to ExOutlines for new users.

**Topics Covered:**
- Installation and setup
- Creating your first schema
- Understanding validation
- Working with backends
- Common patterns

**Best For:** Developers new to ExOutlines

**Time to Complete:** 30-45 minutes

---

#### [Core Concepts](core_concepts.md)

Deep dive into ExOutlines architecture and design.

**Topics Covered:**
- Structured generation principles
- Schema definition and type system
- Validation process
- Retry-repair loop mechanics
- Backend architecture
- Telemetry integration

**Best For:** Developers who want to understand how ExOutlines works internally

**Time to Complete:** 45-60 minutes

---

#### [Architecture](architecture.md)

Technical architecture and design decisions.

**Topics Covered:**
- System overview and module organization
- Validation engine implementation
- Backend architecture patterns
- Retry-repair loop algorithm
- Design rationale and trade-offs
- Extension points

**Best For:** Contributors and advanced users

**Time to Complete:** 60 minutes

---

### Schema Design

#### [Schema Patterns](schema_patterns.md)

Comprehensive guide to schema design and validation patterns.

**Topics Covered:**
- Basic schema patterns
- String validation (length, regex, format)
- Numeric constraints (min, max, ranges)
- Array validation patterns
- Nested object schemas
- Union types for flexibility
- Enum patterns
- Common validation scenarios
- Schema composition and reuse

**Best For:** All users building schemas for real applications

**Time to Complete:** 45-60 minutes

---

### Integration Guides

#### [Phoenix Integration](phoenix_integration.md)

Learn how to integrate ExOutlines into Phoenix applications.

**Topics Covered:**
- Using ExOutlines in controllers and LiveView
- Background job processing with Oban
- Caching strategies for LLM results
- Error handling in web context
- Production deployment patterns

**Best For:** Web developers building AI-powered Phoenix applications

**Time to Complete:** 30-45 minutes

---

#### [Ecto Schema Adapter](ecto_schema_adapter.md)

Reuse existing Ecto schemas with ExOutlines.

**Topics Covered:**
- Converting Ecto schemas to ExOutlines format
- Automatic validation extraction from changesets
- Embedded schemas and Ecto.Enum support
- Integration patterns for Phoenix applications
- Best practices for schema reuse

**Best For:** Developers with existing Ecto schemas who want to avoid duplication

**Time to Complete:** 30-45 minutes

---

### Testing and Quality

#### [Testing Strategies](testing_strategies.md)

Master testing patterns for LLM-powered applications.

**Topics Covered:**
- Unit testing with Mock backend
- Integration testing with real APIs
- Property-based testing with StreamData
- Testing retry and error handling
- CI/CD integration
- Test organization

**Best For:** Developers who want fast, reliable test suites

**Time to Complete:** 45-60 minutes

---

#### [Error Handling](error_handling.md)

Build resilient applications with proper error handling.

**Topics Covered:**
- Understanding Diagnostics
- User-friendly error messages
- Retry strategies and exponential backoff
- Graceful degradation and fallbacks
- Circuit breaker patterns
- Monitoring with telemetry

**Best For:** Production engineers focused on reliability

**Time to Complete:** 45-60 minutes

---

### Performance and Scale

#### [Batch Processing](batch_processing.md)

Process multiple LLM requests concurrently using BEAM's concurrency model.

**Topics Covered:**
- Why batch processing matters
- Using generate_batch/2
- Concurrency configuration
- Error handling for batches
- Performance optimization
- Real-world patterns (content moderation, product categorization)
- Monitoring with telemetry
- Cost optimization

**Best For:** Developers building high-throughput applications

**Time to Complete:** 45-60 minutes

---

## Quick Start

New to ExOutlines? Follow this learning path:

1. **Start Here**: [Getting Started Guide](getting_started.md)
   - Complete introduction to ExOutlines basics
   - Learn schemas, validation, and backends
   - ~30 minutes

2. **Understand the Concepts**: [Core Concepts](core_concepts.md)
   - Structured generation principles
   - Validation and retry-repair loop
   - Backend architecture
   - ~45 minutes

3. **Design Great Schemas**: [Schema Patterns](schema_patterns.md)
   - Common validation patterns
   - String, numeric, and array constraints
   - Nested objects and union types
   - ~45 minutes

4. **Build Something**: [Phoenix Integration](phoenix_integration.md)
   - Integrate ExOutlines into a Phoenix app
   - Controller and LiveView examples
   - ~45 minutes

5. **Scale It**: [Batch Processing](batch_processing.md)
   - Process multiple requests concurrently
   - BEAM concurrency advantages
   - ~45 minutes

6. **Test It**: [Testing Strategies](testing_strategies.md)
   - Write fast, reliable tests
   - Mock backend and integration tests
   - ~45 minutes

7. **Make It Production-Ready**: [Error Handling](error_handling.md)
   - Handle errors gracefully
   - Monitor and alert on issues
   - ~45 minutes

8. **Interactive Learning**: [Sampling Livebook](../livebooks/sampling_and_self_consistency.livemd)
   - Interactive multi-sample generation
   - Self-consistency and entropy analysis
   - ~60 minutes

## Common Use Cases

### Building a Content Analyzer

**Guides to Read:**
1. [Phoenix Integration](phoenix_integration.md) - Set up the endpoint
2. [Testing Strategies](testing_strategies.md) - Test your analyzer
3. [Error Handling](error_handling.md) - Handle failures gracefully

### Background Data Processing

**Guides to Read:**
1. [Phoenix Integration](phoenix_integration.md) - Oban worker pattern
2. [Error Handling](error_handling.md) - Retry strategies
3. [Testing Strategies](testing_strategies.md) - Test async jobs

### Real-time AI Features

**Guides to Read:**
1. [Phoenix Integration](phoenix_integration.md) - LiveView integration
2. [Error Handling](error_handling.md) - User-friendly errors
3. [Testing Strategies](testing_strategies.md) - Test LiveView

## Code Examples

All guides include complete, runnable code examples that you can copy and adapt for your use case.

### Example Projects

Looking for complete example applications? Check out:

- **[Resume Parser](../examples/resume_parser.exs)**
  - Demonstrates: complex nested objects, arrays, union types, format validation
  - Use case: Automated resume screening and ATS integration
  - Schema: Personal info, work history, education, skills, certifications

- **[E-commerce Product Categorization](../examples/ecommerce_categorization.exs)**
  - Demonstrates: nested objects, arrays, enums
  - Use case: Automated product data extraction

- **[Customer Support Triage](../examples/customer_support_triage.exs)**
  - Demonstrates: priority classification, urgency detection
  - Use case: Ticket routing and SLA management

- **[Document Metadata Extraction](../examples/document_metadata_extraction.exs)**
  - Demonstrates: format validation, nested authors
  - Use case: Content management systems

- **[Classification Example](../examples/classification.exs)**
  - Demonstrates: basic enum-based classification
  - Use case: Customer support ticket categorization

## Best Practices Summary

### Development
-Use Mock backend for fast unit tests
-Structure code for testability
-Validate early and often
-Cache LLM results where appropriate

### Production
-Implement graceful degradation
-Monitor with telemetry
-Use circuit breakers for critical paths
-Set appropriate timeouts
-Log errors with context

### Performance
-Process long tasks in background jobs
-Use batch processing for multiple items
-Cache frequently requested results
-Set conservative retry limits

### Security
-Store API keys in environment variables
-Rate limit AI endpoints
-Validate all user input
-Sanitize error messages for users

## Getting Help

### Documentation
- [API Documentation](https://hexdocs.pm/ex_outlines/)
- [README](../README.md) - Project overview
- [Development Plan](../docs/DEVELOPMENT_PLAN.md) - Roadmap

### Community
- [GitHub Issues](https://github.com/your-org/ex_outlines/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/your-org/ex_outlines/discussions) - Questions and community support

### Examples
- [Examples Directory](../examples/) - Production-ready examples
- [Livebooks](../livebooks/) - Interactive tutorials

## Contributing

Found an issue or have a suggestion for these guides?

1. Check [existing issues](https://github.com/your-org/ex_outlines/issues)
2. Open a new issue with the `documentation` label
3. Or submit a pull request with improvements

We welcome contributions to make these guides more helpful!

## Additional Resources

### Related Projects
- [Phoenix Framework](https://phoenixframework.org/)
- [Oban](https://hexdocs.pm/oban/) - Background job processing
- [Cachex](https://hexdocs.pm/cachex/) - Caching library
- [StreamData](https://hexdocs.pm/stream_data/) - Property-based testing

### LLM Providers
- [Anthropic Claude](https://www.anthropic.com/) - Native support via Anthropic backend
- [OpenAI](https://openai.com/) - Compatible via HTTP backend
- [Other Providers](../README.md#backends) - Any OpenAI-compatible API

## License

ExOutlines is released under the MIT License. See [LICENSE](../LICENSE) for details.

---

**Last Updated:** 2026-01-28

**ExOutlines Version:** 0.2.0
