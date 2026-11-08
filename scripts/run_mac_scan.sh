#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Requires Bluetooth permission for Terminal/iTerm when first run.
swift "$ROOT/scripts/scan_mac.swift" "$@"
