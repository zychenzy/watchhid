#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> xcodegen"
xcodegen generate

DERIVED="${ROOT}/build/DerivedData"
mkdir -p "$DERIVED"

common=(
  -project WatchHID.xcodeproj
  -derivedDataPath "$DERIVED"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGN_IDENTITY=""
  CODE_SIGNING_REQUIRED=NO
  DEVELOPMENT_TEAM=""
)

echo "==> build iOS Simulator (generic)"
xcodebuild \
  "${common[@]}" \
  -scheme WatchHID \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  build

echo "==> build watchOS Simulator (generic)"
xcodebuild \
  "${common[@]}" \
  -scheme WatchHIDWatchApp \
  -destination 'generic/platform=watchOS Simulator' \
  -configuration Debug \
  build

echo "==> OK: simulator/generic builds succeeded"
