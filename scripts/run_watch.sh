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
echo "  3) Destination: the paired iPhone and Apple Watch"
echo "  4) Run the WatchHID scheme (embeds watch app)"
echo
echo "CLI sketch (fill UDIDs from devicectl):"
echo "  xcodebuild -project WatchHID.xcodeproj -scheme WatchHID \\"
echo "    -destination 'platform=iOS,id=<IPHONE_UDID>' \\"
echo "    -allowProvisioningUpdates build"
echo "  xcrun devicectl device install app --device <IPHONE_UDID> <path-to-WatchHID.app>"
echo
echo "Free Apple ID: resign roughly every 7 days in Xcode."
