**English** | [简体中文](INDEX.zh-CN.md)

# Docs

Current user and operator documents:

- [Setup](setup.md) — signing, build, and install
- [Usage](usage.md) — trackpad, Crown, dictation, and output selection
- [Troubleshooting](troubleshooting.md) — common failures and what not to do
- [Simulator checks](SIMULATOR-CHECKS.md) — official UI tests for the system text-input sheet (not speech recognition or BLE)
- [Architecture notes](architecture.md) — WatchHID’s HOGP path, and a comparison with a related project (no code shared)

Logic tests (no Bluetooth, no system input):

```bash
swiftc Shared/HIDDescriptors.swift Shared/HIDMetadata.swift Shared/KeyboardInputState.swift Shared/MouseInputState.swift \
  scripts/MouseInputStateTests.swift -o /tmp/watchhid-mouse-tests && /tmp/watchhid-mouse-tests
swiftc Shared/OutputHostRouting.swift scripts/OutputHostRoutingTests.swift \
  -o /tmp/watchhid-output-host-tests && /tmp/watchhid-output-host-tests
python3 scripts/test_watchhid_scriptlib.py
```

Repository layout:

```
Apps/Watch/     Watch app: HID peripheral, trackpad, Crown scroll, system dictation
Shared/         HID descriptors and input state
Config/         Tracked templates; local signing and device files are gitignored
scripts/        Build, install, signing preflight, verification, and unit tests
docs/           Setup, usage, troubleshooting, simulator checks, architecture notes
project.yml     XcodeGen source
```

Local-only (gitignored): `Config/Developer.xcconfig`, `Config/local_devices.env`, and the entire `build/` tree.
