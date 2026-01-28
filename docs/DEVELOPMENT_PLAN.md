# ExOutlines v0.2 Development Plan

Based on gap analysis with Python Outlines (dottxt-ai/outlines).

## Overview

This plan implements high-priority features to close the gap with Python Outlines. The plan consists of 15 development steps, each with a clear scope, branch name, rationale, and detailed LLM prompt.

**Current State:** v0.1.0 - 201 tests, 93% coverage, flat schemas only
**Target State:** v0.2.0 - Nested objects, arrays, string/integer constraints, 5+ examples

**Estimated Timeline:** 3-6 months (15 steps × 1-2 weeks each)

---

## Development Steps

### Step 1: String Length Constraints ✅

**Title:** Add min_length and max_length constraints for string fields

**Branch:** `feature/string-length-constraints`

**Status:** COMPLETED

**Rationale:**
Python Outlines supports string length constraints, which are critical for real-world validation (e.g., usernames 3-20 chars, descriptions max 500 chars). This is a foundational feature that's simpler than nested objects and provides immediate value.

**Dependencies:** None (extends existing string validation)

**Implementation Details:**
- Extended field_spec type with min_length and max_length
- Updated validation logic with String.length/1 for proper unicode handling
- JSON Schema generation includes minLength/maxLength
- 10+ comprehensive tests covering edge cases
- All 211 tests passing

---

### Step 2: Integer Min/Max Constraints

**Title:** Add min and max constraints for integer and number fields

**Branch:** `feature/integer-number-constraints`

**Status:** IN PROGRESS

**Rationale:**
Currently only "positive" constraint exists for integers. Min/max ranges are essential for real validation (age 0-120, quantity 1-999, temperature -273.15+). Complements Step 1 for numeric types.

**Dependencies:** None (extends existing integer validation)

**Key Features:**
- Add min/max constraints for both :integer and :number types
- Backward compatibility: positive: true equivalent to min: 1
- JSON Schema generation with minimum/maximum
- Clear error messages for range violations

---

### Step 3: Array/List Validation

**Title:** Add array type with item schema validation

**Branch:** `feature/array-validation`

**Rationale:**
Arrays are a critical missing feature (Python Outlines has full support). Enables validation of lists like tags, categories, items. Foundational for complex schemas.

**Dependencies:** Steps 1-2 (string/integer constraints will be used in array items)

**Key Features:**
- New field type: {:array, item_spec}
- Array constraints: min_items, max_items, unique_items
- Item validation with all existing constraints
- Error messages with item indices
- JSON Schema "items" generation

---

### Step 4: Nested Object Support

**Title:** Add nested object schemas with recursive validation

**Branch:** `feature/nested-objects`

**Rationale:**
Nested objects are the most requested feature (Python Outlines has full support). Enables real-world schemas like User with Address. Critical for v0.2.

**Dependencies:** Steps 1-3 (nested objects can contain arrays, constrained strings, etc.)

**Key Features:**
- New field type: {:object, Schema.t()}
- Recursive validation with path tracking
- Error message path prefixing (e.g., "address.city")
- Key conversion for nested maps
- Support for multiple nesting levels

---

### Step 5: Regular Expression Support

**Title:** Add regex pattern matching for string fields

**Branch:** `feature/regex-patterns`

**Rationale:**
Regex is critical for formatted strings (email, phone, URL, UUID). Python Outlines has full support. Enables validation of common patterns.

**Dependencies:** Step 1 (builds on string constraints)

**Key Features:**
- Pattern field for custom Regex
- Built-in formats: :email, :url, :uuid, :phone, :date
- String pattern compilation
- JSON Schema "pattern" and "format" generation
- Combine pattern with length constraints

---

### Step 6: Union Types

**Title:** Add union type support for fields that accept multiple types

**Branch:** `feature/union-types`

**Rationale:**
Union types enable flexible schemas that can handle incomplete or varied data (e.g., `age: integer | null`, `id: string | integer`). Python Outlines supports this extensively. Critical for real-world APIs with optional or polymorphic fields.

**Dependencies:** Steps 1-5 (union types can include any validated type)

**Key Features:**
- New field type: {:union, [field_spec()]}
- Special :null type for nullable fields
- Try-all-types validation logic
- JSON Schema "oneOf" generation
- Combined error messages listing all failures

---

### Step 7: Production Example - E-commerce Categorization

**Title:** Add real-world e-commerce product categorization example

**Branch:** `example/ecommerce-categorization`

**Rationale:**
Python Outlines has 13+ production examples. This matches one of their key examples and demonstrates nested objects, arrays, and enums in a realistic scenario.

