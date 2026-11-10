#!/usr/bin/env bash
# Build and optionally install the new-Mac HOGP package whose Report Map /
# input Report use encrypted reads and (for Report) encrypted notifications,
# so a host that only did a cleartext read may be pushed to complete HID bonding.
# This is a build candidate, not a proven first-bond or fast-success path.
# This does not copy or reuse another Mac's Bluetooth bond. Do not reset
# system Bluetooth or unpair the system Apple Watch.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LIB="$ROOT/scripts/watchhid_scriptlib.py"
BUILD_TIMEOUT=1800

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

echo "==> xcodegen"
xcodegen generate

DERIVED="$ROOT/build/DerivedData-encrypted-hogp"
OUT_DIR="$ROOT/build/diagnostics/recovery-root"
mkdir -p "$DERIVED" "$OUT_DIR"
APP="$DERIVED/Build/Products/Debug-watchos/WatchHIDWatchApp.app"
ZIP="$OUT_DIR/WatchHID-encrypted-hogp.zip"

echo "==> signed watchOS build (standard128-encrypted)"
if ! python3 "$LIB" run-bounded --timeout "$BUILD_TIMEOUT" -- \
    xcodebuild \
      -project WatchHID.xcodeproj \
      -scheme WatchHIDWatchApp \
      -destination 'generic/platform=watchOS' \
      -configuration Debug \
      -derivedDataPath "$DERIVED" \
      -jobs 2 \
      -allowProvisioningUpdates \
      SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) WH_HOGP_ENCRYPTED' \
      build; then
  echo "xcodebuild failed or timed out after ${BUILD_TIMEOUT}s." >&2
  exit 1
fi

if [[ ! -d "$APP" ]]; then
  echo "Build finished, but the watch app was not at the expected product path." >&2
  exit 1
fi

if ! python3 "$LIB" run-bounded --timeout 30 -- codesign --verify --verbose=2 "$APP"; then
  echo "codesign verification failed or timed out." >&2
  exit 1
fi
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> packaged encrypted zip under build/diagnostics/recovery-root/ (filename not printed with host paths if you copy this log; the file is WatchHID-encrypted-hogp.zip)"

if [[ "$INSTALL" -eq 1 ]]; then
  echo "==> handing off to install-signed-watch-app.sh (exact UDID, tunnel must be connected)"
  exec "$ROOT/scripts/install-signed-watch-app.sh" "$APP"
else
  echo "Package is ready. Copy WatchHID-encrypted-hogp.zip to the Mac that will talk to the Watch, then:"
  echo "  ./scripts/install-signed-watch-app.sh /path/to/WatchHID-encrypted-hogp.zip"
  echo "The install script unpacks a fresh copy from the zip by default so a stale extract is not used."
  echo "Open WatchHID, accept a pairing prompt if it appears, then run ./scripts/verify-hogp-mouse.sh on that Mac."
  echo "verify-hogp-mouse.sh only checks same-node HID identity; pointer movement is a separate human check."
fi
