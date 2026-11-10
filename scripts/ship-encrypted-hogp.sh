#!/usr/bin/env bash
# Build and optionally install the new-Mac HOGP package whose Report Map /
# input Report use encrypted reads and (for Report) encrypted notifications,
# so a host that only did a cleartext read may be pushed to complete HID bonding.
# Encrypted HOGP plus the current input-gate (any Report CCCD subscriber)
# has been confirmed on a second Mac: same-node advertised HID identity
# (currently WatchHID / Ultra2-R1) and pointer movement. That identity is
# the current build string, not a required physical Watch model.
# Reconnect reliability and wireless iPhone isolation are still not fully proven.
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

# Fail clearly when xcodegen, Config/Developer.xcconfig, or a usable
# Apple Development identity (certificate + private key) is missing.
"$ROOT/scripts/check-signing-prereqs.sh"

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
if [[ -f "$ZIP" ]]; then
  OLD_SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
  ROLLBACK="$OUT_DIR/WatchHID-encrypted-hogp-${OLD_SHA:0:16}-rollback.zip"
  if [[ ! -f "$ROLLBACK" ]]; then
    cp -p "$ZIP" "$ROLLBACK"
    echo "==> kept the previous zip as a rollback beside this file (WatchHID-encrypted-hogp-<sha-prefix>-rollback.zip)"
  fi
fi
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> packaged encrypted zip under build/diagnostics/recovery-root/ (filename not printed with host paths if you copy this log; the file is WatchHID-encrypted-hogp.zip)"

if [[ "$INSTALL" -eq 1 ]]; then
  echo "==> handing off to install-signed-watch-app.sh (exact UDID, tunnel must be connected)"
  exec "$ROOT/scripts/install-signed-watch-app.sh" "$APP"
else
  echo "Package is ready on this Mac at build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip."
  echo "Install (when the developer tunnel is connected) with:"
  echo "  ./scripts/install-signed-watch-app.sh /path/to/WatchHID-encrypted-hogp.zip"
  echo "The install script unpacks a fresh copy from the zip by default so a stale extract is not used."
  echo "Open WatchHID, accept a pairing prompt if it appears, then run ./scripts/verify-hogp-mouse.sh on that Mac."
  echo "verify-hogp-mouse.sh only checks same-node HID identity; pointer movement is a separate human check."
fi
