#!/usr/bin/env bash
set -euo pipefail

# run_local_cluster.sh — Build and launch the oracle runtime locally.

echo "==> Building oracle executable..."
swift build --product oracle

echo "==> Starting oracle runtime..."
swift run oracle