**Dependencies:** Steps 1-6 (uses all features)

**Deliverables:**
- examples/ecommerce_categorization.exs
- Product schema with category, features, tags
- 3+ example product descriptions
- Expected outputs
- Integration guidance

---

### Step 8: Production Example - Customer Support Triage

**Title:** Add customer support ticket triage and routing example

**Branch:** `example/customer-support-triage`

**Rationale:**
Another key Python Outlines example. Demonstrates enums for priority, nested objects for ticket metadata, and real-world urgency detection.

**Dependencies:** Steps 1-6

**Deliverables:**
- examples/customer_support_triage.exs
- Ticket schema with priority, category, urgency
- 4+ example tickets
- Phoenix integration patterns

---

### Step 9: Production Example - Document Metadata Extraction

**Title:** Add document metadata extraction example

**Branch:** `example/document-metadata-extraction`

**Rationale:**
Demonstrates format validation (dates, URLs), nested author objects, arrays of keywords. Common use case for content management systems.

**Dependencies:** Steps 1-6

**Deliverables:**
- examples/document_metadata_extraction.exs
- Document schema with authors, keywords, metadata
- 3+ document examples
- Date/URL validation demonstrations

---

### Step 10: Livebook Notebook - Getting Started

**Title:** Create interactive getting started Livebook tutorial

**Branch:** `docs/livebook-getting-started`

**Rationale:**
Python Outlines has 2+ Jupyter notebooks. Livebook is Elixir's equivalent. Interactive tutorials significantly improve onboarding.

**Dependencies:** Steps 1-6 (demonstrates features)

**Deliverables:**
- livebooks/getting_started.livemd
- Progressive tutorial from basics to intermediate
- 10-15 executable code cells
- Mermaid diagrams for retry-repair loop
- Exercises and working examples

---

### Step 11: Livebook Notebook - Advanced Patterns

**Title:** Create advanced patterns Livebook for complex schemas

**Branch:** `docs/livebook-advanced-patterns`

**Rationale:**
Second Livebook notebook for users who completed getting started. Covers nested objects, arrays, union types, error handling strategies.

**Dependencies:** Steps 1-6 + Step 10

**Deliverables:**
- livebooks/advanced_patterns.livemd
- 15-20 code cells
- Complex working examples
- Production-ready patterns
- Performance tips

---

### Step 12: Anthropic Claude Backend

**Title:** Add native Anthropic Claude API backend

**Branch:** `feature/anthropic-backend`

**Rationale:**
Current HTTP backend works with OpenAI-compatible endpoints. Native Anthropic support enables direct Claude API usage without proxies. Anthropic has excellent structured output capabilities.

**Dependencies:** None (new backend)

**Key Features:**
- Native Anthropic Messages API support
- Separate system message handling
- Configuration: api_key, model, max_tokens, temperature
- Error handling for rate limits
- Integration with ExOutlines.generate/2

---

### Step 13: Batch Processing

**Title:** Add concurrent batch processing for multiple prompts

**Branch:** `feature/batch-processing`

**Rationale:**
BEAM/OTP concurrency is a key advantage. Batch processing enables efficient handling of multiple generation requests concurrently. Python Outlines supports this.

**Dependencies:** None (core feature)

**Key Features:**
- New function: ExOutlines.generate_batch/2
- Task.async_stream for concurrency
- Batch options: max_concurrency, timeout, ordered
- Telemetry events for monitoring
- Error aggregation

---

### Step 14: Tutorial Content - How-To Guides

**Title:** Create 3+ how-to guides for common patterns

**Branch:** `docs/how-to-guides`

**Rationale:**
Python Outlines has 6+ how-to guides. Close documentation gap with practical guides for Phoenix integration, testing, error handling.

**Dependencies:** Steps 1-13 (references features)

**Deliverables:**
1. guides/phoenix_integration.md - Using ExOutlines in Phoenix/LiveView
2. guides/testing_strategies.md - Testing with Mock backend, property-based testing
3. guides/error_handling.md - Diagnostics, retry strategies, monitoring
4. guides/performance_optimization.md - Optimization patterns (optional)
5. guides/README.md - Index of all guides

---

### Step 15: Performance Benchmarks

**Title:** Add performance benchmark suite with Benchee

**Branch:** `feature/benchmark-suite`

**Rationale:**
Measure and track performance. Python Outlines has benchmark infrastructure. Important for optimization and regression detection.

**Dependencies:** Steps 1-13 (benchmarks all features)

