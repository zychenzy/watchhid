#!/usr/bin/env python3
"""Shared helpers for WatchHID ship/install/verify scripts.

Never print a device UDID, Bluetooth address, or ProvisionedDevices list.
These helpers are safe to import in offline fixture tests.
"""
from __future__ import annotations

import argparse
import os
import plistlib
import re
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any

GENERIC_DESKTOP_PAGE = 1
POINTER_USAGE = 1
MOUSE_USAGE = 2
MANUFACTURER = "WatchHID"
MODEL_NUMBER = "Ultra2-R1"

# Apple device UDIDs are often 8-16 hex, not RFC 4122 8-4-4-4-12.
_RE_UUID = re.compile(
    r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"
)
_RE_APPLE_UDID = re.compile(r"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b")
_RE_MAC = re.compile(r"\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\b")
_RE_PROVISIONED = re.compile(
    r"(ProvisionedDevices\s*[=:]\s*)(?:\([^)]*\)|\[[^\]]*\]|<(?:array|dict)[\s\S]*?</(?:array|dict)>)",
    re.IGNORECASE,
)


def redact_text(text: str) -> str:
    if not text:
        return text
    text = _RE_PROVISIONED.sub(r"\1<redacted-device-list>", text)
    text = _RE_UUID.sub("<redacted-id>", text)
    text = _RE_APPLE_UDID.sub("<redacted-id>", text)
    text = _RE_MAC.sub("<redacted-addr>", text)
    return text


def choose_default_package(app_path: str, zip_path: str) -> str:
    """Prefer the canonical zip over an extracted .app.

    ditto preserves inner .app mtimes, so the extracted app can look older
    than a zip that was just unpacked. Never treat that directory as newer
    than the zip beside it.
    """
    app = Path(app_path)
    zipped = Path(zip_path)
    if zipped.is_file():
        return str(zipped)
    if app.is_dir():
        return str(app)
    return ""


def _walk(obj: Any):
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from _walk(value)
    elif isinstance(obj, list):
        for item in obj:
            yield from _walk(item)


def _ident_of(item: dict) -> str:
    hardware = item.get("hardwareProperties") or {}
    props = item.get("deviceProperties") or item.get("properties") or {}
    for key in (
        item.get("identifier"),
        item.get("udid"),
        item.get("Identifier"),
        item.get("UDID"),
        hardware.get("udid"),
        hardware.get("UDID"),
        props.get("udid"),
        props.get("UDID"),
    ):
        if key:
            return str(key).strip()
    return ""


def _same_udid(value: str, expected: str) -> bool:
    left, right = value.strip(), expected.strip()
    if not left or not right:
        return False
    return left.lower() == right.lower()


def watch_developer_state(data: Any, udid: str) -> str:
    """Return the CoreDevice tunnel/state for the exact WATCH_UDID only.

    If that UDID is absent, return "missing". Never fall back to another
    watchOS device, a name containing "Watch", or the first available Watch.
    """
    wanted = (udid or "").strip()
    if not wanted:
        return "missing"

    match = None
    for item in _walk(data):
        if not isinstance(item, dict):
            continue
        ident = _ident_of(item)
        if not ident or not _same_udid(ident, wanted):
            continue
        conn = item.get("connectionProperties") or (item.get("properties") or {}).get("connection") or {}
        state = (
            item.get("state")
            or conn.get("tunnelState")
            or conn.get("state")
            or item.get("connectionState")
        )
        match = {
            "state": state,
            "tunnel": conn.get("tunnelState") or conn.get("state"),
        }
        break
    if match is None:
        return "missing"
    return str(match.get("tunnel") or match.get("state") or "unknown")


def _usage_pairs(node: dict) -> list[tuple[int, int]]:
    pairs = []
    raw = node.get("DeviceUsagePairs") or node.get("HIDDeviceUsagePairs") or []
    if isinstance(raw, list):
        for item in raw:
            if not isinstance(item, dict):
                continue
            page = item.get("DeviceUsagePage", item.get("UsagePage"))
            usage = item.get("DeviceUsage", item.get("Usage"))
            if isinstance(page, int) and isinstance(usage, int):
                pairs.append((page, usage))
    page = node.get("PrimaryUsagePage")
    usage = node.get("PrimaryUsage")
    if isinstance(page, int) and isinstance(usage, int):
        pairs.append((page, usage))
    return pairs


def has_usage(node: dict, page: int, usage: int) -> bool:
    return (page, usage) in _usage_pairs(node)


def is_watchhid_pointer_node(node: dict) -> bool:
    if str(node.get("Manufacturer") or "") != MANUFACTURER:
        return False
    if str(node.get("ModelNumber") or "") != MODEL_NUMBER:
        return False
    # Require Generic Desktop mouse usage, and pointer usage when recorded.
    if not has_usage(node, GENERIC_DESKTOP_PAGE, MOUSE_USAGE):
        return False
    pairs = node.get("DeviceUsagePairs") or node.get("HIDDeviceUsagePairs")
    if pairs:
        return has_usage(node, GENERIC_DESKTOP_PAGE, POINTER_USAGE)
    return True


