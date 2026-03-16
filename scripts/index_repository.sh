#!/usr/bin/env bash
# index_repository.sh — Index a repository into the code index sidecar
set -euo pipefail

REPO_PATH="${1:-.}"
CODEINDEX_URL="${CODEINDEX_URL:-http://127.0.0.1:8081}"

echo "[index] Indexing: $REPO_PATH"
curl -s -X POST "$CODEINDEX_URL/index" \
    -H "Content-Type: application/json" \
    -d "{\"path\": \"$(realpath "$REPO_PATH")\"}" | python3 -m json.tool

echo "[index] Done."
