# ExOutlines How-To Guides

Practical guides for building production applications with ExOutlines.

## Overview

These guides provide step-by-step instructions, code examples, and best practices for common ExOutlines use cases. Each guide is self-contained and focuses on a specific aspect of building LLM-powered Elixir applications.

## Available Guides

### [Phoenix Integration](phoenix_integration.md)

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

### [Testing Strategies](testing_strategies.md)

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

### [Error Handling](error_handling.md)

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

### [Ecto Schema Adapter](ecto_schema_adapter.md)

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

## Quick Start

New to ExOutlines? Follow this learning path:

1. **Start Here**: [Getting Started Livebook](../livebooks/getting_started.livemd)
   - Interactive introduction to ExOutlines basics
   - Learn schemas, validation, and constraints
   - ~30 minutes

2. **Build Something**: [Phoenix Integration](phoenix_integration.md)
   - Integrate ExOutlines into a Phoenix app
   - Controller and LiveView examples
   - ~45 minutes

3. **Test It**: [Testing Strategies](testing_strategies.md)
   - Write fast, reliable tests
   - Mock backend and integration tests
   - ~45 minutes

4. **Make It Production-Ready**: [Error Handling](error_handling.md)
   - Handle errors gracefully
   - Monitor and alert on issues
   - ~45 minutes

5. **Advanced Topics**: [Advanced Patterns Livebook](../livebooks/advanced_patterns.livemd)
   - Nested objects, union types, complex schemas
   - Production patterns and performance tips
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

- **[E-commerce Product Categorization](../examples/ecommerce_categorization.exs)**
  - Demonstrates: nested objects, arrays, enums
  - Use case: Automated product data extraction

- **[Customer Support Triage](../examples/customer_support_triage.exs)**
  - Demonstrates: priority classification, urgency detection
  - Use case: Ticket routing and SLA management

- **[Document Metadata Extraction](../examples/document_metadata_extraction.exs)**
  - Demonstrates: format validation, nested authors
  - Use case: Content management systems

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
