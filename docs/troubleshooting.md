# Troubleshooting

Do not reset system Bluetooth, unpair the system Apple Watch, clear Bluetooth caches, or turn off security settings to “fix” a problem. If this Mac just completed an HOGP pairing, leave that bond alone.

Do not print UDIDs, Bluetooth addresses, or provisioning device lists in chat or git.

| What you see | How to read it | What not to do |
|---|---|---|
| Status is Ready, two devices are listed, but the iPhone or this Mac does not move | Ready means a host has subscribed, not that the device you are watching already received input. Reports go to only one selected Device N. Open Settings, pick the other device, tap Test or drag, and watch that machine. The app no longer labels hosts as Mac or iPhone. | Do not reset Bluetooth. Do not assume the missing movement means the bond is gone. |
| Pointer does not move, but Bluetooth or Device Hub shows the Watch as connected | Open WatchHID in the foreground and check the status text. Confirm a passkey dialog if one is showing. A connected HID BLE entry, or a confirmed prompt, is not success by itself. If status stays on `等待 Mac 系统订阅`, install a build at `dc02abf` or later: older builds required one hardcoded Mac central. | Do not unpair the Watch or reset Bluetooth. |
| Status stays on `等待 Mac 系统订阅` after this Mac subscribed | On builds before `dc02abf`, the input gate ignored any central that was not a hardcoded identifier from the original development Mac. Current source accepts any Report CCCD subscriber. | Do not reset the bond. Rebuild and install from current source on this Mac. |
| `verify-hogp-mouse.sh` prints `NODE_OK` but you are unsure about the pointer | The script only checks same-node identity (`WatchHID` / `Ultra2-R1` plus mouse/pointer usage). Movement is a separate human check. | Do not treat `NODE_OK` as a cursor-movement pass. |
| The HID node is `Apple Inc.` / `Watch7,5` (the system Apple Watch) and the pointer does not move | This was seen on a new Mac with an older encrypted package, before the input-gate fix was installed. After installing a current package, the same Mac showed `WatchHID` / `Ultra2-R1` and the pointer moved. If a current package still shows only the system identity, keep the bond and investigate Device Information / PnP separately. | Do not reset Bluetooth to force a new identity. |
| Mac is locked | Probe failures on a locked Mac are not evidence that the app is broken. Unlock, then test the pointer. | Do not bypass the lock or change security settings for a test. |
| `devicectl` shows the Watch as `connected`, but install fails with “Failed to allocate RSD device” (CoreDevice -1 / mobiledevice -402653181) | The list state is not a sufficient gate. Probe details and DDI, or run `./scripts/install-signed-watch-app.sh --check-ready`, and only then install. On 2026-11-10 the same signed package installed after those probes succeeded. Signing was not the cause. | Do not reset Bluetooth. Do not revoke or replace certificates. Do not keep retrying install in a tight loop. |
| macOS shows Keyboard Setup Assistant (“new keyboard”) | Apple’s Mac User Guide says this assistant opens when a keyboard is not immediately recognized, so you can specify ANSI, ISO, or JIS. Close it. There is no official documented way in this project to guarantee it will not appear while a keyboard HID service is present. | Do not disable or move the system assistant, edit `/Library` keyboard-type preferences, reset Bluetooth, or change the working mouse HID identity or Report Map. |
| `devicectl` shows `unavailable` or only `available (paired)` | The developer tunnel is down. Wake and unlock the Watch, unlock the paired iPhone, join the same Wi-Fi if you can, and wait for `connected`. A USB cable is not required. | Do not reset Bluetooth to “open” the developer connection. Do not treat Bluetooth-connected as install-ready. |
| Install script says the Watch is `unknown` even though the device list shows `connected` | An older matcher used only the first identifier field. CoreDevice puts a UUID in `identifier` and the Watch UDID in `hardwareProperties.udid`. Current `watch_developer_state` matches either. | Do not install onto a different Watch. Do not reset Bluetooth. |
| Signed install is rejected | The development profile may have expired, or this Watch is not in the profile. Re-sign on this Mac as in [setup.md](setup.md). Free profiles usually last about seven days. | Do not copy private keys or login tokens from another Mac. |
| `find-identity -v` is empty, but Xcode shows a certificate in the keychain | Often a missing WWDR G3 intermediate, not a missing private key. Run `./scripts/check-signing-prereqs.sh --install-wwdr`. | Do not click **+** yet. Do not revoke another Mac’s certificate. Do not delete this Mac’s certificate before checking trust. |
| Xcode **+** says a current Development certificate or pending request already exists | A certificate is already present. Check WWDR G3 and trust first. | Do not revoke another machine’s certificate to make room. |
| No pairing prompt, and Manufacturer is only “Apple Inc.” with no project PnP | WatchHID is often not in the foreground, so the host reads system Apple Watch Device Information. Automatic pairing may abort in tens of milliseconds with SMP reason 8, before a dialog can appear. Open WatchHID, keep the screen on, and wait for a prompt if this is the first bond on this Mac. | Do not assume the system never requested pairing. Do not reset Bluetooth. |
| Pointer worked, then stopped after reinstall or after the app went inactive | ATT status 242 can still appear during some launches, and the host may not recreate the mouse node yet. Exit and reopen WatchHID. Keep local logs under `build/diagnostics/`. | Do not unpair, clear caches, or treat a simulator pass as a device recovery. |

## Signing preflight

```bash
./scripts/check-signing-prereqs.sh
```

If it reports a trust failure, install the official intermediate and check again:

```bash
./scripts/check-signing-prereqs.sh --install-wwdr
```

Confirm the keychain password or Allow prompt. That writes Apple’s WWDR G3 intermediate; it does not create a Development certificate.

## Install and verify

```bash
./scripts/install-signed-watch-app.sh --check-ready
./scripts/install-signed-watch-app.sh
./scripts/verify-hogp-mouse.sh
```

Historical recovery notes and earlier experiment logs live under [research/](research/).
