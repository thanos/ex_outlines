# ExOutlines Livebook Tutorials

This directory contains interactive Livebook notebooks demonstrating ExOutlines features and patterns.

## Getting Started

1. Install Livebook: https://livebook.dev/
2. Open Livebook and navigate to this directory
3. Select a notebook and run the cells

All notebooks are self-contained and include Mix.install directives to automatically install dependencies.

## Available Notebooks

### Beginner Level

#### getting_started.livemd
Introduction to ExOutlines for beginners. Learn the basics of schema creation, validation, and structured output generation.

**Topics**: schema basics, required fields, types, validation, error handling

**Duration**: 30-45 minutes

---

### Intermediate Level

#### named_entity_extraction.livemd
Extract structured entities from unstructured text (names, locations, organizations, dates).

**Topics**: nested objects, entity types, relationship extraction

**Duration**: 45-60 minutes

---

#### dating_profiles.livemd
Generate creative content with structured templates. Create dating profile bios with personality-based customization.

**Topics**: creative generation, string constraints, enum choices, EEx templates

**Duration**: 45-60 minutes

---

#### qa_with_citations.livemd
Build question-answering systems that provide cited answers from source documents.

**Topics**: citation tracking, source references, answer validation

**Duration**: 45-60 minutes

---

#### sampling_and_self_consistency.livemd
Explore LLM sampling strategies and self-consistency techniques for improved reliability.

**Topics**: temperature, multiple samples, consensus voting, entropy analysis

**Duration**: 45-60 minutes

---

### Advanced Level

#### models_playing_chess.livemd
Implement a chess game where an LLM plays valid moves using constrained generation.

**Topics**: dynamic schemas, legal move validation, game state tracking

**Duration**: 60-90 minutes

---

#### simtom_theory_of_mind.livemd
Implement Simulation Theory of Mind (SimToM) for perspective-taking tasks.

**Topics**: two-stage reasoning, belief tracking, character perspectives, Mermaid diagrams

**Duration**: 60-90 minutes

---

#### chain_of_thought.livemd
Implement chain-of-thought reasoning with structured intermediate steps.

**Topics**: step-by-step reasoning, reasoning chains, conclusion validation

**Duration**: 60-90 minutes

---

#### react_agent.livemd
Build a ReAct (Reasoning + Acting) agent that interacts with tools and external resources.

**Topics**: thought-action-observation loops, tool integration, agent patterns, Wikipedia API, calculator

**Duration**: 60-90 minutes

---

#### structured_generation_workflow.livemd
Multi-stage generation workflows with iterative refinement and validation.

**Topics**: pipeline patterns, quality checks, iterative improvement, validation metrics

**Duration**: 60-90 minutes

---

### Vision and Document Processing

#### read_pdfs.livemd
Extract structured data from PDF documents using vision-language models.

**Topics**: PDF to image conversion, vision models, invoice extraction, research papers, multi-page processing

**Duration**: 60-90 minutes

---

#### earnings_reports.livemd
Extract financial data from earnings reports and export to CSV for analysis.

**Topics**: financial schemas, income statements, balance sheets, multi-period comparison, CSV export

**Duration**: 60-90 minutes

---

#### receipt_digitization.livemd
Digitize receipts from images into structured data for expense tracking.

**Topics**: receipt schemas, vision models, expense categorization, batch processing, quality assessment

**Duration**: 60-90 minutes

---

#### extract_event_details.livemd
Extract event information from natural language and convert to structured calendar entries.

**Topics**: datetime parsing, relative date handling, iCalendar generation, time zone handling

**Duration**: 45-60 minutes

---

## Notebook Structure

Each notebook follows a consistent structure:

1. **Setup**: Mix.install with dependencies
2. **Introduction**: Overview of the concept and use cases
3. **Schema Design**: Define validation schemas
4. **Examples**: Multiple working examples with increasing complexity
5. **Production Patterns**: Integration guidance for real applications
6. **Testing**: Examples using Mock backend
7. **Summary**: Key takeaways and next steps

## Running the Notebooks

### In Livebook

1. Open Livebook
2. Navigate to the `livebooks/` directory
3. Click on any notebook
4. Click "Run" or use keyboard shortcuts to execute cells

### Command Line (for testing)

You can also run notebooks from the command line:

```bash
elixir livebooks/getting_started.livemd
```

## Mock Backend for Testing

All notebooks include examples using the Mock backend so you can run them without API keys:

```elixir
alias ExOutlines.Backend.Mock

mock = Mock.new([{:ok, ~s({"name": "Alice", "age": 30})}])

result = ExOutlines.generate(schema,
  backend: Mock,
  backend_opts: [mock: mock]
)
```

## Using Real LLM Backends

To use real LLM backends, configure environment variables:

```bash
# For Anthropic Claude
export ANTHROPIC_API_KEY="your-api-key"

# For OpenAI-compatible APIs
export OPENAI_API_KEY="your-api-key"
export OPENAI_API_URL="https://api.openai.com/v1"
```