def iter_hid_nodes(data: Any) -> list[dict]:
    nodes = []
    seen = set()
    for item in _walk(data):
        if not isinstance(item, dict):
            continue
        if not any(
            key in item
            for key in (
                "Manufacturer",
                "ModelNumber",
                "PrimaryUsage",
                "PrimaryUsagePage",
                "DeviceUsagePairs",
            )
        ):
            continue
        node = {
            "Manufacturer": item.get("Manufacturer"),
            "ModelNumber": item.get("ModelNumber"),
            "Product": item.get("Product"),
            "PrimaryUsage": item.get("PrimaryUsage"),
            "PrimaryUsagePage": item.get("PrimaryUsagePage"),
            "DeviceUsagePairs": item.get("DeviceUsagePairs") or item.get("HIDDeviceUsagePairs"),
        }
        marker = (
            node["Manufacturer"],
            node["ModelNumber"],
            node["PrimaryUsage"],
            node["PrimaryUsagePage"],
            repr(node["DeviceUsagePairs"]),
            id(item),
        )
        if marker in seen:
            continue
        seen.add(marker)
        nodes.append(node)
    return nodes


def load_ioreg_data(source: str | bytes) -> Any:
    if isinstance(source, bytes):
        raw = source
        text = source.decode("utf-8")
    else:
        text = source
        raw = source.encode("utf-8")
    stripped = text.lstrip()
    if stripped.startswith(("<", "<?xml")):
        return plistlib.loads(raw)
    import json
    return json.loads(text)


def find_watchhid_pointer_node(data: Any) -> dict | None:
    for node in iter_hid_nodes(data):
        if is_watchhid_pointer_node(node):
            return node
    return None


def verify_status_message(found: bool) -> tuple[str, int]:
    """Describe node identity only. Never claim human pointer movement passed."""
    if found:
        text = (
            "NODE_OK: one IOHID device on this Mac has Manufacturer=WatchHID, "
            "ModelNumber=Ultra2-R1, and Generic Desktop mouse/pointer usage "
            "on that same node.\n"
            "This is only same-node HID identity. It is not a pass for "
            "pointer movement. On a safe blank desktop, short-drag and "
            "light-tap the watch pad to confirm movement yourself."
        )
        return text, 0
    text = (
        "NO: this Mac has no IOHID node that combines Manufacturer=WatchHID, "
        "ModelNumber=Ultra2-R1, and Generic Desktop mouse/pointer usage on "
        "the same device.\n"
        "A Bluetooth-connected Apple Watch, a pairing prompt, or stitching "
        "WatchHID and Ultra2-R1 from different nodes is not enough. Keep "
        "the Watch app open if you are mid-test, and do not reset Bluetooth "
        "or unpair the system Apple Watch."
    )
    return text, 1


def run_bounded(
    cmd: list[str],
    timeout: int,
    cwd: str | None = None,
    redact_output: bool = True,
    stdout_path: str | None = None,
) -> subprocess.CompletedProcess:
    """Run a command with a hard timeout.

    Human-facing stdout/stderr is redacted by default. When stdout_path is
    set, the raw (unredacted) stdout is written only to that file so a
    later parse (for example ioreg XML) is not corrupted by placeholders
    such as "<redacted-id>".
    """
    raw_stdout = open(stdout_path, "w", encoding="utf-8") if stdout_path else None
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    collected = {"out": [], "err": []}

    def pump(src, dest, bucket, do_redact):
        if src is None:
            return
        try:
            for line in iter(src.readline, ""):
                stored = redact_text(line) if do_redact else line
                if dest is not None:
                    dest.write(stored)
                    dest.flush()
                bucket.append(stored)
        finally:
            if dest is not None and dest not in (sys.stdout, sys.stderr):
                dest.close()

    stdout_dest = raw_stdout if raw_stdout is not None else (sys.stdout if redact_output else sys.stdout)
    # Never stream unredacted stdout to the terminal when a capture file is used.
    if raw_stdout is not None:
        stdout_dest = raw_stdout
        stdout_redact = False
    else:
        stdout_dest = sys.stdout
        stdout_redact = redact_output
    t_out = threading.Thread(target=pump, args=(proc.stdout, stdout_dest, collected["out"], stdout_redact))
    t_err = threading.Thread(target=pump, args=(proc.stderr, sys.stderr, collected["err"], True))
    t_out.daemon = True
    t_err.daemon = True
    t_out.start()
    t_err.start()
    deadline = time.monotonic() + timeout
    while proc.poll() is None:
        if time.monotonic() >= deadline:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                proc.kill()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=1)
            t_out.join(timeout=1)
            t_err.join(timeout=1)
            if proc.stdout:
                proc.stdout.close()
            if proc.stderr:
                proc.stderr.close()
            sys.stderr.write(f"Command timed out after {timeout}s.\n")
            raise SystemExit(124)
        time.sleep(0.05)
    t_out.join(timeout=2)
    t_err.join(timeout=2)
    if proc.stdout:
        proc.stdout.close()
    if proc.stderr:
        proc.stderr.close()
    return subprocess.CompletedProcess(
        cmd, proc.returncode, "".join(collected["out"]), "".join(collected["err"])
    )


