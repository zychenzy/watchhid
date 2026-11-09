#!/usr/bin/env python3
"""One bounded read-only iPhone GATT run; never builds, installs or touches Watch."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import json
import selectors
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
from _local_env import require
_ids = require("PHONE_UDID", "BLE_PEER_UUID")
PHONE = _ids["PHONE_UDID"]
PEER = _ids["BLE_PEER_UUID"]
BUNDLE = "com.zy.watchhid.gattaudit"
OUT = ROOT / "build/diagnostics/r5-client" / datetime.now(ZoneInfo("Asia/Hong_Kong")).strftime("run-%Y%m%d-%H%M%S")
OUT.mkdir(parents=True, exist_ok=False)

def device(name, args, timeout=15):
    args = list(args)
    position = args.index("--") if "--" in args else len(args)
    args[position:position] = ["--timeout", str(timeout)]
    command = ["xcrun", "devicectl", *args]
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout + 5)
    (OUT / (name + ".txt")).write_text(result.stdout + result.stderr)
    print(name, "exit", result.returncode, flush=True)
    return result

print("Output:", OUT, "(host timestamps Asia/Hong_Kong)", flush=True)
lock = device("phone-lock", ["device", "info", "lockState", "--device", PHONE, "--json-output", str(OUT / "phone-lock.json")])
if lock.returncode:
    raise SystemExit("Lock-state check failed; no launch/retry")
state = json.loads((OUT / "phone-lock.json").read_text())["result"]
if state.get("passcodeRequired"):
    raise SystemExit("Phone locked: no launch, no repeated requests. Unlock is required for next run.")

err = (OUT / "syslog.err").open("wb")
process = subprocess.Popen(["/opt/homebrew/bin/idevicesyslog", "-u", PHONE, "--no-colors", "-p", "bluetoothd|WatchHIDClientAudit"], stdout=subprocess.PIPE, stderr=err)
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ)
limit = 2 * 1024 * 1024
written = 0
started = time.monotonic()
try:
    launched = device("launch", ["device", "process", "launch", "--device", PHONE, "--terminate-existing", BUNDLE, "--", "--gatt-audit", "--target-id=" + PEER], timeout=12)
    if launched.returncode:
        raise SystemExit("Launch blocked/failed: no retry")
    with (OUT / "iphone-capped.log").open("wb") as stream:
        while time.monotonic() - started < 48 and written < limit and process.poll() is None:
            for key, _ in selector.select(timeout=min(0.5, max(0, 48 - (time.monotonic() - started)))):
                chunk = key.fileobj.read1(min(16384, limit - written))
                if not chunk:
                    break
                stream.write(chunk)
                written += len(chunk)
        print("syslog bytes", written, "elapsed", round(time.monotonic() - started, 2), flush=True)
finally:
    selector.close()
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
    err.close()

device("copy-audit-documents", ["device", "copy", "from", "--device", PHONE, "--domain-type", "appDataContainer", "--domain-identifier", BUNDLE, "--source", "Documents", "--destination", str(OUT / "Documents")], timeout=15)
print("Done. App's own deadline is 45s and log cap 128KiB; no scan/notify/write.", flush=True)
