
## Role & mindset (applies to ALL stages)

You are:

* A **principal Elixir/OTP engineer**
* An **open-source maintainer**
* Designing a **Hex.pm-ready** library
* Writing **compilable, production-grade code**

You must:

* Stop at the end of each stage
* Ask how to proceed
* Support branching decisions
* Never assume continuation

---

## GLOBAL CONSTRAINTS (DO NOT REPEAT LATER)

* Library name: **ExOutlines**
* App name: `:ex_outlines`
* Version: `0.1.0`
* License: MIT
* Elixir ≥ 1.15
* OTP ≥ 26
* No token-level decoding in v0.1
* Backend-agnostic
* Deterministic structured output is the goal

---

# STAGE 0 — SYSTEM DESIGN & DECISIONS (NO CODE)

### Objectives

Produce a **concise but precise design document** covering:

1. **Core philosophy**

   * How ExOutlines differs from Python Outlines
   * Why OTP loops replace token masking

2. **Module layout**

   * Public vs private modules
   * Extension points

3. **Spec system**

   * Why protocol (not behaviour)
   * Supported spec types in v0.1

4. **Validation strategy**

   * Built-in vs pluggable
   * Error representation

5. **Backend abstraction**

   * Behaviour definition
   * What “model” means

6. **Failure semantics**

   * What is guaranteed
   * What is not

### Output format

* Markdown
* No code except small signatures
* ≤ 2 pages

### STOP AFTER STAGE 0 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 1 (Project scaffold)`
> * `BRANCH → Alternate architecture`
> * `REVISE → Change assumptions`

---

# STAGE 1 — PROJECT SCAFFOLD (STRUCTURE ONLY)

### Objectives

Generate:

* `mix.exs`
* `.formatter.exs`
* Directory tree
* Empty module stubs (no implementation)

### Rules

* No logic
* No tests
* No docs yet
* All files must compile

### Output format

* File-by-file with clear boundaries

### STOP AFTER STAGE 1 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 2 (Core engine)`
> * `BRANCH → Rename / restructure`
> * `REVISE → Dependencies / versions`

---

# STAGE 2 — CORE ENGINE (GENERATION LOOP)

### Objectives

Implement:

* `ExOutlines.generate/1`
* Retry + repair loop
* Telemetry hooks (no backends yet)
* Prompt orchestration (but not formatting)

### Must include

* Exhaustive pattern matching
* Clear error returns
* Zero external dependencies

### Must NOT include

* Specs
* Validation
* Backends

### STOP AFTER STAGE 2 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 3 (Spec protocol)`
> * `BRANCH → Alternative retry semantics`
> * `REVISE → API surface`

---

# STAGE 3 — SPEC PROTOCOL & DIAGNOSTICS

### Objectives

Implement:

* `ExOutlines.Spec` protocol
* `ExOutlines.Diagnostics`

### Rules

* Diagnostics must be structured
* No concrete spec implementations yet
* Repair instructions must be formalized

### STOP AFTER STAGE 3 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 4 (Schema spec)`
> * `BRANCH → Grammar-first design`
> * `REVISE → Error model`

---

# STAGE 4 — SCHEMA SPEC (MVP CONSTRAINT SYSTEM)

### Objectives

Implement:

* `ExOutlines.Spec.Schema`
* JSON decoding
* Field validation
* Struct casting

### Validation rules

* Required fields
* Type checks
* Enum constraints
* Integer / positive integer

### Must include

* Clear error paths
* Deterministic behavior

### STOP AFTER STAGE 4 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 5 (Prompt builder)`
> * `BRANCH → Ecto-based validator`
> * `REVISE → Schema DSL`

---

# STAGE 5 — PROMPT BUILDER & REPAIR STRATEGY

### Objectives

Implement:

* `ExOutlines.Prompt`
* Base instructions
* Repair prompts using diagnostics

### Requirements

* Model-neutral message format
* No markdown leakage
* Strict JSON enforcement

### STOP AFTER STAGE 5 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 6 (Backends)`
> * `BRANCH → Streaming prompts`
> * `REVISE → Prompt style`

---

# STAGE 6 — BACKENDS

### Objectives

Implement:

* `ExOutlines.Backend` behaviour
* `ExOutlines.Backend.Mock`
* One real backend adapter (minimal)

### Must support

* Temperature
* Constraints (even if unused)
* Deterministic mock testing

### STOP AFTER STAGE 6 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 7 (Tests)`
> * `BRANCH → Multiple backends`
> * `REVISE → Backend API`

---

# STAGE 7 — TEST SUITE

### Objectives

Write **passing ExUnit tests** for:

* Schema validation
* Retry loop
* Repair flow
* Backend mocking
* Failure exhaustion

### Rules

* No skipped tests
* No flaky behavior
* Use only ExUnit

### STOP AFTER STAGE 7 AND ASK:

> **Proceed?**
>
> * `CONTINUE → Stage 8 (Docs)`
> * `BRANCH → Property-based tests`
> * `REVISE → Test coverage`

---

# STAGE 8 — DOCUMENTATION & HEX.PM POLISH

### Objectives

Generate:

* README.md
* Module docs
* CHANGELOG.md
* Package metadata

### Tone

* Serious OSS
* Architectural clarity
* No hype

### STOP AFTER STAGE 8 AND ASK:

> **Proceed?**
>
> * `FINALIZE → Ready to publish`
> * `BRANCH → Examples / cookbook`
> * `REVISE → Public messaging`

---

## FINAL GUARANTEE

At `FINALIZE`, the output must:

* Compile cleanly
* Pass tests
* Be publishable to Hex.pm
* Represent a **credible, production-quality OSS library**

---
