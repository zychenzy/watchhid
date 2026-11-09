#!/usr/bin/env python3
"""One Watch activation + iPhone read audit. No Mac GATT, reset or cache clearing."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
from _local_env import require
_ids = require("WATCH_UDID", "PHONE_UDID")
BASE = ROOT / "build/diagnostics/r5-client"
OUT = BASE / datetime.now(ZoneInfo("Asia/Hong_Kong")).strftime("iphone-only-%Y%m%d-%H%M%S")
OUT.mkdir(parents=True, exist_ok=False)
WATCH = _ids["WATCH_UDID"]
PHONE = _ids["PHONE_UDID"]

def run(name, command, timeout):
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    (OUT / (name + ".txt")).write_text((result.stdout + result.stderr)[:65536])
    print(name, "exit", result.returncode, flush=True)
    return result

print("OUT", OUT, "HKT; cache state unknown; no Mac GATT client invoked", flush=True)
report = {"cache_state": "unknown, not a cold-cache experiment", "mac_active_gatt_invoked": False}
try:
    activation = run("watch-activation", ["xcrun", "devicectl", "device", "process", "launch", "--device", WATCH, "--activate", "--timeout", "8", "--json-output", str(OUT / "watch-activation.json"), "com.zy.watchhid.watchkitapp"], 13)
    report["activation_exit"] = activation.returncode
    if activation.returncode:
        raise SystemExit("Activation refused/failed: no retry, no iPhone launch")
    lock = run("phone-lock", ["xcrun", "devicectl", "device", "info", "lockState", "--device", PHONE, "--timeout", "8", "--json-output", str(OUT / "phone-lock.json")], 13)
    if lock.returncode:
        raise SystemExit("Lock check failed: no launch/retry")
    state = json.loads((OUT / "phone-lock.json").read_text())["result"]
    report["phone_lock_state"] = state
    if state.get("passcodeRequired") is not False:
        raise SystemExit("Phone not verified unlocked: no launch/retry")
    result = run("iphone-runner", ["python3", str(ROOT / "scripts/run_iphone_gatt_audit.py")], 80)
    report["iphone_runner_exit"] = result.returncode
    print(result.stdout, flush=True)
    if result.returncode:
        raise SystemExit("iPhone runner failed/blocked: no retry")
    match = re.search(r"Output: (.+?) \(host timestamps", result.stdout)
    if match:
        audit_dir = Path(match.group(1))
        report["audit_directory"] = str(audit_dir)
        logs = list((audit_dir / "Documents").glob("watchhid-gatt-audit-*.log"))
        # App Documents contains older audits too; select by embedded BEGIN time, never filesystem order.
        def begin_time(path):
            return path.read_text().splitlines()[0].split(" elapsed=", 1)[0]
        if logs:
            latest = max(logs, key=begin_time)
            rows = latest.read_text().splitlines()
            report["selected_app_log"] = str(latest)
            report["app_begin"] = rows[0]
            report["app_end"] = rows[-1]
            report["service_results"] = [x for x in rows if "DISCOVER RESULT" in x]
            report["characteristic_reads"] = [x for x in rows if " VALUE service=" in x and "READ PLAN" not in x]
            report["descriptor_reads"] = [x for x in rows if "DESCRIPTOR VALUE" in x]
            report["invalidations"] = [x for x in rows if "INVALIDATED" in x]
finally:
    copy = run("watch-log-copy", ["xcrun", "devicectl", "device", "copy", "from", "--device", WATCH, "--domain-type", "appDataContainer", "--domain-identifier", "com.zy.watchhid.watchkitapp", "--source", "Documents/watchhid-r1.log", "--destination", str(OUT / "watch.log"), "--timeout", "12"], 18)
    report["watch_copy_exit"] = copy.returncode
    (OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
