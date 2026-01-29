# ExOutlines Livebook Tutorials

Interactive tutorials for learning ExOutlines using Livebook.

## What is Livebook?

[Livebook](https://livebook.dev/) is an interactive notebook platform for Elixir. It allows you to write Elixir code, add rich markdown documentation, create visualizations, and share your work—all in a single document.

## Getting Started with Livebook

### Installation

Install Livebook using one of these methods:

**Escript (Recommended)**:
```bash
mix escript.install hex livebook
livebook server
```

**Desktop App**:
Download from [livebook.dev](https://livebook.dev/)

**Docker**:
```bash
docker run -p 8080:8080 -p 8081:8081 --pull always ghcr.io/livebook-dev/livebook
```

### Opening Notebooks

1. Start Livebook: `livebook server`
2. Open http://localhost:8080 in your browser
3. Click "Open" and navigate to the `livebooks/` directory
4. Select a notebook to open

## Available Notebooks

### 1. Sampling and Self-Consistency

**File**: `sampling_and_self_consistency.livemd`

**Topics Covered**:
- Multi-sample generation from LLMs
- Answer distribution analysis
- Self-consistency for improved accuracy
- Entropy calculation for uncertainty
- Model comparison (GPT-4o-mini vs GPT-4)
- Interactive parameter exploration

**Prerequisites**:
- Basic Elixir knowledge
- OpenAI API key

**Learning Objectives**:
- Generate multiple samples for the same prompt
- Analyze and visualize answer distributions
- Calculate entropy to measure model uncertainty
- Apply self-consistency to improve results
- Compare different LLM models

**Duration**: 45-60 minutes

## Setting Up API Keys

Notebooks use Livebook secrets for API keys. This keeps your keys secure and out of version control.

### Adding Secrets in Livebook

1. Open a notebook in Livebook
2. Look for the "Secrets" section in the sidebar (lock icon)
3. Click "Add secret"
4. Name: `LB_OPENAI_API_KEY`
5. Value: Your OpenAI API key
6. Click "Add"

### Required Secrets

- **LB_OPENAI_API_KEY**: OpenAI API key for HTTP backend examples
- **LB_ANTHROPIC_API_KEY**: Anthropic API key (if using Claude models)

## Running Notebooks

### Sequential Execution

Run cells in order from top to bottom:

1. **Setup cell**: Installs dependencies (runs first, may take a minute)
2. **Configuration cells**: Set up API keys and options
3. **Example cells**: Interactive demonstrations
4. **Visualization cells**: Charts and graphs

### Interactive Elements

Notebooks include interactive controls:

- **Sliders**: Adjust parameters like temperature
- **Inputs**: Enter custom text or values
- **Buttons**: Trigger re-generation or analysis
- **Charts**: Interactive VegaLite visualizations

### Tips

- Each cell builds on previous cells—run them in order
- Re-run cells to see different results
- Modify code and experiment
- Use "Evaluate all" to run entire notebook
- Add your own cells for exploration

## Cost Considerations

Running these notebooks makes API calls to LLM providers:

**Estimated Costs** (as of 2024):

- **Sampling notebook**: ~$0.10-0.50 per complete run
  - Generates 20+ samples
  - Uses GPT-4o-mini by default (cheaper)

**Cost Reduction Tips**:

1. Use smaller sample sizes for testing
2. Start with GPT-4o-mini before trying GPT-4
3. Cache results to avoid re-running expensive cells
4. Use the Mock backend for testing without API calls

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
- Ensure secret name matches code (`LB_OPENAI_API_KEY`)
- Check API key has credits/not expired

### Timeout Errors

**Problem**: Cells timeout or don't complete

**Solution**:
- Increase timeout in backend_opts: `timeout: 120_000`
- Reduce batch size or concurrency
- Check API rate limits

### Visualizations Not Showing

**Problem**: Charts or graphs don't render

**Solution**:
- Ensure VegaLite and Kino dependencies installed
- Re-run the setup cell
- Restart runtime if needed

### Cells Out of Order

**Problem**: Errors about undefined variables

**Solution**:
- Run cells sequentially from top
- Use "Evaluate all" to run entire notebook
- Check cell dependencies

## Best Practices

### Development Workflow

1. **Start small**: Run sample cells before full examples
2. **Save often**: Livebook auto-saves, but export important work
3. **Document changes**: Add markdown cells to explain modifications
4. **Test with Mock**: Use Mock backend before real API calls
5. **Monitor costs**: Track API usage in provider dashboard

### Performance

1. **Cache results**: Assign expensive results to variables
2. **Batch operations**: Use `generate_batch` for multiple samples
3. **Limit concurrency**: Respect API rate limits
4. **Use branches**: Create branching sections for optional exploration

### Sharing

1. **Export as .livemd**: File → Export to share notebooks
2. **Remove secrets**: Don't commit API keys to repositories
3. **Include README**: Add setup instructions for others
4. **Test fresh**: Open in new runtime to verify it works

## Creating Custom Notebooks

Want to create your own ExOutlines notebook?

### Basic Template

```markdown
# My ExOutlines Tutorial

## Setup

\`\`\`elixir
Mix.install([
  {:ex_outlines, "~> 0.2.0"},
  {:kino, "~> 0.12"}
])
\`\`\`

\`\`\`elixir
alias ExOutlines.{Spec.Schema, Backend.HTTP}

api_key = System.fetch_env!("LB_OPENAI_API_KEY")
:ok
\`\`\`

## Your Content Here

\`\`\`elixir
# Your Elixir code
\`\`\`
```

### Tips for Good Notebooks

- Start with clear learning objectives
- Progress from simple to complex
- Add explanations between code cells
- Include "Try it yourself" sections
- Provide expected outputs as comments
- Add visualizations where helpful
- End with key takeaways

## Contributing

Have an idea for a new notebook? We'd love to see it!

1. Create your notebook in `livebooks/`
2. Test thoroughly (fresh runtime)
3. Add to this README
4. Submit a pull request

**Notebook Ideas**:
- Schema design patterns
- Error handling strategies
- Phoenix/LiveView integration
- Batch processing performance
- Custom backend implementation
- Prompt engineering workshop

## Additional Resources

### Livebook Documentation
- [Livebook Guide](https://hexdocs.pm/livebook/)
- [Kino Library](https://hexdocs.pm/kino/) - Interactive elements
- [VegaLite](https://hexdocs.pm/vega_lite/) - Data visualization

### ExOutlines Documentation
- [Getting Started Guide](../guides/getting_started.md)
- [Core Concepts](../guides/core_concepts.md)
- [Schema Patterns](../guides/schema_patterns.md)
- [API Reference](https://hexdocs.pm/ex_outlines/)

### Community
- [GitHub Issues](https://github.com/aiwaiwa/ex_outlines/issues)
- [Elixir Forum](https://elixirforum.com/)
- [Elixir Slack](https://elixir-slack.com/)

## License

These notebooks are distributed under the same license as ExOutlines.
