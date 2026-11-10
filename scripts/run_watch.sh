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
echo "  2) Select team <DEVELOPMENT_TEAM from Config/Developer.xcconfig> (Apple Development: <your Apple ID>) on both targets if needed"
echo "  3) Destination: the Apple Watch (WatchHID is a watch-only app)"
echo "  4) Run the WatchHIDWatchApp scheme. Do not install from the iOS WatchHID scheme;"
echo "     that target is an optional BLE diagnostic tool and does not embed the Watch app."
echo
echo "CLI sketch (fill the Watch UDID from devicectl; do not put a UDID in the repo):"
echo "  ./scripts/ship-encrypted-hogp.sh"
echo "  ./scripts/install-signed-watch-app.sh --check-ready"
echo "  ./scripts/install-signed-watch-app.sh"
echo
echo "Free Apple ID: resign roughly every 7 days in Xcode."
