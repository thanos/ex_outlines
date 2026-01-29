# ExOutlines Documentation Index

Complete index of all documentation, guides, examples, and tutorials.

**Last Updated:** 2026-01-28

**Version:** 0.2.0

## Quick Links

- [Getting Started](guides/getting_started.md) - Start here if you're new
- [API Reference](https://hexdocs.pm/ex_outlines/) - Complete API documentation
- Examples Directory - Production-ready code examples (see below)
- [Livebook Tutorials](livebooks/README.md) - Interactive learning

## Core Documentation

### Guides (11 total)

#### Foundation (3)

1. **[Getting Started](guides/getting_started.md)** (450+ lines)
   - Installation and setup
   - First schema creation
   - Validation basics
   - Backend configuration
   - Common patterns

2. **[Core Concepts](guides/core_concepts.md)** (800+ lines)
   - Structured generation principles
   - Schema definition
   - Type system
   - Validation process
   - Retry-repair loop
   - Backend architecture
   - Batch processing
   - Telemetry

3. **[Architecture](guides/architecture.md)** (900+ lines)
   - System overview
   - Module organization
   - Validation engine
   - Backend implementations
   - Design decisions
   - Extension points

#### Schema Design (1)

4. **[Schema Patterns](guides/schema_patterns.md)** (600+ lines)
   - Basic patterns
   - String validation (length, regex, format)
   - Numeric constraints
   - Array patterns
   - Nested objects
   - Union types
   - Enum patterns
   - Common scenarios
   - Schema composition

#### Integration (2)

5. **[Phoenix Integration](guides/phoenix_integration.md)** (500+ lines)
   - Controller integration
   - LiveView patterns
   - Background jobs with Oban
   - Caching strategies
   - Production deployment

6. **[Ecto Schema Adapter](guides/ecto_schema_adapter.md)** (400+ lines)
   - Converting Ecto schemas
   - Automatic validation extraction
   - Embedded schemas
   - Integration patterns

#### Testing and Quality (2)

7. **[Testing Strategies](guides/testing_strategies.md)** (550+ lines)
   - Unit testing with Mock
   - Integration testing
   - Property-based testing
   - CI/CD integration

8. **[Error Handling](guides/error_handling.md)** (500+ lines)
   - Diagnostics structure
   - Retry strategies
   - Graceful degradation
   - Circuit breakers
   - Monitoring

#### Performance (1)

9. **[Batch Processing](guides/batch_processing.md)** (700+ lines)
   - Concurrent processing
   - generate_batch/2 usage
   - Configuration options
   - Error handling
   - Performance optimization
   - Real-world patterns
   - Telemetry monitoring

#### Index

10. **[Guides README](guides/README.md)** (250+ lines)
    - Complete guide index
    - Learning paths
    - Use case mappings
    - Best practices summary

## Examples (7 total)

### Production Examples (7)

All examples are complete, runnable scripts with comprehensive documentation.

1. **[Resume Parser](examples/resume_parser.exs)** (550+ lines)
   - Extract structured data from resumes
   - Complex nested schemas
   - Union types for optional fields
   - Format validation
   - Phoenix/Ecto integration patterns

2. **[E-commerce Product Categorization](examples/ecommerce_categorization.exs)** (500+ lines)
   - Product data extraction
   - Category taxonomy
   - Feature extraction
   - Price tier estimation
   - Tag generation

3. **[Customer Support Triage](examples/customer_support_triage.exs)** (650+ lines)
   - Ticket classification
   - Priority detection
   - Urgency indicators
   - Sentiment analysis
   - Department routing

4. **[Document Metadata Extraction](examples/document_metadata_extraction.exs)** (600+ lines)
   - Academic paper metadata
   - Nested author objects
   - Format validation (DOI, dates, URLs)
   - Keyword extraction

5. **[Classification Example](examples/classification.exs)** (300+ lines)
   - Basic enum classification
   - Sentiment analysis
   - Confidence scoring
   - Batch processing example

6. **[Ecto Schema Adapter Example](examples/ecto_schema_adapter.exs)** (250+ lines)
   - Converting Ecto schemas
   - Automatic validation
   - Integration patterns

7. **[Customer Support Triage (Original)](examples/customer_support_triage.exs)** (600+ lines)
   - Original triage implementation
   - Multiple examples
   - Validation failure examples

## Interactive Tutorials

### Livebook Notebooks (14 complete)

#### Beginner Level (1)

1. **[Getting Started](livebooks/getting_started.livemd)** (400+ lines)
   - Introduction to ExOutlines
   - Basic schema creation
   - Validation fundamentals
   - Error handling
   - Backend configuration

#### Intermediate Level (4)

3. **[Named Entity Extraction](livebooks/named_entity_extraction.livemd)** (700+ lines)
   - Pizza order processing example
   - Nested object schemas
   - Handling missing information
   - Batch processing
   - Phoenix integration patterns

4. **[Dating Profile Generation](livebooks/dating_profiles.livemd)** (700+ lines)
   - Creative content generation
   - EEx template systems
   - Different writing styles
   - Profile quality metrics
   - A/B testing variants
   - LiveView integration

5. **[Question Answering with Citations](livebooks/qa_with_citations.livemd)** (750+ lines)
   - Trustworthy Q&A systems
   - Citation extraction and formatting
   - Source verification
   - Handling insufficient evidence
   - Citation quality validation
   - Knowledge base integration

6. **[Sampling and Self-Consistency](livebooks/sampling_and_self_consistency.livemd)** (600+ lines)
   - Multi-sample generation
   - Answer distribution analysis
   - Self-consistency technique
   - Entropy calculation
   - Model comparison
   - Interactive exploration
   - VegaLite visualizations

#### Advanced Level (5)

7. **[Models Playing Chess](livebooks/models_playing_chess.livemd)** (700+ lines)
   - Constrained chess move generation
   - Dynamic schema generation
   - Legal move validation
   - Game state tracking
   - Interactive chess game

8. **[SimToM: Simulation Theory of Mind](livebooks/simtom_theory_of_mind.livemd)** (750+ lines)
   - Two-stage perspective-taking
   - Belief tracking
   - Character knowledge filtering
   - Mermaid diagrams
   - Cognitive reasoning

9. **[Chain of Thought Reasoning](livebooks/chain_of_thought.livemd)** (800+ lines)
   - Step-by-step reasoning
   - Reasoning chain validation
   - Conclusion extraction
   - Mathematical problem solving
   - Complex reasoning patterns

10. **[ReAct Agent](livebooks/react_agent.livemd)** (900+ lines)
    - Thought-Action-Observation loops
    - Tool integration (Wikipedia, calculator)
    - Multi-step problem solving
    - Agent architecture patterns
    - Error handling and recovery

11. **[Structured Generation Workflow](livebooks/structured_generation_workflow.livemd)** (800+ lines)
    - Multi-stage pipelines
    - Iterative refinement
    - Quality validation
    - Pattern testing
    - Workflow orchestration

#### Vision and Document Processing (4)

12. **[PDF Reading with Vision Models](livebooks/read_pdfs.livemd)** (950+ lines)
    - PDF to image conversion
    - Invoice extraction
    - Research paper metadata
    - Multi-page processing
    - Form digitization
    - Document classification

13. **[Earnings Reports Extraction](livebooks/earnings_reports.livemd)** (1050+ lines)
    - Financial data extraction
    - Income statement parsing
    - Balance sheet validation
    - Multi-period comparison
    - CSV export for analysis
    - Accounting equation validation

14. **[Receipt Digitization](livebooks/receipt_digitization.livemd)** (1000+ lines)
    - Receipt image processing
    - Line item extraction
    - Expense categorization
    - Batch processing
    - Quality assessment
    - Restaurant receipt analysis

15. **[Extract Event Details](livebooks/extract_event_details.livemd)** (700+ lines)
    - Natural language to structured events
    - Relative date parsing
    - ISO 8601 conversion
    - iCalendar generation
    - Time zone handling

#### Livebook Index

16. **[Livebook README](livebooks/README.md)** (400+ lines)
    - Setup instructions
    - API key configuration
    - Running notebooks
    - Troubleshooting
    - Cost considerations
    - Learning paths
    - Best practices

## Main Documentation

1. **[README.md](README.md)** (630+ lines)
   - Project overview
   - Quick start
   - Installation
   - Usage examples
   - Feature list
   - Backend documentation
   - Contributing guidelines

2. **[DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md)** (This file)
   - Complete documentation inventory
   - Content organization
   - Quick navigation

## Statistics

### Documentation Coverage

- **Guides**: 11 guides (6,250+ lines total)
- **Examples**: 7 production examples (3,550+ lines total)
- **Livebooks**: 14 interactive notebooks (11,000+ lines)
- **Total Lines**: ~21,000+ lines of documentation and code examples

### Topics Covered

**Core Concepts**:
- Structured generation
- Schema design
- Validation
- Retry-repair loop
- Backend architecture
- Telemetry

**Schema Features**:
- String validation (length, regex, format)
- Numeric constraints (min, max)
- Arrays with constraints
- Nested objects
- Union types
- Enum types
- Required/optional fields

**Integration**:
- Phoenix controllers
- LiveView patterns
- Oban background jobs
- Ecto schemas
- Caching strategies

**Testing**:
- Mock backend
- Integration tests
- Property-based testing
- CI/CD patterns

**Production**:
- Error handling
- Retry strategies
- Graceful degradation
- Circuit breakers
- Monitoring
- Batch processing
- Performance optimization

**Use Cases**:
- Resume parsing
- Product categorization
- Customer support triage
- Document metadata extraction
- Content classification
- Sentiment analysis
- PDF document extraction
- Financial data extraction
- Receipt digitization
- Event information extraction
- Chess game implementation
- Theory of Mind reasoning
- Chain of Thought prompting
- ReAct agent systems
- Multi-stage workflows

**Vision and Document Processing**:
- PDF to image conversion
- Invoice extraction
- Research paper parsing
- Financial statement analysis
- Receipt digitization
- Form processing
- Multi-page document handling

## Content Quality Standards

All documentation follows these standards:

- No emoji (per user requirement)
- Clear, professional style
- Straightforward language
- Complete, runnable code examples
- Real-world use cases
- Error handling examples
- Integration patterns
- Best practices
- Production-ready patterns

## Navigation Guide

### By User Type

**New Users**:
1. [Getting Started](guides/getting_started.md)
2. [Schema Patterns](guides/schema_patterns.md)
3. [Classification Example](examples/classification.exs)
4. [Sampling Livebook](livebooks/sampling_and_self_consistency.livemd)

**Phoenix Developers**:
1. [Getting Started](guides/getting_started.md)
2. [Phoenix Integration](guides/phoenix_integration.md)
3. [Ecto Schema Adapter](guides/ecto_schema_adapter.md)
4. [Error Handling](guides/error_handling.md)

**Production Engineers**:
1. [Core Concepts](guides/core_concepts.md)
2. [Architecture](guides/architecture.md)
3. [Error Handling](guides/error_handling.md)
4. [Batch Processing](guides/batch_processing.md)
5. [Testing Strategies](guides/testing_strategies.md)

**Advanced Users**:
1. [Architecture](guides/architecture.md)
2. [Batch Processing](guides/batch_processing.md)
3. [Schema Patterns](guides/schema_patterns.md)
4. All production examples

### By Use Case

**Building a Classification System**:
- [Classification Example](examples/classification.exs)
- [Schema Patterns](guides/schema_patterns.md) (Enum section)
- [Testing Strategies](guides/testing_strategies.md)

**Processing User-Generated Content**:
- [Resume Parser](examples/resume_parser.exs)
- [Document Metadata](examples/document_metadata_extraction.exs)
- [Batch Processing](guides/batch_processing.md)
- [Error Handling](guides/error_handling.md)

**Real-time Web Features**:
- [Phoenix Integration](guides/phoenix_integration.md) (LiveView)
- [Error Handling](guides/error_handling.md)
- [Testing Strategies](guides/testing_strategies.md)

**Background Processing**:
- [Phoenix Integration](guides/phoenix_integration.md) (Oban)
- [Batch Processing](guides/batch_processing.md)
- [Error Handling](guides/error_handling.md)

**E-commerce Applications**:
- [Product Categorization](examples/ecommerce_categorization.exs)
- [Schema Patterns](guides/schema_patterns.md)
- [Batch Processing](guides/batch_processing.md)

## Contributing to Documentation

### Missing Topics

Potential future documentation:

1. **Performance Guide**: Detailed performance optimization
2. **Streaming Guide**: Streaming responses (when implemented)
3. **Custom Backends**: Building custom backend implementations
4. **Prompt Engineering**: Effective prompt design for structured output
5. **Cost Optimization**: Minimizing LLM API costs
6. **Security Guide**: API key management, input sanitization
7. **Deployment Guide**: Production deployment patterns
8. **Monitoring Guide**: Comprehensive telemetry and alerting

### How to Contribute

1. Identify documentation gap
2. Check existing issues/PRs
3. Follow style guide:
   - No emoji
   - Clear, professional style
   - Complete code examples
   - Real-world patterns
4. Submit PR with updates to this index

## License

All documentation is distributed under the same license as ExOutlines (MIT).

---

**Maintained by**: ExOutlines Contributors

**Repository**: [GitHub](https://github.com/aiwaiwa/ex_outlines)

**Questions**: [GitHub Issues](https://github.com/aiwaiwa/ex_outlines/issues)
