#!/usr/bin/env python3
"""Bounded real-device read-only HID matrix. Run while Watch remains awake."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
from _local_env import require
_ids = require("WATCH_UDID", "PHONE_UDID", "BLE_PEER_UUID", "MAC_TARGET_ID")
OUT = ROOT / "build/diagnostics/r4/resume"
WATCH = _ids["WATCH_UDID"]
PHONE = _ids["PHONE_UDID"]
PEER = _ids["BLE_PEER_UUID"]
MAC_TARGET = _ids["MAC_TARGET_ID"]

def device(*args):
    result = subprocess.run(["xcrun", "devicectl", *args], cwd=ROOT,
                            text=True, capture_output=True, timeout=30)
    print(result.stdout, result.stderr, flush=True)
    if result.returncode:
        raise RuntimeError(result.stderr or result.stdout)
    return result.stdout

def run():
    OUT.mkdir(parents=True, exist_ok=True)
    token = str(uuid.uuid4())
    print("WatchConnectivity command token=" + token, flush=True)
    client = subprocess.Popen(["script", "-q", str(OUT / "inprocess-gatt.txt"),
                               str(ROOT / "build/diagnostics/r4/scan_mac_target"),
                               "--target-id=" + MAC_TARGET, "--no-notify"], cwd=ROOT,
                              start_new_session=True, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT)
    device("device", "process", "launch", "--device", PHONE, "--terminate-existing",
           "com.zy.watchhid", "--", "--scan", "--connect-target", "--target-id=" + PEER, "--r4-matrix", "--r4-token=" + token)
    try:
        output = client.communicate(timeout=44)[0]
    except subprocess.TimeoutExpired:
        os.killpg(client.pid, signal.SIGTERM)
        output = client.communicate(timeout=5)[0]
    (OUT / "inprocess-gatt.txt").write_bytes(output)
    print(output.decode(errors="replace"), flush=True)
    with (OUT / "inprocess-hid.txt").open("w") as handle:
        subprocess.run(["ioreg", "-r", "-c", "IOHIDDevice", "-l"],
                       stdout=handle, check=True, timeout=10)
    for identifier, bundle, name, source in [
        (WATCH, "com.zy.watchhid.watchkitapp", "watch", "watchhid-r1.log"),
        (PHONE, "com.zy.watchhid", "phone", "watchhid-scan.log")]:
        device("device", "copy", "from", "--device", identifier,
               "--domain-type", "appDataContainer", "--domain-identifier", bundle,
               "--source", "Documents/" + source,
               "--destination", str(OUT / ("inprocess-" + name + ".log")))
        device("device", "capture", "screenshot", "--device", identifier,
               "--destination", str(OUT / ("inprocess-" + name + ".png")))
    text = (OUT / "inprocess-watch.log").read_text()
    marker = "COMMAND accepted token=" + token
    if marker not in text:
        raise RuntimeError("Watch command not received yet; queued delivery is not execution")
    latest = text[text.rfind(marker):]
    if not all(marker in latest for marker in ["MATRIX CASE standard128-dynamic", "MATRIX CASE standard128-encrypted", "MATRIX complete — no movement/click sent"]):
        raise RuntimeError("Matrix completion not observed; do not assume all stages ran")
    print("Matrix logs collected; verify latest markers and callbacks before accepting.", flush=True)

if __name__ == "__main__":
    argparse.ArgumentParser(description=__doc__).parse_args()
    run()
