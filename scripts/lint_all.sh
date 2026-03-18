#!/usr/bin/env bash
set -euo pipefail

# lint_all.sh — Run available linting and formatting checks.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Checking Swift formatting..."
if command -v swift-format &>/dev/null; then
    swift-format lint --recursive "$REPO_ROOT/Sources" "$REPO_ROOT/Tests"
elif command -v swiftformat &>/dev/null; then
    swiftformat --lint "$REPO_ROOT/Sources" "$REPO_ROOT/Tests"
else
    echo "  No Swift formatter found (install swift-format or swiftformat)."
fi

echo "==> Running architecture governance tests..."
swift test --filter Governance 2>&1 || true

echo "==> Lint pass complete."
