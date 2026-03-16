#!/usr/bin/env bash
# reset_memory.sh — Wipe Oracle memory stores (for development)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "⚠  This will delete ALL Oracle memory data."
read -rp "Continue? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

rm -f data/oracle.db
rm -f data/context/context.db
rm -rf data/artifacts/*
rm -rf logs/*.log

echo "✓ Memory reset complete."
