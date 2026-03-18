#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — Resolve dependencies and verify the build.
# Run once after cloning or when Package.swift changes.

echo "==> Resolving Swift package dependencies..."
swift package resolve

echo "==> Building all targets..."
swift build

echo "==> Running tests..."
if swift test; then
    echo "  All tests passed."
else
    echo "  WARNING: Some tests failed. Review output above."
fi

echo "==> Bootstrap complete."
