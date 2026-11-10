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

if ! python3 "$LIB" run-bounded --timeout "$IOREG_TIMEOUT" -- \
    ioreg -r -c IOHIDDevice -l -a >"$TMP" 2>/tmp/watchhid-ioreg-err.$$; then
  if [[ -s /tmp/watchhid-ioreg-err.$$ ]]; then
    python3 "$LIB" redact /tmp/watchhid-ioreg-err.$$ >&2 || true
  fi
  rm -f /tmp/watchhid-ioreg-err.$$
  echo "NO: could not read IOHIDDevice registry (timed out or unavailable)."
  echo "This is not a pointer-movement result. Do not reset Bluetooth."
  exit 1
fi
rm -f /tmp/watchhid-ioreg-err.$$

exec python3 "$LIB" verify-hid --ioreg "$TMP"
