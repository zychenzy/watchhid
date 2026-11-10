#!/usr/bin/env bash
# Install a signed WatchHID watch app and launch it on the paired Watch.
# The CoreDevice developer tunnel is not the same as Bluetooth HID.
# Do not reset system Bluetooth or unpair the system Apple Watch.
# Never print a device UDID, Bluetooth address, or provisioned-device list.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
  echo "Usage: $0 [WatchHIDWatchApp.app|signed.zip]" >&2
  echo "If no path is given, uses build/diagnostics/recovery-root/encrypted-hogp/WatchHIDWatchApp.app" >&2
  echo "or WatchHID-encrypted-hogp.zip in that same directory." >&2
  exit 2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

SRC="${1:-}"
DEFAULT_APP="$ROOT/build/diagnostics/recovery-root/encrypted-hogp/WatchHIDWatchApp.app"
DEFAULT_ZIP="$ROOT/build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip"
if [[ -z "$SRC" ]]; then
  if [[ -d "$DEFAULT_APP" ]]; then
    SRC="$DEFAULT_APP"
  elif [[ -f "$DEFAULT_ZIP" ]]; then
    SRC="$DEFAULT_ZIP"
  else
    echo "No package path given, and no default encrypted package was found." >&2
    usage
  fi
fi

ENV_FILE="$ROOT/Config/local_devices.env"
WATCH_UDID=""
if [[ -f "$ENV_FILE" ]]; then
  WATCH_UDID="$(awk -F= '/^WATCH_UDID=/{print $2; exit}' "$ENV_FILE" | tr -d '[:space:]')"
fi
if [[ -z "$WATCH_UDID" ]]; then
  echo "Set WATCH_UDID in Config/local_devices.env (gitignored). Do not put a UDID in the repo or in chat." >&2
  exit 1
fi

print_tunnel_help() {
  cat <<'EOF'
开发安装通道现在不可用。这和蓝牙菜单里 Apple Watch 已连接不是一回事，也不要为此重置蓝牙或取消手表的系统配对。

请同时做到这些，然后重新运行本脚本：
1. 把手表拿近这台 Mac，点亮并解锁，保持屏幕亮着。
2. 把配对的 iPhone 也拿近并解锁，尽量连同一 Wi-Fi。不必插 USB 线。
3. 等 devicectl 把这只手表列为 connected，而不仅是 available (paired) 或 unavailable。
EOF
}

LIST_JSON="$(mktemp -t watchhid-devicelist)"
cleanup() {
  rm -f "$LIST_JSON"
  if [[ -n "${WORKDIR:-}" && -d "${WORKDIR:-}" ]]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

if ! xcrun devicectl list devices --json-output "$LIST_JSON" >/dev/null 2>&1; then
  echo "devicectl could not list devices." >&2
  print_tunnel_help
  exit 2
fi

STATE="$(WATCH_UDID="$WATCH_UDID" LIST_JSON="$LIST_JSON" python3 - <<'PY'
import json, os, sys
from pathlib import Path

udid = os.environ["WATCH_UDID"].strip()
data = json.loads(Path(os.environ["LIST_JSON"]).read_text())

def looks_like_udid(value: str) -> bool:
    s = value.strip()
    return s == udid or s.lower() == udid.lower()

found = []

def walk(obj):
    if isinstance(obj, dict):
        name = obj.get("name") or obj.get("deviceName") or (obj.get("deviceProperties") or {}).get("name")
        ident = str(obj.get("identifier") or obj.get("udid") or obj.get("Identifier") or "")
        conn = obj.get("connectionProperties") or (obj.get("properties") or {}).get("connection") or {}
        state = (
            obj.get("state")
            or conn.get("state")
            or conn.get("tunnelState")
            or obj.get("connectionState")
        )
        platform = (
            (obj.get("hardwareProperties") or {}).get("platform")
            or obj.get("platform")
            or ((obj.get("properties") or {}).get("hardware") or {}).get("platform")
        )
        if name or platform == "watchOS" or ident:
            found.append({
                "name": name,
                "state": state,
                "tunnel": conn.get("tunnelState") or conn.get("state"),
                "platform": platform,
                "ident": ident,
            })
        for v in obj.values():
            walk(v)
    elif isinstance(obj, list):
        for item in obj:
            walk(item)

walk(data)
watch = None
for item in found:
    if looks_like_udid(item.get("ident") or ""):
        watch = item
        break
if watch is None:
    for item in found:
        name = item.get("name") or ""
        if "Watch" in name or item.get("platform") == "watchOS":
            watch = item
            break
if watch is None:
    print("missing")
    sys.exit(0)
print(watch.get("tunnel") or watch.get("state") or "unknown")
PY
)"

echo "Watch developer state: $STATE"
case "$STATE" in
  connected)
    ;;
  missing)
    echo "devicectl did not list this Watch." >&2
    print_tunnel_help
    exit 2
    ;;
  *)
    print_tunnel_help
    exit 2
    ;;
esac

APP=""
WORKDIR=""
if [[ -d "$SRC" ]]; then
  APP="$SRC"
elif [[ -f "$SRC" ]]; then
  WORKDIR="$(mktemp -d -t watchhid-install)"
  ditto -x -k "$SRC" "$WORKDIR"
  find "$WORKDIR" -name '._*' -delete
  xattr -cr "$WORKDIR" 2>/dev/null || true
  APP="$(find "$WORKDIR" -name 'WatchHIDWatchApp.app' -type d | head -1)"
  if [[ -z "$APP" ]]; then
    echo "The archive did not contain WatchHIDWatchApp.app." >&2
    exit 1
  fi
else
  echo "Not a .app directory or zip: $SRC" >&2
  exit 1
fi

codesign --verify --verbose=2 "$APP"
echo "==> installing signed package"
xcrun devicectl device install app --device "$WATCH_UDID" "$APP"
echo "==> launching WatchHID"
xcrun devicectl device process launch --device "$WATCH_UDID" com.zy.watchhid.watchkitapp

cat <<'EOF'
Install and launch finished.

Keep the Watch screen on. If this Mac shows a Bluetooth pairing prompt, confirm it in the system dialog. Then short-drag on the touchpad and run:

  ./scripts/verify-hogp-mouse.sh

Success is a WatchHID mouse plus actual pointer movement. A connected Apple Watch in Bluetooth settings, or only clicking the pairing prompt, is not enough.
Do not reset system Bluetooth, and do not unpair the system Apple Watch.
EOF
