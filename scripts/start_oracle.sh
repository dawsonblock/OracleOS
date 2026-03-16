#!/usr/bin/env bash
# start_oracle.sh — Build and launch the Oracle runtime
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Oracle-OS Build ==="
swift build 2>&1

echo ""
echo "=== Oracle-OS Launch ==="
.build/debug/oracle "$@"