def _read_watch_udid_from_env_file(path: Path) -> str:
    if not path.is_file():
        return ""
    for line in path.read_text().splitlines():
        if line.startswith("WATCH_UDID="):
            return line.split("=", 1)[1].strip()
    return ""


def provision_info(app_path: str, env_file: str = "") -> int:
    """Print expiry and membership boolean only. Never dump ProvisionedDevices."""
    import datetime

    app = Path(app_path)
    prov = app / "embedded.mobileprovision" if app.is_dir() else app
    if not prov.is_file():
        print("No embedded.mobileprovision was found.", file=sys.stderr)
        return 1
    raw = subprocess.check_output(["security", "cms", "-D", "-i", str(prov)], stderr=subprocess.DEVNULL)
    data = plistlib.loads(raw)
    exp = data.get("ExpirationDate")

    def fmt(dt: datetime.datetime | None) -> str:
        if dt is None:
            return "unknown"
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        shanghai = dt.astimezone(datetime.timezone(datetime.timedelta(hours=8)))
        return shanghai.strftime("%Y-%m-%d %H:%M:%S Asia/Shanghai (北京时间)")

    devices = data.get("ProvisionedDevices") or []
    print("ExpirationDate:", fmt(exp))
    print("ProvisionedDevices count:", len(devices))
    env_path = Path(env_file) if env_file else Path("Config/local_devices.env")
    udid = os.environ.get("WATCH_UDID", "").strip() or _read_watch_udid_from_env_file(env_path)
    if udid:
        print("Configured WATCH_UDID is in ProvisionedDevices:", udid in devices)
    else:
        print("Configured WATCH_UDID is in ProvisionedDevices: not-checked (no local UDID provided)")
    return 0


def _cli(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="watchhid_scriptlib.py")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_state = sub.add_parser("watch-state", help="Print developer tunnel state for the exact WATCH_UDID")
    p_state.add_argument("json_path")

    p_pkg = sub.add_parser("choose-default-package")
    p_pkg.add_argument("app_path")
    p_pkg.add_argument("zip_path")

    p_ver = sub.add_parser("verify-hid")
    p_ver.add_argument("--ioreg", default="", help="Path to ioreg -a XML/JSON, or - for stdin")

    p_redact = sub.add_parser("redact")
    p_redact.add_argument("path", nargs="?", default="-")

    p_run = sub.add_parser("run-bounded")
    p_run.add_argument("--timeout", type=int, required=True)
    p_run.add_argument("--stdout", dest="stdout_path", default="", help="Write raw unredacted stdout to this file")
    p_run.add_argument("--no-redact-stdout", action="store_true", help="Do not redact stdout streamed to the terminal")
    p_run.add_argument("command", nargs=argparse.REMAINDER)

    p_prov = sub.add_parser("provision-info")
    p_prov.add_argument("app_path")
    p_prov.add_argument("--env-file", default="")

    args = parser.parse_args(argv)
    if args.cmd == "watch-state":
        udid = os.environ.get("WATCH_UDID", "").strip()
        data = load_ioreg_data(Path(args.json_path).read_text())
        print(watch_developer_state(data, udid))
        return 0
    if args.cmd == "choose-default-package":
        choice = choose_default_package(args.app_path, args.zip_path)
        if not choice:
            return 1
        print(choice)
        return 0
    if args.cmd == "verify-hid":
        if args.ioreg == "-" or not args.ioreg:
            source = os.environ.get("WATCHHID_IOREG_FILE", "")
            if source:
                payload = Path(source).read_text()
            else:
                payload = sys.stdin.read()
        else:
            payload = Path(args.ioreg).read_text()
        data = load_ioreg_data(payload)
        found = find_watchhid_pointer_node(data) is not None
        text, code = verify_status_message(found)
        print(text)
        return code
    if args.cmd == "redact":
        payload = sys.stdin.read() if args.path == "-" else Path(args.path).read_text()
        sys.stdout.write(redact_text(payload))
        return 0
    if args.cmd == "run-bounded":
        command = args.command
        if command and command[0] == "--":
            command = command[1:]
        if not command:
            print("run-bounded needs a command", file=sys.stderr)
            return 2
        proc = run_bounded(
            command,
            args.timeout,
            redact_output=not args.no_redact_stdout,
            stdout_path=args.stdout_path or None,
        )
        return proc.returncode
    if args.cmd == "provision-info":
        return provision_info(args.app_path, args.env_file)
    return 2


if __name__ == "__main__":
    raise SystemExit(_cli())
