---
name: WatchHID new-Mac HOGP
description: Install or enable WatchHID as a system mouse on a new Mac, or when this Mac has no reusable encrypted HOGP bond. Do not copy another Mac’s Bluetooth bond, and do not reset system Bluetooth.
---

# WatchHID on a new Mac

Read [docs/setup.md](../../../docs/setup.md) first. Usage is in [docs/usage.md](../../../docs/usage.md). If something fails, use [docs/troubleshooting.md](../../../docs/troubleshooting.md). Evidence from 2026-11-10 is in [docs/evidence/new-mac-hogp-2026-11-10.md](../../../docs/evidence/new-mac-hogp-2026-11-10.md).

Success is both of these; do not mix them up:

1. `./scripts/verify-hogp-mouse.sh` reports `NODE_OK` (same-node `WatchHID` / `Ultra2-R1` with mouse/pointer usage). That is identity only, not pointer movement.
2. The operator sees the pointer move on a safe blank desktop.

A Bluetooth-connected Watch (including HID BLE), a confirmed pairing prompt, a connected developer tunnel, or Watch status still on `等待 Mac 系统订阅` is not success.

## Do not

- Do not copy an encrypted HOGP bond, Bluetooth preferences, or a keychain from another Mac.
- Do not reset system Bluetooth or unpair the system Apple Watch.
- Do not print or commit UDIDs, Bluetooth addresses, provisioning device lists, or hardcoded central identifiers. Use `python3 scripts/watchhid_scriptlib.py provision-info ./WatchHIDWatchApp.app` instead of pasting `security cms -D`.
- Do not send passwords or codes in chat. Confirm signing and keychain prompts in official dialogs.
- Do not install onto a different Watch when the configured UDID does not match.

## Scripted path

1. Copy `Config/Developer.xcconfig.example` and `Config/local_devices.env.example` to the gitignored local names. Fill `DEVELOPMENT_TEAM` and `WATCH_UDID`.
2. Run `./scripts/check-signing-prereqs.sh`. If it reports a missing WWDR G3 intermediate, run `./scripts/check-signing-prereqs.sh --install-wwdr` and confirm the login keychain password or Allow prompt. That installs Apple’s official intermediate; it does not create a Development certificate. Only use **Manage Certificates… > +** when preflight says there is no identity on this Mac. If **+** says a current Development certificate already exists, stop and fix trust instead of revoking another Mac’s certificate.
3. Run `./scripts/ship-encrypted-hogp.sh` (without `--install` first). Confirm any codesign keychain prompt.
4. When `devicectl` shows this Watch as `connected`, run `./scripts/install-signed-watch-app.sh`. Wake and unlock the Watch, and unlock the paired iPhone on the same Wi-Fi if the tunnel is down. Do not reset Bluetooth.
5. Keep WatchHID in the foreground. Confirm a Bluetooth passkey dialog if macOS shows one. Short-drag, then run `./scripts/verify-hogp-mouse.sh`, and confirm movement visually.

Current source (`dc02abf` and later) accepts any Report CCCD subscriber. Install that before judging a new Mac. On 2026-11-10 a second Mac completed pairing, encryption, `NODE_OK`, and pointer movement after that package was installed.
