#!/usr/bin/env bash
# Build and optionally install the new-Mac HOGP package that requires
# encrypted GATT reads/notifications, so the host must complete HID bonding.
# This does not copy or reuse another Mac's Bluetooth bond. Do not reset
# system Bluetooth or unpair the system Apple Watch.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

INSTALL=0
if [[ "${1:-}" == "--install" ]]; then
  INSTALL=1
elif [[ -n "${1:-}" ]]; then
  echo "Usage: $0 [--install]" >&2
  exit 2
fi

if ! command -v xcodegen >/dev/null; then
  echo "Missing xcodegen. On the signing Mac: brew install xcodegen" >&2
  exit 1
fi

XCCONFIG="$ROOT/Config/Developer.xcconfig"
if [[ ! -f "$XCCONFIG" ]]; then
  echo "Missing $XCCONFIG. Copy Config/Developer.xcconfig.example and set DEVELOPMENT_TEAM." >&2
  exit 1
fi

if ! grep -qE '^DEVELOPMENT_TEAM *= *[A-Z0-9]+' "$XCCONFIG"; then
  echo "Config/Developer.xcconfig has no DEVELOPMENT_TEAM. This machine cannot sign yet." >&2
  exit 1
fi

if ! security find-identity -v -p codesigning 2>/dev/null | grep -q 'Apple Development'; then
  echo "No Apple Development signing identity on this Mac." >&2
  echo "If this Mac is the build machine, open Xcode > Settings > Accounts, sign in with the project Apple ID, then run this script again. The first signed build may show a system or Xcode prompt; confirm it there. Do not send passwords or codes in chat." >&2
  echo "Alternatively, run this script on a Mac that already has the identity, copy the zip, and install it here." >&2
  exit 1
fi

ENV_FILE="$ROOT/Config/local_devices.env"
WATCH_UDID=""
if [[ -f "$ENV_FILE" ]]; then
  WATCH_UDID="$(awk -F= '/^WATCH_UDID=/{print $2; exit}' "$ENV_FILE" | tr -d '[:space:]')"
fi

echo "==> xcodegen"
xcodegen generate

DERIVED="$ROOT/build/DerivedData-encrypted-hogp"
OUT_DIR="$ROOT/build/diagnostics/recovery-root"
mkdir -p "$DERIVED" "$OUT_DIR"
APP="$DERIVED/Build/Products/Debug-watchos/WatchHIDWatchApp.app"
ZIP="$OUT_DIR/WatchHID-encrypted-hogp.zip"

echo "==> signed watchOS build (standard128-encrypted)"
xcodebuild \
  -project WatchHID.xcodeproj \
  -scheme WatchHIDWatchApp \
  -destination 'generic/platform=watchOS' \
  -configuration Debug \
  -derivedDataPath "$DERIVED" \
  -jobs 2 \
  -allowProvisioningUpdates \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) WH_HOGP_ENCRYPTED' \
  build

if [[ ! -d "$APP" ]]; then
  echo "Build finished, but the watch app was not at the expected product path." >&2
  exit 1
fi

codesign --verify --verbose=2 "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> packaged $ZIP"

if [[ "$INSTALL" -eq 1 ]]; then
  if [[ -z "$WATCH_UDID" ]]; then
    echo "Cannot install: set WATCH_UDID in Config/local_devices.env (gitignored)." >&2
    exit 1
  fi
  echo "==> installing encrypted package on the connected Watch"
  xcrun devicectl device install app --device "$WATCH_UDID" "$APP"
  echo "Install finished. Open WatchHID on the Watch, accept a Bluetooth pairing prompt if one appears, keep the screen on, then run: ./scripts/verify-hogp-mouse.sh"
else
  echo "Package is ready. Copy the zip to the Mac that will talk to the Watch, unpack, strip ._* if needed, then:"
  echo "  xcrun devicectl device install app --device \"\$WATCH_UDID\" ./WatchHIDWatchApp.app"
  echo "Open WatchHID, accept a pairing prompt if it appears, then run ./scripts/verify-hogp-mouse.sh on that Mac."
fi
