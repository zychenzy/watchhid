#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate

echo "==> Connected devices (devicectl)"
xcrun devicectl list devices || true

echo
echo "Usage when devices are online:"
echo "  1) Open WatchHID.xcodeproj in Xcode"
echo "  2) Select the development team from Config/Developer.xcconfig (do not put an Apple ID in the repo)"
echo "  3) Destination: the Apple Watch (WatchHID is a watch-only app)"
echo "  4) Run the WatchHIDWatchApp scheme"
echo
echo "Preferred CLI (do not put a UDID in the repo; WATCH_UDID lives in Config/local_devices.env):"
echo "  ./scripts/ship-encrypted-hogp.sh"
echo "  ./scripts/install-signed-watch-app.sh"
echo
echo "The installer has a single readiness gate. Do not run --check-ready immediately before install."
echo "If you sign with a free Personal Team, Apple documents a 7-day provisioning cycle; rebuild and reinstall after expiry. That is not a paid-membership rule."
