#!/usr/bin/env python3
"""Offline fail-closed evidence gate. Reads files only; never launches BLE/lifecycle work.
ready_now is a short evidence lease, NOT a guarantee that a later ATT call will run.
Historical MainActor logs corroborate success but cannot establish callback absence.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time

MAP = "05010902A1010901A1000509190129031500250195037501810295017505810305010930093109381581257F750895038106C0C0"
EXPECTED = {"2A4B": MAP, "2A4A": "11010002"}

def timestamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()

def assess(app_text, watch_text, trace_text="", now=None):
    now = time.time() if now is None else now
    lines = app_text.splitlines()
    begins = [i for i, line in enumerate(lines) if " BEGIN " in line]
    if not begins:
        return {"ready_now": False, "reason": "no BEGIN"}
    lines = lines[begins[-1]:]
    start = timestamp(lines[0].split()[0])
    end_lines = [line for line in lines if " END " in line]
    end = timestamp(end_lines[-1].split()[0]) if end_lines else now
    invalidated = any("INVALIDATED " in line for line in lines)
    responses = []
    for line in trace_text.splitlines():
        try:
            row = json.loads(line)
            if row.get("event") == "att_response_return":
                responses.append(row)
        except (ValueError, TypeError):
            continue
    good, failed = [], []
    for line in lines:
        if " VALUE service=" not in line:
            continue
        if not re.search(r"service=\{(?:1812|00001812-0000-1000-8000-00805F9B34FB) bytes=", line):
            continue
        match = re.search(r"char=\{(\w+) bytes=.*? data=(\w+) error=(.*)$", line)
        if not match:
            continue
        uuid, data, error = match.groups()
        if uuid not in EXPECTED:
            continue
        if error != "nil" or data != EXPECTED[uuid]:
            failed.append(uuid)
            continue
        records = [row for row in responses
                   if row.get("uuid") == uuid and row.get("central") == "908CDCF7-35E7-8966-C8EC-7A89B6E96426"
                   and row.get("result") == 0 and row.get("offset") == 0
                   and row.get("bytes") == len(data) // 2
                   and start - .1 <= row.get("callback_epoch", 0) <= end + 1
                   and 0 <= row.get("latency_ms", -1) < 1000]
        legacy = []
        for watch in watch_text.splitlines():
            if f"ATT read {uuid} " not in watch or "central=908CDCF7-35E7-8966-C8EC-7A89B6E96426" not in watch:
                continue
            if f"offset=0 bytes={len(data)//2} result=0" not in watch:
                continue
            when = timestamp(watch.split("]", 1)[0][1:])
            if start - .1 <= when <= end + 1:
                legacy.append(when)
        good.append({"uuid": uuid, "callback_trace": bool(records), "legacy_corroboration": bool(legacy),
                     "latest_callback_epoch": max([row["callback_epoch"] for row in records], default=0)})
    all_values = {item["uuid"] for item in good} == set(EXPECTED)
    corroborated = all_values and all(item["callback_trace"] or item["legacy_corroboration"] for item in good) and not invalidated
    independent = all_values and all(item["callback_trace"] for item in good)
    latest = min([item["latest_callback_epoch"] for item in good], default=0)
    age = now - latest if latest else None
    ready = bool(corroborated and independent and age is not None and 0 <= age <= 2)
    return {"ready_now": ready, "corroborated_read_window": corroborated,
            "callback_independent_evidence": independent,
            "lease_age_seconds": age, "lease_max_seconds": 2,
            "failed_or_wrong_values": failed, "invalidated": invalidated, "good": good,
            "reason": "fresh matched Map+HIDInfo and independent callbacks" if ready else
                      "closed: need clean Map+HIDInfo, matching independent callbacks, no invalidation and <=2s freshness",
            "scope": "App ATT availability evidence only; not system HID; absence is unknown, not suspension"}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-log", type=Path, required=True)
    parser.add_argument("--watch-log", type=Path, required=True)
    parser.add_argument("--callback-trace", type=Path)
    args = parser.parse_args()
    result = assess(args.app_log.read_text(), args.watch_log.read_text(), args.callback_trace.read_text() if args.callback_trace else "")
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result["ready_now"] else 2)
