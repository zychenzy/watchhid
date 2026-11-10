# WatchHID

Use an Apple Watch as a Bluetooth LE HID mouse (and optional English keyboard) for a Mac. No extra hardware, and no Mac accessibility helper for the pointer.

The Watch app UI follows the Watch system language (English, Simplified Chinese, and Traditional Chinese). Documentation and tests in this repository are English only.

## What this is

WatchHID is a **watch-only** app. It advertises a standard Bluetooth HOGP mouse. A Mac that bonds and subscribes treats it as a system mouse. English typing, when enabled, uses a **separate** keyboard HID service and does not change the baseline mouse Report Map.

watchOS marks `CBPeripheralManager` APIs `API_UNAVAILABLE(watchos)`. This project creates the peripheral at runtime. That has worked on the setups that were actually tested; it is **not** a supported Apple API, not an App Store submission, and not a stability guarantee for future watchOS releases.

## What has been confirmed

These are operator-confirmed results, not a general device or OS matrix:

- **Mac pointer and clicks:** Works as a direct BLE HOGP mouse on more than one Mac, including the operator’s home Mac after the current one-host Device 1 / Device 2 routing was installed. Same-node identity is `WatchHID` / `Ultra2-R1`. `NODE_OK` from the verify script is identity only; movement is what you see on the screen.
- **iPhone as a HID host:** The operator confirmed Watch control of an iPhone while away from a Mac, on a different network. That is a personal confirmation, not an instrumented test across iOS versions or reconnection cases.
- **English dictation into a Mac:** The Watch presents the **system** text-input sheet (`presentTextInputController`). If typable English is accepted and the keyboard HID is on, it is typed into the focused Mac field. The Watch does not show the captured text. The system may open a keyboard or Scribble first; switch to the microphone in that sheet if you want dictation. There is no public API that forces the sheet to open on recording.

## Requirements

- A Mac with full Xcode (not only Command Line Tools)
- An Apple Watch with Developer Mode enabled, and the iPhone it is paired with (pairing with an iPhone is a watchOS requirement; this app does not need a companion iPhone app)
- A free or paid Apple Developer account for signing. The macOS login account may be different; do not change the Mac login just to sign.

Copy local config from the templates. Do not commit device UDIDs, team IDs, private keys, or provisioning profiles.

## Quick start

Full steps, including dialogs you have to confirm yourself, are in [docs/setup.md](docs/setup.md). After install, see [docs/usage.md](docs/usage.md). If something fails, see [docs/troubleshooting.md](docs/troubleshooting.md).

On a Mac that already has the project:

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig   # once; fill DEVELOPMENT_TEAM
cp Config/local_devices.env.example Config/local_devices.env     # once; fill this Watch’s UDID
./scripts/check-signing-prereqs.sh
# If the script says WWDR G3 is missing:
./scripts/check-signing-prereqs.sh --install-wwdr
./scripts/ship-encrypted-hogp.sh
./scripts/install-signed-watch-app.sh
```

The installer has a single readiness gate (a `connected` list entry is not enough). Do **not** run `./scripts/install-signed-watch-app.sh --check-ready` immediately before an install; that flag is a standalone probe for diagnosis only.

Then open WatchHID, confirm a Bluetooth pairing prompt if macOS shows one, short-drag on the pad, and run:

```bash
./scripts/verify-hogp-mouse.sh
```

Success is a WatchHID mouse node **plus** pointer movement you see yourself.

## Layout

```
Apps/Watch/     Watch app: HID peripheral, trackpad, Crown scroll, system dictation
Shared/         HID descriptors and input state
Config/         Tracked templates; local signing and device files are gitignored
scripts/        Build, install, signing preflight, verification, and unit tests
docs/           Setup, usage, troubleshooting, and simulator checks
project.yml     XcodeGen source
```

Local-only (gitignored): `Config/Developer.xcconfig`, `Config/local_devices.env`, and the entire `build/` tree.

## Limits

- Input works while WatchHID is in the foreground with the screen on. After the Watch sleeps or returns to the clock face, open the app again. Background and always-on input are not promised.
- An encrypted HOGP bond cannot be copied from another Mac. System Apple Watch pairing and iCloud do not bring it with you.
- Installing the Watch app uses the CoreDevice developer tunnel. A Bluetooth-connected Watch is not the same as a `connected` developer tunnel.
- Free personal-team provisioning usually expires in about seven days. Re-sign on this Mac with the same Apple ID.
- English keyboard HID is **off** by default. Turning it on can make macOS open Keyboard Setup Assistant; close it. WatchHID does not need that identification completed, and you should not identify it using another keyboard. There is no official guaranteed way to prevent the assistant.
- Do not put the keyboard on a composite Report Map together with the mouse on a host that already bonded the baseline 4-byte mouse map; that has produced vertical-only pointer movement.
- Digital Crown vertical scroll uses the existing mouse wheel field (no Report Map change) and is implemented in current source. Confirm it on a device running this build; it is not a substitute for a published compatibility matrix.
- This is not App Store approved, and it is not a claim that every Apple Watch or host OS has been verified.
- The Watch App Icon slot is empty: `Apps/Watch/Assets.xcassets/AppIcon.appiconset/` currently has only `Contents.json` (watchOS 1024×1024, no filename). A custom 1024×1024 PNG that survives a circular crop can be added later; none is included in this tree.

## Tests (no system input, no Bluetooth)

```bash
swiftc Shared/HIDDescriptors.swift Shared/HIDMetadata.swift Shared/KeyboardInputState.swift Shared/MouseInputState.swift \
  scripts/MouseInputStateTests.swift -o /tmp/watchhid-mouse-tests && /tmp/watchhid-mouse-tests
swiftc Shared/OutputHostRouting.swift scripts/OutputHostRoutingTests.swift \
  -o /tmp/watchhid-output-host-tests && /tmp/watchhid-output-host-tests
python3 scripts/test_watchhid_scriptlib.py
```

Simulator checks for the system text-input sheet (not speech recognition or BLE) are documented in [docs/SIMULATOR-CHECKS.md](docs/SIMULATOR-CHECKS.md).
