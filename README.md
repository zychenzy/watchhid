**English** | [简体中文](README.zh-CN.md)

# WatchHID

Use an Apple Watch as a Bluetooth LE HID mouse, with optional English dictation typing, on a Mac. No extra hardware, and no helper app on the Mac for the pointer.

The Watch UI follows the Watch system language (English, Simplified Chinese, Traditional Chinese). Tests in this repository are English only. Documentation is provided in English and Simplified Chinese.

## Features

- Watch-only app: no WatchHID companion on iPhone (a paired iPhone is still a watchOS requirement, and some privacy controls may live on the phone)
- Standard Bluetooth LE HOGP mouse; a bonded host treats it as a system pointer
- Optional English keyboard on a **separate** HID service — the baseline 4-byte mouse Report Map stays unchanged
- Full-screen trackpad, Digital Crown vertical scroll (existing mouse wheel field), and system dictation (`presentTextInputController`)
- Reports go to one selected host at a time (Device 1, Device 2, …)

## Requirements

You need these to build and sideload the app. They are not a tested-device matrix.

- A Mac with full Xcode (not only Command Line Tools)
- An Apple Watch with Developer Mode enabled
- The iPhone that Watch is paired with
- An Apple account that can sign a watchOS app in Xcode: a free Personal Team or a paid Apple Developer Program membership

Do not commit device UDIDs, team IDs, private keys, or provisioning profiles. Put them in the gitignored files copied from `Config/`.

Signing details, including official 7-day limits that apply to a **free Personal Team only**, are in [docs/setup.md](docs/setup.md). This project is not an App Store submission.

## Tested setup

Operator-confirmed results, **not** a general Watch, Mac, or iOS matrix. Other Apple Watch models are unverified; they are not declared unsupported and not guaranteed.

- **Pointer and clicks** on more than one Mac, with the current one-host Device 1 / Device 2 routing
- **Apple Watch Ultra 2** was the hardware used in that testing
- **iPhone as a HID host** was confirmed once away from a Mac; that is a personal confirmation, not an iOS-version matrix
- **English dictation into a Mac** works through the system text-input sheet when typable English is accepted and keyboard HID is on. The Watch does not show the captured text. The system may open a keyboard or Scribble first; there is no public API that forces dictation-first

The current build advertises HID manufacturer `WatchHID` and model `Ultra2-R1`. That is the app’s advertised identity string, not a requirement that the hardware be an Ultra 2.

## Install

Follow [docs/setup.md](docs/setup.md) for signing, dialogs you must confirm yourself, and Bluetooth permission. On a Mac that already has the project:

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig   # once; fill DEVELOPMENT_TEAM
cp Config/local_devices.env.example Config/local_devices.env     # once; fill this Watch’s UDID
./scripts/check-signing-prereqs.sh
# If the script reports a missing WWDR G3 certificate, see docs/setup.md
./scripts/ship-encrypted-hogp.sh
./scripts/install-signed-watch-app.sh
```

The installer has one readiness gate. Do not run `--check-ready` immediately before install. After install, open WatchHID, confirm a Mac Bluetooth pairing prompt if it appears, short-drag on the pad, then:

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` is same-node HID identity only. Success is that node **plus** pointer movement you see yourself.

## Usage

See [docs/usage.md](docs/usage.md) for gestures, output selection, and dictation.

- Drag to move, tap for left click, hold for right click, Crown to scroll (generic Digital Crown, not an Ultra Action button)
- Input only while the app is in the foreground with the screen on
- English keyboard HID is off by default; if Keyboard Setup Assistant appears, close it
- If the system sheet opens a keyboard first, switch to the microphone, then tap Done
- To use an iPhone as the pointer host, enable **Settings > Accessibility > Touch > AssistiveTouch** on that iPhone. This is a system setting on the target iPhone, not a WatchHID companion app, and it is separate from Watch Bluetooth privacy on the paired iPhone.

## Limitations

- `CBPeripheralManager` is `API_UNAVAILABLE(watchos)`. This project creates the peripheral at runtime. That is **not** a supported Apple API, not App Store approved, and not a guarantee for future watchOS releases.
- Encrypted HOGP bonds are not transferable through system Apple Watch pairing or iCloud.
- A Bluetooth-connected Watch is not the same as a `connected` CoreDevice developer tunnel used for install.
- Free Personal Team provisioning follows Apple’s 7-day cycle; that is not described here as a paid-membership rule.
- Do not put keyboard and mouse on one composite Report Map on a host that already bonded the baseline 4-byte mouse map (that has produced vertical-only movement).
- Crown scroll is implemented in current source; confirm it on a device running this build.
- The Watch App Icon slot is still empty (watchOS 1024×1024 well, no PNG yet).

## Docs

- [Setup](docs/setup.md) — signing, build, install, and permission
- [Usage](docs/usage.md) — trackpad, Crown, dictation, output device
- [Troubleshooting](docs/troubleshooting.md)
- [Simulator checks](docs/SIMULATOR-CHECKS.md) — system text-input UI tests, not speech or BLE
- [Architecture notes](docs/architecture.md) — how this project works, and a comparison with a related HOGP app (no code shared)
- [Docs index](docs/INDEX.md)

Logic tests (no Bluetooth, no system input) and the repository layout are listed in the docs index.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
