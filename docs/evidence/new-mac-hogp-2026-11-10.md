# Second-Mac encrypted HOGP path: evidence from 2026-11-10 (Asia/Shanghai)

This note separates what was observed from what was inferred. It does not print UDIDs, Bluetooth addresses, provisioning device lists, or hardcoded central identifiers. The shorter operator path is [setup.md](../setup.md).

## Confirmed

### Morning, unencrypted package (about 11:16)

BTLEServer read a WatchHID Device Information fingerprint (Manufacturer first logged as `<private>`, then “Apple Inc.”; PnP `BT / 0x004C / 0x0000 / 0x0001`, matching the default `pnpIDBytes`). The operator confirmed a pairing dialog. BTLEServer then refused to create an HID device: `Not creating HID device as the link is not encrypted`. That explains that one refusal. It does not prove this Mac had no bond at all. Confirming the prompt is a setup step, not proof that HID encryption succeeded. No WatchHID IOHID node appeared then.

### Encrypted package install (11:54)

The first encrypted zip used `WH_HOGP_ENCRYPTED` / `standard128-encrypted`: encrypted reads for the Report Map and input Report, and encrypted notifications for the input Report. Those characteristics do not also require encrypted writes.

At 11:54 the package was installed and launched over the local network, with the paired iPhone on the same Wi-Fi, unlocked, and no USB cable. That is one wireless-install observation. It does not mean an iPhone is always required, and it does not prove install works when no iPhone is nearby. An encrypted HOGP bond from another Mac cannot be copied onto this one.

### Before the afternoon passkey (13:24–13:58)

No pairing dialog appeared on the Watch or the Mac. A typical cycle was: Manufacturer often only “Apple Inc.” with no PnP, ATT 242, then `startAutoPairing`, then Pairing Failed reason 8 in about 60 ms (Unspecified Reason in the Bluetooth SMP spec; that is a spec mapping of the logged number, not a string the system printed), then ATT 15, and no visible prompt. The stack did start pairing; the peer aborted before a dialog could appear. WatchHID was not always in the foreground. Residual or conflicting LE bonds were possible, not proven.

### Passkey completed (14:01)

With WatchHID in the foreground and status `等待 Mac 系统订阅`, the host again read the WatchHID GATT fingerprint, including Report Map `0x2A4B` and Report `0x2A4D`. A Passkey Entry dialog appeared; the operator confirmed it on this Mac. Encryption was enabled (`isPairing=1`, `smpPairingCompleted status=0`). This Mac subscribed to the input Report, and BTLEServer started an `IOHIDUserDevice`. In the 14:00–14:03:50 window there was no ATT 242, ATT 15, reason 8, or “Not creating HID…”.

The HID mouse created in that window used the system Apple Watch identity, not `WatchHID` / `Ultra2-R1`. A short drag and tap did not move the pointer, and Watch status stayed on `等待 Mac 系统订阅`. Pairing and encryption on this Mac were confirmed; identity and movement were not, yet. The bond made at 14:01 was left in place.

### Why the pointer did not move on that older package (source, not a log reread)

In the package installed at that time, `macInputReady` and everyday `submitMouseReport` required the CCCD subscriber set to equal one hardcoded Mac central from the original development Mac. `WHUpdateReport` would notify every subscribed central once called (`onSubscribedCentrals: nil`), but the everyday path never called it when the set did not match. That explains a Watch that stays on `等待 Mac 系统订阅` after this Mac has already subscribed.

`dc02abf` changes the gate: the pad arms and reports are sent when at least one Report subscriber is present.

Default PnP uses Apple vendor ID `0x004C`. Source comments only speculate that this may encourage SameAccount merging. The system-identity node that afternoon was consistent with that comment, not proof of the mechanism.

### Local signing (15:36–15:39)

Xcode already showed a same-day Apple Development certificate in the keychain (blank status). `security find-identity -v -p codesigning` was still empty because the login and System keychains lacked WWDR G3 (only an expired WWDR with the same common name was present). This was not a missing private key, and it was not a reason to create another Development certificate.

Installing [AppleWWDRCAG3.cer](https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer) with `security add-certificates` into the login keychain prompted for the login keychain password. After the operator confirmed that dialog, the identity became valid. `./scripts/check-signing-prereqs.sh` passed, and `./scripts/ship-encrypted-hogp.sh` produced `build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip` (SHA-256 `c8c48cf1c361fcd5e813fdd314038bd50399375f0d79fa4e6be9455b806ebfde`). That password prompt was not certificate creation.

### Install and pointer (16:09–16:13)

An earlier install loop saw `tunnelState=connected` but the install script reported Watch developer state `unknown`. The device-list JSON has a CoreDevice UUID in `identifier` and the hardware UDID in `hardwareProperties.udid`. Matching only the first field skipped the device object and hit the nested hardware dict, which has no tunnel state. That matcher is fixed in `scripts/watchhid_scriptlib.py`.

After the fix, the locally signed package installed and launched while the tunnel was `connected`. The operator confirmed that the pointer could be controlled. `./scripts/verify-hogp-mouse.sh` reported `NODE_OK` for same-node Manufacturer `WatchHID`, ModelNumber `Ultra2-R1`, and Generic Desktop mouse/pointer usage.

## Still open

- Reconnect and restart reliability
- Wireless install or mouse use with no iPhone nearby
- Live dictation capture on this installed build
- English HID typing into the Mac (kept off)
- Whether Apple-vendor PnP can still merge identity on some hosts after the gate is open