**Deliverables:**
- benchmarks/schema_validation.exs - Validation speed across complexity
- benchmarks/generation_loop.exs - Retry/repair overhead
- benchmarks/batch_processing.exs - Concurrency speedup
- benchmarks/README.md - How to run and interpret
- HTML output with visualizations

---

## Implementation Order Rationale

1. **Steps 1-2:** Foundation (string/integer constraints) - Simplest, high value
2. **Step 3:** Arrays - Builds on 1-2, enables real schemas
3. **Step 4:** Nested objects - Most complex, depends on 1-3
4. **Step 5:** Regex - Independent, high value for validation
5. **Step 6:** Union types - Advanced feature, uses 1-5
6. **Steps 7-9:** Examples - Showcase features, provide templates
7. **Steps 10-11:** Livebooks - Interactive learning, community building
8. **Steps 12-13:** Backend/Batch - Infrastructure improvements
9. **Steps 14-15:** Docs/Perf - Polish and optimization

---

## Testing Strategy

Each step must:
1. Add 10-20 new tests
2. Maintain 90%+ coverage
3. Pass all existing tests
4. Zero Credo warnings
5. Format with `mix format`

---

## Branch Naming Convention

- `feature/` - New features (Steps 1-6, 12-13, 15)
- `example/` - Production examples (Steps 7-9)
- `docs/` - Documentation (Steps 10-11, 14)

---

## Success Criteria (v0.2.0)

After completing Steps 1-15:
- ✅ Nested object support
- ✅ Array validation with constraints
- ✅ String length + regex patterns
- ✅ Integer/number min/max
- ✅ Union types
- ✅ 5+ production examples
- ✅ 2+ Livebook notebooks
- ✅ Native Anthropic backend
- ✅ Batch processing
- ✅ 300+ tests (currently 201)
- ✅ 3+ how-to guides
- ✅ Performance benchmarks

**Gap Reduction:** From 44/100 to ~70/100 (26 point improvement)

---

## Critical Files

All steps modify:
- `lib/ex_outlines/spec/schema.ex` (core validation)
- `test/ex_outlines/spec/schema_test.exs` (tests)

Some steps add:
- `lib/ex_outlines/backend/*.ex` (new backends)
- `examples/*.exs` (production examples)
- `livebooks/*.livemd` (interactive tutorials)

---

## Risk Mitigation

**Technical Risks:**
1. Nested objects complexity → Start simple, one level first
2. Regex performance → Compile patterns once, benchmark
3. Union type ambiguity → Clear error messages, try all types
4. Breaking changes → Maintain backward compatibility

**Schedule Risks:**
1. Features take longer than estimated → Prioritize Steps 1-4, defer others
2. Test coverage drops → Require tests in PR before merge
3. Credo warnings accumulate → Run checks in CI

---

## Next Steps After v0.2

**v0.3.0 Targets (from gap analysis):**
- Prompt template system (EEx)
- Streaming support
- Caching layer
- Tutorial content expansion
- Community Discord
- Blog launch

**v0.4.0+ (Long-term):**
- Context-free grammars
- Local model support (Bumblebee)
- Function calling DSL
- LiveView integration examples

---

## Progress Tracking

| Step | Status | Tests | Notes |
|------|--------|-------|-------|
| 1. String Length | ✅ Complete | 211 | min_length, max_length working |
| 2. Integer Min/Max | ✅ Complete | 229 | min/max for integers and numbers |
| 3. Array Validation | ✅ Complete | 249 | Arrays with item validation |
| 4. Nested Objects | ✅ Complete | 262 | Recursive validation with paths |
| 5. Regex Patterns | ✅ Complete | 211 | Pattern and format validation |
| 6. Union Types | ✅ Complete | 223 | Union and null type support |
| 7. E-commerce Example | ✅ Complete | 223 | Product categorization example |
| 8. Support Triage Example | ✅ Complete | 223 | Ticket triage and routing |
| 9. Document Extraction Example | ✅ Complete | 223 | Bibliographic metadata extraction |
| 10. Getting Started Livebook | ✅ Complete | 223 | Interactive tutorial notebook |
| 11. Advanced Patterns Livebook | ✅ Complete | 223 | Advanced features notebook |
| 12. Anthropic Backend | ✅ Complete | 243 | Native Anthropic Claude API backend |
| 13. Batch Processing | ⏳ Pending | - | - |
| 14. How-To Guides | ⏳ Pending | - | - |
| 15. Benchmarks | ⏳ Pending | - | - |

---

**Last Updated:** 2026-01-28
