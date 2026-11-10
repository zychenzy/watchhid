#!/usr/bin/env bash
# Check whether this Mac has created the WatchHID system mouse.
# Does not print Bluetooth addresses or device UDIDs.
set -euo pipefail

blob="$(ioreg -r -c IOHIDDevice -l 2>/dev/null || true)"
if printf '%s' "$blob" | grep -q 'WatchHID' && printf '%s' "$blob" | grep -q 'Ultra2-R1'; then
  echo "OK: system HID includes WatchHID / Ultra2-R1. Short-drag on the watch pad to confirm the pointer moves."
  exit 0
fi

if hidutil list 2>/dev/null | grep -qi 'WatchHID'; then
  echo "OK: hidutil lists WatchHID. Short-drag on the watch pad to confirm the pointer moves."
  exit 0
fi

echo "NO: this Mac has not created a WatchHID mouse."
echo "If the Watch app is open and Bluetooth shows Apple Watch with HID BLE, the usual cause is that the HID link is not encrypted yet. Open WatchHID, accept a pairing prompt if one appears, and do not reset Bluetooth or unpair the system Apple Watch."
exit 1
