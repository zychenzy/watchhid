#!/usr/bin/env bash
# Install a signed WatchHID watch app and launch it on the paired Watch.
# The CoreDevice developer tunnel is not the same as Bluetooth HID.
# Do not reset system Bluetooth or unpair the system Apple Watch.
# Never print a device UDID, Bluetooth address, or provisioned-device list.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
LIB="$ROOT/scripts/watchhid_scriptlib.py"
LIST_TIMEOUT=30
INSTALL_TIMEOUT=180
LAUNCH_TIMEOUT=60
CODESIGN_TIMEOUT=30

usage() {
  echo "Usage: $0 [--check-ready] [WatchHIDWatchApp.app|signed.zip]" >&2
  echo "If no path is given, prefers build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip" >&2
  echo "over a previously extracted encrypted-hogp/WatchHIDWatchApp.app, so a stale extract cannot win." >&2
  echo "--check-ready lists the exact Watch, then probes details/DDI without installing." >&2
  exit 2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

CHECK_READY=0
if [[ "${1:-}" == "--check-ready" ]]; then
  CHECK_READY=1
  shift
fi

SRC="${1:-}"
DEFAULT_APP="${WATCHHID_DEFAULT_APP:-$ROOT/build/diagnostics/recovery-root/encrypted-hogp/WatchHIDWatchApp.app}"
DEFAULT_ZIP="${WATCHHID_DEFAULT_ZIP:-$ROOT/build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip}"
if [[ -z "$SRC" && "$CHECK_READY" -eq 0 ]]; then
  SRC="$(python3 "$LIB" choose-default-package "$DEFAULT_APP" "$DEFAULT_ZIP" || true)"
  if [[ -z "$SRC" ]]; then
    echo "No package path given, and no default encrypted package was found." >&2
    usage
  fi
fi

ENV_FILE="${WATCHHID_ENV_FILE:-$ROOT/Config/local_devices.env}"
WATCH_UDID="${WATCH_UDID:-}"
if [[ -z "$WATCH_UDID" && -f "$ENV_FILE" ]]; then
  WATCH_UDID="$(awk -F= '/^WATCH_UDID=/{print $2; exit}' "$ENV_FILE" | tr -d '[:space:]')"
fi
if [[ -z "$WATCH_UDID" ]]; then
  echo "Set WATCH_UDID in Config/local_devices.env (gitignored). Do not put a UDID in the repo or in chat." >&2
  exit 1
fi

print_tunnel_help() {
  cat <<'EOF'
The Watch developer tunnel is not available. A Bluetooth-connected Apple Watch is not the same thing. Do not reset Bluetooth or unpair the Watch to fix this.

Do all of the following, then run this script again:
1. Bring the Watch close to this Mac, wake and unlock it, and keep the screen on.
2. Bring the paired iPhone close, unlock it, and join the same Wi-Fi if you can. A USB cable is not required. A wireless install can succeed while the iPhone is nearby, unlocked, and on the same Wi-Fi; that does not mean the iPhone is always required, and it does not prove install still works when no iPhone is nearby.
3. Wait until devicectl lists this Watch as connected, not only available (paired) or unavailable. The script matches the exact WATCH_UDID in Config/local_devices.env and will not install onto a different Watch.
EOF
}


print_services_help() {
  cat <<'EOF'
The developer tunnel was listed as connected, but CoreDevice details or DDI services were not usable. This is the same class of failure as "Failed to allocate RSD device": the list state is not a sufficient install gate. Do not reset Bluetooth or unpair the Watch.

Keep the Watch close, awake, unlocked, and screen-on, then run this script again. Optional: ./scripts/install-signed-watch-app.sh --check-ready
EOF
}

probe_developer_services() {
  DETAILS_JSON="$(mktemp "${TMPDIR:-/tmp}/watchhid-details.XXXXXX")"
  DDI_JSON="$(mktemp "${TMPDIR:-/tmp}/watchhid-ddi.XXXXXX")"
  if ! python3 "$LIB" run-bounded --timeout 20 --       xcrun devicectl device info details         --device "$WATCH_UDID"         --timeout 20         --json-output "$DETAILS_JSON" >/dev/null; then
    echo "Watch developer details probe failed or timed out." >&2
    print_services_help
    return 2
  fi
  if ! python3 "$LIB" run-bounded --timeout 20 --       xcrun devicectl device info ddiServices         --device "$WATCH_UDID"         --timeout 20         --json-output "$DDI_JSON" >/dev/null; then
    echo "Watch DDI services probe failed or timed out." >&2
    print_services_help
    return 2
  fi
  local reason
  if ! reason="$(python3 "$LIB" services-ready "$DETAILS_JSON" "$DDI_JSON")"; then
    echo "Watch developer services are not ready ($reason). A connected tunnel list entry is not enough." >&2
    print_services_help
    return 2
  fi
  echo "Watch developer services: ready"
  return 0
}

LIST_JSON="$(mktemp "${TMPDIR:-/tmp}/watchhid-devicelist.XXXXXX")"
cleanup() {
  rm -f "$LIST_JSON"
  if [[ -n "${INSTALL_JSON:-}" && -f "${INSTALL_JSON:-}" ]]; then
    rm -f "$INSTALL_JSON"
  fi
  if [[ -n "${LAUNCH_JSON:-}" && -f "${LAUNCH_JSON:-}" ]]; then
    rm -f "$LAUNCH_JSON"
  fi
  if [[ -n "${DETAILS_JSON:-}" && -f "${DETAILS_JSON:-}" ]]; then
    rm -f "$DETAILS_JSON"
  fi
  if [[ -n "${DDI_JSON:-}" && -f "${DDI_JSON:-}" ]]; then
    rm -f "$DDI_JSON"
  fi
  if [[ -n "${WORKDIR:-}" && -d "${WORKDIR:-}" ]]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

if [[ -n "${WATCHHID_DEVICELIST_JSON:-}" ]]; then
  cp "$WATCHHID_DEVICELIST_JSON" "$LIST_JSON"
else
  if ! python3 "$LIB" run-bounded --timeout "$LIST_TIMEOUT" -- \
      xcrun devicectl list devices --timeout "$LIST_TIMEOUT" --json-output "$LIST_JSON" >/dev/null; then
    echo "devicectl could not list devices, or the command timed out." >&2
    print_tunnel_help
    exit 2
  fi
fi

STATE="$(WATCH_UDID="$WATCH_UDID" python3 "$LIB" watch-state "$LIST_JSON")"

echo "Watch developer state: $STATE"
case "$STATE" in
  connected)
    ;;
  missing)
    echo "devicectl did not list this Watch (exact UDID only; no fallback to another Watch)." >&2
    print_tunnel_help
    exit 2
    ;;
  *)
    print_tunnel_help
    exit 2
    ;;
