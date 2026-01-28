#!/bin/bash

# Run all ExOutlines benchmarks
# Usage: ./benchmarks/run_all.sh

set -e

echo "========================================="
echo "ExOutlines Performance Benchmark Suite"
echo "========================================="
echo ""

# Check if benchmarks directory exists
if [ ! -d "benchmarks" ]; then
  echo "Error: Must be run from project root"
  exit 1
fi

# Create output directory
mkdir -p benchmarks/output

echo "Running benchmarks..."
echo ""

# Schema Validation
echo "→ Running schema_validation.exs..."
mix run benchmarks/schema_validation.exs
echo ""

# Generation Loop
echo "→ Running generation_loop.exs..."
mix run benchmarks/generation_loop.exs
echo ""

# Batch Processing
echo "→ Running batch_processing.exs..."
mix run benchmarks/batch_processing.exs
echo ""

echo "========================================="
echo "✓ All benchmarks complete!"
echo "========================================="
echo ""
echo "HTML reports available in:"
echo "  - benchmarks/output/schema_validation.html"
echo "  - benchmarks/output/generation_loop.html"
echo "  - benchmarks/output/batch_processing.html"
echo ""
