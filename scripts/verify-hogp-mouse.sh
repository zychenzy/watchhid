#!/usr/bin/env bash
# Check whether this Mac has created the WatchHID system mouse on one IOHID node.
# Does not print Bluetooth addresses or device UDIDs.
# A passing result is same-node identity only; it does not mean pointer movement was verified.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIB="$ROOT/scripts/watchhid_scriptlib.py"
IOREG_TIMEOUT=20

FIXTURE="${WATCHHID_IOREG_FILE:-}"
if [[ -n "$FIXTURE" ]]; then
  exec python3 "$LIB" verify-hid --ioreg "$FIXTURE"
fi

TMP="$(mktemp "${TMPDIR:-/tmp}/watchhid-ioreg.XXXXXX")"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

# Capture raw ioreg XML to $TMP and parse that file later. Do not pipe
# it through a redactor first: placeholders such as "<redacted-id>" are
# themselves XML and will break plistlib (mismatched tag).
ERR="$(mktemp "${TMPDIR:-/tmp}/watchhid-ioreg-err.XXXXXX")"
if ! python3 "$LIB" run-bounded --timeout "$IOREG_TIMEOUT" --stdout "$TMP" -- \
    ioreg -r -c IOHIDDevice -l -a 2>"$ERR"; then
  if [[ -s "$ERR" ]]; then
    python3 "$LIB" redact "$ERR" >&2 || true
  fi
  rm -f "$ERR"
  echo "NO: could not read IOHIDDevice registry (timed out or unavailable)."
  echo "This is not a pointer-movement result. Do not reset Bluetooth."
  exit 1
fi
rm -f "$ERR"

exec python3 "$LIB" verify-hid --ioreg "$TMP"
