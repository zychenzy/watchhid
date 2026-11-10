#!/usr/bin/env python3
"""Offline fixture tests for WatchHID install/verify helpers.

Does not call devicectl, ioreg, hidutil, Bluetooth, or a physical Watch.
"""
from __future__ import annotations

import io
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import watchhid_scriptlib as lib


TARGET = "FFFFFFFF-0000000000000001"
OTHER = "FFFFFFFF-0000000000000002"
FAKE_UUID = "12345678-1234-1234-1234-1234567890ab"
FAKE_MAC = "AA:BB:CC:DD:EE:FF"


def device_list(*devices):
    return {"result": {"devices": list(devices)}}


def watch_device(udid, tunnel, name="Other Watch", platform="watchOS"):
    return {
        "identifier": udid,
        "deviceProperties": {"name": name},
        "hardwareProperties": {"platform": platform, "udid": udid},
        "connectionProperties": {
            "transport": "localNetwork",
            "tunnelState": tunnel,
            "state": tunnel,
        },
    }


def hid_node(
    manufacturer="",
    model="",
    product="Fixture Watch",
    usage=2,
    page=1,
    pairs=None,
):
    node = {
        "Manufacturer": manufacturer,
        "ModelNumber": model,
        "Product": product,
        "PrimaryUsage": usage,
        "PrimaryUsagePage": page,
    }
    if pairs is not None:
        node["DeviceUsagePairs"] = [
            {"DeviceUsagePage": p, "DeviceUsage": u} for p, u in pairs
        ]
    return node


MOUSE_POINTER_PAIRS = ((1, 2), (1, 1))


