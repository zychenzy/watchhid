#!/usr/bin/env python3
"""One known-peer Mac read, no Watch lifecycle/advertising/scan/notify/write changes."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "build/diagnostics/r5-client"
BINARY = BASE / "run-20261109-222949/mac-read-control"
OUT = BASE / datetime.now(ZoneInfo("Asia/Hong_Kong")).strftime("recovery-%Y%m%d-%H%M%S")
OUT.mkdir(parents=True, exist_ok=False)
if not BINARY.is_file():
    raise SystemExit("Prepared read-control binary missing; no auto-build or alternate route")
source = (ROOT / "Shared/HIDDescriptors.swift").read_text()
map_section = source.split("static let mouseReportMap: [UInt8] = [", 1)[1].split("]", 1)[0]
expected = "".join(re.findall(r"0x([0-9a-fA-F]{2})", map_section)).upper()
try:
    result = subprocess.run([str(BINARY)], capture_output=True, text=True, timeout=14)
except subprocess.TimeoutExpired as error:
    (OUT / "result.json").write_text(json.dumps({"passed": False, "reason": "14s process timeout; no retry"}, indent=2))
    raise SystemExit("Read control timeout; no retry") from error
text = result.stdout + result.stderr
(OUT / "mac-read.log").write_text(text[:65536])
match = re.search(r"ReportMap data=([0-9A-F]+) error=nil", text)
passed = result.returncode == 0 and match is not None and match.group(1) == expected and "END read succeeded" in text
report = {"passed": passed, "expected_report_map": expected, "actual_report_map": match.group(1) if match else None, "returncode": result.returncode, "output": str(OUT), "scope": "public Mac read only; no proof of iPhone system HID binding"}
(OUT / "result.json").write_text(json.dumps(report, indent=2) + "\n")
print(text, end="")
print(json.dumps(report, indent=2))
raise SystemExit(0 if passed else 2)
