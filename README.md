# WatchHID

Use an Apple Watch as a **real Bluetooth LE HID mouse** for a paired Mac.

## Status (2026-11-09 HKT)

| Path | Status |
|---|---|
| **Mac direct BLE mouse / Watch touchpad** | **Accepted by owner after live move + click** on Mac mini |
| iPhone system HID / AssistiveTouch / UU remote path | **Not achieved** |
| watchOS `CBPeripheralManager` | Runtime-created via existing factory; **SDK marks peripheral APIs `API_UNAVAILABLE(watchos)`** — works empirically on this setup, **no supported stability guarantee** |

Tonight’s usable surface is the Watch **Mac 触控板** UI: explicit enable, large finger drag pad, separate left-click. Default is no motion/click.

## Limits (honest)

- **Foreground / screen-off:** input stops on inactive/background; after sleep or return-to-clock you may need to reopen and tap **启用输入** again. No claimed continuous 75s window, no screen-off background mouse, no fake workout / extended-runtime category.
- **SDK unavailable:** peripheral role is unsupported in public watchOS SDK headers; this project uses the already-present runtime factory. That is not proof of future OS compatibility.
- **Input gate (source vs installed package):** Current source (`dc02abf` and later) arms the pad and sends reports when at least one Report CCCD subscriber is present; it no longer requires one hardcoded Mac central. The encrypted package still installed on the Watch (as of 2026-11-10) is the older exact-match build, so a new Mac can subscribe and still see `等待 Mac 系统订阅` until that source is signed and installed. Do not print the old identifier. Pairing and encryption on a new Mac were evidenced at 14:01 Asia/Shanghai that day; WatchHID identity and pointer movement are still open. Do not reset that bond.
- **iPhone:** App-level GATT discovery/read was sometimes possible; **system mouse acceptance was not**.

## Layout

```
Apps/Watch/     Watch app: dynamic HID peripheral + Mac touchpad UI
Apps/iOS/       Companion / diagnostics (not required for Mac mouse use)
Shared/         HID descriptors + pure MouseInputState
Config/         Developer.xcconfig.example + local_devices.env.example
scripts/        build, pure logic tests, sanitized diagnostic runners
docs/           INDEX + experiment notes (no raw logs/screenshots in git)
project.yml     XcodeGen source
```

Local-only (gitignored): `Config/Developer.xcconfig`, `Config/local_devices.env`, entire `build/` tree (diagnostics, DerivedData copies, screenshots, logs).

## Build / sign

Setting up Xcode and a signing identity on a new Mac: [`docs/SETUP.zh-CN.md`](docs/SETUP.zh-CN.md) §4. The Mac login / iCloud account may differ from the Xcode signing Apple ID; do not switch the system account just to sign. Use the existing developer Apple ID and the same team. Create an **Apple Development** certificate on this Mac via Xcode > Settings > Accounts > the team > Manage Certificates… > “+”; the private key stays in this Mac’s Keychain. Do not copy private keys from another Mac, and do not revoke another machine’s certificate just to make room unless the owner explicitly approves. Installing a still-valid already-signed Watch `.app` does not require a local certificate.

Unsigned simulator compile:

```bash
./scripts/build.sh
```

Signed Watch device build (free personal team):

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig   # once
# put your DEVELOPMENT_TEAM into Config/Developer.xcconfig
xcodegen generate
xcodebuild -project WatchHID.xcodeproj -scheme WatchHIDWatchApp \
  -destination 'generic/platform=watchOS' -configuration Debug \
  -derivedDataPath build/DerivedData-nudge -jobs 2 build
xcrun devicectl device install app --device "$WATCH_UDID" \
  build/DerivedData-nudge/Build/Products/Debug-watchos/WatchHIDWatchApp.app
