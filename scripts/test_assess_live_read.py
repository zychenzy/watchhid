#!/usr/bin/env python3
import json
from pathlib import Path
import unittest
from assess_live_read import assess, EXPECTED, MAP, timestamp

class EvidenceGateTests(unittest.TestCase):
    def setUp(self):
        self.now = timestamp("2026-11-09T14:41:27Z")
        self.app = "2026-11-09T14:41:27Z elapsed=0 BEGIN test\n"
        for uuid, value in EXPECTED.items():
            self.app += f"2026-11-09T14:41:27Z elapsed=.1 VALUE service={{1812 bytes=2}} char={{{uuid} bytes=2}} data={value} error=nil\n"
        self.app += "2026-11-09T14:41:27Z elapsed=.2 END test\n"
        self.trace = "\n".join(json.dumps(dict(event="att_response_return", uuid=u,
            central="908CDCF7-35E7-8966-C8EC-7A89B6E96426", result=0, offset=0, bytes=len(v)//2,
            callback_epoch=self.now+.05, latency_ms=1)) for u,v in EXPECTED.items())
    def gate(self, app=None, trace=None, offset=1):
        return assess(self.app if app is None else app, "", self.trace if trace is None else trace,
                      self.now+offset)["ready_now"]
    def test_fresh(self): self.assertTrue(self.gate())
    def test_data_and_error(self): self.assertFalse(self.gate(self.app.replace("error=nil", "error=242")))
    def test_bad_value(self): self.assertFalse(self.gate(self.app.replace(MAP,"DEAD")))
    def test_wrong_service(self): self.assertFalse(self.gate(self.app.replace("service={1812", "service={180A")))
    def test_stale(self): self.assertFalse(self.gate(offset=4))
    def test_future(self): self.assertFalse(self.gate(offset=-1))
    def test_invalidated(self): self.assertFalse(self.gate(self.app+"INVALIDATED service\n"))
    def test_missing_callback(self): self.assertFalse(self.gate(trace=""))
    def test_wrong_host(self): self.assertFalse(self.gate(trace=self.trace.replace("908CDCF7","F7A703F6")))
    def test_response_error(self): self.assertFalse(self.gate(trace=self.trace.replace('"result": 0','"result": 1')))
    def test_no_begin(self): self.assertFalse(self.gate(app=""))
    def test_existing_windows(self):
        root=Path(__file__).resolve().parents[1]
        watch=(root/"build/diagnostics/r5-client/iphone-only-20261109-224821/watch.log").read_text()
        for run,expected in [("224126",True),("224826",False)]:
            logs=list((root/f"build/diagnostics/r5-client/run-20261109-{run}/Documents").glob("watchhid-gatt-audit-*.log"))
            path=max(logs,key=lambda p:p.read_text().splitlines()[0])
            result=assess(path.read_text(),watch)
            self.assertEqual(result["corroborated_read_window"],expected)
            self.assertFalse(result["ready_now"])
if __name__ == "__main__": unittest.main()
