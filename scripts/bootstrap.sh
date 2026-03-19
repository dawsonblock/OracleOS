#!/usr/bin/env bash
set -e

if ! command -v swift >/dev/null 2>&1; then
  echo "swift is required but not installed or not on PATH" >&2
  exit 1
fi

swift build
swift test