```

Free Apple ID signing typically needs manual re-sign about every 7 days. Prefer Xcode Run if `devicectl` activation is flaky. Phone USB is **not** required for the Mac BLE HID path once Watch is installed, and it is not required for a wireless developer install either; the Watch and the paired iPhone should be nearby, unlocked, and preferably on the same Wi-Fi until `devicectl` shows the Watch as `connected`. Use `./scripts/install-signed-watch-app.sh` rather than calling `devicectl` by hand. A Bluetooth-connected Watch is not the same as a connected developer tunnel.

## Use on Mac (owner-verified flow)

1. On the Mac, move the pointer to a **safe blank area**.
2. Open **WatchHID** on the Watch.
3. When status shows **Mac 已订阅 · 待启用**, tap **启用输入**.
4. Drag on the large pad (relative move). Lift to stop. Optional: tap **左键单击** once if the location is safe.
5. Tap **停用输入** when finished.

Advertising of the known `standard128-dynamic` recipe can start on launch; **input never auto-enables** and never injects motion/click by itself.

## Tests (no system input)

```bash
swiftc Shared/MouseInputState.swift scripts/MouseInputStateTests.swift \
  -o /tmp/watchhid-mouse-tests && /tmp/watchhid-mouse-tests
python3 scripts/test_assess_live_read.py
```

## Proven vs not proven

**Proven on the original Mac mini:** Mac system IOHID node with Manufacturer `WatchHID`, Model `Ultra2-R1`, 4-byte report map matching `Shared/HIDDescriptors.swift`; owner-confirmed pointer move + click via Watch touchpad over BLE.

**Proven on a new Mac (2026-11-10, Asia/Shanghai), and still open:** pairing and encryption can complete, and BTLEServer can start an `IOHIDUserDevice`. The created mouse node used the system Apple Watch identity (`Apple Inc.` / `Watch7,5`), not `WatchHID` / `Ultra2-R1`, and a short drag + tap did not move the pointer. The encrypted path is not yet a quickly reliable success. Details: [`docs/new-mac-hogp-2026-11-10.zh-CN.md`](docs/new-mac-hogp-2026-11-10.zh-CN.md).

**Not proven:** iPhone system HID binding, UU remote use, cold-cache GATT claims, always-on/background mouse, or that SDK-unavailable APIs remain available on future watchOS.

## Docs

Once the project is on this Mac, the default rebuild path is a local Apple Development identity plus `./scripts/ship-encrypted-hogp.sh`. Check tools, the gitignored `Config/Developer.xcconfig`, and a usable identity (certificate + private key) with `./scripts/check-signing-prereqs.sh`. A still-valid pre-signed zip can be installed without a local cert, but that is not the preferred rebuild path, and the previous signing Mac is not required for packaging. New Mac prerequisites, developer-tunnel vs Bluetooth, and the encrypted HOGP path (pairing and encryption evidenced on a new Mac on 2026-11-10; WatchHID identity and pointer movement still open, so not yet a quickly reliable success): [`docs/SETUP.zh-CN.md`](docs/SETUP.zh-CN.md). Same-day evidence: [`docs/new-mac-hogp-2026-11-10.zh-CN.md`](docs/new-mac-hogp-2026-11-10.zh-CN.md). Reusable steps: [`.cursor/skills/watchhid-new-mac-hogp/SKILL.md`](.cursor/skills/watchhid-new-mac-hogp/SKILL.md). Scripts: `scripts/check-signing-prereqs.sh`, `scripts/ship-encrypted-hogp.sh`, `scripts/install-signed-watch-app.sh`, `scripts/verify-hogp-mouse.sh`. Return checklist: [`docs/RETURN-CHECKLIST.zh-CN.md`](docs/RETURN-CHECKLIST.zh-CN.md). Index: [`docs/INDEX.md`](docs/INDEX.md). Raw syslog/screenshot/crash packages stay under local `build/diagnostics/` and are not part of the git tree. Do not commit private keys, `.p12`/`.cer`, or provisioning profiles.

## Explicitly out of scope

External chips, Mac accessibility/helper injection as the mouse path, unpairing/BT reset as a “fix”, cloud push of private device logs, or claiming iPhone success.

## Current local candidate

Chinese quick start and honest acceptance limits: [回来后试用](docs/QUICKSTART.zh-CN.md). Recovery evidence and regression matrix: [HOGP recovery](docs/HOGP-RECOVERY.md). Signed current/rollback archives remain local under `build/diagnostics/recovery-root/`; no release or push is implied.
