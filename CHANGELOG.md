# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

Initial release of ExOutlines - deterministic structured output from LLMs via retry-repair loops.

### Added

#### Core Engine
- Core `ExOutlines.generate/2` function with retry-repair loop
- Configurable `max_retries` for controlling generation attempts
- Backend abstraction via behaviour pattern
- Telemetry integration for observability
- Comprehensive error handling and propagation

#### Spec System
- `ExOutlines.Spec` protocol for extensible constraint specifications
- `ExOutlines.Spec.Schema` - JSON Schema-based validation
  - Support for string, integer, boolean, number, and enum types
  - Required vs optional fields
  - Positive integer constraint (> 0)
  - Field descriptions for LLM guidance
  - JSON Schema generation for prompts
  - String-to-atom key conversion

#### Validation & Diagnostics
- `ExOutlines.Diagnostics` module for structured error reporting
  - Field-level error details (field, expected, got, message)
  - Top-level error support
  - Automatic repair instruction generation
  - Error merging and aggregation
  - Human-readable error formatting

#### Prompt Construction
- `ExOutlines.Prompt` module for message building
  - Initial prompt with JSON Schema
  - Repair prompts with diagnostic feedback
  - OpenAI/Anthropic compatible message format
  - Clean, trimmed content without markdown leakage
  - Strict JSON-only enforcement

#### Backends
- `ExOutlines.Backend` behaviour definition
  - Standard `call_llm/2` callback
  - Message and option type specifications
- `ExOutlines.Backend.Mock` - Deterministic testing backend
  - Pre-configured response sequences
  - Error simulation support
  - Helper constructors (`always/1`, `always_fail/1`)
  - Call count tracking
- `ExOutlines.Backend.HTTP` - Production HTTP backend
  - OpenAI-compatible endpoint support
  - Uses `:httpc` from Erlang stdlib (zero dependencies)
  - SSL/TLS support with certificate verification
  - Configuration validation
  - Support for temperature, max_tokens, model parameters
  - Comprehensive error handling

#### Testing
- 201 comprehensive tests with 93% code coverage
- 12 doctests across modules
- Mock backend for deterministic testing
- Integration tests for end-to-end workflows
- Edge case coverage (unicode, large responses, zero values)
- No flaky tests, deterministic with seed
- Async test execution

#### Quality
- Zero compilation warnings
- Credo strict mode compliance
- Code formatting with `mix format`
- Dialyzer type checking ready
- GitHub Actions CI/CD pipeline
  - Matrix testing (Elixir 1.16.0 - 1.20.0-rc.1)
  - Coverage reporting with Coveralls
  - Security auditing with mix_audit
  - Code quality checks

#### Documentation
- Comprehensive README with philosophy, examples, and architecture
- Module-level documentation for all public APIs
- Inline documentation with doctests
- Type specifications for all public functions
- Usage examples and integration patterns

### Limitations (v0.1)

- No nested object support (flat fields only)
- No array/list validation
- No custom validator functions
- No streaming support
- Stateless mock backend (no automatic state tracking)

## [Unreleased]

Future enhancements planned for v0.2+:

### Spec Enhancements
- [ ] Nested object schemas
- [ ] Array/list validation with item constraints
- [ ] Custom validator functions
- [ ] Min/max constraints for strings and numbers
- [ ] Pattern matching (regex) for strings
- [ ] Optional Ecto.Changeset integration

### Backend Features
- [ ] Streaming support with token-by-token validation
- [ ] Stateful mock backend (GenServer-based)
- [ ] Anthropic Claude native backend
- [ ] Google PaLM/Gemini backend
- [ ] Local model support (Ollama, llama.cpp)
- [ ] Connection pooling for HTTP backend
- [ ] Request retry with exponential backoff
- [ ] Rate limit handling

### Advanced Features
- [ ] Multi-step generation workflows
- [ ] Conditional field validation
- [ ] Field dependencies ("if X then Y required")
- [ ] Validation middleware/hooks
- [ ] Caching layer for identical schemas
- [ ] Cost tracking and budgeting
- [ ] Token counting and optimization

### Developer Experience
- [ ] ExUnit assertions (`assert_generates/2`)
- [ ] Property-based testing helpers
- [ ] Schema DSL macros
- [ ] Mix task for schema validation
- [ ] LiveView integration examples

### Documentation
- [ ] Cookbook with common patterns
- [ ] Video tutorials
- [ ] Performance tuning guide
- [ ] Migration guide from Python Outlines
- [ ] Architecture decision records

## Release Process

1. Update version in `mix.exs`
2. Update this CHANGELOG with release date
3. Create git tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
4. Push tag: `git push origin v0.1.0`
5. Publish to Hex: `mix hex.publish`
6. Generate docs: `mix docs`
7. Announce release

## Links

- [GitHub Repository](https://github.com/your_org/ex_outlines)
- [Hex.pm Package](https://hex.pm/packages/ex_outlines)
- [Documentation](https://hexdocs.pm/ex_outlines)
- [Issue Tracker](https://github.com/your_org/ex_outlines/issues)
