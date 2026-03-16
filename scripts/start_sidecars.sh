#!/usr/bin/env bash
# start_sidecars.sh — Launch all sidecar services
set -euo pipefail
cd "$(dirname "$0")/.."

PIDS=()

cleanup() {
    echo "[sidecars] Stopping all sidecars..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait
    echo "[sidecars] All stopped."
}

trap cleanup EXIT INT TERM

echo "[sidecars] Starting sandbox on :8080..."
python3 sidecars/sandbox/server.py &
PIDS+=($!)

echo "[sidecars] Starting codeindex on :8081..."
python3 sidecars/codeindex/index_server.py &
PIDS+=($!)

echo "[sidecars] Starting contextdb on :8082..."
python3 sidecars/contextdb/context_api.py &
PIDS+=($!)

echo "[sidecars] Starting crawler on :8083..."
python3 sidecars/crawler/crawler_server.py &
PIDS+=($!)

echo "[sidecars] Starting metasearch (docker) on :8084..."
if command -v docker &>/dev/null; then
    (cd sidecars/metasearch && docker compose up -d 2>/dev/null) || \
        echo "[sidecars] ⚠ Docker not available — metasearch skipped"
else
    echo "[sidecars] ⚠ Docker not installed — metasearch skipped"
fi

echo ""
echo "[sidecars] All sidecars running. Press Ctrl+C to stop."
wait
