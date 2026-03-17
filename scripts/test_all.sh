#!/bin/bash
set -e
echo "[Test Runner] Starting full test suite for engineering-hardening branch..."
# Use swift test directly, excluding the .build and Vendor folders
swift test --parallel
echo "[Test Runner] All tests passed."