esac

if [[ "$CHECK_READY" -eq 1 ]]; then
  probe_developer_services
  exit $?
fi

APP=""
WORKDIR=""
if [[ -d "$SRC" ]]; then
  APP="$SRC"
elif [[ -f "$SRC" ]]; then
  WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/watchhid-install.XXXXXX")"
  if command -v ditto >/dev/null 2>&1; then
    ditto -x -k "$SRC" "$WORKDIR"
  else
    WATCHHID_ZIP_SRC="$SRC" WATCHHID_ZIP_DST="$WORKDIR" python3 - <<'PY'
import os, zipfile
zipfile.ZipFile(os.environ["WATCHHID_ZIP_SRC"]).extractall(os.environ["WATCHHID_ZIP_DST"])
PY
  fi
  find "$WORKDIR" -name '._*' -delete
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$WORKDIR" 2>/dev/null || true
  fi
  APPS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && APPS+=("$line")
  done <<EOF
$(find "$WORKDIR" -name 'WatchHIDWatchApp.app' -type d)
EOF
  if [[ "${#APPS[@]}" -eq 0 ]]; then
    echo "The archive did not contain WatchHIDWatchApp.app." >&2
    exit 1
  fi
  if [[ "${#APPS[@]}" -gt 1 ]]; then
    echo "The archive contained more than one WatchHIDWatchApp.app; refusing to guess." >&2
    exit 1
  fi
  APP="${APPS[0]}"
else
  echo "Not a .app directory or zip: $SRC" >&2
  exit 1
fi

if [[ "${WATCHHID_DRY_RUN:-}" == "1" ]]; then
  echo "DRY_RUN: would verify signature, probe developer services, install, and launch WatchHID. Package is ready and the exact UDID is connected."
  exit 0
fi

if [[ "${WATCHHID_SKIP_SERVICES_READY:-}" != "1" ]]; then
  probe_developer_services || exit $?
fi

if ! python3 "$LIB" run-bounded --timeout "$CODESIGN_TIMEOUT" -- \
    codesign --verify --verbose=2 "$APP"; then
  echo "codesign verification failed or timed out." >&2
  exit 1
fi

INSTALL_JSON="$(mktemp "${TMPDIR:-/tmp}/watchhid-install-json.XXXXXX")"
echo "==> installing signed package"
if ! python3 "$LIB" run-bounded --timeout "$INSTALL_TIMEOUT" -- \
    xcrun devicectl device install app \
      --device "$WATCH_UDID" \
      --timeout "$INSTALL_TIMEOUT" \
      --json-output "$INSTALL_JSON" \
      --quiet \
      "$APP"; then
  echo "Install failed or timed out. Output above is redacted and does not include device identifiers." >&2
  exit 1
fi

LAUNCH_JSON="$(mktemp "${TMPDIR:-/tmp}/watchhid-launch-json.XXXXXX")"
echo "==> launching WatchHID"
if ! python3 "$LIB" run-bounded --timeout "$LAUNCH_TIMEOUT" -- \
    xcrun devicectl device process launch \
      --device "$WATCH_UDID" \
      --timeout "$LAUNCH_TIMEOUT" \
      --json-output "$LAUNCH_JSON" \
      --quiet \
      com.zy.watchhid.watchkitapp; then
  echo "Launch failed or timed out. Output above is redacted and does not include device identifiers." >&2
  exit 1
fi

cat <<'EOF'
Install and launch finished.

Keep the Watch screen on. If this Mac shows a Bluetooth pairing prompt, confirm it in the system dialog. Then short-drag on the touchpad and run:

  ./scripts/verify-hogp-mouse.sh

The verify script only checks same-node IOHID identity (Manufacturer=WatchHID, ModelNumber=Ultra2-R1, mouse/pointer usage). A NODE_OK result is not proof that the pointer moved. Success for a return test is a WatchHID mouse node plus actual pointer movement you see yourself.
A connected Apple Watch in Bluetooth settings, or only clicking the pairing prompt, is not enough.
Do not reset system Bluetooth, and do not unpair the system Apple Watch.
EOF