Then in notebooks, use the appropriate backend:

```elixir
# Anthropic Claude
result = ExOutlines.generate(schema,
  backend: ExOutlines.Backend.Anthropic,
  backend_opts: [
    api_key: System.get_env("ANTHROPIC_API_KEY"),
    model: "claude-3-5-sonnet-20241022"
  ]
)

# OpenAI-compatible
result = ExOutlines.generate(schema,
  backend: ExOutlines.Backend.HTTP,
  backend_opts: [
    api_key: System.get_env("OPENAI_API_KEY"),
    api_url: System.get_env("OPENAI_API_URL"),
    model: "gpt-4"
  ]
)
```

## Learning Path

Recommended order for learning:

1. **getting_started.livemd** - Fundamentals and basic concepts
2. **classification.livemd** - Simple real-world example
3. **named_entity_extraction.livemd** - Nested structures and extraction
4. **chain_of_thought.livemd** - Reasoning patterns
5. **react_agent.livemd** - Agent architectures and tool use
6. **read_pdfs.livemd** - Vision models for document processing
7. **structured_generation_workflow.livemd** - Production workflows

Alternative paths based on interest:

- **Creative applications**: dating_profiles → qa_with_citations → sampling_and_self_consistency
- **Document processing**: read_pdfs → earnings_reports → receipt_digitization → extract_event_details
- **Agent systems**: react_agent → models_playing_chess → simtom_theory_of_mind
- **Reasoning**: chain_of_thought → simtom_theory_of_mind → sampling_and_self_consistency

## API Key Setup

### Livebook Secrets (Recommended)

1. Open a notebook in Livebook
2. Click the "Secrets" section in the sidebar (lock icon)
3. Add secrets:
   - `LB_OPENAI_API_KEY` - OpenAI API key
   - `LB_ANTHROPIC_API_KEY` - Anthropic Claude API key

### Environment Variables

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export OPENAI_API_URL="https://api.openai.com/v1"
```

## Cost Considerations

Running these notebooks makes API calls to LLM providers:

**Estimated Costs** (as of 2024):

- **Text notebooks**: $0.01-0.10 per complete run
- **Vision notebooks**: $0.10-0.50 per complete run (higher due to image processing)
- **Agent notebooks**: $0.05-0.25 per complete run (multiple API calls)

**Cost Reduction Tips**:

1. Use smaller sample sizes for testing
2. Start with cheaper models (claude-3-haiku, gpt-4o-mini)
3. Use the Mock backend for development and testing
4. Cache results to avoid re-running expensive cells
5. Limit concurrency in batch operations

## Contributing

To add a new notebook:

1. Create a new `.livemd` file in this directory
2. Follow the standard structure (see existing notebooks)
3. Include Mix.install with all dependencies
4. Provide working examples with Mock backend
5. Add production integration guidance
6. Update this README with the new notebook
7. Test thoroughly with fresh runtime

## Troubleshooting

### Dependencies Won't Install

**Problem**: `Mix.install` fails with dependency errors

**Solution**:
- Restart Livebook runtime (Runtime → Reconnect)
- Check internet connection
- Update Livebook to latest version

### API Key Errors

**Problem**: "Invalid API key" or authentication errors

**Solution**:
- Verify API key is correct in Secrets
- Ensure secret name matches code
- Check API key has credits and is not expired

### Timeout Errors

**Problem**: Cells timeout or don't complete

**Solution**:
- Increase timeout in backend_opts: `timeout: 120_000`
- Reduce batch size or concurrency
- Check API rate limits

### Vision Model Errors

**Problem**: Vision notebooks fail with image processing errors

**Solution**:
- Ensure image files exist
- Check image format (PNG, JPG supported)
- Verify base64 encoding is correct
- Try with smaller images first

### Cells Out of Order

**Problem**: Errors about undefined variables

**Solution**:
- Run cells sequentially from top
- Use "Evaluate all" to run entire notebook
- Check cell dependencies

## Additional Resources

### ExOutlines Documentation
- Getting Started Guide: `/guides/getting_started.md`
- Core Concepts: `/guides/core_concepts.md`
- Schema Patterns: `/guides/schema_patterns.md`
- Architecture: `/guides/architecture.md`
- API Reference: https://hexdocs.pm/ex_outlines

### Livebook Resources
- [Livebook Guide](https://hexdocs.pm/livebook/)
- [Kino Library](https://hexdocs.pm/kino/) - Interactive elements
- [VegaLite](https://hexdocs.pm/vega_lite/) - Data visualization

### Community
- [GitHub Repository](https://github.com/aiwaiwa/ex_outlines)
- [Elixir Forum](https://elixirforum.com/)
- [Elixir Slack](https://elixir-slack.com/)

## Statistics

- **Total notebooks**: 14
- **Total lines of code and documentation**: ~11,000+
- **Topics covered**: 25+
- **Example schemas**: 60+
- **Production integration examples**: 15+

## License

These notebooks are distributed under the same license as ExOutlines (Apache 2.0).

Last updated: 2024-01-28