class DefaultPackageTests(unittest.TestCase):
    def test_prefers_zip_even_when_extracted_app_exists(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            app = root / "encrypted-hogp" / "WatchHIDWatchApp.app"
            app.mkdir(parents=True)
            (app / "Info.plist").write_text("fixture")
            zipped = root / "WatchHID-encrypted-hogp.zip"
            zipped.write_bytes(b"zip-bytes")
            # Make the extracted app look newer than the zip; the chooser
            # must still prefer the zip so a stale extract cannot win.
            now = time.time()
            os.utime(app, (now + 3600, now + 3600))
            os.utime(zipped, (now - 3600, now - 3600))
            self.assertEqual(lib.choose_default_package(str(app), str(zipped)), str(zipped))

    def test_uses_extracted_app_only_when_zip_is_absent(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            app = root / "WatchHIDWatchApp.app"
            app.mkdir()
            self.assertEqual(lib.choose_default_package(str(app), str(root / "missing.zip")), str(app))

    def test_empty_when_neither_exists(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            self.assertEqual(lib.choose_default_package(str(root / "no.app"), str(root / "no.zip")), "")


class WatchStateTests(unittest.TestCase):
    def test_exact_udid_connected(self):
        data = device_list(
            watch_device(OTHER, "connected", name="Wrong Watch"),
            watch_device(TARGET, "connected", name="Target Watch"),
        )
        self.assertEqual(lib.watch_developer_state(data, TARGET), "connected")

    def test_exact_udid_unavailable_is_not_connected(self):
        data = device_list(watch_device(TARGET, "unavailable", name="Target Watch"))
        self.assertEqual(lib.watch_developer_state(data, TARGET), "unavailable")

    def test_no_fallback_when_udid_missing_but_another_watch_is_connected(self):
        data = device_list(
            watch_device(OTHER, "connected", name="Apple Watch"),
            {
                "deviceProperties": {"name": "Some Watch"},
                "hardwareProperties": {"platform": "watchOS"},
                "connectionProperties": {"tunnelState": "connected"},
            },
        )
        self.assertEqual(lib.watch_developer_state(data, TARGET), "missing")

    def test_case_insensitive_same_udid_still_matches(self):
        data = device_list(watch_device(TARGET.lower(), "connected"))
        self.assertEqual(lib.watch_developer_state(data, TARGET.upper()), "connected")

    def test_iphone_with_same_list_is_not_used_as_fallback(self):
        data = device_list(
            {
                "identifier": "IIIIIIII-0000000000000009",
                "deviceProperties": {"name": "iPhone"},
                "hardwareProperties": {"platform": "iOS", "udid": "IIIIIIII-0000000000000009"},
                "connectionProperties": {"tunnelState": "connected"},
            }
        )
        self.assertEqual(lib.watch_developer_state(data, TARGET), "missing")


class VerifyNodeTests(unittest.TestCase):
    def test_same_node_identity_and_usage_passes(self):
        data = [hid_node("WatchHID", "Ultra2-R1", pairs=MOUSE_POINTER_PAIRS)]
        self.assertIsNotNone(lib.find_watchhid_pointer_node(data))
        text, code = lib.verify_status_message(True)
        self.assertEqual(code, 0)
        self.assertIn("NODE_OK", text)
        self.assertNotIn("指针已", text)
        self.assertNotIn("already passed", text)
        self.assertIn("not a pass for pointer movement", text)

    def test_does_not_stitch_manufacturer_and_model_across_nodes(self):
        data = [
            hid_node("WatchHID", "OtherModel", product="A", pairs=MOUSE_POINTER_PAIRS),
            hid_node("OtherMaker", "Ultra2-R1", product="B", pairs=MOUSE_POINTER_PAIRS),
        ]
        self.assertIsNone(lib.find_watchhid_pointer_node(data))
        text, code = lib.verify_status_message(False)
        self.assertEqual(code, 1)
        self.assertTrue(text.startswith("NO:"))

    def test_product_ultra2_is_not_identity(self):
        # Real WatchHID nodes use ModelNumber=Ultra2-R1; Product is the watch name.
        data = [
            hid_node(
                "WatchHID",
                model="not-the-model",
                product="Ultra2-R1",
                pairs=MOUSE_POINTER_PAIRS,
            )
        ]
        self.assertIsNone(lib.find_watchhid_pointer_node(data))

    def test_keyboard_usage_on_matching_names_fails(self):
        data = [hid_node("WatchHID", "Ultra2-R1", usage=6, page=1, pairs=((1, 6),))]
        self.assertIsNone(lib.find_watchhid_pointer_node(data))

    def test_mouse_without_pointer_pair_fails_when_pairs_present(self):
        data = [hid_node("WatchHID", "Ultra2-R1", pairs=((1, 2),))]
        self.assertIsNone(lib.find_watchhid_pointer_node(data))

    def test_mouse_primary_usage_enough_when_no_pairs(self):
        data = [hid_node("WatchHID", "Ultra2-R1", usage=2, page=1, pairs=None)]
        self.assertIsNotNone(lib.find_watchhid_pointer_node(data))

    def test_plist_fixture_roundtrip(self):
        payload = plistlib.dumps(
            [hid_node("WatchHID", "Ultra2-R1", pairs=MOUSE_POINTER_PAIRS)],
            fmt=plistlib.FMT_XML,
        )
        data = lib.load_ioreg_data(payload)
        self.assertIsNotNone(lib.find_watchhid_pointer_node(data))


class RedactionTests(unittest.TestCase):
    def test_redacts_uuid_apple_udid_mac_and_provisioned_devices(self):
        raw = (
            f"device {TARGET} also {FAKE_UUID} addr {FAKE_MAC}\n"
            'ProvisionedDevices = ( "FFFFFFFF-0000000000000001", "FFFFFFFF-0000000000000002" );\n'
        )
        out = lib.redact_text(raw)
        self.assertNotIn(TARGET, out)
        self.assertNotIn(FAKE_UUID, out)
        self.assertNotIn(FAKE_MAC, out)
        self.assertNotIn("0000000000000001", out)
        self.assertIn("<redacted-id>", out)
        self.assertIn("<redacted-addr>", out)
        self.assertIn("<redacted-device-list>", out)
        self.assertNotIn("FFFFFFFF-0000000000000001", out)
        self.assertNotIn("FFFFFFFF-0000000000000002", out)


class TimeoutTests(unittest.TestCase):
    def test_run_bounded_kills_a_sleep(self):
        with self.assertRaises(SystemExit) as cm:
            lib.run_bounded([sys.executable, "-c", "import time; time.sleep(5)"], timeout=1)
        self.assertEqual(cm.exception.code, 124)


class SkillLinkTests(unittest.TestCase):
    def test_skill_relative_links_resolve_from_skill_dir_to_repo_root(self):
        skill = ROOT / ".cursor/skills/watchhid-new-mac-hogp/SKILL.md"
        if not skill.is_file():
            self.skipTest("skill file not in this checkout")
        import re

        text = skill.read_text()
        hrefs = re.findall(r"\[[^\]]+\]\(([^)]+)\)", text)
        self.assertTrue(hrefs, "skill should link to repo docs")
        for href in hrefs:
            if href.startswith(("http://", "https://", "sand-workflow:")):
                continue
            resolved = (skill.parent / href).resolve()
            self.assertTrue(resolved.is_file(), f"broken skill link {href} -> {resolved}")
            self.assertTrue(
                ROOT in resolved.parents or resolved.parent == ROOT,
                f"{href} should stay inside the repo root, resolved={resolved}",
            )


class ScriptHelpTests(unittest.TestCase):
    def test_bash_scripts_parse(self):
        for name in (
            "install-signed-watch-app.sh",
            "ship-encrypted-hogp.sh",
            "verify-hogp-mouse.sh",
        ):
            path = ROOT / "scripts" / name
            if not path.is_file():
                self.skipTest(f"{name} not in this checkout")
            subprocess.check_call(["bash", "-n", str(path)])


class InstallScriptDryRunTests(unittest.TestCase):
    def _write_list(self, path, *devices):
        path.write_text(json.dumps(device_list(*devices)))

    def _run(self, env, *args):
        script = ROOT / "scripts" / "install-signed-watch-app.sh"
        merged = os.environ.copy()
        merged.update(env)
        return subprocess.run(
            ["bash", str(script), *args],
            cwd=str(ROOT),
            env=merged,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=20,
        )

    def test_dry_run_prefers_zip_and_requires_exact_udid(self):
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            app_dir = tmp / "encrypted-hogp" / "WatchHIDWatchApp.app"
            app_dir.mkdir(parents=True)
            (app_dir / "Info.plist").write_text("stale-extract")
            payload = tmp / "payload"
            nested = payload / "WatchHIDWatchApp.app"
            nested.mkdir(parents=True)
            (nested / "Info.plist").write_text("from-zip")
            zipped = tmp / "WatchHID-encrypted-hogp.zip"
            import zipfile
            with zipfile.ZipFile(zipped, "w") as zf:
                zf.write(nested / "Info.plist", "WatchHIDWatchApp.app/Info.plist")
            envf = tmp / "local_devices.env"
            envf.write_text(f"WATCH_UDID={TARGET}\n")
            listed = tmp / "devices.json"
            self._write_list(listed, watch_device(TARGET, "connected"), watch_device(OTHER, "connected", name="Apple Watch"))
            proc = self._run(
                {
                    "WATCHHID_DEFAULT_APP": str(app_dir),
                    "WATCHHID_DEFAULT_ZIP": str(zipped),
                    "WATCHHID_ENV_FILE": str(envf),
                    "WATCHHID_DEVICELIST_JSON": str(listed),
                    "WATCHHID_DRY_RUN": "1",
                }
            )
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assertIn("DRY_RUN", proc.stdout)
            self.assertNotIn(TARGET, proc.stdout + proc.stderr)
            self.assertNotIn(OTHER, proc.stdout + proc.stderr)

    def test_dry_run_does_not_fall_back_to_another_watch(self):
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            app_dir = tmp / "WatchHIDWatchApp.app"
            app_dir.mkdir()
            (app_dir / "Info.plist").write_text("app")
            envf = tmp / "local_devices.env"
            envf.write_text(f"WATCH_UDID={TARGET}\n")
            listed = tmp / "devices.json"
            self._write_list(listed, watch_device(OTHER, "connected", name="Apple Watch"))
            proc = self._run(
                {
                    "WATCHHID_ENV_FILE": str(envf),
                    "WATCHHID_DEVICELIST_JSON": str(listed),
                    "WATCHHID_DRY_RUN": "1",
                },
                str(app_dir),
            )
            self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
            combined = proc.stdout + proc.stderr
            self.assertIn("exact UDID only", combined)
            self.assertNotIn(TARGET, combined)
            self.assertNotIn(OTHER, combined)

    def test_verify_script_fixture_same_node_and_cross_node(self):
        script = ROOT / "scripts" / "verify-hogp-mouse.sh"
        with tempfile.TemporaryDirectory() as raw:
            tmp = Path(raw)
            ok = tmp / "ok.plist"
            bad = tmp / "bad.plist"
            ok.write_bytes(plistlib.dumps([hid_node("WatchHID", "Ultra2-R1", pairs=MOUSE_POINTER_PAIRS)], fmt=plistlib.FMT_XML))
            bad.write_bytes(plistlib.dumps([
                hid_node("WatchHID", "OtherModel", pairs=MOUSE_POINTER_PAIRS),
                hid_node("OtherMaker", "Ultra2-R1", pairs=MOUSE_POINTER_PAIRS),
            ], fmt=plistlib.FMT_XML))
            ok_proc = subprocess.run(
                ["bash", str(script)],
                env={**os.environ, "WATCHHID_IOREG_FILE": str(ok)},
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10,
            )
            bad_proc = subprocess.run(
                ["bash", str(script)],
                env={**os.environ, "WATCHHID_IOREG_FILE": str(bad)},
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10,
            )
            self.assertEqual(ok_proc.returncode, 0, ok_proc.stdout + ok_proc.stderr)
            self.assertIn("NODE_OK", ok_proc.stdout)
            self.assertIn("not a pass for pointer movement", ok_proc.stdout)
            self.assertEqual(bad_proc.returncode, 1, bad_proc.stdout + bad_proc.stderr)
            self.assertTrue(bad_proc.stdout.startswith("NO:"))



class IoregParseOrderTests(unittest.TestCase):
    def _xml_with_uuid(self):
        nodes = [hid_node("WatchHID", "Ultra2-R1", pairs=MOUSE_POINTER_PAIRS)]
        nodes[0]["SerialNumber"] = FAKE_UUID
        return plistlib.dumps(nodes, fmt=plistlib.FMT_XML)

    def test_redacting_xml_before_parse_breaks_plist(self):
        raw = self._xml_with_uuid()
        self.assertIsNotNone(lib.find_watchhid_pointer_node(lib.load_ioreg_data(raw)))
        redacted = lib.redact_text(raw.decode("utf-8")).encode("utf-8")
        with self.assertRaises(Exception):
            plistlib.loads(redacted)

    def test_run_bounded_stdout_path_keeps_raw_xml_parseable(self):
        raw = self._xml_with_uuid()
        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "in.xml"
            dest = Path(tmp) / "out.xml"
            src.write_bytes(raw)
            proc = lib.run_bounded(
                [sys.executable, "-c", "import sys; sys.stdout.buffer.write(open(sys.argv[1], 'rb').read())", str(src)],
                timeout=10,
                redact_output=True,
                stdout_path=str(dest),
            )
            self.assertEqual(proc.returncode, 0)
            saved = dest.read_bytes()
            self.assertIn(FAKE_UUID.encode(), saved)
            data = lib.load_ioreg_data(saved)
            self.assertIsNotNone(lib.find_watchhid_pointer_node(data))
            # Default streaming redaction would have broken this XML.
            with self.assertRaises(Exception):
                plistlib.loads(lib.redact_text(saved.decode("utf-8")).encode("utf-8"))


if __name__ == '__main__':
    unittest.main()
