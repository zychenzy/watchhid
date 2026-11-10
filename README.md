# WatchHID

Use an Apple Watch as a real Bluetooth LE HID mouse for a Mac. No extra hardware, and no Mac accessibility helper for the pointer.

This repository is written in English. The Watch app UI follows the Watch system language, with English, Simplified Chinese, and Traditional Chinese; any other language falls back to English.

## Status (2026-11-10, Asia/Shanghai)

| Path | Status |
|---|---|
| Mac as a direct BLE HOGP mouse | Confirmed on two Macs: same-node identity `WatchHID` / `Ultra2-R1`, plus pointer movement the operator saw. A new Mac needs its own encrypted HOGP bond and a build that accepts any Report subscriber. |
| Watch dictation | System dictation captures text on the Watch and can type typable English into the focused Mac field when the keyboard HID is on. The Watch does not show the captured text. |
| English HID keyboard into the Mac | **Off** by default. Do not use the composite mouse+keyboard Report Map on a Mac that already bonded the baseline mouse map (that made movement vertical-only). The Settings toggle adds a separate keyboard service instead. |
| iPhone system HID / AssistiveTouch / UU remote | Not achieved. |

watchOS marks `CBPeripheralManager` APIs `API_UNAVAILABLE(watchos)`. This project creates the peripheral at runtime and it works on the setups below. That is not a supported stability guarantee for future watchOS.

## Requirements

- A Mac with full Xcode (not only Command Line Tools)
- An Apple Watch with Developer Mode enabled, and the iPhone it is paired with
- A free or paid Apple Developer Apple ID for signing. The macOS login account may be different; do not change the Mac login just to sign.

The method works for another Apple Watch and another Mac. Copy local config from the templates; do not commit device UDIDs, team files, private keys, or provisioning profiles.

## Quick start

Full steps, including every dialog you have to confirm yourself, are in [docs/setup.md](docs/setup.md). After the app is installed, use [docs/usage.md](docs/usage.md). If something fails, see [docs/troubleshooting.md](docs/troubleshooting.md).

On a Mac that already has the project:

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig   # once; fill DEVELOPMENT_TEAM
cp Config/local_devices.env.example Config/local_devices.env     # once; fill this Watch's UDID
./scripts/check-signing-prereqs.sh
# If the script says WWDR G3 is missing:
./scripts/check-signing-prereqs.sh --install-wwdr
./scripts/ship-encrypted-hogp.sh
./scripts/install-signed-watch-app.sh
```

Then open WatchHID on the Watch, confirm a Bluetooth pairing prompt if macOS shows one, short-drag on the pad, and run:

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` means this Mac sees the WatchHID mouse node. It is not proof that the pointer moved. Success is that node plus movement you see yourself.

## Layout

```
Apps/Watch/     Watch app: HID peripheral + touchpad + dictation
Apps/iOS/       Companion / diagnostics (not required for the Mac mouse)
Shared/         HID descriptors and input state
Config/         Tracked templates; local signing and device files are gitignored
scripts/        Build, install, signing preflight, and verification
docs/           Setup, usage, troubleshooting, and research notes
project.yml     XcodeGen source
```

Local-only (gitignored): `Config/Developer.xcconfig`, `Config/local_devices.env`, and the entire `build/` tree.

## Limits

- Input only works while WatchHID is in the foreground with the screen on. After the Watch sleeps or returns to the clock face, open the app again.
- An encrypted HOGP bond cannot be copied from another Mac. System Apple Watch pairing and iCloud do not bring it with you.
- Installing the Watch app uses the CoreDevice developer tunnel. A Bluetooth-connected Watch is not the same as a `connected` developer tunnel.
- Free personal-team provisioning usually expires in about seven days. Re-sign on this Mac with the same Apple ID. That is acceptable.

## Out of scope

External chips, Mac accessibility or event-injection helpers as the mouse path, unpairing or resetting Bluetooth as a fix, and claiming iPhone system-HID success.

## Tests (no system input)

```bash
swiftc Shared/MouseInputState.swift scripts/MouseInputStateTests.swift \
  -o /tmp/watchhid-mouse-tests && /tmp/watchhid-mouse-tests
python3 scripts/test_watchhid_scriptlib.py
python3 scripts/test_assess_live_read.py
```
